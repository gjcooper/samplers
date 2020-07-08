#' Extract relevant samples from the list for conditional dist calc
#'
#' From the sampler, extract relevant samples for the creation of
#' the proposal distribution.
#'
#' @param sampler The pmwgs object containing the samples
#' @param stage The stage, or list of stages from which you want the samples
#'
#' @return A list containing only appropriate samples (non init/burnin samples)
#' @examples
#' # No example yet
#' @keywords internal
extract_samples <- function(sampler, stage = c("adapt", "sample")) {
  samples <- sampler$samples
  sample_filter <- samples$stage %in% stage
  list(
    theta_mu = samples$theta_mu[, sample_filter],
    theta_sig = samples$theta_sig[, , sample_filter],
    alpha = samples$alpha[, , sample_filter]
  )
}


#' Unwinds variance matrix to a vector
#'
#' Takes a variance matrix and unwind to a vector via Cholesky decomposition
#' then take the log of the diagonal.
#'
#' @param var_matrix A variance matrix
#'
#' @return The unwound matrix as a vector
#' @examples
#' pmwg:::unwind(diag(rep(1, 7)))
#' @keywords internal
unwind <- function(var_matrix, ...) {
  y <- t(chol(var_matrix))
  diag(y) <- log(diag(y))
  y[lower.tri(y, diag = TRUE)]
}

#' Winds a variance vector back to a vector
#'
#' The reverse of the unwind function, takes a variance vector and windows back
#' into matrix
#'
#' @param var_vector A variance vector
#'
#' @return The wound vector as a matrix
#' @examples
#' pmwg:::wind(diag(rep(1, 7)))
#' @keywords internal
wind <- function(var_vector, ...) {
  n <- sqrt(2 * length(var_vector) + 0.25) - 0.5 ## Dim of matrix.
  if ((n * n + n) != (2 * length(var_vector))) stop("Wrong sizes in unwind.")
  out <- array(0, dim = c(n, n))
  out[lower.tri(out, diag = TRUE)] <- var_vector
  diag(out) <- exp(diag(out))
  out %*% t(out)
}


#' Create a new list for storage samples in the pmwgs object
#'
#' @param par_names The names of each parameter as a character vector
#' @param n_subjects The number of subjects for the subject mean storage.
#' @param iters The number of iterations to be pre-allocated
#' @param stage The stage for which the samples will be created. Should be one
#'   of \code{c("init", "burn", "adapt", "sample")}
#'
#' @return A list containing the conditional mean and variances for this subject
#' @examples
#' # No example yet
#' @keywords internal
sample_store <- function(par_names, n_subjects, iters = 1, stage = "init") {
  n_pars <- length(par_names)
  list(
    alpha = array(
      NA_real_,
      dim = c(n_pars, n_subjects, iters),
      dimnames = list(par_names, NULL, NULL)
    ),
    theta_mu = array(
      NA_real_,
      dim = c(n_pars, iters),
      dimnames = list(par_names, NULL)
    ),
    theta_sig = array(
      NA_real_,
      dim = c(n_pars, n_pars, iters),
      dimnames = list(par_names, par_names, NULL)
    ),
    stage = array(stage, iters),
    subj_ll = array(
      NA_real_,
      dim = c(n_subjects, iters),
      dimnames = list(NULL, NULL)
    ),
    a_half = array(
      NA_real_,
      dim = c(n_pars, iters),
      dimnames = list(par_names, NULL)
    )
  )
}


#' Update the main data store with the results of the last stage
#'
#' @param sampler The pmwgs object that we are adding the new samples to
#' @param store The sample storage stage just run
#'
#' @return The pmwgs object with the new samples concatenated to the old
#' @examples
#' # No example yet
#' @keywords internal
update_sampler <- function(sampler, store) {
  old_tmu <- sampler$samples$theta_mu
  old_tsig <- sampler$samples$theta_sig
  old_alpha <- sampler$samples$alpha
  old_stage <- sampler$samples$stage
  old_sll <- sampler$samples$subj_ll
  old_a_half <- sampler$samples$a_half
  li <- store$idx

  sampler$samples$theta_mu <- array(c(old_tmu, store$theta_mu[, 1:li]),
                                      dim = dim(old_tmu) + c(0, li))
  sampler$samples$theta_sig <- array(c(old_tsig, store$theta_sig[, , 1:li]),
                                     dim = dim(old_tsig) + c(0, 0, li))
  sampler$samples$alpha <- array(c(old_alpha, store$alpha[, , 1:li]),
                                        dim = dim(old_alpha) + c(0, 0, li))
  sampler$samples$idx <- ncol(sampler$samples$theta_mu)
  sampler$samples$last_theta_sig_inv <- store$last_theta_sig_inv
  sampler$samples$stage <- c(old_stage, store$stage[1:li])
  sampler$samples$subj_ll <- array(c(old_sll, store$subj_ll[, 1:li]),
                                   dim = dim(old_sll) + c(0, li))
  sampler$samples$a_half <- array(c(old_a_half, store$a_half[, 1:li]),
                                      dim = dim(old_a_half) + c(0, li))
  sampler
}


#' Create a list with the last samples in the pmwgs object
#'
#' @param store The list containing samples from which to grab the last.
#'
#' @return A list containing the last sample of group mean and variance and
#'   subject means.
#' @examples
#' # No example yet
#' @keywords internal
last_sample <- function(store) {
  list(
    tmu = store$theta_mu[, store$idx],
    tsig = store$theta_sig[, , store$idx],
    alpha = store$alpha[, , store$idx],
    tsinv = store$last_theta_sig_inv,
    a_half = store$a_half[, store$idx]
  )
}
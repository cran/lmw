get_w_from_X <- function(X, treat, method, base.weights = NULL, s.weights = NULL, dr.method = "WLS",
                         fixef = NULL) {

  if (is.null(s.weights)) s.weights <- rep(1, nrow(X))

  w <- s.weights
  if (!is.null(base.weights) && dr.method != "AIPW") {
    w <- w * base.weights
  }

  if (method == "URI") {
    t <- X[,2]
  }

  if (!is.null(fixef)) {
    if (!is.null(base.weights) && dr.method == "AIPW") {
      chk::err("fixed effects cannot be used with AIPW")
    }
    for (i in seq_len(ncol(X))) {
      X[,i] <- demean(X[,i], fixef, w)
    }
  }

  rw <- sqrt(w)
  qr_X <- qr(rw*X)
  p <- qr_X$rank

  XtX1 <- chol2inv(qr_X$qr[1:p, 1:p, drop = FALSE])

  #Remove linearly dependent columns
  X <- X[, qr_X$pivot[1:p], drop = FALSE]

  if (method == "URI") {
    #Treated group dummy always in second column
    weights <- drop(w * (X %*% XtX1[, qr_X$pivot[1:p] == 2, drop = FALSE]))
    weights[t == 0] <- -weights[t == 0]
  }
  else { #MRI
    weights <- rep(0, length(treat))
    for (i in seq_len(nlevels(treat))) {
      in_t <- which(treat == levels(treat)[i])
      if (i %in% qr_X$pivot[1:p]) {
        weights[in_t] <- w[in_t] * (X[in_t,,drop = FALSE] %*% XtX1[, qr_X$pivot[1:p] == i, drop = FALSE])
      }
      else {
        weights[in_t] <- -w[in_t] * (X[in_t,,drop = FALSE] %*% XtX1[, 1, drop = FALSE])
      }
    }
  }

  if (!is.null(base.weights) && dr.method == "AIPW") {

    ipw.weights <- base.weights * s.weights
    for (i in levels(treat)) {
      ipw.weights[treat == i] <- ipw.weights[treat == i]/sum(ipw.weights[treat == i])
    }
    ipw.weights_rw <- ipw.weights/rw
    ipw.weights_rw[rw == 0] <- 0

    if (method == "URI") {
      #For multicategory treatments, set base.weights of groups not
      # involved in contrast to 0
      if (nlevels(treat) > 2) ipw.weights_rw[!treat %in% levels(treat)[1:2]] <- 0

      #Funky formula for augmentation weights, but it works
      ipw.weights_rw[t == 0] <- -ipw.weights_rw[t == 0]
      aug.weights <- rw * .lm.fit(rw * X, ipw.weights_rw)$residuals
      aug.weights[t == 0] <- -aug.weights[t == 0]
    }
    else { #MRI
      aug.weights <- rw * .lm.fit(rw * X, ipw.weights_rw)$residuals
    }

    weights <- weights + aug.weights
  }

  weights <- drop(weights)

  #Rescale weights to have a mean of 1 in each group
  if (method == "URI" && nlevels(treat) > 2) {
    for (i in 0:1) {
      weights[t == i] <- weights[t == i] / mean(weights[t == i])
    }
  }
  else {
    for (i in levels(treat)) {
      weights[treat == i] <- weights[treat == i] / mean(weights[treat == i])
    }
  }

  weights
}

get_w_from_X_iv <- function(X, A, treat, method, base.weights = NULL, s.weights = NULL, fixef = NULL) {
  #X should be from get_1st_stage_X_from_formula_iv()$X
  #A should be from get_1st_stage_X_from_formula_iv()$A

  iv_names <- attr(X, "iv_names")

  if (is.null(s.weights)) s.weights <- rep(1, nrow(X))

  w <- s.weights
  if (!is.null(base.weights)) {
    w <- w * base.weights
  }

  rw <- sqrt(w)

  #Remove linearly dependent columns
  qr_X <- qr(rw * X)
  X <- X[, qr_X$pivot[seq_len(qr_X$rank)], drop = FALSE]

  if (!is.null(fixef)) {
    for (i in seq_len(ncol(X))) {
      X[,i] <- demean(X[,i], fixef, w)
    }
    for (i in seq_len(ncol(A))) {
      A[,i] <- demean(A[,i], fixef, w)
    }
  }

  iv_ind <- which(colnames(X) %in% iv_names)

  weights_ <- rw * .lm.fit(rw * X[,-iv_ind, drop = FALSE], rw * A)$residuals -
    rw * .lm.fit(rw * X, rw * A)$residuals

  if (ncol(A) == 1) {
    weights <- weights_ #/ sum(A * weights_)
    weights[treat == levels(treat)[1]] <- -weights[treat == levels(treat)[1]]
  }
  else {
    #Scaling factor is a [ncol(A) x 1] vector (solve(t(A) %*% weights_)[,1])
    weights <- weights_ %*% solve(crossprod(A, weights_), c(1, rep(0, ncol(A) - 1)))
    weights[treat == levels(treat)[1]] <- -weights[treat == levels(treat)[1]]
  }

  #Rescale weights to have a mean of 1 in each group
  for (i in levels(treat)) {
    weights[treat == i] <- weights[treat == i] / mean(weights[treat == i])
  }

  weights
}

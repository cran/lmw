get_X_from_formula <- function(formula, data, treat, method, estimand, target = NULL,
                               s.weights = NULL, target.weights = NULL, focal = NULL,
                               treat_fixed = NULL) {
  formula <- delete.response(terms(formula, data = data))

  #Extract treatment variable
  treat_name <- attr(treat, "treat_name")

  #Process formula, removing treatment variable
  formula_without_treat <- remove_treat_from_formula(formula, treat_name)

  mf <- model.frame(formula_without_treat, data = data, na.action = "na.pass")

  if (anyNA(mf)) {
    chk::err("missing values are not allowed in the covariates")
  }

  mf <- process_mf(mf)

  covs <- model.matrix(formula_without_treat, data = mf)

  assign <- attr(formula_without_treat, "term.labels")[attr(covs, "assign")[-1]]
  covs <- covs[,-1, drop = FALSE]

  #Process target when estimand = "CATE"
  if (estimand == "CATE") {
    target <- process_target(target, formula_without_treat, mf, target.weights)
  }

  #Center covariates at mean based on estimand; only affects weights if there
  #are interactions w/ treatment
  covs <- center_covs(covs, treat, target, s.weights, focal)

  if (is.null(treat_fixed)) {
    t_mat <- do.call("cbind", lapply(levels(treat)[-1], function(j) as.numeric(treat == j)))
  }
  else {
    t_mat <- matrix(as.numeric(levels(treat)[-1] == treat_fixed),
                    nrow = nrow(covs), ncol = nlevels(treat)-1,
                    byrow = TRUE)
  }
  colnames(t_mat) <- paste0(treat_name, levels(treat)[-1])

  if (method == "URI") {
    #Reconstruct X from centered covs by multiplying covs that interact with treat
    #by treat
    interacts_with_treat <- attr(formula_without_treat, "interacts_with_treat")
    new.f.terms <- attr(formula_without_treat, "new.f.terms")
    X <- do.call("cbind", lapply(seq_along(new.f.terms), function(i) {
      if (interacts_with_treat[i]) {
        do.call("cbind", lapply(which(assign == new.f.terms[i]), function(j) {
          out_ <- t_mat * covs[,j]
          colnames(out_) <- paste(colnames(t_mat), colnames(covs)[j], sep = ":")
          out_
        }))
      }
      else {
        covs[,assign == new.f.terms[i], drop = FALSE]
      }
    }))

    #Add treatment and intercept to X
    X <- cbind(1, t_mat, X)
    colnames(X)[1] <- "(Intercept)"
  }
  else if (method == "MRI") {
    #Reconstruct X from centered covs by multiplying all covs by treat and adding
    #treat and intercept
    covs_int <- do.call("cbind", lapply(seq_len(ncol(covs)), function(i) {
      out <- t_mat * covs[,i]
      colnames(out) <- paste(colnames(t_mat), colnames(covs)[i], sep = ":")
      out
    }))

    X <- cbind(1, t_mat, covs, covs_int)
    colnames(X)[1] <- "(Intercept)"
  }

  attr(mf, "terms") <- NULL

  list(X = X, mf = mf, target = target)
}

center_covs <- function(covs, treat, target = NULL, s.weights = NULL, focal = NULL) {
  if (!is.null(focal)) {
    sweep(covs, 2L, colMeans_w(covs, s.weights, subset = treat == focal), check.margin = FALSE)
  }
  else if (!is.null(target)) {
    sweep(covs, 2L, target, check.margin = FALSE)
  }
  else {
    sweep(covs, 2L, colMeans_w(covs, s.weights), check.margin = FALSE)
  }
}

remove_treat_from_formula <- function(formula, treat) {
  tt.factors <- attr(terms(formula), "factors")

  if (NCOL(tt.factors) > 0) {
    tt.factors <- tt.factors[, colnames(tt.factors) != treat, drop = FALSE]
  }

  #Extract terms that interact w/ treat
  new.f.terms <- colnames(tt.factors)
  interacts_with_treat <- {
    if (treat %in% rownames(tt.factors)) tt.factors[treat,] > 0
    else rep(FALSE, NCOL(tt.factors))
  }

  #Remove treat from interactions
  for (i in seq_along(new.f.terms)[interacts_with_treat]) {
    new.f.terms[i] <- paste(rownames(tt.factors)[rownames(tt.factors) != treat & tt.factors[, i] != 0], collapse = ":")
  }

  #Reconstruct formula and dataset without treat
  formula_without_treat <- {
    if (length(new.f.terms) == 0) terms(~1)
    else terms(reformulate(new.f.terms, intercept = TRUE))
  }

  attr(formula_without_treat, "new.f.terms") <- new.f.terms
  attr(formula_without_treat, "interacts_with_treat") <- setNames(interacts_with_treat, new.f.terms)

  formula_without_treat
}

get_1st_stage_X_from_formula_iv <- function(formula, data, treat, iv, method, estimand, target = NULL,
                                            s.weights = NULL, target.weights = NULL, focal = NULL) {
  formula <- delete.response(terms(formula, data = data))

  #Extract treatment variable
  treat_name <- attr(treat, "treat_name")

  #Process formula, removing treatment variable
  formula_without_treat <- remove_treat_from_formula(formula, treat_name)

  # if (any(attr(formula_without_treat, "interacts_with_treat"))) {
  #   stop("Treatment-covariate interactions are not permitted in lmw_iv().", call. = FALSE)
  # }

  mf <- model.frame(formula_without_treat, data = data, na.action = "na.pass")

  if (anyNA(mf)) {
    chk::err("missing values are not allowed in the covariates")
  }

  mf <- process_mf(mf)

  covs <- model.matrix(formula_without_treat, data = mf)

  assign <- attr(formula_without_treat, "term.labels")[attr(covs, "assign")[-1]]
  covs <- covs[,-1, drop = FALSE]

  iv_mf <- model.frame(iv, data = data, na.action = "na.pass")

  if (anyNA(iv_mf)) {
    chk::err("missing values are not allowed in the instrumental variable(s)")
  }

  iv_mf <- process_mf(iv_mf)

  iv_mm <- model.matrix(iv, data = iv_mf)[,-1, drop = FALSE]

  #Process target when estimand = "CATE"
  if (estimand == "CATE") {
    target <- process_target(target, formula_without_treat, mf, target.weights)
  }

  #Center covariates at mean based on estimand; only affects weights if there
  #are interactions w/ treatment
  covs <- center_covs(covs, treat, target, s.weights, focal)

  t_mat <- do.call("cbind", lapply(levels(treat)[-1], function(j) as.numeric(treat == j)))
  colnames(t_mat) <- paste0(treat_name, levels(treat)[-1])

  if (method == "URI") {
    interacts_with_treat <- attr(formula_without_treat, "interacts_with_treat")
    new.f.terms <- attr(formula_without_treat, "new.f.terms")

    #Create new IVs by interacting with covs that interact w/ treatment
    Xiv <- cbind(iv_mm, do.call("cbind", lapply(which(interacts_with_treat), function(i) {
      do.call("cbind", lapply(which(assign == new.f.terms[i]), function(j) {
        out_ <- iv_mm * covs[,j]
        colnames(out_) <- paste(colnames(iv_mm), colnames(covs)[j], sep = ":")
        out_
      }))
    })))

    #Create 1st stage LHS matrix of endogenous vars from treat and treat-cov interactions
    t_int <- do.call("cbind", lapply(which(interacts_with_treat), function(i) {
      do.call("cbind", lapply(which(assign == new.f.terms[i]), function(j) {
        out_ <- t_mat * covs[,j]
        colnames(out_) <- paste(colnames(t_mat), colnames(covs)[j], sep = ":")
        out_
      }))
    }))

  }
  else if (method == "MRI") {
    #Reconstruct X from centered covs by multiplying all covs by treat and adding
    #treat and intercept
    Xiv <- cbind(iv_mm, do.call("cbind", lapply(seq_len(ncol(covs)), function(i) {
      out <- iv_mm * covs[,i]
      colnames(out) <- paste(colnames(iv_mm), colnames(covs)[i], sep = ":")
      out
    })))

    #Create 1st stage LHS matrix of endogenous vars from treat and treat-cov interactions
    t_int <- do.call("cbind", lapply(seq_len(ncol(covs)), function(i) {
      out <- t_mat * covs[,i]
      colnames(out) <- paste(colnames(t_mat), colnames(covs)[i], sep = ":")
      out
    }))
  }

  #Add intercept and IV to X
  X <- cbind(1, covs, Xiv)
  colnames(X) <- c("(Intercept)", colnames(covs), colnames(Xiv))
  attr(X, "iv_names") <- colnames(Xiv)

  A <- cbind(t_mat, t_int)

  attr(mf, "terms") <- NULL

  list(X = X, mf = mf, target = target, A = A)
}

get_2nd_stage_X_from_formula_iv <- function(formula, data, treat, treat_fitted, method, estimand, target = NULL,
                                            s.weights = NULL, target.weights = NULL, focal = NULL) {

  m <- match.call()
  m[[1]] <- quote(get_X_from_formula)
  m[["treat_fitted"]] <- NULL

  out <- eval(m, parent.frame())

  out$X[,colnames(treat_fitted)] <- treat_fitted

  out
}

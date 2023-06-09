process_base.weights <- function(base.weights = NULL, data = NULL, obj = NULL) {

  base.weights_sub <- substitute(base.weights)
  base.weights_char <- deparse1(base.weights_sub)
  base.weights <- try(eval(base.weights_sub, data, parent.frame(2)), silent = TRUE)
  if (inherits(base.weights, "try-error")) {
    cond <- conditionMessage(attr(base.weights, "condition"))
    if (startsWith(cond, "object") && endsWith(cond, "not found")) {
      if (is.null(data)) {
        stop(sprintf("The base weights variable '%s' cannot be found in the environment. Please supply an argument to 'data' containing the base weights.",
                     base.weights_char), call. = FALSE)
      }
      else {
        stop(sprintf("The base weights variable '%s' must be present in the supplied dataset or environment.",
                     base.weights_char), call. = FALSE)
      }
    }
    else {
      stop(cond, call. = FALSE)
    }
  }
  else if (length(base.weights) == 0) {
    if (!is.null(obj) &&
        (inherits(obj, "matchit") || inherits(obj, "weightit")) &&
        !is.null(obj$weights) && is.numeric(obj$weights) &&
        abs(diff(range(obj$weights))) > sqrt(.Machine$double.eps)) {
      base.weights <- obj$weights
      attr(base.weights, "origin") <- if (inherits(obj, "matchit")) "matchit" else "weightit"
    }
  }
  else if (is.character(base.weights) && length(base.weights) == 1) {
    if (is.null(data)) {
      stop("A dataset must be present when 'base.weights' is supplied as a string. Please supply an argument to 'data' containing the base weights.", call. = FALSE)
    }
    base.weights_char <- base.weights
    base.weights <- try(eval(str2expression(base.weights_char), data), silent = TRUE)
    if (length(base.weights) == 0 || inherits(base.weights, "try-error")) {
      stop("The base weights variable must be present in the dataset.", call. = FALSE)
    }
  }

  if (length(base.weights) == 0) {
    return(NULL)
  }
  if (!is.numeric(base.weights)) {
    stop("The base weights variable must be numeric.", call. = FALSE)
  }

  return(base.weights)
}

process_s.weights <- function(s.weights = NULL, data = NULL, obj = NULL) {

  s.weights_sub <- substitute(s.weights)
  s.weights_char <- deparse1(s.weights_sub)
  s.weights <- try(eval(s.weights_sub, data, parent.frame(2)), silent = TRUE)
  if (inherits(s.weights, "try-error")) {
    cond <- conditionMessage(attr(s.weights, "condition"))
    if (startsWith(cond, "object") && endsWith(cond, "not found")) {
      if (is.null(data)) {
        stop(sprintf("The sampling weights variable '%s' cannot be found in the environment. Please supply an argument to 'data' containing the sampling weights.", s.weights_char),
             call. = FALSE)
      }
      else {
        stop(sprintf("The sampling weights variable '%s' must be present in the supplied dataset or environment.", s.weights_char), call. = FALSE)
      }
    }
    else {
      stop(cond, call. = FALSE)
    }
  }
  else if (length(s.weights) == 0) {
    if (!is.null(obj) &&
        (inherits(obj, "matchit") || inherits(obj, "weightit")) &&
        !is.null(obj$s.weights) && is.numeric(obj$s.weights) &&
        abs(diff(range(obj$s.weights))) > sqrt(.Machine$double.eps)) {
      s.weights <- obj$s.weights
      attr(s.weights, "origin") <- if (inherits(obj, "matchit")) "matchit" else "weightit"
    }
  }
  else if (is.character(s.weights) && length(s.weights) == 1) {
    if (is.null(data)) {
      stop("A dataset must be present when 's.weights' is supplied as a string. Please supply an argument to 'data' containing the sampling weights.", call. = FALSE)
    }
    s.weights_char <- s.weights
    s.weights <- try(eval(str2expression(s.weights_char), data), silent = TRUE)
    if (length(s.weights) == 0 || inherits(s.weights, "try-error")) {
      stop("The sampling weights variable must be present in the dataset.", call. = FALSE)
    }
  }

  if (length(s.weights) == 0) {
    return(NULL)
  }
  if (!is.numeric(s.weights)) {
    stop("The sampling weights variable must be numeric.", call. = FALSE)
  }

  return(s.weights)
}

process_dr.method <- function(dr.method, base.weights, method, estimand) {
  if (is.null(base.weights)) return(NULL)
  if (length(dr.method) != 1 || !is.character(dr.method)) {
    stop("'dr.method' must be a string.", call. = FALSE)
  }
  dr.method <- toupper(dr.method)
  # dr.method <- match_arg(dr.method, c("WLS"))
  # dr.method <- match_arg(dr.method, c("WLS", "AIPW"[method == "MRI"]))
  dr.method <- match_arg(dr.method, c("WLS", "AIPW"))

  if (estimand == "CATE" && dr.method == "AIPW") {
    stop("The CATE cannot be used with AIPW.", call. = FALSE)
  }
  dr.method
}

process_treat <- function(treat_name, data, multi.ok = TRUE) {

  treat <- model.response(model.frame(reformulate("0", treat_name),
                                      data = data, na.action = "na.pass"))

  if (anyNA(treat)) stop("Missing values are not allowed in the treatment.", call. = FALSE)

  unique_treat <- unique(treat)

  if (length(unique_treat) == 2) {
    if (is.factor(treat)) treat <- factor(treat, levels = levels(treat)[levels(treat) %in% unique_treat])
    else if (is.numeric(treat) && !all(treat == 0 | treat == 1)) {
      stop("If the treatment is not a 0/1 variable, it must be a factor variable.", call. = FALSE)
    }
    else treat <- factor(treat, levels = sort(unique_treat))
  }
  else if (multi.ok) {
    if (is.character(treat)) treat <- factor(treat, levels = sort(unique_treat))
    else if (is.factor(treat)) treat <- factor(treat, levels = levels(treat)[levels(treat) %in% unique_treat])
    else {
      stop("The treatment must be a factor variable if it takes on more than two values.", call. = FALSE)
    }
  }
  else {
    stop("The treatment must be binary.", call. = FALSE)
  }

  attr(treat, "treat_name") <- treat_name

  return(treat)
}

process_estimand <- function(estimand, target, obj) {
  #Get lmw() call to see if estimand arg was specified; if not, it may
  #be replaced by estimand in obj
  m <- match.call(sys.function(sys.parent()),
                  sys.call(sys.parent()))

  estimand.supplied <- utils::hasName(m, "estimand")

  if (!is.character(estimand) || length(estimand) != 1) {
    stop("'estimand' must be a string of length 1.", call. = FALSE)
  }
  estimand <- toupper(estimand)
  estimand <- match_arg(estimand, c("ATE", "ATT", "ATC", "CATE"))

  if (estimand == "CATE") {
    if (is.null(target)) {
      stop("'target' must be specified when estimand = \"CATE\".", call. = FALSE)
    }
  }
  else if (!is.null(target)) {
    if (estimand.supplied) {
      warning("Setting 'estimand' to \"CATE\" because 'target' was supplied.", call. = FALSE)
    }
    estimand <- "CATE"
  }

  if (!is.null(obj) && (inherits(obj, "matchit") || inherits(obj, "weightit"))) {
    if (!estimand.supplied) {
      estimand <- obj$estimand
    }
    else if (!identical(estimand, obj$estimand)) {
      warning(sprintf("'estimand' (\"%s\") does not agree with the estimand specified in the supplied %s object (\"%s\"). Using \"%s\".",
                      estimand, if (inherits(obj, "matchit")) "matchit" else "weightit", obj$estimand, estimand),
              call. = FALSE)
    }
  }

  return(estimand)
}

process_mf <- function(mf) {
  for (i in seq_len(ncol(mf))) {
    if (is.character(mf[[i]])) mf[[i]] <- factor(mf[[i]])
    else if (any(!is.finite(mf[[i]]))) stop("Non-finite values are not allowed in the covariates.", call. = FALSE)
  }
  mf
}

process_data <- function(data = NULL, obj = NULL) {

  null.data <- is.null(data)
  if (!null.data) {
    if (is.matrix(data)) {
      data <- as.data.frame(data)
    }
    else if (!is.data.frame(data)) {
      stop("'data' must be a data.frame object.", call. = FALSE)
    }
  }

  obj.data <- NULL
  if (inherits(obj, "matchit")) {
    if (!requireNamespace("MatchIt", quietly = TRUE)) {
      if (null.data) {
        warning("The 'MatchIt' package should be installed when a matchit object is supplied to 'obj'.",
                call. = FALSE)
      }
    }
    else {
      obj.data <- MatchIt::match.data(obj, drop.unmatched = FALSE, include.s.weights = FALSE)
    }
  }

  if (!null.data) {
    if (!is.null(obj.data)) {
      data <- cbind(data, obj.data[setdiff(names(obj.data), names(data))])
    }
  }
  else {
    data <- obj.data #NULL if no obj
  }

  return(data)
}

process_treat_name <- function(treat, formula, data, method, obj) {
  tt.factors <- attr(terms(formula, data = data), "factors")

  obj_treat <- NULL
  if (inherits(obj, "matchit")) {
    obj_treat <- deparse1(as.list(obj$formula)[[2]])
  }

  if (is.null(treat)) {
    if (is.null(obj_treat)) {
      if (!any(colSums(tt.factors != 0) == 1)) {
        stop("Please supply an argument to 'treat' to identify the treatment variable.", call. = FALSE)
      }

      #Use first variable in formula that doesn't involve an interaction
      treat <- colnames(tt.factors)[which(colSums(tt.factors != 0) == 1)[1]]
      message(paste0("Using \"", treat, "\" as the treatment variable. If this is incorrect or to suppress this message, please supply an argument to 'treat' to identify the treatment variable."))
    }
    else {
      if (method == "URI" && !obj_treat %in% rownames(tt.factors)) {
        stop(sprintf("The treatment variable in the supplied matchit object (%s) does not align with any variables in 'formula'.",
                     obj_treat), call. = FALSE)
      }
      treat <- obj_treat
    }
  }
  else {
    if (length(treat) != 1 || !is.character(treat)) {
      stop("'treat' must be a string naming the treatment variable.", call. = FALSE)
    }
    if (method == "URI" && !treat %in% rownames(tt.factors)) {
      stop(sprintf("The supplied treatment variable (\"%s\") does not align with any variables in 'formula'.",
                   treat), call. = FALSE)
    }
  }
  return(treat)
}

process_contrast <- function(contrast = NULL, treat, method) {

  treat_f <- if (is.factor(treat)) droplevels(treat) else as.factor(treat)
  t_levels <- levels(treat_f)

  if (is.null(contrast)) {
    if (is.null(contrast) && length(t_levels) > 2 && method == "URI") {
      stop("'contrast' must be specified when the treatment has more than two levels and method = \"URI\".", call. = FALSE)
    }
    return(NULL)
  }

  if (is.numeric(contrast)) {
    if (can_str2num(treat)) {
      contrast <- as.character(contrast)
    }
    else if (!all(contrast %in% seq_along(t_levels))) {
      stop("'contrast' must contain the names or indices of treatment levels to be contrasted.", call. = FALSE)
    }
    else {
      contrast <- t_levels[contrast]
    }
  }
  if (is.factor(contrast)) {
    contrast <- as.character(contrast)
  }

  #contrast is now character
  if (!all(contrast %in% t_levels)) {
    stop("'contrast' must contain the names or indices of treatment levels to be contrasted.", call. = FALSE)
  }

  if (length(contrast) == 1) {
    if (length(t_levels) == 2) {
      contrast <- c(contrast, t_levels[t_levels != contrast])
    }
    else if (contrast == t_levels[1]) {
      stop("If 'contrast' is a single value, it cannot be the reference value of the treatment.", call. = FALSE)
    }
    else {
      contrast <- c(contrast, t_levels[1])
    }
  }
  else if (length(contrast) != 2) {
    stop("'contrast' cannot have length greater than 2.", call. = FALSE)
  }

  return(contrast)
}

process_focal <- function(focal = NULL, treat, estimand) {
  if (estimand %in% c("ATE", "CATE")) {
    if (!is.null(focal)) warning(sprintf("'focal' is ignored when estimand = \"%s\".", estimand), call. = FALSE)
    return(NULL)
  }

  if (is.null(focal)) {
    focal <- switch(estimand, "ATT" = levels(treat)[2], levels(treat)[1])
    if (nlevels(treat) > 2 || !can_str2num(unique(treat, nmax = 2)))
      message(sprintf("Using \"%s\" as the focal (%s) group. If this is incorrect or to suppress this message, please supply an argument to 'focal' to identify the focal treatment level.",
                      focal, switch(estimand, "ATT" = "treated", "control")))
  }
  else if (length(focal) != 1) {
    stop("'focal' must be of length 1.", call. = FALSE)
  }
  else if (!as.character(focal) %in% levels(treat)) {
    stop("'focal' must be the name of a value of the treatment variable.", call. = FALSE)
  }

  return(as.character(focal))
}

apply_contrast_to_treat <- function(treat, contrast = NULL) {
  if (is.null(contrast)) return(treat)

  attrs <- attributes(treat)
  treat <- factor(treat, levels = c(rev(contrast), levels(treat)[!levels(treat) %in% contrast]))
  for (i in setdiff(names(attrs), "levels")) attr(treat, i) <- attrs[[i]]
  treat
}

#Extract data from an lmw object
get_data <- function(data, x) {
  #x is a lmw object

  if (is.null(data)) {
    f_env <- environment(x$formula)
    data <- try(eval(x$call$data, envir = f_env), silent = TRUE)

    if (length(data) == 0 || inherits(data, "try-error") || length(dim(data)) != 2 || nrow(data) != length(x[["treat"]])) {
      data <- try(eval(x$call$data, envir = parent.frame(2)), silent = TRUE)
    }

    obj <- try(eval(x$call$obj, envir = f_env), silent = TRUE)
    if (length(obj) == 0 || inherits(obj, "try-error") || (!inherits(obj, "matchit") && !inherits(obj, "weightit"))) {
      obj <- try(eval(x$call$obj, envir = parent.frame(2)), silent = TRUE)
    }

    data <- process_data(data, obj)

    if (length(data) != 0 && (length(dim(data)) != 2 || nrow(data) != length(x[["treat"]]))) {
      stop("A valid dataset could not be found. Please supply an argument to 'data' containing the original dataset used to estimate the weights.", call. = FALSE)
    }
  }
  else {
    if (!is.data.frame(data)) {
      if (is.matrix(data)) data <- as.data.frame.matrix(data)
      else stop("'data' must be a data frame.", call. = FALSE)
    }
    if (nrow(data) != length(x$treat)) {
      stop("'data' must have as many rows as there were units in the original call to lmw().", call. = FALSE)
    }

    obj <- try(eval(x$call$obj, envir = f_env), silent = TRUE)
    if (length(obj) == 0 || inherits(obj, "try-error") || (!inherits(obj, "matchit") && !inherits(obj, "weightit"))) {
      obj <- try(eval(x$call$obj, envir = parent.frame(2)), silent = TRUE)
    }

    data <- process_data(data, obj)
  }

  data
}

#Get outcome from 'outcome' or formula
# 'outcome' can be a string or the name of a variable in 'data' or the environment
# containing the outcome
# Uses NSE, so must be called with this idiom when used inside functions:
#    do.call("get_outcome", list(substitute(outcome_arg), data_arg, formula_arg))
get_outcome <- function(outcome, data = NULL, formula, X) {

  tt <- terms(formula, data = data)

  if (missing(outcome)) {
    if (attr(tt, "response") == 0) {
      stop("'outcome' must be supplied.", call. = FALSE)
    }

    outcome_char <- deparse1(attr(tt, "variables")[[2]])

    mf <- try(eval(model.frame(tt, data = data)), silent = TRUE)
    if (inherits(mf, "try-error")) {
      cond <- attr(mf, "condition")$message
      if (startsWith(cond, "object") && endsWith(cond, "not found")) {
        stop(sprintf("The outcome variable '%s' must be present in the supplied dataset or environment.", outcome_char), call. = FALSE)
      }
    }
    outcome <- model.response(mf)
  }
  else {
    outcome_sub <- substitute(outcome)
    outcome_char <- deparse1(outcome_sub)
    outcome <- try(eval(outcome_sub, envir = data), silent = TRUE)
    if (inherits(outcome, "try-error")) {
      cond <- attr(outcome, "condition")$message
      if (startsWith(cond, "object") && endsWith(cond, "not found")) {
        if (is.null(data)) {
          stop(sprintf("The outcome variable '%s' cannot be found in the environment. Please supply an argument to 'data' containing the original dataset used to estimate the weights.", outcome_char),
               call. = FALSE)
        }
        else {
          stop(sprintf("The outcome variable '%s' must be present in the supplied dataset or environment.", outcome_char), call. = FALSE)
        }
      }
    }
    if (is.character(outcome) && length(outcome) == 1) {
      if (is.null(data)) {
        stop("A dataset must be present when 'outcome' is supplied as a string. Please supply an argument to 'data' containing the original dataset used to estimate the weights.", call. = FALSE)
      }
      outcome_char <- outcome
      outcome <- try(eval(str2expression(outcome_char), data), silent = TRUE)
      if (length(outcome) == 0 || inherits(outcome, "try-error")) {
        stop("The outcome variable must be present in the dataset.", call. = FALSE)
      }
    }
  }

  if (length(outcome) == 0) {
    stop("The outcome variable cannot be NULL.", call. = FALSE)
  }
  if (!is.numeric(outcome) && !is.logical(outcome)) {
    stop("The outcome variable must be numeric.", call. = FALSE)
  }
  if (length(outcome) != nrow(X)) {
    stop("The outcome variable must have length equal to the number of units in the dataset.", call. = FALSE)
  }

  attr(outcome, "outcome_name") <- outcome_char
  outcome
}

process_target <- function(target, formula, mf, target.weights = NULL) {
  if (any(c("$", "[", "[[") %in% all.names(formula))) {
    stop("Subsetting operations ($, [.], [[.]]) are not allowed in the model formula when 'target' is specified.", call. = FALSE)
  }
  if (!is.list(target)) {
    stop("'target' must be a list of covariate-value pairs or a data frame containing the target population.", call. = FALSE)
  }
  if (!is.data.frame(target) && !all(lengths(target) == 1L)) {
    stop("All entries in 'target' must have lengths of 1 when supplied as a list.", call. = FALSE)
  }
  if (!is.null(target.weights)) {
    if (!is.data.frame(target) || nrow(target) == 1) {
      warning("'target.weights' is ignored when 'target' is a target profile.", call. = FALSE)
    }
    if (!is.numeric(target.weights) || length(target.weights) != nrow(target)) {
      stop("'target.weights' must be a numeric vector with length equal to the number of rows of the target dataset.", call. = FALSE)
    }
    target.weights <- as.numeric(target.weights)
  }

  vars_in_formula <- all.vars(formula)
  vars_in_target <- names(target)
  vars_in_formula_not_in_target <- setdiff(vars_in_formula, vars_in_target)
  if (length(vars_in_formula_not_in_target) > 0) {
    stop(paste0("All covariates in the model formula must be present in 'target'; variable(s) not present:\n\t",
                paste(vars_in_formula_not_in_target, collapse = ", ")), call. = FALSE)
  }

  vars_in_target_not_in_formula <- setdiff(vars_in_target, vars_in_formula)
  if (length(vars_in_target_not_in_formula) > 0) {
    if (!is.data.frame(target)) {
      warning(paste0("The following value(s) in 'target' will be ignored:\n\t",
                     paste(vars_in_target_not_in_formula, collapse = ", ")), call. = FALSE)
    }
    target <- target[vars_in_target %in% vars_in_formula]
  }

  target <- process_mf(as.data.frame(target))
  .checkMFClasses(vapply(mf, .MFclass, character(1L)), target)

  for (i in names(target)[vapply(target, is.factor, logical(1L))]) {
    target[[i]] <- factor(as.character(target[[i]]), levels = levels(mf[[i]]))
  }

  target_mf <- model.frame(formula, data = target)
  target_mm <- model.matrix(formula, data = target_mf)[,-1, drop = FALSE]

  if (nrow(target_mm) == 1) {
    out <- setNames(drop(target_mm), colnames(target_mm))
  }
  else {
    out <- setNames(colMeans_w(target_mm, target.weights), colnames(target_mm))
  }

  attr(target, "target.weights") <- target.weights
  attr(out, "target_original") <- target

  out
}

process_iv <- function(iv, formula, data = NULL) {
  if (length(iv) == 0) {
    stop("An argument to 'iv' specifying the instrumental variable(s) is required.", call. = FALSE)
  }

  tt.factors <- attr(terms(formula, data = data), "factors")

  if (is.character(iv)) {
    if (!is.null(data) && is.data.frame(data)) {
      if (!all(iv %in% names(data))) {
        stop("All variables in 'iv' must be in 'data'.", call. = FALSE)
      }
      iv_f <- reformulate(iv)
    }
    else {
      stop("If 'iv' is specified as a string, a data frame argument must be supplied to 'data'.", call. = FALSE)
    }
  }
  else if (inherits(iv, "formula")) {
    iv_f <- iv
  }
  else {
    stop("'iv' must be a one-sided formula or character vector of instrumental variables.", call. = FALSE)
  }

  iv.factors <- attr(terms(iv_f, data = data), "term.labels")

  if (any(iv.factors %in% rownames(tt.factors))) {
    stop("The instrumental variable(s) should not be present in the model formula.", call. = FALSE)
  }

  return(iv_f)
}

process_fixef <- function(fixef, formula, data = NULL, treat_name) {
  if (length(fixef) == 0) return(NULL)

  tt.factors <- attr(terms(formula, data = data), "factors")

  if (is.character(fixef)) {
    if (!is.null(data) && is.data.frame(data)) {
      if (!all(fixef %in% names(data))) {
        stop("All variables in 'fixef' must be in 'data'.", call. = FALSE)
      }
      fixef_f <- reformulate(fixef)
    }
    else {
      stop("If 'fixef' is specified as a string, a data frame argument must be supplied to 'data'.", call. = FALSE)
    }
  }
  else if (inherits(fixef, "formula")) {
    fixef_f <- fixef
  }
  else {
    stop("'fixef' must be a one-sided formula or string naming the fixed effect variable.", call. = FALSE)
  }

  fixef_name <- attr(terms(fixef_f, data = data), "term.labels")
  if (length(fixef_name) > 1) {
    stop("Only one fixed effect variable may be supplied.", call. = FALSE)
  }

  if (any(fixef_name == treat_name)) {
    stop("The fixed effect variable cannot be the same as the treatment variable.", call. = FALSE)
  }
  if (any(fixef_name %in% rownames(tt.factors))) {
    stop("The fixed effect variable should not be present in the model formula.", call. = FALSE)
  }

  fixef_mf <- model.frame(fixef_f, data = data, na.action = "na.pass")

  if (anyNA(fixef_mf)) {
    stop("Missing values are not allowed in the fixed effect variable.", call. = FALSE)
  }

  fixef <- factor(fixef_mf[[fixef_name]])
  attr(fixef, "fixef_name") <- fixef_name

  return(fixef)
}

check_lengths <- function(treat, ...) {
  arg_names <- c("treatment", unlist(lapply(substitute(list(...))[-1], deparse1)))
  args <- c(list(treat), list(...))

  lengths <- setNames(vapply(args, function(x) {
    if (length(dim(x)) == 2) NROW(x)
    else length(x)
  }, integer(1L)), arg_names)

  lengths <- lengths[lengths > 0L]
  arg_names <- names(lengths)

  if (!all(lengths == lengths[1])) {
    error_df <- data.frame(sort(unique(lengths)))
    rownames(error_df) <- format(sapply(error_df[[1]], function(n) {
      paste0(paste(arg_names[lengths == n], collapse = ", "), ":")
    }), justify = "right")
    names(error_df) <- NULL

    msg <- paste(
      sprintf("%s and %s must have the same length. Variable lengths:",
              paste(arg_names[-length(lengths)], collapse = ", "),
              arg_names[length(lengths)]),
      format(do.call("paste", lapply(rownames(error_df), function(i) {
        paste0("\n", i, " ", error_df[i, 1])
      })), justfify = "right")
    )

    stop(msg, call. = FALSE)
  }
}

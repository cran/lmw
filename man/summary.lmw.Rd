% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/summary.lmw.R
\name{summary.lmw}
\alias{summary.lmw}
\alias{summary.lmw_multi}
\alias{print.summary.lmw}
\title{Assess balance for an \code{lmw} object}
\usage{
\method{summary}{lmw}(
  object,
  un = TRUE,
  addlvariables = NULL,
  standardize = TRUE,
  data = NULL,
  stat = "balance",
  ...
)

\method{summary}{lmw_multi}(
  object,
  un = TRUE,
  addlvariables = NULL,
  standardize = TRUE,
  data = NULL,
  contrast = NULL,
  stat = "balance",
  ...
)

\method{print}{summary.lmw}(x, digits = max(3, getOption("digits") - 4), ...)
}
\arguments{
\item{object}{an \code{lmw} object; the output of a call to \code{\link[=lmw]{lmw()}}.}

\item{un}{\code{logical}; whether to display balance statistics for the sample
prior to weighting and, additionally, with base weights applied (if
supplied). If \code{s.weights} were supplied to \code{lmw()}, the unadjusted sample
will be weighted by the sampling weights.}

\item{addlvariables}{additional variables for which balance statistics are to
be computed along with the covariates in the \code{lmw} object. Can be entered
in one of three ways: as a data frame of covariates with as many rows as
there were units in the original \code{lmw()} call, as a string containing the
names of variables in \code{data}, or as a right-sided formula with the
additional variables (and possibly their transformations) found in \code{data},
the environment, or the \code{lmw} object.}

\item{standardize}{\code{logical}; whether to compute standardized (\code{TRUE}) or
unstandardized (\code{FALSE}) mean differences. Default is \code{TRUE}.}

\item{data}{a optional data frame containing variables named in
\code{addlvariables} if specified as a string or formula.}

\item{stat}{\code{character}; whether to display balance statistics (i.e.,
standardized mean differences and Kolmogorv-Smirnov statistics;
\code{"balance"}) or distribution statistics (i.e., means and standard
deviations; \code{"distribution"}). Default is \code{"balance"}. Abbreviations
allowed.}

\item{\dots}{ignored.}

\item{contrast}{for multi-category treatments with \code{method = "MRI"}, which
two groups should be compared. If \code{NULL}, only target balance statistics
will be displayed. Ignored with binary treatments or when \code{method = "URI"}.}

\item{x}{a \code{summary.lmw} object.}

\item{digits}{the number of digits to print.}
}
\value{
A \code{summary.lmw} object, which contains the following components:
\item{call}{The original call to \code{lmw()}.}
\item{nn}{The (effective)
sample sizes before and after weighting.}
\item{bal.un}{When \code{stat = "balance"} and \code{un = TRUE}, the balance statistics prior
to weighting.}
\item{bal.base.weighted}{When \code{stat = "balance"}, \code{un = TRUE} and
base weights were supplied to \code{lmw()}, the balance statistics with the
base weights applied.}
\item{bal.weighted}{When \code{stat = "balance"}, the balance statistics with the implied regression
weights applied.}
\item{dist.un}{When \code{stat = "distribution"} and \code{un = TRUE}, the
distribution statistics prior to weighting.}
\item{dist.base.weighted}{When
\code{stat = "distribution"}, \code{un = TRUE} and base weights were
supplied to \code{lmw()}, the distribution statistics with the base weights
applied.}
\item{dist.weighted}{When \code{stat = "distribution"}, the distribution statistics with the implied
regression weights applied.}
\item{method}{The method used to estimate the weights (i.e., URI or MRI)}
\item{base.weights.origin}{If base weights were supplied through the
\code{obj} argument to \code{lmw()}, their origin (i.e, \pkg{MatchIt} or \pkg{WeightIt})}

With multi-category treatments and \code{method = "MRI"}, the object will also
inherit from class \code{summary.lmw_multi}.
}
\description{
Computes balance statistics for an \code{lmw} object created by
\code{\link[=lmw]{lmw()}}. Balance involves not only the similarity between the treatment
groups but also the similarity between each treatment group and the target
population.
}
\details{
\code{summary.lmw()} produces covariate balance or distribution
statistics and effective samples sizes before and after adjustment by the
regression weights and base weights, if supplied. For each covariate, the
following balance statistics are computed when \code{stat = "balance"}:

\itemize{
\item \code{SMD} - the standardized mean difference (SMD) between the
treated and control groups
\item \verb{TSMD Treated} - the target
standardized mean difference (TSMD) between the treated group and target
sample
\item \verb{TSMD Control} - the TSMD between between the control
group and target sample
\item \code{KS} - the Kolmogorov-Smirnov (KS)
statistic between the treated and control groups
\item \verb{TKS Treated} -
the target KS (TKS) statistic between the treated group and target sample
\item \verb{TKS Control} - the TKS statistic between the control group and
target sample
}

For multi-category treatments with \code{method = "MRI"}, balance statistics are
are computed between each treatment group and the target sample.

When \code{stat = "distribution"} the mean and standard deviation of each
covariate is compute before and after adjustment and for the target sample.
(Standard deviations are printed in parentheses for visual clarity.)

After weighting with the regression weights, the mean difference between
the treated and control groups of each covariate included in the original
call to \code{lmw()} will be equal to zero. However, the mean difference between
each treatment group and the target sample may not be equal to zero when
\code{method = "URI"} in the call to \code{lmw()}, and covariates supplied to
\code{addlvariables} not included in the call to \code{lmw()} may not be well
balanced.

When \code{s.weights} are supplied to \code{lmw()}, the unadjusted statistics (if
requested) will incorporate the sampling weights. When \code{base.weights} are
supplied to \code{lmw()}, the unadjusted statistics will \emph{not} incorporate the
base weights; rather, balance with base weights applied (if supplied) will
be produced in a separate balance table (see Value below).

SMDs are computed as the difference between the (weighted) means divided by
a standardization factor, which is the standard deviation of the covariate
in the target sample. When \code{estimand = "ATT"} in the call to \code{lmw()}, the
standardization factor is the standard deviation in the treated group; when
\code{estimand = "ATC"}, the standardization factor is the standard deviation in
the control group; when \code{estimand = "ATE"} or when \code{estimand = "CATE"} and
a target profile is supplied, the standardization factor is the square root
of the average of the variances of both treatment groups; when \code{estimand = "CATE"}
and a target dataset is supplied, the standardization factor is the
standard deviation in the target dataset. When \code{s.weights} is supplied, the
standardization factor is computed including the sampling weights;
otherwise it is computed in the unweighted sample.

For binary covariates, the KS statistic is equal to the unstandardized
difference in means and is computed as such.

When \code{estimand = "CATE"} in the original call to \code{lmw()}, any variables
supplied to \code{addlvariables} that were not given a target value will not
have any target statistics computed (e.g., TSMD, TKS, target means, etc.).

The effective sample size (ESS) is computed within each group as \eqn{(\sum w)^2/\sum w^2}.
With uniform weights, this is equal to the sample size.
}
\examples{
data("lalonde")

# URI regression for ATT
lmw.out1 <- lmw(~ treat + age + education + race + married +
                  nodegree + re74 + re75, data = lalonde,
                  estimand = "ATT", method = "URI",
                  treat = "treat")

lmw.out1

summary(lmw.out1)

summary(lmw.out1, stat = "distribution")

# Adding additional variables to summary, removing unweighted
summary(lmw.out1, un = FALSE,
        addlvariables = ~I(age^2) + I(nodegree*re74))

\dontshow{if (requireNamespace("MatchIt")) (if (getRversion() >= "3.4") withAutoprint else force)(\{ # examplesIf}
# MRI regression for ATT after PS matching
m.out <- MatchIt::matchit(treat ~ age + education + race + married +
                            nodegree + re74 + re75,
                          data = lalonde, method = "nearest",
                          estimand = "ATT")

lmw.out2 <- lmw(~ treat + age + education + race + married +
                  nodegree + re74 + re75, data = lalonde,
                method = "MRI", treat = "treat", obj = m.out)

lmw.out2

summary(lmw.out2)
\dontshow{\}) # examplesIf}
# MRI for a multi-category treatment ATE
lmw.out3 <- lmw(~ treat_multi + age + education + race + married +
                  nodegree + re74 + re75, data = lalonde,
                estimand = "ATE", method = "MRI",
                treat = "treat_multi")

lmw.out3

summary(lmw.out3)

summary(lmw.out3, contrast = c("2", "1"))

}
\seealso{
\code{\link[=lmw]{lmw()}} for computing the implied regression weights,
\code{\link[=plot.summary.lmw]{plot.summary.lmw()}} for plotting the balance statistics in a Love plot,
\code{\link[=plot.lmw]{plot.lmw()}} for assessing the representativeness and extrapolation of the
weights
}

##' Sensitivity analysis using covset objects
##' 
##' @param mod the model object
##' @param covset a covset object
##' @param .n the number of replicates to simulate
##' @param univariate if \code{TRUE}, separate simulations are done for 
##' each input parameter
##' @param ... passed to \code{mutate_random} and \code{mrgsim}
##' 
##' @seealso \code{\link{sens_unif}} \code{\link{sens_norm}} 
##' 
##' @examples
##' mod <- mrgsolve:::house() %>% ev(amt = 100)
##' 
##' \dontrun{
##' library(dmutate)
##' cov1 <- covset(CL ~ runif(0.5, 1.5), VC ~ rlnorm(log(20), 0.5))
##'   
##' mod %>%
##'   sens_covset(.n = 10)
##' }
##' 
##' @export
sens_covset <- function(mod,covset,.n=100,univariate = FALSE, ...) {
  assert_that(requireNamespace("dmutate"))
  assert_that(inherits(covset,"covset"))
  mod <- strip_args(mod) %>% obsonly
  idata <- data_frame(ID = seq(.n))
  idata <- dmutate::mutate_random(idata,covset,...)
  if(univariate) {
    idata <- col_sep(idata)
    return(sens_univariate(mod, idata, ...))
  }
  out <- mrgsim(mod,idata=idata,obsonly=TRUE,...)
  out <- left_join(as_data_frame(out),idata,by = "ID")
  mutate(out, name = "multivariate", value = 1)
  
}

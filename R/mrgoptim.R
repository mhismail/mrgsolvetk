
ML_obj_fun <- function(raw,pred,var){
  1/2*sum(((raw-pred)*(raw-pred))/var+
            log(var))+1/2*length(raw)*log(2*pi)
}

get_preds <- function (mod,params,Request){
  out <- mod%>%
    param(params)%>%
    carry.out(dv,cmt)%>%
    obsonly()%>%
    mrgsim(Request=Request,end=-1)%>%
    as.data.frame()

  return(out)
} 


ML_optim <- function(params,mod,output,var,input){
  Request <- c(output,var)
  
  params<- 10^params
  predicted <- get_preds (mod,params,Request)
  
  predicted<- reformat(predicted,input,output)
  
  ML_obj_fun(predicted$dv,predicted[,5],predicted[,5+length(output)])

}





# Covariance step functions -----------------------------------------------

h <- function (atol,rtol,param){
    (rtol)^(1/3)*max(param,atol)
}

hj <- Vectorize(h,c("param"))

get_matrices <- function(params,mod,output,var,input){
  a<-mod@args$data
  class(a)<- NULL
  a<- as.data.frame(a)
  a<-a[a$evid==0,2]
  
  dydtheta <- matrix(0, nrow =length(a),ncol=length(params))
  dgdtheta <- matrix(0, nrow =length(a),ncol=length(params))

  hja<- hj(mod@atol,mod@rtol,params)
  Request <- c(output,var)
  
  for (i in 1:length(params)){
    new_params1 <- params
    new_params2 <- params


    new_params1[i] <- params[i]+hja[i]
    new_params2[i] <- params[i]-hja[i]

    a1 <- reformat(get_preds(mod,new_params1,Request),input,output)
    a2 <- reformat(get_preds(mod,new_params2,Request),input,output)

    dydthetai <- (a1[,5]-a2[,5])/(2*hja[i])
    dydtheta[,i] <- as.matrix(dydthetai)
    
    dgdthetai <- (a1[,5+length(output)]-a2[,5+length(output)])/(2*hja[i])
    dgdtheta[,i] <- as.matrix(dgdthetai)
  }
  
  list(dydtheta,dgdtheta)
}



reformat<-function(predicted,input,output){
  for (i in 1:length(output)){
    predicted[,5]<- ifelse(input[i]==predicted$cmt,predicted[,i+4],predicted[,5])
    predicted[,5+length(output)]<- ifelse(input[i]==predicted$cmt,
                                          predicted[,i+4+length(output)],
                                          predicted[,5+length(output)])
    
  }
  return(predicted)
}


##' Fit a model to data using maximum likelihood objective function
##' with newuoa or optim
##' 
##' @param mod a model object
##' @param input a numeric vector containing observation compartments in data_set to be fit
##' @param output a character vector containing names of pred output columns
##' @param var a character vector containing names of variance output columns of preds
##' @param prms a character vector of parameters to fit
##' @param v_prms a character vector of variance parameters to fit
##' @param cov logical, perform covariance step
##' @param restarts number of times to restart fit with final estimates of previous optimization
##' @param method method to be used: "newuoa","Nelder-Mead", "BFGS", "CG", "L-BFGS-B", "SANN", "Brent"
##' @param options options passed to optim function, see ?optim for more information
##' @export
##' @rdname mrgoptim

mrgoptim <- function(mod,
                     input,
                     output,
                     var,
                     prms,
                     v_prms,
                     cov=T,
                     restarts=0,
                     method="newuoa",
                     options=list(maxit=10000)){
  
  data<-as.data.frame(unclass(mod@args$data))
  
  if(!is.mrgmod(mod)) {
    stop("mod argument must be a model object",call.=FALSE) 
  }
  
  if(is.null(dim(data))){
    stop("dataset not found",call.=FALSE) 
  }
  
  if(!all(output%in%c(names(mod@init@data),mod@capture))) {
    stop("couldn't find ",
         paste(output[which(!output%in%c(names(mod@init@data),mod@capture))],collapse=", "), 
         " in model output",call.=FALSE) 
  }
  
  if(!all(var%in%c(names(mod@init@data),mod@capture))) {
    stop("couldn't find ",
         paste(output[which(!var%in%c(names(mod@init@data),mod@capture))],collapse=", "), 
         " in model output",call.=FALSE) 
  }
  
  if(!all(input%in%data$cmt)) {
    stop("couldn't find compartment/s ",
         paste(input[which(!input%in%data$cmt)],collapse=", "), 
         " in cmt column",call.=FALSE) 
  }
  
  if(!(length(input)==length(output)&length(input)==length(var))){
    stop("input, output, and var vectors should have same length",call.=FALSE)
  }
  
  if(!all(prms %in% names(mod@param))){
    stop("couldn't find ",
         paste(prms[which(!prms %in% names(mod@param))],collapse=", "),
         " in parameter list",call.=FALSE) 
  }
  
  if(!all(v_prms %in% names(mod@param))){
    stop("couldn't find ",
         paste(v_prms[which(!v_prms %in% names(mod@param))],collapse=", "),
         " in parameter list",call.=FALSE) 
  }
  
  #Get all parameters in mod object
  params <- as.list(mod)$param
  
  #Select only parameters to be estimated
  params <- params[which(names(params)%in%c(prms,v_prms))]%>%
    unlist()%>%log10()
  
  
  fit <-list()
  for (i in 1:(1+restarts)){
    if (i == 1){
      fit[[1]] <- if(method!="newuoa"){
        # Fit with optim
        optim(par = params,
              fn=ML_optim,
              gr=NULL,
              method=method,
              mod,
              output,
              var,
              input,
              control=options)}else{
        # Fit with newuoa
        minqa::newuoa(
              par = params,
              fn=ML_optim, 
              mod=mod,
              output=output,
              var=var,
              input=input)
              }
       names(fit[[1]]$par)<-names(params)
    }else{
      fit[[i]] <- if(method!="newuoa"){
        optim(par = fit[[i-1]]$par,
              fn=ML_optim,
              gr=NULL,
              method=method,
              mod,
              output,
              var,
              input,
              control=options)}else{
        minqa::newuoa(
          par = fit[[i-1]]$par,
          fn=ML_optim, 
          mod=mod,
          output=output,
          var=var,
          input=input)
      }
      names(fit[[i]]$par)<-names(params)
    }
  }
  
  # Cov step
  if (cov==T){ 
    
    params<-10^fit[[1+restarts]]$par
    mats<- get_matrices(params,mod,output,var,input)
    
    M <- matrix (0,nrow =length(params),ncol=length(params))
    dydtheta.all<-mats[[1]]
    dgdtheta.all<-mats[[2]]
    variances<- reformat(get_preds(mod,params,c(output,var)),input,output)[,5+length(output)]
    
    thetas<- which(names(params)%in%c(prms))
    M <- 1/2*(t(dgdtheta.all/(c(variances^2)))%*%(dgdtheta.all))
    M[thetas,thetas] <- (M[thetas,thetas]+t(dydtheta.all[,thetas]/c(variances))%*% (dydtheta.all[,thetas]))
    
    cov <- tryCatch(solve(M),error=function(err) "Error")
    
    if(is.matrix(cov)){
      fit[[1+restarts]]$cov <- cov
      fit[[1+restarts]]$cor <- cov2cor(cov)
      fit[[1+restarts]]$CVPercent <- sqrt(diag(cov))/params*100
    }else{
      fit[[1+restarts]]$cov <- "Error in covariance step"
    }
  }
  
  fitted_data<- get_preds(mod,params,c(output,var))
  names(fitted_data)[c(5,5+length(output))]<- c("pred","var")
  
  fit[[1+restarts]]$fitted_data<- reformat(fitted_data,input,output)[,c(1:5,5+length(output))]
  fit[[1+restarts]]$par<-10^fit[[1+restarts]]$par
  
  return(unclass(fit[[1+restarts]]))
} 





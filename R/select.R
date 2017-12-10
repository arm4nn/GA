#### IMPORTANT: Please make sure you have installed 'dplyr' packages ####

## Please make sure you have installed the following packages if you choose parallelization ##
## parallel, doParallel, & foreach

########################################################################

#support scripts (functions)
source('popInitial.R')
source('evaluation.R')
source('rankSelection.R')
source('choosing.R')
source('crossover.R')
source('mutation.R')
source('breed.R')
#source('foo.R')
#...(list all the sources)

#this is the primary function of the R package of this project
#the output of this function should be the selected predictors 

select <- function(X, Y, popNum = 100, reg = 'lm', criterion = 'AIC', useParallel = FALSE,
                   numCores = 4, usingRank = TRUE, cross_cutNum = 1, mutation_prob = 0.01,
                   mut_pCurve = FALSE, initial_zeroRate = 0.5, min_iter = 10, max_iter = 500){
  
  #prepare for parallelization if the user choose it
  if(useParallel == TRUE){
    library(parallel)
    library(doParallel)
    library(foreach)
    nCores <- numCores
    registerDoParallel(nCores)
    source('superEvaluation.R')
  }
  
  #X is treated as a data frame; Y is treated as a vector
  X <- as.data.frame(X)
  Y <- as.vector(Y)
  
  if(dim(X)[1] != length(Y)){
    stop("Invalid data: X and Y does not match")
  }
  
  #intialization: generate the first generation
  geneLength <- dim(X)[2]
  firstGeneration <- popInitial(popNum, geneLength, zeroRate = initial_zeroRate)
  currentGeneration <- firstGeneration
  
  #first evaluation
  if(useParallel == TRUE){
    df_current <- superEvaluation(X, Y, firstGeneration, popNum, reg, criterion)
  }else{
    df_current <- evaluation(X, Y, firstGeneration, popNum, reg, criterion)
  }
  
  #iterations for the GA
  #this can go right after the evaluation as well
  i <- 1
  threshold <- 0
  dif <- 0
  fit_record <- c(min(df_current$fitness))
  mutation_prob_backup <- mutation_prob
  
  while(i <= min_iter | (i > min_iter & i <= max_iter & dif > threshold)){
 
	# curving the mutation probability
	  if(mut_pCurve == TRUE){
		  mutation_prob <- min(mutation_prob_backup + 1/(i+1),1)
	  }
    
    if(i > min_iter){
      dif <- abs(min(df_current$fitness) - mean(fit_record[(i - min_iter + 1):i]))
      threshold <- .Machine$double.eps * abs(min(df_current$fitness) + mean(fit_record[(i - min_iter):i]))
    }
    
    #implement GA   
    crtRank <- rankSelection(df_current, usingRank)
    crtChosen <- chooseChromosomes(crtRank, usingRank)
    nextGeneration <- breed(crtChosen, cross_cutNum, mutation_prob)
    
    if(useParallel == TRUE){
      df_current <- superEvaluation(X, Y, nextGeneration, popNum, reg, criterion)
    }else{
      df_current <- evaluation(X, Y, nextGeneration, popNum, reg, criterion)
    }
      
	  fit_record <- c(fit_record, min(df_current$fitness))
	  i <- i + 1
  }
  
  #the selected predictors
  predictor_tmp <- unlist(strsplit(df_current[1,1:(dim(df_current)[2]-1)], NULL))
  predictor. <- as.matrix(X[which(predictor_tmp == '1')])
  
  #return the best model
  if(reg == 'lm'){
    bestModel <- lm(Y ~ predictor.)
  }else{
    bestModel <- glm(Y ~ predictor.)
  }
  
  cat(' Selected predictors:', colnames(predictor.), '\n', 'Fitness value:', 
      mean(fit_record),'\n')
  
  return(bestModel)
}
# "This is just the scratchpad for the analysis not the final report"
# author: "Ozan Aygun"
# date: "3/30/2017"
# output: html_document
# ---
        
#Download the data sets:
        
      

fileURLTrain <- "https://d396qusza40orc.cloudfront.net/predmachlearn/pml-training.csv"

fileURLTest <- "https://d396qusza40orc.cloudfront.net/predmachlearn/pml-testing.csv"

download.file(fileURLTrain,"train.csv")
download.file(fileURLTest,"test.csv")


#Load the datasets:
        
        
training <- read.csv("train.csv")
final_testing <- read.csv("test.csv")


#Understand the variables:
        
     
nameframe <- data.frame(names(training),names(final_testing))


# We notice that the **classe** variable is the outcome variable representing: exactly according to the specification (Class A), throwing the elbows to the front (Class B), lifting the dumbbell only halfway (Class C), lowering the dumbbell only halfway (Class D) and throwing the hips to the front (Class E).
# 
# Class A corresponds to the specified execution of the exercise, while the other 4 classes correspond to common mistakes.
# 
# We will use the training set to build a predictive model in order to classify the cases in the final_test set.
# 
# # Partitioning the training data set
# 
# It would be useful to partition the training set into:
#         
#         - building: actual model building set
# - tune.testing: testing set for tuning the build models
# - validation: for one-time evaluation of the model performance


library(caret);library(ggplot2); set.seed(23445)
INbuilding <- createDataPartition(y = training$classe,p=0.6,list = FALSE)
building <- training[INbuilding,]

rest <- training[-INbuilding,]

INtune <- createDataPartition(y = rest$classe,p=0.5,list = FALSE)
tune.testing <- rest[INtune,]
validation <- rest[-INtune,]
```

# General preprocessing and EDA (all processing performed in the building set and exactly applied to tune.testing,validation, and final_testing sets)


summary(building)

table(building$classe) # Classes are slightly unbalanced, we have more class A.

# Decide what to do with the missing values
apply(is.na(building),2,sum) #  11548 data points (98% of them) are consistently missing in 
length(which(apply(is.na(building),2,sum)>0)) # 67 variables

plot(building$classe[is.na(building$amplitude_pitch_forearm)]) # slightly more NA's in A class but #overall balanced distribution across the classes

##################################################################################################
# STEP1: Drop the missing value containing variables as they are unlikely to add value to our #prediction (process the tune.testing, validation, final_testing sets exactly in the same way )


tune.testing <- tune.testing[,-which(apply(is.na(building),2,sum)>0)]
validation <- validation[,-which(apply(is.na(building),2,sum)>0)]
final_testing <- final_testing[,-which(apply(is.na(building),2,sum)>0)]
building <- building[,-which(apply(is.na(building),2,sum)>0)]
##################################################################################################


# Find and remove near-zero variance variables
nsv <- nearZeroVar(x = building, saveMetrics = TRUE)

sum(!nsv$nzv) # 59 variables have non-zero variance and will be kept in the building set

##################################################################################################
# STEP 2: Remove nzv variables, (process the tune.testing, validation and final_testing sets exactly in the same way #)

tune.testing <- tune.testing[,!nsv$nzv]
validation <- validation[,!nsv$nzv]
final_testing <- final_testing[,!nsv$nzv]
building <- building[,!nsv$nzv]
##################################################################################################
#                                       
#                                        EDA
#
##################################################################################################
# Next, let's have a look at the correlation between the continuous variables
cont <- !sapply(building,is.factor) # Continuous variables in the building set

M <- abs(cor(building[,cont])) # M is an absolute value correlation matrix representing the pairwise #correlations between all continuous variables 
diag(M) <- 0 # We replace the diagonal values with zero (just because these are the correations with  #themselves we are not interested in capturing them).
which(M > 0.8, arr.ind = TRUE) # What are the highest correated variables?
unique(row.names(which(M > 0.8, arr.ind = TRUE))) # We find that there are 18 highly correlated #predictiors in the data set
qplot(building[,row.names(M)[7]],building[,colnames(M)[5]], color = classe, data = building)
qplot(building[,row.names(M)[8]],building[,colnames(M)[5]], color = classe, data = building)
plot(building[,row.names(M)[13]],building[,colnames(M)[5]])
plot(building[,row.names(M)[15]],building[,colnames(M)[6]])
plot(building[,row.names(M)[33]],building[,colnames(M)[40]])
qplot(building[,row.names(M)[33]],building[,colnames(M)[40]], color = classe, data = building)

cor.variables <- building[,unique(row.names(which(M > 0.8, arr.ind = TRUE)))]
cor.variables$classe <- building$classe

# Performing PCA to see if dimension reduction might help to resolve classes
prePCA <- preProcess(cor.variables[,-19],method = "pca")
PCAcor <- predict(prePCA,cor.variables[,-19])
qplot(PCAcor$PC1,PCAcor$PC2, color = classe, data = cor.variables)
qplot(PCAcor$PC1,PCAcor$PC3, color = classe, data = cor.variables)
qplot(PCAcor$PC2,PCAcor$PC3, color = classe, data = cor.variables)
# Not much obvious advantage gained by calculating principal components to seperate classes

# We notice that the correlated predictors have already clusters within them. In this case, I will not #attempt #further dimension reduction, because the data looks like suitable for classification algorithms (rather than linear #models)

##################################################################################################
# STEP3: Converting factor variables into dummy variables

which(sapply(building[,-59],is.factor)) # Only two factor variables remained in the datasets
# Note that one of them is a time stamp composed of 20 unique values. At this point we will model them as categorical variables
factors <- which(sapply(building[,-59],is.factor))
# Convert these variables into dummy variables:

dummies <- dummyVars(classe ~ user_name + cvtd_timestamp, data = building)

# Add them into building and all test and validation sets and drop the original factor variables


building <- cbind(building[,-factors],predict(dummies,building))
tune.testing <- cbind(tune.testing[,-factors],predict(dummies,tune.testing))
validation <- cbind(validation[,-factors],predict(dummies,validation))
names(final_testing)[59] <- "classe" # Names in newdata should match the object to use predict
final_testing <- cbind(final_testing[,-factors],predict(dummies,final_testing))

##################################################################################################
# STEP4: Eliminating the bias from the indexing variable X

# We notice that the variable X is just an indexing variable that can perfectly seperate the classes
qplot(X,classe,data = building,color = classe)+theme_bw()

# Such a variable has no real predictive power because the real samples will not be ordered based on such index
# Therefore, we remove the variable X from all sets before building the models:

building <- subset(building,select = -c(X))
tune.testing <- subset(tune.testing,select = -c(X))
validation <- subset(validation,select = -c(X))
final_testing <- subset(final_testing,select = -c(X))

##########################################################################
# STEP5 :Finally legitimize the names of the variables: (needed for the classification algorithms to run #smoothly)

names(building) <- make.names(names(building))
names(tune.testing) <- make.names(names(tune.testing))
names(validation) <- make.names(names(validation))
names(final_testing) <- make.names(names(final_testing))
```

#This concludes data pre-processing and exploratory data analysis. Only the building set was used to perform exploration, then all 4 sets were processed exactly in the same way.

# Next we can start model building approaches using the building set

#Since this is a classification problem and there are clear non-linear trends/structures/clusters in the data, I will perform tree-based prediction algorithms and support vector machines to perform predictions.

# Individual classifiers:

#- Simple classification tree (method = "rpart") with cross validation

```{r,results='markup', message=FALSE,warning=FALSE, cache=TRUE}
set.seed(125745)
RPART <- train(classe ~ ., data = building,method = "rpart", trControl = trainControl(method = "cv", number = 10))
saveRDS(RPART,"RPART.rds") #Save model object for future loading if necessary
```

#- Random Forest (method = "cv") with cross validation


set.seed(125745)
RF <- train(classe ~ ., data = building,method = "rf", trControl = trainControl(method = "cv", number = 10)) # Takes very long time to run!!
saveRDS(RF,"RF.rds") #Save model object for future loading if necessary



#- Boosted tree (method = "gbm") with cross validation


set.seed(125745)
GBM <- train(classe ~ ., data = building,method = "gbm", trControl = trainControl(method = "cv", number = 10), verbose = FALSE) # Takes very long time to run!!
saveRDS(GBM,"GBM.rds") #Save model object for future loading if necessary
```

#- support vector machines with a radial kernel


set.seed(125745)
SVM <- train(classe ~ ., data = building,method = "svmRadial", trControl = trainControl(method = "cv", number = 10))
# Takes very long time to run!!
saveRDS(SVM,"SVM.rds")



# Reading back the earlier classifiers when needed to work with them

RPART = readRDS("RPART.rds")
RF = readRDS("RF.rds")
GBM = readRDS("GBM.rds")
SVM = readRDS("SVM.rds")


# Summarizing the initial results from the individual classifiers

# Using resamples function from the caret package to summarize the data

modelsummary <- resamples(list(RPART=RPART,RF=RF,GBM=GBM,SVM=SVM))

# In-sample accuracy values for each model
summary(modelsummary)$statistics$Accuracy

# If necessary we can also produce 'variable importance' plots to see which variables are making most contributions #to each model
dotPlot(varImp(RPART))
dotPlot(varImp(RF))
dotPlot(varImp(SVM))
dotPlot(varImp(GBM))
```

# Making predictions by using the classifiers and tune.testing set

```{r,results= 'markup', message=FALSE,warning=FALSE, cache=TRUE}

pred.tune.RPART <- predict(RPART,newdata = tune.testing)
pred.tune.RF <- predict(RF,newdata = tune.testing)
pred.tune.SVM <- predict(SVM,newdata = tune.testing)
pred.tune.GBM <- predict(GBM,newdata = tune.testing)

# Collect accuracy values in a data.frame:

tune.testing.predictions <-data.frame(pred.tune.RPART,pred.tune.RF,pred.tune.SVM,pred.tune.GBM)

tune.testing.accuracy <- apply(tune.testing.predictions, 2, function(x){
        temp=confusionMatrix(x,tune.testing$classe)$overall[1]
        names(temp) <- names(x)
        return(temp)
})

```
#Based on the prediction in the tune.testing set, Random Forest classification tree gave the highest accuracy. The accuracy is remarkable. Boosted tree also gave a comparable accuracy.

# Stacked classifiers:


```{r,results='markup'}
# At this stage I will carry over the predictions of the individual models above and see if I can stack some #combinations of these models to see if we can further improve the accuracy.
# 
# - I will assemble all possible combinations of the above models:
# 
# This approach below will help me to build all these combinatorial models within a loop:


# library(combinat)
# 
# lsmod = list ("RPART","GBM","RF","SVM")
# lsmod.combin = list(combn(lsmod,2),combn(lsmod,3),combn(lsmod,4)) # each column makes a prediction model fit
########################################################


set.seed(125745)
tune.testing.predictions$classe <- tune.testing$classe



stacked.model.rpart <- train(classe ~ ., method = "rpart", data = tune.testing.predictions,trControl = trainControl(method = "cv", number = 10) )

stacked.model.rf <- train(classe ~ ., method = "rf", data = tune.testing.predictions,trControl = trainControl(method = "cv", number = 10) )

stacked.model.svm <- train(classe ~ ., method = "svmRadial", data = tune.testing.predictions,trControl = trainControl(method = "cv", number = 10) )

stacked.model.gbm <- train(classe ~ ., method = "gbm", data = tune.testing.predictions,trControl = trainControl(method = "cv", number = 10) )


# Using resamples function from the caret package to summarize the data

stacked.modelsummary <- resamples(list(RPART=stacked.model.rpart,RF=stacked.model.rf,GBM=stacked.model.gbm ,SVM=stacked.model.svm))

# In-sample accuracy values for each model
summary(stacked.modelsummary)$statistics$Accuracy

```





#Then I will perform one-time out of the sample validation by using the validation data set:
        
        # Making predictions by using all classifiers and validation set
        
        
        ```{r,results= 'markup', message=FALSE,warning=FALSE, cache=TRUE}

# Individual model fits
pred.validation.RPART <- predict(RPART,newdata = validation)
pred.validation.RF <- predict(RF,newdata = validation)
pred.validation.SVM <- predict(SVM,newdata = validation)
pred.validation.GBM <- predict(GBM,newdata = validation)


# Stacked model fits : needs to be updated:
# First combine the predictions of the individual classifiers from the validation set:

validation.predictions <-data.frame(pred.tune.RPART = pred.validation.RPART, 
                                    pred.tune.RF = pred.validation.RF,
                                    pred.tune.SVM=pred.validation.SVM,
                                    pred.tune.GBM = pred.validation.GBM)

pred.validation.Stacked.RPART <- predict(stacked.model.rpart,newdata = validation.predictions)
pred.validation.Stacked.RF <- predict(stacked.model.rf,newdata = validation.predictions)
pred.validation.Stacked.SVM <- predict(stacked.model.svm,newdata = validation.predictions)
pred.validation.Stacked.GBM <- predict(stacked.model.gbm,newdata = validation.predictions)



# Collect accuracy values in a data.frame:

collected.validation.predictions<-data.frame(pred.validation.RPART,pred.validation.RF,pred.validation.SVM,pred.validation.GBM,pred.validation.Stacked.RPART,pred.validation.Stacked.RF,pred.validation.Stacked.SVM,pred.validation.Stacked.GBM)

validation.accuracy <- apply(collected.validation.predictions, 2, function(x){
        temp=confusionMatrix(x,validation$classe)$overall[1]
        names(temp) <- names(x)
        return(temp)
})

```

# We found that the combinations of the individual models stacked by SVM and GBM further increased the overall accuracy of the predictions. However, they did not go beyond the accuracy level of RF function. 
# 
# We will perform the predictions on the final_testing data set by using the stand alone RF model:
        
final.prediction.RF <- predict(RF,newdata = final_testing)
# This provides the correct prediction as confirmed by the quiz results!!
# [1] B A B A A E D B A A B C B A E E A B B B



library(ggplot2)
library(survival)
library(survminer)
library(gtsummary)
library(dplyr)
library(plyr)
library(tableone)  
library(kableExtra)
library(randomForestSRC)
library(pec)
library(mice)
library(corrplot)
library(circlize)
library(ggplot2)
library(tidyverse)
library(RColorBrewer)
library(survival)
library(survminer)
library(mgcv)
library(lattice)
library(MASS)
library(nnet)
library(mice)
library(sjPlot)
library(sjmisc)
library(sjlabelled)
library(AUC)
library(tableone)  
library(survival)
library(kableExtra)
library(forestplot)
library(stringr)
library(rms)
library(pec)
library(ipred)

# read data
rawdata <- read.csv("rawraw1.csv",sep=" ")

#data preparation
#choose year
raw1 <- rawdata[rawdata$Year.of.diagnosis<=2015&rawdata$Year.of.diagnosis>=2010,]

#rename colname
colnames(raw1) <- c("age1","sex","year","diagnose","ICDO31","ICDO32","race","age2","months","flag","ER","PR","HER","tumor_size","stage1","RX1","reginal")

#factor age
#raw1$age <- factor(raw1$age,levels = c("01-04 years", "05-09 years", "10-14 years","15-19 years","20-24 years","25-29 year","30-34 years","35-39 years","40-44 years","45-49 years","50-54 years","55-59 years","60-64 years","65-69 years","70-74 years","75-79 years","80-84 years","85+ years"))
#raw1$age <- factor(raw1$age, labels=c("01-04", "05-09", "10-14","15-19","20-24","30-34","35-39","40-44","45-49","50-54","55-59","60-64","65-69","70-74","75-79","80-84","85+"))

#deal with age
raw1$age <- as.numeric(lapply(raw1$age2,function(x) substr(x,1,2)))

#deal with race
r1 <- c("Chinese","Japanese","Filipino","Korean (1988+)","Vietnamese (1988+)","Laotian (1988+)","Hmong (1988+)","Kampuchean (1988+)","Thai (1994+)","Asian Indian (2010+)","Asian Indian or Pakistani, NOS (1988+)")
r2 <- c("White")
r3 <- c("Black")
r4 <- c("American Indian/Alaska Native")
r5 <- c("Hawaiian","Micronesian, NOS (1991+)","Chamorran (1991+)","Guamanian, NOS (1991+)","Polynesian, NOS (1991+)","Tahitian (1991+)","Samoan (1991+)","Tongan (1991+)","Melanesian, NOS (1991+)","Fiji Islander (1991+)","New Guinean (1991+)","Pacific Islander, NOS (1991+)")

raw1$race_6 <- 0
for (i in 1:dim(raw1)[1]){
  if (raw1$race[i] %in% r1){
    raw1$race_6[i] <- 0 #"Asian"
  }
  else if (raw1$race[i] %in% r2){
    raw1$race_6[i] <- 1 #"White"
  }
  else if (raw1$race[i] %in% r3){
    raw1$race_6[i] <- 2 #"Black"
  }
  else if (raw1$race[i] %in% r4){
    raw1$race_6[i] <- 3 #"America Indian"
  }
  else if (raw1$race[i] %in% r5){
    raw1$race_6[i] <- 4 #"Native Hawaii or other Pacific Islander"
  }
  else{
    raw1$race_6[i] <- 5 #"Others"
  }
}

#deal with stage
raw1$stage <- NA
raw1$stage[raw1$stage1=="0"] <- 0
raw1$stage[raw1$stage1=="I"] <- 1
raw1$stage[raw1$stage1 %in% c("IIA","IIB")] <- 2
raw1$stage[raw1$stage1 %in% c("IIIA","IIIB","IIIC","IIINOS")] <- 3
raw1$stage[raw1$stage1=="IV"] <- 4


#deal with ER status
raw1$ER[raw1$ER %in% c("Borderline/Unknown","Recode not available")] <- NA
raw1$ER[raw1$ER=="Positive"] <- 1
raw1$ER[raw1$ER=="Negative"] <- 0

#deal with PR status
raw1$PR[raw1$PR %in% c("Borderline/Unknown","Recode not available")] <- NA
raw1$PR[raw1$PR=="Positive"] <- 1
raw1$PR[raw1$PR=="Negative"] <- 0

#deal with HER status
raw1$HER[raw1$HER %in% c("Borderline/Unknown","Recode not available")] <- NA
raw1$HER[raw1$HER=="Positive"] <- 0
raw1$HER[raw1$HER=="Negative"] <- 1

#construct new variable
raw1$ER_PR <- NA
raw1$ER_PR[raw1$ER==1|raw1$PR==1] <- 1
raw1$ER_PR[raw1$ER==1&raw1$PR==1] <- 2
raw1$ER_PR[raw1$ER==0&raw1$PR==0] <- 0

#deal with RX1
raw1 <- raw1[raw1$RX1!=99,]
raw1$surgery <- NA
raw1$surgery[raw1$RX1>0] <- 1
raw1$surgery[raw1$RX1==0] <- 0


#deal with tumor size
raw1$tumor_size <- as.integer(raw1$tumor_size)
raw1$real_tumor <- NA
for (i in 1:dim(raw1)[1]){
  if (raw1$tumor_size[i] %in% c(990,995,996,997,998,999)){
    raw1$real_tumor[i] <- NA
  }
  else if (raw1$tumor_size[i]<=100 | raw1$tumor_size[i] == 991){
    raw1$real_tumor[i] <- 10 
  }
  else if (raw1$tumor_size[i]<=200 | raw1$tumor_size[i] == 992){
    raw1$real_tumor[i] <- 20
  }
  else if (raw1$tumor_size[i]<=300 | raw1$tumor_size[i] == 993){
    raw1$real_tumor[i] <- 30
  }
  else if (raw1$tumor_size[i]<=400 | raw1$tumor_size[i] == 994){
    raw1$real_tumor[i] <- 40 
  }
  else if (raw1$tumor_size[i]<=500){
    raw1$real_tumor[i] <- 50
  }
  else if (raw1$tumor_size[i]>500){
    raw1$real_tumor[i] <- 60
  }
}

#deal with survival month
raw1$months <- as.integer(raw1$months)
raw1 <- raw1[raw1$months>=0,]
raw1 <- raw1[!is.na(raw1$flag),]

#deal with flag
raw1$status  <- NA
for (i in 1:dim(raw1)[1]){
  if (raw1$flag[i]=="Complete dates are available and there are 0 days of survival"){
    raw1$status[i] <- 2 
  }
  else if (raw1$flag[i]=="Complete dates are available and there are more than 0 days of survival"){
    raw1$status[i] <- 2 
  }
  else if (raw1$flag[i]=="Incomplete dates are available and there cannot be zero days of follow-up"){
    raw1$status[i] <- 1
  }
  else if (raw1$flag[i]=="Incomplete dates are available and there could be zero days of follow-up"){
    raw1$status[i] <- 1 
  }
}

#deal with bad tumor number #delete this variable
#raw1$tumor_number_bad[raw1$tumor_number_bad=="Unknown"] <- NA
#raw1$tumor_number_bad <- as.integer(raw1$tumor_number_bad)

#deal with good tumor number #delete this variable
#raw1$tumor_number_good <- as.integer(raw1$tumor_number_good)

#deal with sex
raw1$sex[raw1$sex=="Female"] <- 1
raw1$sex[raw1$sex=="Male"] <- 0
raw1$sex <- as.numeric(raw1$sex)

#deal with reginal
raw1$reginal <- as.numeric(raw1$reginal)
raw1$reginal[raw1$reginal>90] <- NA

data <- raw1 %>% select("age","sex","year","months","status","HER","race_6","stage","ER_PR","surgery","real_tumor","reginal")

#factorize
data$HER <- factor(data$HER)
data$race_6 <- factor(data$race_6)
data$stage <- factor(data$stage)
data$ER_PR <- factor(data$ER_PR)
data$surgery <- factor(data$surgery)
data$sex <- factor(data$sex)
data$real_tumor <- factor(data$real_tumor)

#five year status
data$status5 <- NA
data$status5[data$months>60] <- 0
data$status5[data$months<=60&data$status==1] <- 1
data$status5[data$months<=60&data$status==2] <- 2

train <- data[data$year<=2014,]
test <- data[data$year==2015,]
test <- na.omit(test)

# complete data
complete_train <- na.omit(train)

#Missing value analysis
table1_data <- data
table1_data$Incomplete = rep(0,nrow(table1_data))
for(i in 1:nrow(table1_data)){
  if(sum(is.na(table1_data[i,]))!=0){table1_data$Incomplete[i]=1}
}
## Table 1 generation (outcome is generated using original data with 1707 samples)
table1_data %>%
  select("age","sex","HER","race_6","stage","ER_PR","surgery","real_tumor","reginal","Incomplete")%>%
  tbl_summary(by = Incomplete,
              missing = "no",
              type = list(age ~ 'continuous',
                          real_tumor ~ 'continuous'),
              statistic = list(all_continuous() ~ "{mean} ({sd})",
                               all_categorical() ~ "{n} ({p}%)"),
              digits = list(all_continuous() ~ c(2,2),
                            all_categorical() ~ c(0,2))
  ) %>%
  add_n %>%
  add_p(test = list(all_continuous() ~ "t.test",
                    all_categorical() ~ "chisq.test"),
        test.args = all_tests("t.test") ~ list(var.equal = TRUE),## Important argument! 
        pvalue_fun = function(x) style_pvalue(x, digits = 2)) %>%
  bold_p(t = 0.05) %>%
  bold_labels

imp <- mice(train, m=5,printFlag = T,seed=10000)
trainc <- complete(imp)
write.csv(x = trainc,file = "train.csv")
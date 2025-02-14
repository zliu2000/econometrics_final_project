
# ECON 21030 Econometrics - Honors
# Spring 2020, Final Project
# This version: 05/27/2020
# Author: Zhengyang (Jim) Liu

################################################################################
################################ (0) ENVIRONMENT ###############################
################################################################################

root <- "/Users/jimliu/Desktop/econ2103"

maindir <- paste0(root, "/final_project")

outdir <- paste0(maindir, "/out")

rawdir <- paste0(maindir, "/raw")

#libraries
library(MASS)
library(AER)
library(sandwich)
library(lmtest)
library(tidyverse)
library(haven)
library(plm)
library(xlsx)
library(readxl)
library(miceadds)
library(survey)
library(ipumsr)
library(Synth)
library(dplyr)
################################################################################
#DATA CLEANING
################################################################################

setwd(rawdir)
#reading in data using ipumsr package
ddi <- read_ipums_ddi("cps_00004.xml")
data <- read_ipums_micro(ddi)

myvars <- c("YEAR", "MONTH", "STATEFIP", "PERNUM","AGE", "SEX", "RACE",
            "EMPSTAT", "LABFORCE", "IND1950", "UHRSWORKT", "WKSTAT", "EDUC")

data <- data[myvars]

#subsetting based on race
#data <- subset(data, RACE == 200)

#not sure about individual fixed effects when we aggregate by state

#aggregate female employment ratio (and part time hours; not enough data tho) 
#and covariates (shares of education, industry)

#per state, aggregate
#iterating over states
for (i in c(1,2,4:6,8:13,15:42,44:51,53:56))
{
  statedata <- subset(data, STATEFIP==i)
  femstatedata <- subset(data, STATEFIP==i & SEX == 2)
  #sample population
  population = nrow(statedata)
  fempopulation = nrow(femstatedata)
  #Employment status: EMPSTAT
  #10,12 = employed, 20-29 = unemployed, 30-39 = not in labor force
  #CALCULATING COUNTS FOR INTEREST VAR AND COVARIATES GROUPED BY MONTH/YEAR
  #Industry: IND1950
  #sectors:
  #1; 100-299: Agriculture, Forestry, and Fishing, Mining, Construction
  #2; 300-399: Manufacturing
  #3; 400-699:transportation, communications, utilities, wholesale, 
  #and retail trade;
  #4; 700-849:finance, insurance, real estate, business, repair, and 
  #personal services
  #5; 850-936:entertainment and recreation, professional and related services, 
  #public administration, and active duty military 
  grouped <- count(statedata, YEAR)
  #calculating sec1 industry share grouped on year/month
  sec1 <- subset(statedata, 100 <= IND1950 & IND1950 < 300)
  sec1c <- count(sec1, YEAR)
  names(sec1c)[names(sec1c)=="n"] <- "sec1"
  grouped <- left_join(grouped, sec1c, by = c("YEAR" = "YEAR"))
  #calculating sec2 industry share grouped on year/month
  sec2 <- subset(statedata, 300 <= IND1950 & IND1950 < 400)
  sec2c <- count(sec2, YEAR)
  names(sec2c)[names(sec2c)=="n"] <- "sec2"
  grouped <- left_join(grouped, sec2c, by = c("YEAR" = "YEAR"))
  sec3 <- subset(statedata, 400 <= IND1950 & IND1950 < 700)
  sec3c <- count(sec3, YEAR)
  names(sec3c)[names(sec3c)=="n"] <- "sec3"
  grouped <- left_join(grouped, sec3c, by = c("YEAR" = "YEAR"))
  sec4 <- subset(statedata, 700 <= IND1950 & IND1950 < 850)
  sec4c <- count(sec4, YEAR)
  names(sec4c)[names(sec4c)=="n"] <- "sec4"
  grouped <- left_join(grouped, sec4c, by = c("YEAR" = "YEAR"))
  sec5 <- subset(statedata, (850 <= IND1950 & IND1950 < 937) | EMPSTAT == 01)
  sec5c <- count(sec5, YEAR)
  names(sec5c)[names(sec5c)=="n"] <- "sec5"
  grouped <- left_join(grouped, sec5c, by = c("YEAR" = "YEAR"))
  #age 16 to age 19, age 20 to age 24, age 25 to age 64, and age 65 or older
  age1 <- subset(statedata, 16 <= AGE & AGE <= 19)
  age1c <- count(age1, YEAR)
  names(age1c)[names(age1c)=="n"] <- "age1"
  grouped <- left_join(grouped, age1c, by = c("YEAR" = "YEAR"))
  age2 <- subset(statedata, 20 <= AGE & AGE <= 24)
  age2c <- count(age2, YEAR)
  names(age2c)[names(age2c)=="n"] <- "age2"
  grouped <- left_join(grouped, age2c, by = c("YEAR" = "YEAR"))
  age3 <- subset(statedata, 25 <= AGE & AGE <= 64)
  age3c <- count(age3, YEAR)
  names(age3c)[names(age3c)=="n"] <- "age3"
  grouped <- left_join(grouped, age3c, by = c("YEAR" = "YEAR"))
  age4 <- subset(statedata, 65 <= AGE)
  age4c <- count(age1, YEAR)
  names(age4c)[names(age4c)=="n"] <- "age4"
  grouped <- left_join(grouped, age4c, by = c("YEAR" = "YEAR"))
  #less than high school
  edu1 <- subset(statedata, 0 < EDUC & EDUC < 73)
  edu1 <- count(edu1, YEAR)
  names(edu1)[names(edu1)=="n"] <- "edu1"
  grouped <- left_join(grouped, edu1, by = c("YEAR" = "YEAR"))
  
  #high school or equivalent
  edu2 <- subset(statedata, EDUC == 73)
  edu2 <- count(edu2, YEAR)
  names(edu2)[names(edu2)=="n"] <- "edu2"
  grouped <- left_join(grouped, edu2, by = c("YEAR" = "YEAR"))
  
  #some college
  edu3 <- subset(statedata, 80 <= EDUC & EDUC <999)
  edu3 <- count(edu3, YEAR)
  names(edu3)[names(edu3)=="n"] <- "edu3"
  grouped <- left_join(grouped, edu3, by = c("YEAR" = "YEAR"))
  
  #adding female shares
  fem <- count(femstatedata, YEAR)
  names(fem)[names(fem)=="n"] <- "fem"
  grouped <- left_join(grouped, fem, by = c("YEAR" = "YEAR"))
  
  covariates <- c("sec1", "sec2", "sec3", "sec4", "sec5", "age1", "age2", "age3", "age4",
                  "edu1","edu2","edu3", "fem")
  #turning things into shares
  grouped[covariates] <- grouped[covariates]/grouped$n
  grouped$stateid=i;
  
  #ADDING var of interest (employment rate of women)
  femp <- subset(femstatedata, 10 <= EMPSTAT & EMPSTAT<20)
  fempc <- count(femp, YEAR)
  fempc$n <- fempc$n/count(femstatedata, YEAR)$n
  names(fempc)[names(fempc)=="n"] <- "femp"
  grouped <- left_join(grouped, fempc, by = c("YEAR" = "YEAR"))
  
  
  #rbind into collective DI and SFA
  if (i == 1)
  {
    statepanel<-grouped
  }
  else
  {
    statepanel <- rbind(statepanel,grouped)
  }
}
statepanel <- subset(statepanel, YEAR != 2020)
#synthetic control package 
#https://www.rdocumentation.org/packages/Synth/versions/1.1-5/topics/synth
#https://www.rdocumentation.org/packages/Synth/versions/1.1-5/topics/dataprep
  
#statepanel to be balanced
statepanelfoo <- make.pbalanced(as.data.frame(statepanel), balance.type="shared.times", index=c("stateid","YEAR"))
predictors <-c("sec1", "sec2", "sec3", "sec4", "sec5", "age1", "age2", "age3", "age4", "edu1","edu2","edu3", "fem")

dataprep.out<-
  dataprep(
    foo = statepanelfoo,
    predictors = predictors,
    predictors.op = "mean",
    dependent = "femp",
    unit.variable = "stateid",
    time.variable = "YEAR",
    treatment.identifier = 2,
    controls.identifier = c(1,4:6,8:13,15:42,44:51,53:56),
    time.predictors.prior = c(1977:1981),
    time.optimize.ssr = c(1977:1981),
    time.plot = 1977:2019
  )

# run synth
synth.out <- synth(data.prep.obj = dataprep.out)

# Get result tables
synth.tables <- synth.tab(
  dataprep.res = dataprep.out,
  synth.res = synth.out
) 

# results tables:
print(synth.tables)

# plot results:
# synthetic Alaska vs Alaska
path.plot(synth.res = synth.out,
          dataprep.res = dataprep.out,
          Ylab = c("Female Employment Ratio"),
          Xlab = c("year"), 
          Ylim = c(0,1), 
          Legend = c("Alaska","synthetic Alaska"),
) 

#Weights from synthetic control
#(Maryland)24: .063, #(Hawaii)15:.810 #(Wyoming)56:.127


syncontrol <- subset(statepanelfoo, stateid==24)*.063 + 
  .81*subset(statepanelfoo, stateid==15)+.127*subset(statepanelfoo, stateid==56)
#adding dummies for control (synthetic) and treated state (alaska)
syncontrol$alaska <- 0

alaskapanel <- subset(statepanelfoo, stateid==02)
#adding dummies for treated state (alaska)
alaskapanel$alaska <- 1
#combining into one panel
finalpanel <- rbind(alaskapanel, syncontrol)

post <- as.numeric(finalpanel["YEAR"]>=1982)

#adding dummy variables
finalpanel<-cbind(finalpanel, post)

treatment <- as.numeric((finalpanel["alaska"]==1) & (finalpanel["post"]==1))
finalpanel<-cbind(finalpanel, treatment)

outcome <- "femp"
regvariables <- c("alaska","post","treatment", predictors)
# our modeling effort, 
# fully parameterized!
f <- as.formula(
  paste(outcome, 
        paste(regvariables, collapse = " + "), 
        sep = " ~ "))
print(f)

reg1 <- lm(f, data=finalpanel)
#storing heteskedastic robust coefficients
reg1c <- coeftest(reg1, vcov = vcovHC(reg1,type="HC1"))
reg1c

#excluding controls
reg2 <- lm(femp~alaska+post+treatment, data=finalpanel)
#storing heteskedastic robust coefficients
reg2c <- coeftest(reg2, vcov = vcovHC(reg2,type="HC1"))
reg2c
setwd(outdir)
write.xlsx(finalpanel, "finalpanel.xlsx")


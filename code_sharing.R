
# load required packages----

packages= c("openxlsx","dplyr", "tidyverse","knitr", "tidyr", 
            "fastDummies", "openxlsx", "rstatix", "ggpubr","Routliers",
            "caret", "flextable", "officer", "plotly","gtsummary","moderndive",
            "lavaan","robustbase","robustlmm","mice","effectsize", "semTools")


invisible(lapply(packages, library, character.only = TRUE))     



# load data frame----

clinical.trial.all=read.xlsx("clinical.trial.all.xlsx")




#DESCRIPTIVE statistic ----



table.pain.ps.vt= clinical.trial.all %>% 
  select(id, group, time,McGill_n.descriptor,McGill_pain.index,
         McGill_index.sensory,McGill_index.evaluative,McGill_index.affective,
         PSS_10_total, sf_36_vitality) %>% 
  pivot_wider(names_from = time,values_from = c( McGill_n.descriptor,McGill_pain.index,McGill_index.sensory,
                                                 McGill_index.evaluative, McGill_index.affective,
                                                 PSS_10_total, sf_36_vitality)) %>% 
  select(-id,-McGill_n.descriptor_t3,-McGill_pain.index_t3,-McGill_index.sensory_t3,-McGill_index.evaluative_t3,
         -McGill_index.affective_t3,-PSS_10_total_t3,-sf_36_vitality_t2)  %>% 
  tbl_summary(by = group, missing = "no", label = list( McGill_n.descriptor_t1 ~ "Pain n descriptors (MPQ) T0",
                                                        McGill_n.descriptor_t2 ~ "T1",
                                                        McGill_pain.index_t1 ~ "Pain index (MPQ) T0",
                                                        McGill_pain.index_t2 ~ "T1",
                                                        McGill_index.sensory_t1 ~ "Sensory index (MPQ) T0",
                                                        McGill_index.sensory_t2 ~ "T1",
                                                        McGill_index.evaluative_t1 ~ "Evaluative index (MPQ) T0",
                                                        McGill_index.evaluative_t2 ~ "T1",
                                                        McGill_index.affective_t1 ~ "Affective index (MPQ) T0",
                                                        McGill_index.affective_t2 ~ "T1",
                                                        PSS_10_total_t1 ~ "Perceived stress (PSS-10) T0",
                                                        PSS_10_total_t2 ~ "T1",
                                                        sf_36_vitality_t1 ~ "QoL-Vitality (SF-36) T0",
                                                        sf_36_vitality_t3 ~ "T2")) %>% 
  add_n(last = "TRUE")



#df wide format-----


med.pain.ps.vt= clinical.trial.all%>% 
  select(id, group, time,McGill_pain.index, McGill_index.sensory,
         McGill_index.affective, McGill_index.evaluative,PSS_10_total, sf_36_vitality) %>% 
  pivot_wider(names_from = time,values_from = c( McGill_pain.index, McGill_index.sensory,
                                                 McGill_index.affective,McGill_index.evaluative, PSS_10_total, sf_36_vitality)) %>% 
  dummy_cols(select_columns ="group") %>% 
  select(-group_control,-group)



med.pain.ps.vt=med.pain.ps.vt[-c(59,21),]#remove previously identified outliers

names(med.pain.ps.vt)

# Variables distribution----

#Skewness
med.pain.ps.vt %>% 
  select(McGill_pain.index_t2, McGill_index.sensory_t2,
         McGill_index.affective_t2, sf_36_vitality_t3,
         PSS_10_total_t2) %>% 
  skewness( na.rm = TRUE)

#Kurtosis


med.pain.ps.vt %>% 
  select(McGill_pain.index_t2, McGill_index.sensory_t2,
         McGill_index.affective_t2, sf_36_vitality_t3,
         PSS_10_total_t2) %>% 
  kurtosis( na.rm = TRUE)

## Multiple NA imputation df------


med.pain.ps.vt.imp=clinical.trial.all %>% 
  select(id, group, time, McGill_n.descriptor,
         McGill_pain.index, McGill_descriptor.sensory,
         McGill_descriptor.affective,McGill_index.sensory,
         McGill_index.affective, McGill_index.evaluative,PSS_10_total, sf_36_vitality,
         PCS_total, affect_Negative,affect_positive) %>% 
  pivot_wider(names_from = time,values_from = c( McGill_n.descriptor,
                                                 McGill_pain.index, McGill_descriptor.sensory,
                                                 McGill_descriptor.affective,McGill_index.sensory,
                                                 McGill_index.affective,McGill_index.evaluative, PSS_10_total, sf_36_vitality,
                                                 PCS_total, affect_Negative, affect_positive)) %>% 
  dummy_cols(select_columns ="group") %>% 
  select(-group_control,-group)



#construct the predictor matrix setting: -2  to indicate the cluster variable, 1 imputation model with a fixed effect and a random intercept(default)

med.matrix=make.predictorMatrix(med.pain.ps.vt.imp)

med.matrix[,"group_intervention"]=-2

med.pain.ps.vt.imp=mice(med.pain.ps.vt.imp, m=5, predictorMatrix = med.matrix, seed=225)
summary(med.pain.ps.vt.imp)



# Check similarity between raw and imputed data to each variable

stripplot(med.pain.ps.vt.imp,  McGill_index.sensory_t2~ .imp, pch = 20, cex = 2)




#LR Pain Index----

pain.index.lm=lm(McGill_pain.index_t2~McGill_pain.index_t1+group_intervention, data = med.pain.ps.vt) 
summary(pain.index.lm)
cohens_f_squared(pain.index.lm) 
par(mfrow=c(2,2))
plot(pain.index.lm.adj2)
pain.index.lm=tidy(pain.index.lm, conf.int = TRUE) %>% 
  filter(term=="group_intervention") %>% 
  mutate(r2.adj=0.37, term = "Pain index", f2 = 0.22) 

##Test for Trend in Proportions on McGill_index.evaluative----
#Index evaluative has little range (0-2)

table_index.evaluative=med.pain.ps.vt %>% 
  select(id,group,McGill_index.evaluative_t1, McGill_index.evaluative_t2)

table_index.evaluative=table(table_index.evaluative)


trend.proportions.index.evaluative.t2=prop_trend_test(table_index.evaluative)


#LR Index Sensory----

index.sensory.lm=lm(McGill_index.sensory_t2~McGill_index.sensory_t1+group_intervention, data = med.pain.ps.vt) 
summary(index.sensory.lm)
cohens_f_squared(index.sensory.lm) 
par(mfrow=c(2,2))
plot(index.sensory.lm)
index.sensory.lm=tidy(index.sensory.lm, conf.int = TRUE) %>% 
  filter(term=="group_intervention") %>% 
  mutate(r2.adj=0.30, term = "Index sensory", f2 = 0.16 ) 


#LR Index Affective----

index.affective.lm=lm(McGill_index.affective_t2~McGill_index.affective_t1+group_intervention, data = med.pain.ps.vt) 
summary(index.affective.lm)
cohens_f_squared(index.affective.lm)
par(mfrow=c(2,2))
plot(index.affective.lm)
index.affective.lm=tidy(index.affective.lm, conf.int = TRUE) %>% 
  filter(term=="group_intervention") %>% 
  mutate(r2.adj=0.35, term = "Index affective", f2 = 0.22 ) 


#MODELO 1 -PAIN INDEX--> STRESS--->vt----

#MODELO 1 - Good fit, Reduction in Pain Index reduce Perceived stress


path.pain.ps.vt1= '
# Path a
McGill_pain.index_t2~a*group_intervention+McGill_pain.index_t1

# Path b
sf_36_vitality_t3~b*McGill_pain.index_t2+McGill_pain.index_t1+sf_36_vitality_t1

# Path c

PSS_10_total_t2~c*McGill_pain.index_t2+PSS_10_total_t1+McGill_pain.index_t1

# Path d

PSS_10_total_t2~d*group_intervention

# Path e

sf_36_vitality_t3~e*group_intervention

# Path f
sf_36_vitality_t3~f*PSS_10_total_t2+PSS_10_total_t1

# Indirect effect  
ab:=a*b
ac:=a*c
df:=d*f
'

# Fit/estimate the model
set.seed(2021)

model.pain.ps.vt1=sem(path.pain.ps.vt1, med.pain.ps.vt , se="bootstrap", bootstrap= 2000)

# Summarize the results/output

sum.model.pain.ps.vt1=summary(model.pain.ps.vt1, fit.measures=TRUE, standardized= TRUE, rsquare= TRUE)


model.pain.ps.vt1.par=parameterEstimates(model.pain.ps.vt1, ci=TRUE, level=0.95, boot.ci.type= "perc")


model.pain.ps.vt1.stand=standardizedSolution(model.pain.ps.vt1)

#Large positive values indicate the model underpredicts the correlation; large negative values suggest overprediction of correlation

resid(model.pain.ps.vt1, "cor")


#IMPUTED----



set.seed(2021)

model.pain.ps.vt1.imp=sem.mi(path.pain.ps.vt1,med.pain.ps.vt.imp)

sum.model.pain.ps.vt1.imp=summary(model.pain.ps.vt1.imp, fit.measures=TRUE, ci = TRUE, stand = TRUE, rsq = TRUE,
                                  standardized= TRUE)
sum.model.pain.ps.vt1.imp=tibble(sum.model.pain.ps.vt1.imp)

fitMeasures(model.pain.ps.vt1.imp)

print.data.frame(sum.model.pain.ps.vt1.imp)

#MODELO 2 - ----



path.pain.ps.vt2= '
# Path a
McGill_pain.index_t2~a*group_intervention+McGill_pain.index_t1


# Path c

PSS_10_total_t2~c*McGill_pain.index_t2+PSS_10_total_t1+McGill_pain.index_t1

# Path d

PSS_10_total_t2~d*group_intervention

# Path e

sf_36_vitality_t3~e*group_intervention+sf_36_vitality_t1

# Path f
sf_36_vitality_t3~f*PSS_10_total_t2+PSS_10_total_t1

# Indirect effect  
ac:=a*c
acf:=a*c*f
'

# Fit/estimate the model
set.seed(2021)

model.pain.ps.vt2=sem(path.pain.ps.vt2, med.pain.ps.vt , se="bootstrap", bootstrap= 2000)

# Summarize the results/output

sum.model.pain.ps.vt2=summary(model.pain.ps.vt2, fit.measures=TRUE, standardized= TRUE, rsquare= TRUE)


model.pain.ps.vt2.par=parameterEstimates(model.pain.ps.vt2, ci=TRUE, level=0.95, boot.ci.type= "perc")



model.pain.ps.vt2.stand=standardizedSolution(model.pain.ps.vt2)

#Large positive values indicate the model underpredicts the correlation; large negative values suggest overprediction of correlation

resid(model.pain.ps.vt2, "cor")


#IMPUTED----



set.seed(2021)

model.pain.ps.vt2.imp=sem.mi(path.pain.ps.vt2,med.pain.ps.vt.imp)

sum.model.pain.ps.vt2.imp=summary(model.pain.ps.vt2.imp, fit.measures=TRUE, ci = TRUE, stand = TRUE, rsq = TRUE,
                                  standardized= TRUE)
sum.model.pain.ps.vt2.imp=tibble(sum.model.pain.ps.vt2.imp)

fitMeasures(model.pain.ps.vt2.imp)

print.data.frame(sum.model.pain.ps.vt2.imp)


#REVERSED----

path.pain.ps.vt2.rev= '
# Path a
PSS_10_total_t2~a*group_intervention+PSS_10_total_t1


# Path c

McGill_pain.index_t2~c*PSS_10_total_t2+PSS_10_total_t1+McGill_pain.index_t1

# Path d

McGill_pain.index_t2~d*group_intervention

# Path e

sf_36_vitality_t3~e*group_intervention+sf_36_vitality_t1

# Path f
sf_36_vitality_t3~f*McGill_pain.index_t2+McGill_pain.index_t1

# Indirect effect  
ac:=a*c
acf:=a*c*f
'

# Fit/estimate the model
set.seed(2021)

model.pain.ps.vt2.rev=sem(path.pain.ps.vt2.rev, med.pain.ps.vt , se="bootstrap", bootstrap= 2000)

# Summarize the results/output

sum.model.pain.ps.vt2.rev=summary(model.pain.ps.vt2.rev, fit.measures=TRUE, standardized= TRUE, rsquare= TRUE)


model.pain.ps.vt2.par.rev=parameterEstimates(model.pain.ps.vt2.rev, ci=TRUE, level=0.95, boot.ci.type= "perc")



model.pain.ps.vt2.stand.rev=standardizedSolution(model.pain.ps.vt2.rev)

#Large positive values indicate the model underpredicts the correlation; large negative values suggest overprediction of correlation

resid(model.pain.ps.vt2.rev, "cor")

#MODELO 3 - SENSORY INDEX--> STRESS--->vt----

#MODELO 3 - Good fit, Reduction in Pain sensory Index reduce Perceived stress



path.sensory.ps.vt1= '
# Path a
McGill_index.sensory_t2~a*group_intervention+McGill_index.sensory_t1

# Path b
sf_36_vitality_t3~b*McGill_index.sensory_t2+McGill_index.sensory_t1+sf_36_vitality_t1

# Path c

PSS_10_total_t2~c*McGill_index.sensory_t2+PSS_10_total_t1+McGill_index.sensory_t1

# Path d

PSS_10_total_t2~d*group_intervention

# Path e

sf_36_vitality_t3~e*group_intervention

# Path f
sf_36_vitality_t3~f*PSS_10_total_t2+PSS_10_total_t1

# Indirect effect  
ab:=a*b
ac:=a*c
df:=d*f
'

# Fit/estimate the model
set.seed(2021)

model.sensory.ps.vt1=sem(path.sensory.ps.vt1, med.pain.ps.vt , se="bootstrap", bootstrap= 2000)

# Summarize the results/output

sum.model.sensory.ps.vt1=summary(model.sensory.ps.vt1, fit.measures=TRUE, standardized= TRUE, rsquare= TRUE)


model.sensory.ps.vt1.par=parameterEstimates(model.sensory.ps.vt1, ci=TRUE, level=0.95, boot.ci.type= "perc")



model.sensory.ps.vt1.stand=standardizedSolution(model.sensory.ps.vt1)

#Large positive values indicate the model underpredicts the correlation; large negative values suggest overprediction of correlation

resid(model.sensory.ps.vt1, "cor")


#IMPUTED----



set.seed(2021)

model.sensory.ps.vt1.imp=sem.mi(path.sensory.ps.vt1,med.pain.ps.vt.imp)

sum.model.sensory.ps.vt1.imp=summary(model.sensory.ps.vt1.imp, fit.measures=TRUE, ci = TRUE, stand = TRUE, rsq = TRUE,
                                     standardized= TRUE)
sum.model.sensory.ps.vt1.imp=tibble(sum.model.sensory.ps.vt1.imp)

fitMeasures(model.sensory.ps.vt1.imp)

print.data.frame(sum.model.sensory.ps.vt1.imp)



#MODELO 4 - -----



path.sensory.ps.vt2= '
# Path a
McGill_index.sensory_t2~a*group_intervention+McGill_index.sensory_t1


# Path c

PSS_10_total_t2~c*McGill_index.sensory_t2+PSS_10_total_t1+McGill_index.sensory_t1

# Path d

PSS_10_total_t2~d*group_intervention

# Path e

sf_36_vitality_t3~e*group_intervention+sf_36_vitality_t1

# Path f
sf_36_vitality_t3~f*PSS_10_total_t2+PSS_10_total_t1

# Indirect effect  
ac:=a*c
acf:=a*c*f
'

# Fit/estimate the model
set.seed(2021)

model.sensory.ps.vt2=sem(path.sensory.ps.vt2, med.pain.ps.vt , se="bootstrap", bootstrap= 2000)

# Summarize the results/output

sum.model.sensory.ps.vt2=summary(model.sensory.ps.vt2, fit.measures=TRUE, standardized= TRUE, rsquare= TRUE)


model.sensory.ps.vt2.par=parameterEstimates(model.sensory.ps.vt2, ci=TRUE, level=0.95, boot.ci.type= "perc")



model.sensory.ps.vt2.stand=standardizedSolution(model.sensory.ps.vt2)

#Large positive values indicate the model underpredicts the correlation; large negative values suggest overprediction of correlation

resid(model.sensory.ps.vt2, "cor")

#IMPUTED----
set.seed(2021)

model.sensory.ps.vt2.imp=sem.mi(path.sensory.ps.vt2,med.pain.ps.vt.imp)

sum.model.sensory.ps.vt2.imp=summary(model.sensory.ps.vt2.imp, fit.measures=TRUE, ci = TRUE, stand = TRUE, rsq = TRUE,
                                     standardized= TRUE)
sum.model.sensory.ps.vt2.imp=tibble(sum.model.sensory.ps.vt2.imp)

fitMeasures(model.sensory.ps.vt2.imp)

print.data.frame(sum.model.sensory.ps.vt2.imp)

#REVERSED----

path.sensory.ps.vt2.rev= '
# Path a
PSS_10_total_t2~a*group_intervention+PSS_10_total_t1


# Path c

McGill_index.sensory_t2~c*PSS_10_total_t2+PSS_10_total_t1+McGill_index.sensory_t1

# Path d

McGill_index.sensory_t2~d*group_intervention

# Path e

sf_36_vitality_t3~e*group_intervention+sf_36_vitality_t1

# Path f
sf_36_vitality_t3~f*McGill_index.sensory_t2+McGill_index.sensory_t1

# Indirect effect  
ac:=a*c
acf:=a*c*f
'

# Fit/estimate the model
set.seed(2021)

model.sensory.ps.vt2.rev=sem(path.sensory.ps.vt2.rev, med.pain.ps.vt , se="bootstrap", bootstrap= 2000)

# Summarize the results/output

sum.model.sensory.ps.vt2.rev=summary(model.sensory.ps.vt2.rev, fit.measures=TRUE, standardized= TRUE, rsquare= TRUE)


model.sensory.ps.vt2.par.rev=parameterEstimates(model.sensory.ps.vt2.rev, ci=TRUE, level=0.95, boot.ci.type= "perc")



model.sensory.ps.vt2.stand.rev=standardizedSolution(model.sensory.ps.vt2.rev)

#Large positive values indicate the model underpredicts the correlation; large negative values suggest overprediction of correlation

resid(model.sensory.ps.vt2.rev, "cor")
#MODELO 5 - AFFECTIVE INDEX--> STRESS--->vt----

#MODELO 5 - Good fit, Reduction in Pain sensory Index reduce Perceived stress



path.affective.ps.vt1= '
# Path a
McGill_index.affective_t2~a*group_intervention+McGill_index.affective_t1

# Path b
sf_36_vitality_t3~b*McGill_index.affective_t2+McGill_index.affective_t1+sf_36_vitality_t1

# Path c

PSS_10_total_t2~c*McGill_index.affective_t2+PSS_10_total_t1+McGill_index.affective_t1

# Path d

PSS_10_total_t2~d*group_intervention

# Path e

sf_36_vitality_t3~e*group_intervention

# Path f
sf_36_vitality_t3~f*PSS_10_total_t2+PSS_10_total_t1

# Indirect effect  
ab:=a*b
ac:=a*c
df:=d*f
'

# Fit/estimate the model
set.seed(2021)

model.affective.ps.vt1=sem(path.affective.ps.vt1, med.pain.ps.vt , se="bootstrap", bootstrap= 2000)

# Summarize the results/output

sum.model.affective.ps.vt1=summary(model.affective.ps.vt1, fit.measures=TRUE, standardized= TRUE, rsquare= TRUE)


model.affective.ps.vt1.par=parameterEstimates(model.affective.ps.vt1, ci=TRUE, level=0.95, boot.ci.type= "perc")



model.affective.ps.vt1.stand=standardizedSolution(model.affective.ps.vt1)

#Large positive values indicate the model underpredicts the correlation; large negative values suggest overprediction of correlation

resid(model.affective.ps.vt1, "cor")



#IMPUTED----



set.seed(2021)

model.affective.ps.vt1.imp=sem.mi(path.affective.ps.vt1,med.pain.ps.vt.imp)

sum.model.affective.ps.vt1.imp=summary(model.affective.ps.vt1.imp, fit.measures=TRUE, ci = TRUE, stand = TRUE, rsq = TRUE,
                                       standardized= TRUE)
sum.model.affective.ps.vt1.imp=tibble(sum.model.affective.ps.vt1.imp)

fitMeasures(model.affective.ps.vt1.imp)

print.data.frame(sum.model.affective.ps.vt1.imp)



#MODELO 6-----



path.affective.ps.vt2= '
# Path a
McGill_index.affective_t2~a*group_intervention+McGill_index.affective_t1


# Path c

PSS_10_total_t2~c*McGill_index.affective_t2+PSS_10_total_t1+McGill_index.affective_t1

# Path d

PSS_10_total_t2~d*group_intervention

# Path e

sf_36_vitality_t3~e*group_intervention+sf_36_vitality_t1

# Path f
sf_36_vitality_t3~f*PSS_10_total_t2+PSS_10_total_t1

# Indirect effect  
ac:=a*c
acf:=a*c*f
'

# Fit/estimate the model
set.seed(2021)

model.affective.ps.vt2=sem(path.affective.ps.vt2, med.pain.ps.vt , se="bootstrap", bootstrap= 2000)

# Summarize the results/output

sum.model.affective.ps.vt2=summary(model.affective.ps.vt2, fit.measures=TRUE, standardized= TRUE, rsquare= TRUE)


model.affective.ps.vt2.par=parameterEstimates(model.affective.ps.vt2, ci=TRUE, level=0.95, boot.ci.type= "perc")



model.affective.ps.vt2.stand=standardizedSolution(model.affective.ps.vt2)

#Large positive values indicate the model underpredicts the correlation; large negative values suggest overprediction of correlation

resid(model.affective.ps.vt2, "cor")



#IMPUTED----



set.seed(2021)

model.affective.ps.vt2.imp=sem.mi(path.affective.ps.vt2,med.pain.ps.vt.imp)

sum.model.affective.ps.vt2.imp=summary(model.affective.ps.vt2.imp, fit.measures=TRUE, ci = TRUE, stand = TRUE, rsq = TRUE,
                                       standardized= TRUE)
sum.model.affective.ps.vt2.imp=tibble(sum.model.affective.ps.vt2.imp)

fitMeasures(model.affective.ps.vt2.imp)

print.data.frame(sum.model.affective.ps.vt2.imp)







#REVERSED----



path.affective.ps.vt2.rev= '
# Path a
PSS_10_total_t2~a*group_intervention+PSS_10_total_t1


# Path c

McGill_index.affective_t2~c*PSS_10_total_t2+PSS_10_total_t1+McGill_index.affective_t1

# Path d

McGill_index.affective_t2~d*group_intervention

# Path e

sf_36_vitality_t3~e*group_intervention+sf_36_vitality_t1

# Path f
sf_36_vitality_t3~f*McGill_index.affective_t2+McGill_index.affective_t1

# Indirect effect  
ac:=a*c
acf:=a*c*f
'

# Fit/estimate the model
set.seed(2021)

model.affective.ps.vt2.rev=sem(path.affective.ps.vt2.rev, med.pain.ps.vt , se="bootstrap", bootstrap= 2000)

# Summarize the results/output

sum.model.affective.ps.vt2.rev=summary(model.affective.ps.vt2.rev, fit.measures=TRUE, standardized= TRUE, rsquare= TRUE)


model.affective.ps.vt2.par.rev=parameterEstimates(model.affective.ps.vt2.rev, ci=TRUE, level=0.95, boot.ci.type= "perc")



model.affective.ps.vt2.stand.rev=standardizedSolution(model.affective.ps.vt2.rev)

#Large positive values indicate the model underpredicts the correlation; large negative values suggest overprediction of correlation

resid(model.affective.ps.vt2.rev, "cor")

#MEDIATORS TABLE----

#TABLE DF IMPUTED ANALISYS----

pain.ps.vt1.tab.imp=sum.model.pain.ps.vt1.imp %>% 
  filter(label%in% c("a","b","c","d","e","f","ab","ac","df")) %>% 
  select(- op, - exo, - df, - std.lv, - std.nox,- label, - lhs) %>% 
  relocate(any_of(c("rhs","ihs","est","std.all"))) %>% 
  rename(pain.ps.vt1.tab.imp=rhs, Unstandardized.beta=est, Standardized.beta=std.all , SE=se)

pain.ps.vt1.tab.imp=pain.ps.vt1.tab.imp %>% 
  mutate_if(is.numeric, round, 2) %>% 
  flextable() %>% 
  compose(i=c(1,2,3,4,5,6,7,8,9),j=1, value = as_paragraph (c("a - Group-->Pain index", "b - Pain index-->QoL-Vitality",
                                                              "c - Pain index-->PS","d' - Group-->PS",
                                                              "e' - Group-->QoL-Vitality","f - PS-->QoL-Vitality",
                                                              "ab - Group-->Pain index-->QoL-Vitality",
                                                              "ac - Group-->Pain index-->PS","df - Group-->PS-->QoL-Vitality"))) %>% 
  autofit()  %>% 
  save_as_docx( path = "tab1.imput.docx")



pain.ps.vt2.tab.imp=sum.model.pain.ps.vt2.imp %>% 
  filter(label%in% c("a","c","d","e","f","ac","acf")) %>% 
  select(- op, - exo, - df, - std.lv, - std.nox,- label, - lhs) %>% 
  relocate(any_of(c("rhs","ihs","est","std.all"))) %>% 
  rename(pain.ps.vt2.tab.imp=rhs, Unstandardized.beta=est, Standardized.beta=std.all , SE=se)

pain.ps.vt2.tab.imp=pain.ps.vt2.tab.imp %>% 
  mutate_if(is.numeric, round, 2) %>% 
  flextable() %>% 
  compose(i=c(1,2,3,4,5,6,7),j=1, value = as_paragraph (c("a - Group-->Pain index", "c - Pain index-->PS","d' - Group-->PS",
                                                          "e' - Group-->QoL-Vitality","f - PS-->QoL-Vitality",
                                                          "ac - Group-->Pain index-->PS","acf - Group-->Pain index-->PS-->QoL-Vitality"))) %>% 
  autofit()  %>% 
  save_as_docx( path = "tab2.imput.docx")



sensory.ps.vt1.tab.imp=sum.model.sensory.ps.vt1.imp %>% 
  filter(label%in% c("a","b","c","d","e","f","ab","ac","df")) %>% 
  select(- op, - exo, - df, - std.lv, - std.nox,- label, - lhs) %>% 
  relocate(any_of(c("rhs","ihs","est","std.all"))) %>% 
  rename(sensory.ps.vt1.tab.imp=rhs, Unstandardized.beta=est, Standardized.beta=std.all , SE=se)

sensory.ps.vt1.tab.imp=sensory.ps.vt1.tab.imp %>% 
  mutate_if(is.numeric, round, 2) %>% 
  flextable() %>% 
  compose(i=c(1,2,3,4,5,6,7,8,9),j=1, value = as_paragraph (c("a - Group-->Pain Sensory", "b - Pain Sensory-->QoL-Vitality",
                                                              "c - Pain Sensory-->PS","d' - Group-->PS",
                                                              "e' - Group-->QoL-Vitality","f - PS-->QoL-Vitality",
                                                              "ab - Group-->Pain Sensory-->QoL-Vitality",
                                                              "ac - Group-->Pain Sensory-->PS","df - Group-->PS-->QoL-Vitality"))) %>% 
  autofit()  %>% 
  save_as_docx( path = "tab3.imput.docx")



sensory.ps.vt2.tab.imp=sum.model.sensory.ps.vt2.imp %>% 
  filter(label%in% c("a","c","d","e","f","ac","acf")) %>% 
  select(- op, - exo, - df, - std.lv, - std.nox,- label, - lhs) %>% 
  relocate(any_of(c("rhs","ihs","est","std.all"))) %>% 
  rename(sensory.ps.vt2.tab.imp=rhs, Unstandardized.beta=est, Standardized.beta=std.all , SE=se)

sensory.ps.vt2.tab.imp=sensory.ps.vt2.tab.imp %>% 
  mutate_if(is.numeric, round, 2) %>% 
  flextable() %>% 
  compose(i=c(1,2,3,4,5,6,7),j=1, value = as_paragraph (c("a - Group-->Pain Sensory", "c - Pain Sensory-->PS","d' - Group-->PS",
                                                          "e' - Group-->QoL-Vitality","f - PS-->QoL-Vitality",
                                                          "ac - Group-->Pain Sensory-->PS","acf - Group-->Pain Sensory-->PS-->QoL-Vitality"))) %>% 
  autofit()  %>% 
  save_as_docx( path = "tab4.imput.docx")


affective.ps.vt1.tab.imp=sum.model.affective.ps.vt1.imp %>% 
  filter(label%in% c("a","b","c","d","e","f","ab","ac","df")) %>% 
  select(- op, - exo, - df, - std.lv, - std.nox,- label, - lhs) %>% 
  relocate(any_of(c("rhs","ihs","est","std.all"))) %>% 
  rename(affective.ps.vt1.tab.imp=rhs, Unstandardized.beta=est, Standardized.beta=std.all , SE=se)

affective.ps.vt1.tab.imp=affective.ps.vt1.tab.imp %>% 
  mutate_if(is.numeric, round, 2) %>% 
  flextable() %>% 
  compose(i=c(1,2,3,4,5,6,7,8,9),j=1, value = as_paragraph (c("a - Group-->Pain Affective", "b - Pain Affective-->QoL-Vitality",
                                                              "c - Pain Affective-->PS","d' - Group-->PS",
                                                              "e' - Group-->QoL-Vitality","f - PS-->QoL-Vitality",
                                                              "ab - Group-->Pain Affective-->QoL-Vitality",
                                                              "ac - Group-->Pain Affective-->PS","df - Group-->PS-->QoL-Vitality"))) %>% 
  autofit()  %>% 
  save_as_docx( path = "tab5.imput.docx")


affective.ps.vt2.tab.imp=sum.model.affective.ps.vt2.imp %>% 
  filter(label%in% c("a","c","d","e","f","ac","acf")) %>% 
  select(- op, - exo, - df, - std.lv, - std.nox,- label, - lhs) %>% 
  relocate(any_of(c("rhs","ihs","est","std.all"))) %>% 
  rename(affective.ps.vt2.tab.imp=rhs, Unstandardized.beta=est, Standardized.beta=std.all , SE=se)

affective.ps.vt2.tab.imp=affective.ps.vt2.tab.imp %>% 
  mutate_if(is.numeric, round, 2) %>% 
  flextable() %>% 
  compose(i=c(1,2,3,4,5,6,7),j=1, value = as_paragraph (c("a - Group-->Pain Affective", "c - Pain Affective-->PS","d' - Group-->PS",
                                                          "e' - Group-->QoL-Vitality","f - PS-->QoL-Vitality",
                                                          "ac - Group-->Pain Affective-->PS","acf - Group-->Pain Affective-->PS-->QoL-Vitality"))) %>% 
  autofit()  %>% 
  save_as_docx( path = "tab6.imput.docx")


#TABLE ALTERNATIVE MODEL----
pain.ps.vt2.tab.rev= model.pain.ps.vt2.stand.rev %>% 
  filter(label%in% c("a","c","d","e","f","ac","acf")) %>% 
  select(est.std) %>% 
  rename(Standardized.beta=est.std)

pain.ps.vt2.tab.b.rev=model.pain.ps.vt2.par.rev %>% 
  filter(label%in% c("a","c","d","e","f","ac","acf")) %>% 
  select(-op) %>% 
  relocate(any_of(c("rhs","ihs"))) %>% 
  rename(pain.ps.vt2.rev=rhs,var2=lhs, Unstandardized.beta=est, SE=se)

tab1.rev=pain.ps.vt2.tab.b.rev %>% 
  bind_cols(pain.ps.vt2.tab.rev) %>% 
  relocate(any_of(c("pain.ps.vt2.rev","var2","label","Unstandardized.beta", "Standardized.beta"))) %>% 
  mutate_if(is.numeric, round, 2) %>% 
  select(-var2, -label) %>% 
  flextable() %>% 
  compose(i=c(1,2,3,4,5,6,7),j=1, value = as_paragraph (c("a - Group-->PS", "c - PS-->Pain index","d' - Group-->Pain index",
                                                          "e' - Group-->QoL-Vitality","f - Pain index-->QoL-Vitality",
                                                          "ac - Group-->PS-->Pain index","acf - Group-->PS-->Pain index-->QoL-Vitality"))) %>% 
  autofit() %>% 
  save_as_docx( path = "tab1.rev.imput.docx")



sensory.ps.vt2.tab.rev= model.sensory.ps.vt2.stand.rev %>% 
  filter(label%in% c("a","c","d","e","f","ac","acf")) %>% 
  select(est.std) %>% 
  rename(Standardized.beta=est.std)

sensory.ps.vt2.tab.b.rev=model.sensory.ps.vt2.par.rev %>% 
  filter(label%in% c("a","c","d","e","f","ac","acf")) %>% 
  select(-op) %>% 
  relocate(any_of(c("rhs","ihs"))) %>% 
  rename(sensory.ps.vt2.rev=rhs,var2=lhs, Unstandardized.beta=est, SE=se)

tab2.rev=sensory.ps.vt2.tab.b.rev %>% 
  bind_cols(sensory.ps.vt2.tab.rev) %>% 
  relocate(any_of(c("sensory.ps.vt2.rev","var2","label","Unstandardized.beta", "Standardized.beta"))) %>% 
  mutate_if(is.numeric, round, 2) %>% 
  select(-var2, -label) %>% 
  flextable() %>% 
  compose(i=c(1,2,3,4,5,6,7),j=1, value = as_paragraph (c("a - Group-->PS", "c - PS-->Pain Sensory","d' - Group-->Pain Sensory",
                                                          "e' - Group-->QoL-Vitality","f - Pain Sensory-->QoL-Vitality",
                                                          "ac - Group-->PS-->Pain Sensory","acf - Group-->PS-->Pain Sensory-->QoL-Vitality"))) %>% 
  autofit() %>% 
  save_as_docx( path = "tab2.rev.imput.docx")



affective.ps.vt2.tab.rev= model.affective.ps.vt2.stand.rev %>% 
  filter(label%in% c("a","c","d","e","f","ac","acf")) %>% 
  select(est.std) %>% 
  rename(Standardized.beta=est.std)

affective.ps.vt2.tab.b.rev=model.affective.ps.vt2.par.rev %>% 
  filter(label%in% c("a","c","d","e","f","ac","acf")) %>% 
  select(-op) %>% 
  relocate(any_of(c("rhs","ihs"))) %>% 
  rename(affective.ps.vt2.rev=rhs,var2=lhs, Unstandardized.beta=est, SE=se)

tab3.rev=affective.ps.vt2.tab.b.rev %>% 
  bind_cols(affective.ps.vt2.tab.rev) %>% 
  relocate(any_of(c("affective.ps.vt2.rev","var2","label","Unstandardized.beta", "Standardized.beta"))) %>% 
  mutate_if(is.numeric, round, 2) %>% 
  select(-var2, -label) %>% 
  flextable() %>% 
  compose(i=c(1,2,3,4,5,6,7),j=1, value = as_paragraph (c("a - Group-->PS", "c - PS-->Pain Affective","d' - Group-->Pain Affective",
                                                          "e' - Group-->QoL-Vitality","f - Pain Affective-->QoL-Vitality",
                                                          "ac - Group-->PS-->Pain Affective","acf - Group-->PS-->Pain Affective-->QoL-Vitality"))) %>% 
  autofit() %>% 
  save_as_docx( path = "tab3.rev.imput.docx")


# Power analyses


packages.power.med= c("lavaan", "bmem", "moments")


invisible(lapply(packages.power.med, library, character.only = TRUE)) 

#Model S1----
modelS1= '
psychological_stress ~ d*group_intervention+start(-0.99)*group_intervention+c*pain_index+start(0.20)*pain_index
pain_index ~ a*group_intervention+start(-14.42)*group_intervention
QoL_vitality ~ e*group_intervention+start(7.13)*group_intervention+b*pain_index+start(-0.18)*pain_index+f*psychological_stress+start(-0.57)*psychological_stress



psychological_stress ~~ start(20)*psychological_stress
pain_index ~~ start(124)*pain_index
QoL_vitality ~~ start(65)*QoL_vitality
'

power_Pain.Index_PS_QoL.VT = 'ab:=a*b
                          ac:=a*c
                          df:=d*f'




set.seed(2021)

power.modelS1=power.boot(model=modelS1, indirect=power_Pain.Index_PS_QoL.VT, nobs=59, nrep=100, nboot=100, parallel="multicore",
                         skewness= c(0,-0.73, 0.05, -0.10), kurtosis= c(0,4.81, 2.31, 1.90), 
                         ovnames=c("group_intervention","psychological_stress","pain_index", "QoL_vitality"))



summary(power.modelS1)


#Increase N power simulation

set.seed(2021)

power.modelS1n100=power.boot(model=modelS1, indirect=power_Pain.Index_PS_QoL.VT, nobs=100, nrep=100, nboot=100, parallel="multicore",
                             skewness= c(0,-0.73, 0.05, -0.10), kurtosis= c(0,4.81, 2.31, 1.90), 
                             ovnames=c("group_intervention","psychological_stress","pain_index", "QoL_vitality"))



summary(power.modelS1n100)


set.seed(2021)

power.modelS1n150=power.boot(model=modelS1, indirect=power_Pain.Index_PS_QoL.VT, nobs=150, nrep=100, nboot=100, parallel="multicore",
                             skewness= c(0,-0.73, 0.05, -0.10), kurtosis= c(0,4.81, 2.31, 1.90), 
                             ovnames=c("group_intervention","psychological_stress","pain_index", "QoL_vitality"))



summary(power.modelS1n150)


#Model S2----
modelS2= '
psychological_stress ~ d*group_intervention+start(-0.82)*group_intervention+c*pain_index+start(0.20)*pain_index
pain_index ~ a*group_intervention+start(-14.09)*group_intervention
QoL_vitality ~ e*group_intervention+start(6.87)*group_intervention+f*psychological_stress+start(-0.81)*psychological_stress



psychological_stress ~~ start(20)*psychological_stress
pain_index ~~ start(124)*pain_index
QoL_vitality ~~ start(65)*QoL_vitality
'

power_Pain.Index_PS_QoL.VT2 = 'ac:=a*c
                          acf:=a*c*f'




set.seed(2021)

power.modelS2=power.boot(model=modelS2, indirect=power_Pain.Index_PS_QoL.VT2, nobs=59, nrep=100, nboot=100, parallel="multicore",
                         skewness= c(0,-0.73, 0.05, -0.10), kurtosis= c(0,4.81, 2.31, 1.90), 
                         ovnames=c("group_intervention","psychological_stress","pain_index", "QoL_vitality"))



summary(power.modelS2)

#Model 1----
model1= '
psychological_stress ~ d*group_intervention+start(-0.66)*group_intervention+c*pain_sensory+start(0.46)*pain_sensory
pain_sensory ~ a*group_intervention+start(-6.09)*group_intervention
QoL_vitality ~ e*group_intervention+start(6.63)*group_intervention+b*pain_sensory+start(-0.23)*pain_sensory+f*psychological_stress+start(-0.63)*psychological_stress



psychological_stress ~~ start(20)*psychological_stress
pain_sensory ~~ start(36)*pain_sensory
QoL_vitality ~~ start(65)*QoL_vitality
'

power_Pain.Sensory_PS_QoL.VT = 'ab:=a*b
                          ac:=a*c
                          df:=d*f'




set.seed(2021)

power.model1=power.boot(model=model1, indirect=power_Pain.Sensory_PS_QoL.VT, nobs=59, nrep=100, nboot=100, parallel="multicore",
                        skewness= c(0,-0.73, 0.10, -0.10), kurtosis= c(0,4.81, 2.92, 1.90), 
                        ovnames=c("group_intervention","psychological_stress","pain_sensory", "QoL_vitality"))



summary(power.model1)



#Increase N power simulation


set.seed(2021)

power.model1.n100=power.boot(model=model1, indirect=power_Pain.Sensory_PS_QoL.VT, nobs=100, nrep=100, nboot=100, parallel="multicore",
                             skewness= c(0,-0.73, 0.10, -0.10), kurtosis= c(0,4.81, 2.92, 1.90), 
                             ovnames=c("group_intervention","psychological_stress","pain_sensory", "QoL_vitality"))



summary(power.model1.n100)


set.seed(2021)

power.model1.n150=power.boot(model=model1, indirect=power_Pain.Sensory_PS_QoL.VT, nobs=150, nrep=100, nboot=100, parallel="multicore",
                             skewness= c(0,-0.73, 0.10, -0.10), kurtosis= c(0,4.81, 2.92, 1.90), 
                             ovnames=c("group_intervention","psychological_stress","pain_sensory", "QoL_vitality"))



summary(power.model1.n150)






#Model 2----
model2= '
psychological_stress ~ d*group_intervention+start(-0.66)*group_intervention+c*pain_sensory+start(0.46)*pain_sensory
pain_sensory ~ a*group_intervention+start(-6.09)*group_intervention
QoL_vitality ~ e*group_intervention+start(6.63)*group_intervention+f*psychological_stress+start(-0.63)*psychological_stress



psychological_stress ~~ start(20)*psychological_stress
pain_sensory ~~ start(36)*pain_sensory
QoL_vitality ~~ start(65)*QoL_vitality
'

power_Pain.Sensory_PS_QoL.VT2 = 'ac:=a*c
                          acf:=a*c*f'




set.seed(2021)

power.model2=power.boot(model=model2, indirect=power_Pain.Sensory_PS_QoL.VT2, nobs=59, nrep=100, nboot=100, parallel="multicore",
                        skewness= c(0,-0.73, 0.10, -0.10), kurtosis= c(0,4.81, 2.92, 1.90), 
                        ovnames=c("group_intervention","psychological_stress","pain_sensory", "QoL_vitality"))



summary(power.model2)




#Model 3----
model3= '
psychological_stress ~ d*group_intervention+start(-1.70)*group_intervention+c*pain_affective+start(0.58)*pain_affective
pain_affective ~ a*group_intervention+start(-3.40)*group_intervention
QoL_vitality ~ e*group_intervention+start(4.61)*group_intervention+b*pain_affective+start(-0.92)*pain_affective+f*psychological_stress+start(-0.62)*psychological_stress



psychological_stress ~~ start(20)*psychological_stress
pain_affective ~~ start(7)*pain_affective
QoL_vitality ~~ start(65)*QoL_vitality
'

power_Pain.Affective_PS_QoL.VT = 'ab:=a*b
                          ac:=a*c
                          df:=d*f'




set.seed(2021)

power.model3=power.boot(model=model3, indirect=power_Pain.Affective_PS_QoL.VT, nobs=57, nrep=100, nboot=100, parallel="multicore",
                        skewness= c(0,-0.73, 0.17, -0.10), kurtosis= c(0,4.81, 1.96, 1.90), 
                        ovnames=c("group_intervention","psychological_stress","pain_affective", "QoL_vitality"))



summary(power.model3)



#Increase N power simulation


set.seed(2021)

power.model3n100=power.boot(model=model3, indirect=power_Pain.Affective_PS_QoL.VT, nobs=100, nrep=100, nboot=100, parallel="multicore",
                            skewness= c(0,-0.73, 0.17, -0.10), kurtosis= c(0,4.81, 1.96, 1.90), 
                            ovnames=c("group_intervention","psychological_stress","pain_affective", "QoL_vitality"))



summary(power.model3n100)


set.seed(2021)

power.model3n150=power.boot(model=model3, indirect=power_Pain.Affective_PS_QoL.VT, nobs=150, nrep=100, nboot=100, parallel="multicore",
                            skewness= c(0,-0.73, 0.17, -0.10), kurtosis= c(0,4.81, 1.96, 1.90), 
                            ovnames=c("group_intervention","psychological_stress","pain_affective", "QoL_vitality"))



summary(power.model3n150)





#Model 4----
model4= '
psychological_stress ~ d*group_intervention+start(-1.70)*group_intervention+c*pain_affective+start(0.62)*pain_affective
pain_affective ~ a*group_intervention+start(-3.40)*group_intervention
QoL_vitality ~ e*group_intervention+start(6.87)*group_intervention+f*psychological_stress+start(-0.81)*psychological_stress



psychological_stress ~~ start(20)*psychological_stress
pain_affective ~~ start(7)*pain_affective
QoL_vitality ~~ start(65)*QoL_vitality
'

power_Pain.Affective_PS_QoL.VT2 = ' ac:=a*c
                          acf:=a*c*f'




set.seed(2021)

power.model4=power.boot(model=model4, indirect=power_Pain.Affective_PS_QoL.VT2, nobs=57, nrep=100, nboot=100, parallel="multicore",
                        skewness= c(0,-0.73, 0.17, -0.10), kurtosis= c(0,4.81, 1.96, 1.90), 
                        ovnames=c("group_intervention","psychological_stress","pain_sensory", "QoL_vitality"))



summary(power.model4)


#Increase N power simulation

set.seed(2021)

power.model4n100=power.boot(model=model4, indirect=power_Pain.Affective_PS_QoL.VT2, nobs=100, nrep=100, nboot=100, parallel="multicore",
                            skewness= c(0,-0.73, 0.17, -0.10), kurtosis= c(0,4.81, 1.96, 1.90), 
                            ovnames=c("group_intervention","psychological_stress","pain_sensory", "QoL_vitality"))



summary(power.model4n100)







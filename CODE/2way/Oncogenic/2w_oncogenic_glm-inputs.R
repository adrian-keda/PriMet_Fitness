
### ... Loading libraries ----
library(stringr)
library(dplyr)
library(purrr)
library(reshape2)
library(tidyr)
library(tibble)
library(eulerr)
library(gridExtra)
library(ggplot2)



### ... Variables ----
SPLITMOD <- "Subtype-Stage-PM"
freqmut_threshold <- "0.01"
freqcnv_threshold <- "0.10"
FREQ <- paste0("mf",
               as.numeric(freqmut_threshold)*100,
               "-cf",
               as.numeric(freqcnv_threshold)*100)



### ... Loading functions
source("./CODE/common_reg-model-functions.R",local=T)



## Uploading files ----
cancgenedf <- read.csv("./DATA/PROCESSED_DATA/p_cancer-gene-list.tsv",
                       sep = "\t",
                       header = TRUE,
                       stringsAsFactors = FALSE)
color_codes <- read.csv("./DATA/PROCESSED_DATA/p_color_codes.tsv",
                        sep="\t",
                        header=T)
binary_mats <- readRDS("./DATA/PROCESSED_DATA/001_oncokb_binary_matrixes.RDS")
clinical_data <- read.table("./DATA/PROCESSED_DATA/p_clinical-data.tsv",
                            sep = "\t",
                            header=T)



### ... Subsetting clinical data according to model ----
clinical_data <- filter(clinical_data,N_ONCOGENIC_ALTERATIONS>0)
if (SPLITMOD == "Tissue"){model_split_data <- "CANC_TYPE"
}else if (SPLITMOD == "Subtype"){model_split_data <- c("CANC_TYPE","CANC_SUBTYPE")
}else if (SPLITMOD == "Tissue-Stage-PM"){model_split_data <- c("CANC_TYPE","STAGE_PM")
}else if (SPLITMOD == "Subtype-Stage-PM"){model_split_data <- c("CANC_TYPE","CANC_SUBTYPE","STAGE_PM")
}else if (SPLITMOD == "Tissue-Stage-PWOWM"){model_split_data <- c("CANC_TYPE","STAGE_PWOWM")
}else if (SPLITMOD == "Subtype-Stage-PWOWM"){model_split_data <- c("CANC_TYPE","CANC_SUBTYPE","STAGE_PWOWM")}

clinical_data <-
  clinical_data %>%
  group_by_at(model_split_data) %>%
  mutate(G = cur_group_id(),
         name = ifelse(SPLITMOD == "Subtype-Stage-PWOWM",paste(CANC_TYPE,CANC_SUBTYPE,STAGE_PWOWM,sep="."),
                       ifelse(SPLITMOD == "Subtype-Stage-PM",paste(CANC_TYPE,CANC_SUBTYPE,STAGE_PM,sep="."),
                              ifelse(SPLITMOD == "Tissue-Stage-PWOWM",paste(CANC_TYPE,NA,STAGE_PWOWM,sep="."),
                                     ifelse(SPLITMOD == "Tissue-Stage-PM",paste(CANC_TYPE,NA,STAGE_PM,sep="."),
                                            ifelse(SPLITMOD == "Subtype",paste(CANC_TYPE,CANC_SUBTYPE,NA,sep="."),paste(CANC_TYPE,NA,NA,sep="."))))))
         )





### ... Subsetting matrixes according to model ----
ready_bm <- unlist(mapply(function(binary_matrix,clinical_table){
  bm <- subset(binary_matrix,rownames(binary_matrix)%in%clinical_table$SAMPLE_ID)
  bm <- merge(bm,clinical_table[c("SAMPLE_ID","name")],by.x="row.names",by.y="SAMPLE_ID")
  rownames(bm) <- bm$Row.names
  bm$Row.names <- NULL
  split_bm <- split(bm[1:(ncol(bm)-1)],bm$name)
  return(split_bm)},
  unname(binary_mats),
  split(clinical_data,clinical_data$CANC_TYPE),
  SIMPLIFY=F),
  recursive=F)



### ... Generating model inputs ----
model_inputs <- lapply(ready_bm,oncogenic_model_input,freqmut_threshold,freqcnv_threshold)
model_inputs_df <- map_df(model_inputs, ~as.data.frame(.x), .id="id")
model_inputs_df <- model_inputs_df %>% relocate("id", .after = last_col())
model_inputs_df[c("Tissue","Subtype","Stage")] <- str_split_fixed(model_inputs_df$id,"\\.",3)
if (grepl("Tissue",SPLITMOD)){model_inputs_df$Subtype <- NA}
if (!grepl("Stage",SPLITMOD)){model_inputs_df$Stage <- NA}
model_inputs_df[c("id")] <- NULL
model_inputs_df <- merge(model_inputs_df,cancgenedf)



### ... Storing files ----
if (!file.exists('./DATA/GLM_INPUTS/')){
  dir.create('./DATA/GLM_INPUTS/')
}
if (!file.exists('./DATA/GLM_INPUTS/2way__OG')){
  dir.create('./DATA/GLM_INPUTS/2way__OG')
}
setwd('./DATA/GLM_INPUTS/2way__OG')
# Saving
saveRDS(model_inputs,sprintf("2w__OG__glm-inputs_%s_%s.RDS",FREQ,SPLITMOD))
write.table(model_inputs_df,
            sprintf("2w__OG__glm-inputs_%s_%s.tsv",FREQ,SPLITMOD),
            sep="\t",
            quote=FALSE,
            row.names = FALSE)

#Loading packages 
library(tidyverse)
library(lubridate)
library(BiocManager)
library(Biostrings)

df_messy_samples <- read_csv("data/raw/messy_samples.csv",
                             col_types = cols(.default = col_character()))
#exploring messy_samples.csv
dim(df_messy_samples)
colnames(df_messy_samples)
head(df_messy_samples, 10)
str(df_messy_samples)
summary(df_messy_samples)

table(df_messy_samples$sex, useNA = "ifany")
table(df_messy_samples$enrollment_site, useNA = "ifany")
table(df_messy_samples$glucose_unit, useNA = "ifany")
table(df_messy_samples$notes, useNA = "ifany")
unique(df_messy_samples$dob)
unique(df_messy_samples$sample_id)
unique(df_messy_samples$glucose_value)

table(str_replace_all(df_messy_samples$dob, c("[0-9]" = "9", "[a-z]" = "a", "[A-Z]" = "A")))

unique(df_messy_samples$patient_name)
table(str_replace_all(df_messy_samples$patient_name, c("[a-z]" = "a", "[A-Z]" = "A")))
df_messy_samples %>% filter(str_detect(dob, "^\\d{2}\\.\\d{2}\\.\\d{2}$")) %>% select(sample_id, dob)



#Exploring messy_sequences.fasta
fasta_lines <- readLines("data/raw/messy_sequences.fasta")

length(fasta_lines)
head(fasta_lines, 12)

headers <- fasta_lines[str_starts(fasta_lines, ">")]
length(headers)
headers

table(str_detect(headers, "\\|"))
table(str_detect(headers, ";"))
table(str_detect(headers, "="))
table(str_detect(headers, ":"))

seq_lines <- fasta_lines[!str_starts(fasta_lines, ">")]
table(str_detect(seq_lines, "^[ACGTN]+$"))
range(nchar(seq_lines))




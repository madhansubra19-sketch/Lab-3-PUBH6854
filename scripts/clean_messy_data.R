#Loading packages 
library(tidyverse)
library(lubridate)
library(BiocManager)
library(Biostrings)

#Part 1 Clean Messy samples csv Data
df_messy_samples <- read_csv("data/raw/messy_samples.csv",
                             col_types = cols(.default = col_character()))
#1. sample_id
#Found: 2 versions, "S0001" (50 rows) and "s-0003" (10 rows)
#Fix: uppercase, remove hyphen -> "S0003"
clean <- df_messy_samples %>%
  mutate(sample_id = str_remove_all(str_to_upper(sample_id), "-"))

#2. patient_name
#Found: 3 rows with all-caps surname (J. KIM, S. DAVIS, T. DAVIS)
#Fix: surname to title case -> "J. Kim"
clean <- clean %>%
  mutate(patient_name = str_to_title(patient_name))

#3. dob
#Found: 4 formats, MM/DD/YYYY   (18)  e.g. 07/09/1962, YYYY-MM-DD   (16)  e.g. 1997-12-02   already ISO, DD-Mon-YYYY  (12)  e.g. 21-Jun-1997, MM.DD.YY     (14)  e.g. 11.24.53     two-digit year, ambiguous century
#Fix: detect each format with its own regex, parse, output ISO YYYY-MM-DD
#Rule: dot format read as month-first (verified: no first number > 12,and 11.24.53 / 05.30.02 can only be month-first)
#Rule: two-digit year <= 26 -> 20YY, else 19YY  (ASSUMPTION - document it)
#Keep: original string in dob_raw for comparison
clean <- clean %>%
  mutate(
    dob_raw = dob,
    dob = case_when(
      #YYYY-MM-DD (already ISO)
      str_detect(dob_raw, "^\\d{4}-\\d{2}-\\d{2}$") ~ dob_raw,
      
      #MM/DD/YYYY
      str_detect(dob_raw, "^\\d{1,2}/\\d{1,2}/\\d{4}$") ~ as.character(mdy(dob_raw)),
      
      #DD-Mon-YYYY
      str_detect(dob_raw, "^\\d{1,2}-[A-Za-z]{3}-\\d{4}$") ~ as.character(dmy(dob_raw)),
      
      #MM.DD.YY (two-digit year cut-off rule)
      str_detect(dob_raw, "^\\d{1,2}\\.\\d{1,2}\\.\\d{2}$") ~ {
        m <- as.numeric(str_extract(dob_raw, "^\\d{1,2}"))
        d <- as.numeric(str_extract(dob_raw, "(?<=\\.)\\d{1,2}(?=\\.)"))
        y <- as.numeric(str_extract(dob_raw, "\\d{2}$"))
        yyyy <- if_else(y <= 26, 2000 + y, 1900 + y)
        sprintf("%04d-%02d-%02d", yyyy, m, d)
      },
      
      TRUE ~ dob_raw
    )
  ) %>%
  relocate(dob_raw, .after = dob)


#4. sex/gender
#Found: f, F, Female (18) / m, M, Male (23) / U, unknown (15) / NA (4)
#Fix: "female", "male", "unknown"; NA stays NA (not recorded != unknown)
clean <- clean %>%
  mutate(sex = case_when(
    str_detect(sex, "(?i)^(f|female)$") ~ "female",
    str_detect(sex, "(?i)^(m|male)$") ~ "male",
    str_detect(sex, "(?i)^(u|unknown)$") ~ "unknown",
    TRUE ~ NA_character_
  ))


#5. enrollment_site
#Found: 7 spellings for 3 sites
#Site A, SITE-A, site_a          -> Site A
#Site B, siteB                   -> Site B
#"Site C ", "Site  C"            -> Site C   (trailing space, double space)
# Fix: strip whitespace/punctuation, pull the site letter, rebuild "Site X"
clean <- clean %>%
  mutate(
    enrollment_site = paste("Site", str_extract(str_to_upper(str_trim(enrollment_site)), "[A-C]$"))
  )


#6. glucose_value
#Found: mostly clean decimals; "N/A" (2 rows); trailing "*" (2 rows: 112.3*, 223.1*)
#Fix: numeric column glucose_value; "N/A" -> NA
#Keep: glucose_flag = "asterisk" / "missing" / NA so nothing is silently lost
clean <- clean %>%
  mutate(
    glucose_flag = case_when(
      str_detect(glucose_value, "\\*$") ~ "asterisk",
      is.na(glucose_value) | glucose_value %in% c("N/A", "NA", "") ~ "missing",
      TRUE ~ NA_character_
    ),
    glucose_value = suppressWarnings(as.numeric(str_remove(glucose_value, "\\*")))
  )


#7. glucose_unit
#Found: mg/dl, mg/dL, MG/DL (47) / mmol/L (13)
#Fix:   case-insensitive match -> "mg/dL"; "mmol/L" as is
#Issue: mmol/L rows have values 74.9-249.2, identical to the mg/dL range (74.9-249.3).
#ADA thresholds: 126 mg/dL = 7.0 mmol/L, 200 mg/dL = 11.1 mmol/L (factor 18.016).
#Taken literally, 74.9-249.2 mmol/L would be ~1350-4490 mg/dL, which is not
#physiologically plausible, so the unit label is suspect.
#Decision: do NOT convert; add unit_suspect = TRUE for mmol/L rows and
#report unit consistency as unresolved in the readiness note
#(alternative: convert x 18.016 and show why that gives nonsense)
clean <- clean %>%
  mutate(
    unit_suspect = str_detect(glucose_unit, "(?i)mmol"),
    glucose_unit = case_when(
      str_detect(glucose_unit, "(?i)mg/dl") ~ "mg/dL",
      str_detect(glucose_unit, "(?i)mmol/l") ~ "mmol/L",
      TRUE ~ glucose_unit
    )
  )

#8. notes
#Found: "re-draw requested" (5) / NA (55) - already clean, leave as is
#(No transformation required for notes)

#9. write output and verification checks
print(clean %>% select(-patient_name, -notes), n = Inf)
table(clean$sex, useNA = "ifany")
table(clean$enrollment_site, useNA = "ifany")
table(clean$glucose_unit, clean$unit_suspect, useNA = "ifany")
table(clean$glucose_flag, useNA = "ifany")
sum(is.na(clean$dob))
range(clean$dob, na.rm = TRUE)
clean %>% filter(str_detect(dob_raw, "\\.")) %>% select(sample_id, dob_raw, dob) %>% print(n = Inf)
str_subset(clean$sample_id, "^S\\d{4}$", negate = TRUE)
dir.create("data/processed", showWarnings = FALSE)
write_csv(clean, "data/processed/clean_samples.csv")

#Part 2 Clean Messy Fasta Data

#1. read and split into records
#Found: 30 lines, 8 headers, sequences wrap across 1-3 lines (3-60 chars each)
#Fix: Use Biostrings::readDNAStringSet to automatically parse FASTA headers and join wrapped sequence lines
dna_seqs <- readDNAStringSet("data/raw/messy_sequences.fasta")

df_messy_fasta <- tibble(
  header_raw = paste0(">", names(dna_seqs)),
  sequence = as.character(dna_seqs)
)


#2. sample_id
#Found: 8 shapes - sample_001, Sample002, sample-003, SAMPLE_004, sample005,seq6, Sample_007, sample-8. Only the number is reliable.
#Fix: extract token up to delimiter (^>[^\s|;]+), extract digits, zero-pad -> "S001" ... "S008"
#Keep: header_raw for comparison
clean_seq <- df_messy_fasta %>%
  mutate(
    sample_token = str_extract(header_raw, "^>[^\\s|;]+"),
    sample_num = as.numeric(str_extract(sample_token, "\\d+")),
    sample_id = sprintf("S%03d", sample_num)
  ) %>%
  select(-sample_token, -sample_num)


#3. organism
#Found: keyed as organism=, organism:, species=, species: or bare; 4 spellings: Homo_sapiens, Homo sapiens, H.sapiens, Hsapiens
#Fix: detect any of the 4 spellings (case-insensitive) -> "Homo sapiens"
clean_seq <- clean_seq %>%
  mutate(
    organism = if_else(
      str_detect(header_raw, "(?i)(Homo[_\\s]?sapiens|H\\.?sapiens)"),
      "Homo sapiens",
      NA_character_
    )
  )


#4. gene
#Found: keyed as gene=, gene:, target= or bare; always BRCA1 / TP53 / EGFR
#Fix: extract whichever of the three symbols appears (word-bounded)
clean_seq <- clean_seq %>%
  mutate(
    gene = str_extract(header_raw, "\\b(BRCA1|TP53|EGFR)\\b")
  )


#5. length_reported
#Found: len=120, length=150bp, "130 bp", len:NA, or absent (4 headers)
#Fix: capture digits after len/length[=:] or digits before "bp" -> integer; NA if "NA" or absent
clean_seq <- clean_seq %>%
  mutate(
    length_match = str_extract(header_raw, "(?i)(len(gth)?[:=]\\s*\\d+|\\d+\\s*bp)"),
    length_reported = as.integer(str_extract(length_match, "\\d+"))
  ) %>%
  select(-length_match)


#6. note
#Found: only header 7 has one (note:re-sequenced)
#Fix: capture text after note[=:] , NA otherwise
clean_seq <- clean_seq %>%
  mutate(
    note = str_match(header_raw, "(?i)note[:=]\\s*([^|;\\s]+)")[, 2]
  )


#7. sequence and length_actual
#Fix: sequence already joined in step 1; length_actual = nchar(sequence)
#Check: compare length_actual to length_reported where both exist
clean_seq <- clean_seq %>%
  mutate(
    length_actual = nchar(sequence)
  ) %>%
  select(sample_id, organism, gene, length_reported, length_actual, note, sequence, header_raw)

#Evidence check: compare reported vs actual sequence length where reported length exists
clean_seq %>%
  filter(!is.na(length_reported)) %>%
  select(sample_id, length_reported, length_actual)

#8. write output
dir.create("data/processed", showWarnings = FALSE)
write_csv(clean_seq, "data/processed/clean_sequences.csv")

#9. verification checks
print(clean_seq %>% select(-sequence, -header_raw), n = Inf)
table(clean_seq$organism, useNA = "ifany")
table(clean_seq$gene, useNA = "ifany")

#Part 3 Reshaping messy_samples.csv --> samples x features x metadata table

#1. sample-level metadata
#One row per sample; columns that DESCRIBE the sample, not measurements
#Take: sample_id, patient_name, dob, sex, enrollment_site, notes
#Add:  redraw_requested = TRUE/FALSE derived from notes (explicit is better than a free-text field)
sample_metadata <- clean %>%
  select(sample_id, patient_name, dob, sex, enrollment_site, notes) %>%
  mutate(
    redraw_requested = !is.na(notes) & str_detect(notes, "(?i)re-draw")
  )


#2. features, long form
#One row per sample x feature, following the Week 5 gene_counts_long shape
#Take: sample_id, feature = "glucose", value = glucose_value, unit = glucose_unit, flag = glucose_flag
features_long <- clean %>%
  transmute(
    sample_id = sample_id,
    feature = "glucose",
    value = glucose_value,
    unit = glucose_unit,
    flag = glucose_flag
  )


#3. features, wide form
#pivot_wider so each feature x unit becomes its own column:
#glucose_mg_dL (47 values, 13 NA) and glucose_mmol_L (13 values, 47 NA)
#Keeping them as two columns makes the unresolved-units problem visible
#instead of hiding it in a single mixed column
features_wide <- features_long %>%
  mutate(
    feature_unit = case_when(
      unit == "mg/dL" ~ "glucose_mg_dL",
      unit == "mmol/L" ~ "glucose_mmol_L",
      TRUE ~ paste0("glucose_", unit)
    )
  ) %>%
  pivot_wider(
    id_cols = sample_id,
    names_from = feature_unit,
    values_from = value
  ) %>%
  left_join(features_long %>% select(sample_id, glucose_flag = flag), by = "sample_id")


#4. join metadata + wide features by sample_id
#Check: still 60 rows after the join (nothing duplicated or dropped)
sfm <- sample_metadata %>%
  left_join(features_wide, by = "sample_id")

stopifnot(nrow(sfm) == 60)
nrow(sfm)


#5. feature-level metadata
#Small table describing each feature COLUMN: feature, unit, n_nonmissing, source
#(Week 5's gene_metadata.csv analogue)
feature_metadata <- tibble(
  feature = c("glucose_mg_dL", "glucose_mmol_L"),
  unit = c("mg/dL", "mmol/L"),
  n_nonmissing = c(sum(!is.na(sfm$glucose_mg_dL)), sum(!is.na(sfm$glucose_mmol_L))),
  source = "messy_samples.csv",
  qc_note = c(NA_character_,
              "values 74.9-249.2 match the mg/dL range; if truly mmol/L they would equal ~1350-4490 mg/dL (x18.016), which is not physiologically plausible. Unit label suspect; not converted.")
)


#6. readiness checks - these outputs are the evidence for the 2-3 sentence note
#Types:        sapply(sfm, class)
#Missingness: colSums(is.na(sfm)), and how many missing glucose are "missing" vs "asterisk" flagged
#Units:        how many samples have a value in mg/dL vs mmol/L
#Leakage:      is any metadata column something you'd predict from glucose? (write the answer, no code needed)

#Types check
sapply(sfm, class)

#Missingness checks
colSums(is.na(sfm))
table(sfm$glucose_flag, useNA = "ifany")

#Units check
sum(!is.na(sfm$glucose_mg_dL))
sum(!is.na(sfm$glucose_mmol_L))

#Leakage Answer:
#Data leakage specifically occurs when information about a target outcome is present in feature columns. Because no predictive outcome target is defined in this dataset, leakage cannot be formally assessed. However, feature columns contain strictly glucose measurements, and metadata columns (sex, site, dob, redraw_requested) represent independent experimental design factors rather than downstream consequences of glucose levels. Note that patient_name is a direct identifier included for sample tracing that should be removed prior to modeling.

#7. write output
dir.create("data/processed", showWarnings = FALSE)
write_csv(sfm, "data/processed/samples_features_metadata.csv")
write_csv(feature_metadata, "data/processed/feature_metadata.csv")
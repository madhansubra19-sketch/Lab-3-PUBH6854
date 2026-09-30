# Lab 3- PUBH 6854
This Repository compares regex cleaning vs AI-assisted cleaning on two
messy files: `messy_samples.csv` and `messy_sequences.fasta`. 

## Dependencies 
- R 4.4 or higher
- `tidyverse` (includes `stringr`, `readr`, `dplyr`, `tidyr`, `lubridate`)
- `BiocManager` and `Biostrings` (Bioconductor) for reading the FASTA file

Installing `BiocManager` in R:
```r
install.packages(c("tidyverse", "BiocManager"))
BiocManager::install("Biostrings")
```

## How to run
1. Open `Lab-3-PUBH6854.Rproj` in RStudio so all paths resolve relative to the project root.
2. (Optional, recommended first) Run `scripts/explore_messy_data.R`. This prints the exploratory summaries (distinct values, format "shapes" per column, FASTA header patterns) that the cleaning rules were built from.
3. Run `scripts/clean_messy_data.R`. This loads the packages, reads both raw files, applies the regex cleaning, writes the processed outputs, and builds the samples x features x metadata table.

`clean_messy_data.R` is self-contained and can be run on its own. The exploration script shows how the format variants were identified; it is not a prerequisite.

## Regex Inputs and Outputs
- Input: `data/raw/messy_samples.csv` -> Output: `data/processed/clean_samples.csv`
- Input: `data/raw/messy_sequences.fasta` -> Output: `data/processed/clean_sequences.csv`

Columns added beyond the original fields:
- `dob_raw` (clean_samples): the original date string, kept next to the standardized ISO `dob` for comparison.
- `glucose_flag` (clean_samples): `asterisk` for values that carried a trailing `*`, `missing` for `N/A`, otherwise NA.
- `unit_suspect` (clean_samples): TRUE for rows labeled `mmol/L` whose values fall in the same range as the `mg/dL` rows, indicating a probable unit mislabel. These values were not converted.
- `length_actual` (clean_sequences): character count of the joined sequence, for checking against `length_reported` from the header.

## AI Outputs
- `AI_USAGE.md`: the exact prompts used, the full responses, and a description of how AI was used elsewhere in the lab.
- `data/ai/ai_clean_samples.csv`: AI-cleaned version of `messy_samples.csv`, same columns as the raw file.
- `data/ai/ai_clean_sequences.csv`: AI-parsed version of `messy_sequences.fasta`, same columns as the regex output minus `length_actual`.

## Samples Features Metadata  Inputs and Outputs
- Input: `data/processed/samples_features_metadata.csv` (one row per sample, metadata plus feature columns) -> Output: `data/processed/feature_metadata.csv` (one row per feature column).

## Comparison  Write-up
See WRITEUP.md for the regex vs AI comparison analysis, samples x feautres x netadata table notes and analytic readiness notes. 

## Comments   for Instructor
- **Biostrings dependency:** the FASTA read uses `Biostrings::readDNAStringSet`, which is installed through `BiocManager`, not CRAN. All header parsing is done with `stringr` regex; 
Biostrings is only used to join the wrapped sequence lines.




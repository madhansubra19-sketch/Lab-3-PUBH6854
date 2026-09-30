# Lab 3 Write up PUBH 6854
## Approach
Prior to cleaning the `messy_samples.csv` and `messy_sequences.fasta` I explored
each column's distinct values by using the `explore_messy_data.R` script. 
For each discrepancy I found, I wrote a block in `clean_messy_data.R` that fixes 
that column, building up the  `clean` and `clean_seq` data frames, 
which the results from these data frames were written to `data/processed/` as 
`clean_samples.csv` and `clean_sequences.csv` respectively. 

For the AI approach, I used Claude and created one prompt per file which fixed 
output columns, asking for the rule applied to each column and which records 
were ambiguous. The prompts and full responses from Claude can be found in `AI_USAGE.md`. 
Claude produced 3 files, 2 for `messy_samples.csv`, `ai_clean_samples.csv` 
and `cleaning_flags.csv`, and `ai_clean_sequences.csv` was created from 
`messy_sequences.fasta`. 

## How different formats were handlded 

###  messy_samples.csv 
Every column had different variations of data which needed to be harmonized to 
one version. 

`sample_id` came in two versions: `S0001` (51 rows) and lowercase with a hyphen, 
`s-0003` (9 rows). I uppercased everything and removed the hyphen.

`patient_name` was clean except for three all-caps surnames 
(`J. KIM`, `S. DAVIS`, `T. DAVIS`), which I converted to title case.

`dob` had four formats: `MM/DD/YYYY` (18 rows), `YYYY-MM-DD` (16 rows), 
`DD-Mon-YYYY` (12 rows), and `MM.DD.YY` (14 rows).
Each format is matched by its own regex and converted to ISO `YYYY-MM-DD`; 
the original string is kept in `dob_raw`.
Two assumptions were needed for the dot format.
I read it as month-first, because no first field is greater than 12 and records 
like `11.24.53` and `05.30.02` can only be parsed that way.
For the two-digit year I used a cutoff: 26 or less becomes 20YY, 
anything higher becomes 19YY.

`sex` had nine codings: `f`, `F`, `Female` (18 rows), `m`, `M`, `Male` (23), 
`U`, `unknown` (15), and blank (4).These became `female`, `male`, and `unknown`; 
blanks stay NA, since "not recorded" and "recorded as unknown" are different facts.

`enrollment_site` had seven spellings for three sites: 
`Site A`, `SITE-A`, `site_a`; `Site B`, `siteB`; and `Site C ` and `Site  C` 
with a trailing or double space.I trimmed whitespace, uppercased, and pulled the 
final letter to rebuild `Site A`, `Site B`, `Site C`.

`glucose_value` was mostly clean decimals, plus two `N/A` entries and two values
with a trailing asterisk (`112.3*`, `223.1*`).The column is now numeric, with a 
`glucose_flag` column recording `missing` or `asterisk` so neither case is silently lost.

`glucose_unit` had four spellings for two units: `mg/dl`, `mg/dL`, `MG/DL` (47 rows) 
and `mmol/L` (13 rows).The mg/dL variants were collapsed to `mg/dL`.
The mmol/L rows were not converted: their values (74.9 to 249.2) are identical 
in range to the mg/dL rows, and taken literally would equal roughly 1,350 to 4,490 mg/dL, 
which is not physiologically plausible.I kept the label as recorded and added `unit_suspect = TRUE` for those 13 rows.

`notes` had only two states (`re-draw requested` or blank) and needed no cleaning.

###  messy_sequences.fasta
The eight headers had no shared delimiter (pipes, semicolons, spaces, or a mix),
so each field was extracted with its own regex rather than by splitting.

`sample_id` had eight shapes (`sample_001`, `Sample002`, `sample-003`, `SAMPLE_004`, `sample005`, `seq6`, `Sample_007`, `sample-8`); 
only the number is reliable, so I extracted the digits and rebuilt `S001` to `S008`.

`organism` was keyed as `organism=`, `organism:`, `species=`, `species:`, or not 
keyed at all, with four spellings (`Homo_sapiens`, `Homo sapiens`, `H.sapiens`, `Hsapiens`); 
all became `Homo sapiens`.

`gene` was keyed as `gene=`, `gene:`, `target=`, or bare, and was always one of 
`BRCA1`, `TP53`, or `EGFR`, so I matched those three symbols directly.

`length_reported` appeared in five states: `len=120`, `length=150bp`, `130 bp`, `len:NA`, or absent 
(four headers); the number is captured where present and NA otherwise.
A `length_actual` column (character count of the joined sequence) was added to 
check the reported values.

`note` appeared once (`note:re-sequenced` on header 7) and is NA elsewhere.

Biostrings handled joining the wrapped sequence lines; all header parsing is regex.

## Comparison
After reviewing `clean_samples.csv` vs `ai_clean_samples.csv` I noticed that all 
Sample IDS matched, with 5 of the columns agreeing on every row. These columns are:
glucose_value, dob, enrollment_site, patient_name, and notes. Due to different
label conventions there were 56 sex column differences ("F" vs "female").
Claude relabeled 12 rows under the glucose_unit column from mmol/L to mg/dL
(S0006, S0011, S0014, S0015, S0016, S0017, S0024, S0033, S0035, S0038, S0039, S0046).
The AI noted in `cleaning_flags.csv` that these values were not 
physiologically possible. The`cleaning_flags.csv` also gave more annotations about 
the five dot dates whose month/day order is ambiguous (S0034, S0037,S0046,S0058, and S0060) 
and eight slash dates where the day is 12 or less S0001, S0010, S0015, S0016, S0031, S0039, S0044, S0052)
than I did with my `clean_samples.csv`. 

After reviewing `clean_sequences.csv` vs `ai_clean_sequences.csv`
I noticed that organism, gene, reported length, note, and sequence agreed. But sample_id
columns differed due to label conventions (S001 vs sample_001). Although reported 
lengths were agreed upon between the regex and AI files, the regex accounted for 
length and calculated the actual length under `length_actual` column that exposed
some mismatches like in S0003 where reported length was 150 but actual length was
157. Claude did not make a `length_actual` column but it did report this discrepancy 
in its response which can be found in `AI_USAGE.md`.

While writing the regex script and exploratory script took longer than prompting 
Claude to clean the file (a few hours vs a few minutes) verifying that the AI was
correct took about just as long. For a data set I had to defend, I would write
regex but use an AI model like Claude to verify.

## Failure Modes
There are 4 instances where one or both approaches went wrong. First one is 
the unit relabel, where Claude rewrote the recorded unit on 12 rows 
(S0006, S0011, S0014, S0015, S0016, S0017, S0024, S0033, S0035, S0038, S0039, S0046) 
and documented each change in a separate `cleaning_flags.csv`, so anyone who 
receives only `ai_clean_samples.csv` sees 60 rows of `mg/dL` with no sign that 
anything was changed, whereas my script kept the label as recorded and put the 
flag in the same table as `unit_suspect`.Both choices are defensible, 
the difference is whether the record of the change can be separated from the data.
Second, the Claude's written explanation contained counts that do not match the file: 
it reported 17 ISO and 17 slash dates (my `table()` output shows 16 and 18), 
7 re-draw notes (there are 5), and 12 hyphenated IDs while correctly listing all 9.
The table was right but the prose about it was not, because the explanation is 
generated alongside the output rather than computed from it. Third, 
both approaches turned S0040's `04.17.18` into 2018-04-17; the agreement is a 
shared guess, not confirmation, because the string does not contain the century.
Finally, on S0056 (`N/A` value, `mmol/L` label) I kept the unit and flagged 
the missing value while Claude set the unit to NA, discarding a recorded field 
because there was no value to check it against.

## Samples  Features and Metadata
The samples x features x metadata table `samples_features_metadata.csv` is a 
60 rows x 10 columns with metadata(`sample_id`, `patient_name`, `dob`, `sex`, 
`enrollment_site`, `notes`, `redraw_requested`), two feature columns (`glucose_mg_dL`, `glucose_mmol_L`), 
and `glucose_flag`. A companion feature_metadata.csv describes each feature column 
with its unit, non-missing count (47 and 13), and a QC note on the suspect unit.

In terms of readiness for use, there are still a few operations that need to be
executed before it is ready to be use. The dates under the `dob` column need to be 
converted to date type before any calculation can be done. The Units have not
resolved on purpose since there are 13 rows that need verification against the 
source before the two feature columns can be merged.



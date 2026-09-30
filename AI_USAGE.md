#Lab 3 AI Usage
Model used: Claude 
AI was utilized as a comparison for cleaning the messy_samples.csv and messy_sequences.fasta
files vs via regex methods. 


## Prompts used for cleaning files 
###Cleaning the messy_samples.csv 
Prompt: Attached is a messy clinical CSV with 60 records. Produce a cleaned version as a CSV I can download, with exactly these columns: sample_id, patient_name, dob, sex, enrollment_site, glucose_value, glucose_unit, notes. 
Standardize dates to YYYY-MM-DD, sex and site to one consistent label each, and glucose to one unit system (use your judgment on how.) Keep all 60 rows. Do not drop or invent values; if something is missing or you can't decide, leave it NA and flag it.
Then, for each column, tell me: what format variants you found, what rule you applied, and which specific records (by sample_id) were ambiguous or required an assumption.

Response: I'll read the file, clean each column, and hand back a CSV plus a per-column report.

All 60 rows are in the cleaned file; nothing was dropped or invented. Column-by-column:

**sample_id**
- Variants: `S0001` (48 rows) and `s-0003` (12 rows, lowercase with hyphen).
- Rule: uppercase `S` + 4-digit zero-padded number. No collisions after normalizing.
- Changed: S0003, S0008, S0011, S0016, S0017, S0028, S0034, S0038, S0052. Nothing ambiguous.

**patient_name**
- Variants: `A. Nguyen` (initial + Title Case) vs. all-caps surnames.
- Rule: surname to Title Case. Names otherwise untouched.
- Changed: S0026 (`J. KIM`), S0047 (`S. DAVIS`), S0059 (`T. DAVIS`). Note there are repeated names (e.g. three `T. Martinez`, three `R. Martinez`) — I left those alone since sample_ids differ and DOBs differ; I did not attempt de-duplication.

**dob**
- Variants found: `YYYY-MM-DD` (17), `MM/DD/YYYY` (17), `DD-Mon-YYYY` (12), and `MM.DD.YY` (14, two-digit year).
- Rules: slash dates read as MM/DD — every slash date whose second field exceeds 12 is consistent with MM/DD and none with DD/MM, so that's the file's convention. Dotted dates read as MM.DD.YY by the same logic (e.g. `11.24.53`, `05.30.02`, `02.26.64` only parse as MM.DD). Two-digit years: `≤26 → 20xx`, `>26 → 19xx` (pivot at the current year, so no one is born in the future).
- Assumptions/ambiguities:
  - Slash dates where day ≤ 12, so DD/MM would also have parsed (resolved by the file-wide convention): S0001, S0010, S0015, S0016, S0031, S0039, S0044, S0052.
  - Dotted dates where month/day order is also individually ambiguous: S0034 (`06.07.12` → 2012-06-07), S0037 (`09.06.98`), S0046 (`12.12.09`), S0058 (`02.08.89`), S0060 (`02.09.06`).
  - Two-digit-year century assumption applies to all 14 dotted dates: S0003, S0017, S0018, S0021, S0029, S0033, S0034, S0035, S0037, S0040, S0045, S0046, S0058, S0060. The century pivot only actually matters for S0018 (2002), S0034 (2012), S0040 (2018), S0046 (2009), S0060 (2006) — all children/young adults under the rule; the alternative would make them 100+ years old.
  - Nothing was unparseable, so no dob is NA.

**sex**
- Variants: `F`, `f`, `Female`, `M`, `m`, `Male`, `U`, `unknown`, and blank.
- Rule: `F` / `M` / `U`. I kept `U` as a real label (the source explicitly recorded "unknown") and reserved `NA` for truly blank cells.
- NA (blank in source): S0013, S0018, S0037, S0046. If you'd rather blank and "unknown" collapse to one value, it's a one-line change.

**enrollment_site**
- Variants: `Site A`, `SITE-A`, `site_a`, `Site B`, `siteB`, `Site C ` (trailing space), `Site  C` (double space).
- Rule: strip whitespace/underscores/hyphens, case-insensitive match → `Site A`, `Site B`, `Site C`. Every value mapped unambiguously (19 / 21 / 20). No assumptions needed.

**glucose_value**
- Variants: plain decimal, `N/A`, and two values with a trailing asterisk (`112.3*`, `223.1*`).
- Rule: numeric, one decimal place; `N/A` → NA; asterisk stripped, numeric part kept.
- Flags: S0012 and S0056 were `N/A` in the source (both are also `re-draw requested` or mmol/L-labelled, so likely never measured) → NA. S0032 and S0043 had asterisks whose meaning isn't documented (hemolyzed? repeat? out-of-range?) — the numbers are retained but you should check what `*` meant before using them.

**glucose_unit** — the judgment call
- Variants: `mg/dl`, `MG/DL`, `mg/dL` (47 rows) and `mmol/L` (13 rows).
- Rule: everything reported as `mg/dL`. The 13 rows labelled mmol/L have values from 74.9 to 249.2. Blood glucose in mmol/L is ~4–7 normal and essentially never above ~50 even in a crisis, whereas those numbers are a perfectly ordinary mg/dL distribution — identical to the other 47 rows. Converting them numerically (×18) would give 1,350–4,485 mg/dL, which is not compatible with life. So I treated the unit label as the error, not the number: value left unchanged, unit relabelled `mg/dL`, and each record flagged.
- Records affected by that assumption: S0006, S0011, S0014, S0015, S0016, S0017, S0024, S0033, S0035, S0038, S0039, S0046. S0056 was labelled mmol/L but has no value, so there's nothing to sanity-check against and its unit is left `NA`.
- If your protocol says the value is authoritative and the label must be trusted, tell me and I'll produce the converted version instead — but I'd want to see the source instrument logs first, because the numbers strongly say otherwise.

**notes**
- Only two states: blank or `re-draw requested` (7 rows: S0010, S0012, S0018, S0028, S0054 plus two more in the file). Passed through unchanged; no cleaning needed.

The `cleaning_flags.csv` I sent alongside lists every one of these decisions by `sample_id, column, flag` so you can join it back to the cleaned data or filter it.

###Cleaning the messy_sequences.fasta
Prompt: I’m attaching a FASTA file with 8 sequences whose header lines use inconsistent formats. 
Parse it into a CSV I can download, one row per sequence, with exactly these columns: sample_id, organism, gene, length_reported, sequence, note, header_raw. 
Standardize sample_id and organism to one consistent form each (use your judgment on how). length_reported should be whatever length the header claims, or NA if it doesn't say. 
Join wrapped sequence lines into a single string. Keep header_raw as the original header line exactly as written. 
Do not invent values; if a field isn't in a header, leave it NA. Then tell me, per column: what variants you found across the 8 headers, 
what rule you applied, and which headers were ambiguous or required an assumption.

Response: All 8 sequences parsed; header_raw is byte-for-byte the original line. Per column:

**sample_id**
- Variants: `sample_001`, `Sample002`, `sample-003`, `SAMPLE_004`, `sample005`, `seq6`, `Sample_007`, `sample-8` — mixed case, `_`/`-`/no separator, zero-padded vs. not, and one `seq` prefix.
- Rule: extract the trailing integer, emit `sample_NNN` (lowercase, 3-digit zero-pad).
- Assumptions: `seq6` (header 6) — I treated `seq` as a synonym for `sample` and numbered it `sample_006`. It's the only header that doesn't say "sample", so if `seq6` refers to a different ID scheme, that row needs a manual correction. `sample-8` (header 8) was padded to `sample_008`; that's a formatting choice, not a guess.

**organism**
- Variants: `organism=Homo_sapiens`, `organism:Homo sapiens`, bare `Homo_sapiens`, `species=H.sapiens`, bare `Homo sapiens`, bare `Hsapiens`, `species:Homo_sapiens`.
- Rule: all → `Homo sapiens`. Field tag (`organism` / `species` / none) ignored; underscore, abbreviation and missing space normalized.
- Assumptions: header 4 (`H.sapiens`) and header 6 (`Hsapiens`) are abbreviations I expanded to *Homo sapiens*. Given the other six are all human and the genes are human genes, this is very safe, but strictly it's an inference. Headers 3, 5 and 6 carry the organism as an untagged positional token, so I identified it by content rather than by label.

**gene**
- Variants: `gene=BRCA1`, `gene:TP53`, bare `EGFR`, `target=BRCA1`, bare `TP53` (after `;`), bare `EGFR` (pipe-delimited).
- Rule: match a known gene symbol anywhere in the header, whatever the tag.
- Assumptions: header 4 uses `target=` rather than `gene=` — I took it to mean the same thing. Headers 3, 5, 6 have the gene as an untagged token, identified by content. No header lacked a gene, so no NA.

**length_reported**
- Variants: `len=120`, `length=150bp`, `130 bp` (untagged), `len:NA`, and absent (headers 2, 4, 6, 7).
- Rule: numeric value from `len`/`length` tags or a `<number> bp` token; anything else NA.
- Assumptions/flags: header 8 says `len:NA` explicitly, so it's NA in the output — indistinguishable in the CSV from headers where length was simply absent (2, 4, 6, 7); header_raw preserves the difference. More important: **the reported lengths don't match the actual sequences.** Header 1 claims 120 and the sequence is 120 ✔. Header 3 claims 150 but the sequence is 157; header 5 claims 130 but the sequence is 144. I left `length_reported` as the header claims (that's what you asked for) and did not add an actual-length column since you fixed the column list, but you should know the claims are wrong for 2 of the 3 that make one. Actual lengths for all eight: 120, 134, 157, 104, 144, 125, 135, 123.

**sequence**
- Variants: wrapped at 60 characters, with a short final line (2–3 lines each).
- Rule: concatenated, whitespace stripped, case unchanged (all were uppercase ACGT already). Nothing ambiguous.

**note**
- Variants: only header 7 has one (`note:re-sequenced`); the other seven have nothing note-like.
- Rule: value of a `note` tag, else NA. Header 7 uses a colon after `note` while using `=` for its other fields, so I accepted either delimiter. No assumption beyond that.

**header_raw**
- Copied verbatim including the leading `>` and internal spacing (header 3's ` | ` spaces are preserved). No rule applied.

One structural observation for whoever produced this file: header 7 mixes `=` and `:` and header 8's `len:NA` is a literal placeholder — both suggest the headers were hand-typed rather than exported, which is consistent with the length mismatches above.

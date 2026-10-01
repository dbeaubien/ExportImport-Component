# Comparison and discrepancy report

Status: open
Type: grilling
Blocked by: 06
Reads: GLOSSARY.md, answer to 06

## Question

How do the source and target fingerprints get compared, and what does the discrepancy report look like? Decide:

- the matching algorithm (for example, a sorted merge on record key),
- how missing, extra and changed records are reported, including the changed field names,
- how record-count and sequence-number discrepancies are reported,
- the report format, both a human-readable summary and machine-readable detail,
- the signature of the standalone `Compare` shared method, and how it hooks into the end of the import,
- how a table-subset run limits the comparison to the exported tables.

# Trusting the export set

Status: resolved
Assignee: Dani Beaubien (claimed 2026-10-02)
Type: grilling
Blocked by: —
Reads: map.md Notes and Out of scope, answers to 05, 06, 07 and 21, README.md (the export and Compare)

## Question

How far must the operator be able to trust the export set between the export and the import?

Raised by the human in [Rework Compare's per-record path](21-rework-compare-per-record-path.md):
"there is no guarantee that the export files were created accurately", and "someone modified the
exported data prior to import". Today:

- the manifest holds each segment's SHA-256 (spec 05), and the import and Compare check every one
  before using the set (specs 06 and 07). That catches corruption and any edit to a segment;
- an edit that also rewrites the segment's SHA-256 in the manifest isn't caught. So far that falls
  under "protecting the folder is the operator's responsibility" (Out of scope);
- the export doesn't prove its files match the source datafile. A self-check (Compare of the set on
  the source) proves it, but it runs only when the operator chooses. If the self-check is exact,
  the segments are unchanged and the import's Compare is exact, then the target matches the source.

Decide:

- whether the export ends with a self-check, always, as an option on by default, or not at all.
  It costs one Compare on the source, which is 141 s on the bench today and less after
  [Compare: the lean merge loop](../../exact-copy-v2-build/issues/23-compare-lean-merge-loop.md);
- whether edits that also rewrite the manifest stay out of scope. The alternative: the export's
  result shows one fingerprint of the whole set (the manifest's SHA-256), and the import shows it
  too, for the operator to match.

## Answer

Decided with the human on 2026-10-02 in a grilling session. The glossary gained **Self-check** and
**Set digest**. Built in [Export: self-check and set digest](../../exact-copy-v2-build/issues/24-export-self-check-and-set-digest.md)
and [Codec: values survive the round trip](../../exact-copy-v2-build/issues/25-codec-values-survive-the-round-trip.md).

**Every export ends with a self-check, and a set is complete only when its self-check is exact.
The set digest, one SHA-256 of `manifest.json`, is shown at export and checked at import. A
one-time check proves that the codec keeps every value.**

The proof is now a chain with no trusted link:

1. the self-check is exact: the set holds the source's records;
2. the set digest matches: the set hasn't changed since the export;
3. every segment's SHA-256 matches the manifest: no segment changed;
4. the import's Compare is exact: the target holds the set's records.

The self-check and Compare compare encoded bytes, so a value the codec loses the same way every
time passes both. The value check below rules that out.

- **The self-check (amends spec 06, where nothing ran it automatically):** the export's last phase
  is a Compare of the new set on the source. It always runs, with no option, like the blocker
  gate (spec 09). Its cost is one Compare on the source, about 1 to 1.5 times the export after
  [Compare: the lean merge loop](../../exact-copy-v2-build/issues/23-compare-lean-merge-loop.md).
  - It catches what the import's Compare can't: an export that writes wrong bytes, skips or doubles
    a record, or reads a source that changes during the export.
  - **The manifest:** written as `manifest.json.tmp`, so the self-check runs on that file. The
    file is renamed `manifest.json` only when the self-check is `exact`. The rule "a set without
    `manifest.json` is incomplete" now covers an unproven set too, a crash during the self-check
    included. The import and the dialog's set list need no change for it.
  - **Verdict:** `exported` only when the self-check is `exact`. Otherwise `failed`, with a next
    step by the self-check's verdict:
    - `notExact`: the export set doesn't match the source; run the export again;
    - `inconclusive`: check the source copy with the MSC (records and indexes), then run the
      export again. On the source, an order guard break points at a damaged index.
  - **Result:** the self-check's envelope is the export's `compare`, as in the import (spec 12).
  - **Workers:** the export passes its options to the self-check, as the import passes them to its
    Compare. A worker count given covers both. With none, each pass uses its own default (spec
    15), because each Compare job holds a segment of up to 100 MB.
- **The set digest:** the SHA-256 of `manifest.json`, in hex. The manifest holds every segment's
  SHA-256, so the set digest covers the whole set. `manifest.json` is written once and never
  rewritten, so its set digest is stable.
  - **Shown:** in the export's result, its run report and the dialog. Again in the import's and
    Compare's results and run reports, and in the import's set summary before anything is
    written. The operator keeps the value outside the set, for example in a ticket.
  - **Checked:** `ImportPass` and `ComparePass` take an optional `set_digest`. When given, a
    mismatch is a pre-flight problem and the run refuses. The dialog has a paste field on the
    Import and Compare steps. Empty means not checked. People compare only the first few
    characters by eye, and a match on 8 characters can be forged in minutes.
  - It detects a change only. Signing or encrypting the set stays out of scope.
- **Compare on a source:** today its next steps assume a target ("The target is unusable…"). When
  this datafile is the set's source (by path, as in the import's check), Compare gives next steps
  for the source.
- **Codec fidelity:** a one-time development check decodes each record into a new record and
  compares every field with the source by value, without the codec. It runs on the bench and in
  [Final check on a customer copy](../../exact-copy-v2-build/issues/20-final-check-on-a-customer-copy.md).
  Build ticket 02's `__Check_Codec` compared re-encoded bytes, which has the same blind spot as the
  self-check. Its 11 edge cases compared values, but only those cases. Objects and pictures go
  through 4D's `VARIABLE TO BLOB`, which the spike proved stable, not faithful. A per-export value
  check was rejected: it would double the self-check's cost, and testing the code once proves it
  for every set.
- **Outside the proof** (Out of scope): whether the source copy is a faithful copy of production,
  and the target after the import's session. The README already says to reopen the target and run
  Compare again.
- **Rejected:**
  - the self-check as an option, on or off by default, or left to the operator through the
    Compare step;
  - leaving edits that also rewrite the manifest out of scope;
  - showing the set digest with no check;
  - a value check on every export, and relying on the codec's design and the 11 edge cases alone.

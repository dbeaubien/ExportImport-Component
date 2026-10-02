# Rework the codec's per-record loops

Status: open
Type: grilling
Blocked by: 17
Reads: map.md Notes, answers to 04, 15 and 17, research/15-preemptive-contention-4d-facts.md, ../../exact-copy-v2-build/issues/02-structure-and-record-codec.md (Answer), Project/Sources/Classes/_Codec.4dm, Project/Sources/Classes/_CompareJob.4dm

## Question

From [Probe: the codec without object operations](17-probe-codec-without-object-operations.md),
decide whether the per-record loops should stop making object, collection and class operations.
That means the codec (`encode()`, `decode()`, `key()`), which every pass uses (ticket 02), and
Compare's merge, which calls `key()` and other functions for every record. Decide:

- whether to rework, and in which form (descriptor arrays in project methods, or another form the
  probe shows);
- whether the per-pass `workers` defaults (Compare 2, the others 4, spec 15) change with it;
- what proves the rework: ticket 02's byte-for-byte round trip on the bench, and the `bench` gate.

A rework becomes a build ticket. Not probed: reading with `SELECTION RANGE TO ARRAY`, which is
thread-safe and supports Object fields, while its BLOB and Picture support is undocumented
(research 15).

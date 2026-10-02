# Rework Compare's per-record path

Status: open
Type: grilling
Blocked by: 20
Reads: map.md Notes, answers to 15, 17, 18 and 20, research/20-__Spike_Compare_Path-compiled.json, ../../exact-copy-v2-build/issues/09-compare-merge.md (Answer), ../../exact-copy-v2-build/issues/10-compare-unverified-and-detail.md (Answer), ../../exact-copy-v2-build/issues/13-bench-on-the-new-api.md (Answer), Project/Sources/Classes/_CompareJob.4dm, Project/Sources/Classes/_Codec.4dm

## Question

From [Probe: Compare's per-record path](20-probe-compare-per-record-path.md), decide:

- whether to rework `_CompareJob`'s per-record loop, and in which form, removing the suspects the
  probe shows growing with the worker count (for example: state in locals, no object per record,
  the row written once at the end, the key compared as a Blob);
- whether `_Codec.key()` changes with it, and whether `encode()` does after all, if class calls
  slow down ([Rework the codec's per-record loops](18-rework-codec-per-record-loops.md) left it as
  it is);
- Compare's `workers` default (2 today, spec 15), from a bench run at 2 and 4 Compare workers after
  the rework;
- what proves the rework: build tickets 09 and 10's checks (the planted discrepancies, a damaged
  segment, an order guard break), the `bench` gate, and build ticket 02's round trip if the codec
  changes.

A rework becomes a build ticket, after
[Compare: extras before an order guard break](../../../exact-copy-v2-build/issues/22-compare-extras-before-an-order-break.md),
which changes the same loop. That build ticket, or this ticket if there is no rework, deletes the
probe's harness: `__Spike_Compare_Path` and `__ComparePath`.

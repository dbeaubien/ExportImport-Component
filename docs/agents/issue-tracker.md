# Issue tracker: Local Markdown

Planning and build work for this repo lives as markdown files under `.scratch/`, not in GitHub
Issues. **Agents: the two-minute card is [`issue-tracker-rules.md`](issue-tracker-rules.md).** This
file holds the full conventions and the inventory of what is tracked.

## Conventions

- One feature per directory: `.scratch/<feature-slug>/`.
- A wayfinder map is `.scratch/<feature-slug>/map.md`. Output that a ticket produces (research
  notes, benchmark results) goes in `.scratch/<feature-slug>/research/` and is linked from the ticket.
- Tickets are `.scratch/<feature-slug>/issues/<NN>-<slug>.md`, numbered from `01`, one file per
  ticket. The header lines and status values are in the rules card.
- Comments, and hand-offs from other tickets, append at the bottom under a `## Comments` heading.
- A finished feature moves to `.scratch/DONE/<feature-slug>/`, with the links into and out of it fixed.

## When a skill says "publish to the issue tracker"

Create a new file under `.scratch/<feature-slug>/` (creating the directory if needed).

## When a skill says "fetch the relevant ticket"

Read the file at the referenced path. The path or the `NN` number is normally passed directly.

## Wayfinding operations

Used by `/wayfinder`. The **map** is a file with one **child** file per ticket.

- **Map**: `.scratch/<effort>/map.md` (Destination, Notes, Decisions so far, Not yet specified, Out
  of scope).
- **Child ticket**: `.scratch/<effort>/issues/NN-<slug>.md`, with the question under `## Question`. A
  `Type:` line records the ticket type (`research`/`prototype`/`grilling`/`task`).
- **Blocking**: a `Blocked by: NN, NN` line near the top. A ticket is unblocked when every ticket it
  lists is `resolved`.
- **Frontier**: the tickets that are `open`, unblocked, and have no `Assignee:` line. The lowest
  number wins.
- **Claim**: before any work, set `Status: claimed`, add `Assignee: <name> (claimed YYYY-MM-DD)` and save.
- **Resolve**: append the answer under `## Answer`, set `Status: resolved`, then add a one-line gist
  with a link to the map's Decisions so far. Notes for other tickets go to their `## Comments`.

## Existing features

- ✅ **DONE**: [`.scratch/DONE/exact-copy-v2/`](../../.scratch/DONE/exact-copy-v2/map.md), a wayfinder
  map (**planning**). Destination reached: a locked spec for the fingerprint, the export set format,
  import, the health check and the discrepancy report, split into build tickets. All 23 tickets
  are resolved; keys that contain @, worker count, extras before an order guard break, the codec probe,
  the codec rework, the cut rule's cost, the two probes of Compare's per-record path and its loop,
  and the rework of that path came from the build, and trusting the export set from that rework.
  The build tickets are in `.scratch/exact-copy-v2-build/`.
- 🔵 **OPEN**: [`.scratch/exact-copy-v2-build/`](../../.scratch/exact-copy-v2-build/map.md), the build tickets
  (**build**) for the exact-copy-v2 spec: 25 tickets, from a 4D-fact spike through the codec, the
  passes, the shared-method wrappers, deleting the old code and the dialog, then one validation of
  14 to 18 (21) and a final check on a customer copy. 22 to 25 came from the spec map. **01 spike, 02 structure and record codec, 03 pass skeleton and gate, 04 worker pool and planner, 05 health check scan, 06 fixer, 07 export, 08 manifest checks and pre-flight, 09 Compare: the merge, 10 Compare: unverified records and readable detail, 11 Import, 12 shared methods and the ExportImport namespace, 13 bench on the new API, 14 delete the old code, 15 dialog: step list, export sets and marks, 16 dialog: running a step, progress and Stop, 17 dialog: the Health check and Export steps, 18 dialog: the Switch to target, Import and Compare steps, 19 README and docs, and 22 Compare: extras before an order guard break resolved. Claimed: 21 validate the cleanup and the dialog together (part 1 done, part 2 after 23 and 24), and 23 Compare: the lean merge loop (built, waiting on its runs). Open: 25 Codec: values survive the round trip (frontier), then 24 Export: self-check and set digest, and 20 final check on a customer copy.** The spec ticket on keys that contain @ is resolved, so 04, 07, 09 and 10 no longer wait on it.

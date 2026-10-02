# Issue tracker: rules card

The two-minute version, for agents. The full conventions, the wayfinding operations and the
tracked-features inventory are in [`issue-tracker.md`](issue-tracker.md) beside this file.

⚠ **This repo is public on GitHub.** Don't name customers, their apps or their datafiles in tickets,
docs or commits. Write "a customer datafile" instead.

## Ticket header

```
Status: open                       <- open · claimed · resolved
Assignee: <name> (claimed YYYY-MM-DD)   <- the claim; absent = unclaimed
Type: grilling                     <- research · prototype · grilling · task
Blocked by: 01, 02                 <- ticket numbers in the same feature; — if none
Reads: <path>, <path>              <- the exact files this ticket's work needs
Gates: <gate>, …                   <- build tickets only; which gates the change can move
```

`Reads:` exists so an agent opens those files directly instead of exploring for them.

## Working a ticket

- **Read**: the ticket, the tickets it is blocked by, its `Reads:` list, and the feature's `map.md`
  (an index, so it stays small).
- **Claim, frontier, resolve**: follow "Wayfinding operations" in
  [`issue-tracker.md`](issue-tracker.md).
- **Batched validation**: when several build tickets share run steps (export, import, Compare,
  the dialog), a validation ticket holds them, and each build ticket marks those steps with its
  number. The build tickets resolve once built and compiled. In the exact-copy-v2 build, that's
  ticket 21 for tickets 14 to 18.

## Gates: what a ticket's `Gates:` header can name

There is no command-line runner. Both gates run in the 4D IDE, so an agent cannot run them. A ticket
that needs one hands that step to a human, or states what was not validated.

| gate | what it moves for | how to run it |
|---|---|---|
| `compile` | any `.4dm`, class or catalog change | Design ▸ Compile |
| `bench` | a change to the speed of export, import, fingerprinting or comparison | on the generated datafile (`__Bench_Generate(1)`), run `__Bench_Baseline` compiled: an export of every table, then a Compare self-check, each at its default worker count. Compare the JSON it writes with the latest baseline under `research/` |

There are no unit tests in this repo.

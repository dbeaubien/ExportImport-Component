Follow YAGNI principles, and one-liner solutions.

The name of a 4D method or 4D variable cannot exceed **31 characters**. The limit does not apply to
4D class function names, nor to properties within classes.

A leading `_` on a class or a class function marks it private by convention only: the host can
still call it. A project method is hidden from the host by its unticked "Shared by components and
host project" property, never by its name, so name methods without a leading `_` unless they are
throw-away. Throw-away code (methods, classes, tables) is there for research only, not part of the
final solution: delete it once nothing needs it any more.

Use the [.claude/skills/karpathy-guidelines/SKILL.md](.claude/skills/karpathy-guidelines/SKILL.md)
guidelines when writing, reviewing, or refactoring code.

## Communication mode

Default to caveman ultra (see .claude/skills/caveman/SKILL.md) for all prose responses. Code, commits, PRs stay normal.

## Issue tracker

Build work is tracked as markdown in [`.scratch/<feature>/`](.scratch/), not in GitHub Issues (work is
also tracked in an external "Task" system). Rules card:
[docs/agents/issue-tracker-rules.md](docs/agents/issue-tracker-rules.md): the ticket header, this
repo's gates, and a link to the conventions and the feature inventory.

When working a ticket: read the ticket file, the tickets it is blocked by, its Reads: list, and the
feature's `map.md`.

## Docs

Before changing or explaining the component, read the doc that covers it. When a change alters what
a doc describes, update the doc in the same change.

- [README.md](README.md): the host contract: shared methods, options, the result envelope, verdicts,
  the dialog.
- [docs/how-it-works.md](docs/how-it-works.md): class diagrams, each pass's phases, `_Planner`,
  `_WorkerPool`, the jobs, `_Codec`, Compare's merge, error codes.
- [docs/file-formats.md](docs/file-formats.md): the bytes of segments and record buffers,
  `manifest.json`, run reports, run logs, worker logs.
- [docs/overview.md](docs/overview.md): the goals and limits behind the design.
- [GLOSSARY.md](GLOSSARY.md): the domain terms, each with the words to avoid. Use its terms in code,
  comments and docs.
- [docs/adr/](docs/adr/): decisions. [ADR 0001](docs/adr/0001-two-host-seams.md) keeps the shared
  methods and the `ExportImport` namespace compatible.

## 4D facts and gotchas

- **Facts** this code relies on, tested in 4D v21 (`@` as a wildcard, `""` in a UUID field,
  constraints and the log file, …): the table under `## Answer` in
  [01-spike-4d-facts.md](.scratch/DONE/exact-copy-v2-build/issues/01-spike-4d-facts.md).
- **Gotchas** met in the build (a subclass function silently overriding the base class's, a
  property left Null, thread safety failing only at runtime): the Notes of
  [the build map](.scratch/DONE/exact-copy-v2-build/map.md).

## Citations in code comments

Comments cite the ticket behind a decision:

- `spec NN`: `.scratch/DONE/exact-copy-v2/issues/NN-*.md`, its `## Answer` and the dated notes under
  it.
- `ticket NN`, and `ticket 01's fact N`: `.scratch/DONE/exact-copy-v2-build/issues/NN-*.md`.
- `<feature> ticket NN` (`finer-job-cut ticket 01`): `.scratch/<feature>/issues/NN-*.md`, or under
  `.scratch/DONE/` once the feature is done.

## Running 4D, and the public repo

- An agent can't run 4D: compiling, running a pass and the bench happen in the 4D IDE. Hand those
  steps to the human, naming what to run, and say what wasn't validated.
- The repo is public on GitHub: write "a customer datafile" wherever a customer's name, app,
  datafile or tables would go, in code, docs and commits.


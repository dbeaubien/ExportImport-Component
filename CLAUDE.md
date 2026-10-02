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


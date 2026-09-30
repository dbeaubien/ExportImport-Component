Follow YAGNI principles, and one-liner solutions.

The name of a 4D method or 4D variable cannot exceed **31 characters**. The limit does not apply to
4D class function names, nor to properties within classes.

Use the [.claude/skills/karpathy-guidelines/SKILL.md](.claude/skills/karpathy-guidelines/SKILL.md)
guidelines when writing, reviewing, or refactoring code.

## Communication mode

Default to caveman ultra (see .claude/skills/caveman/SKILL.md) for all prose responses. Code, commits, PRs stay normal.

## Issue tracker

Build work is tracked as markdown in [`.scratch/<feature>/`](.scratch/) (GitHub Issues are disabled; work
is also tracked in an external "Task" system). Rules card:
[docs/agents/issue-tracker-rules.md](docs/agents/issue-tracker-rules.md) — it links the family rules,
this repo's gates, and the feature inventory.

When working a ticket: read the ticket file, its Blocked-by links, and its Reads: list. From the feature
map's `README.md`, read only its ticket table and frontier note.


# Issue tracker: GitHub

Issues and specs for this repo live as GitHub issues. Use the `gh` CLI for all operations.

## Conventions

- **Create an issue**: `gh issue create --title "..." --body "..."`.
- **Read an issue**: `gh issue view <number> --comments`, including labels and relevant comments.
- **List issues**: `gh issue list --state open --json number,title,body,labels,comments`, with appropriate filters.
- **Comment on an issue**: `gh issue comment <number> --body "..."`
- **Apply / remove labels**: `gh issue edit <number> --add-label "..."` / `--remove-label "..."`
- **Close**: `gh issue close <number> --comment "..."`

Infer the repo from `git remote -v`; `gh` does this automatically inside a clone.

## Pull requests as a triage surface

**PRs as a request surface: no.**

When set to `yes`, use the corresponding `gh pr` commands and triage external PRs alongside issues. GitHub shares one number space across issues and PRs, so resolve ambiguous references before acting.

## When a skill says "publish to the issue tracker"

Create a GitHub issue.

## When a skill says "fetch the relevant ticket"

Run `gh issue view <number> --comments`.

## Wayfinding operations

Used by `/wayfinder`. The map is one issue labelled `wayfinder:map`; child tickets are sub-issues when available, or linked through a task list in the map body. Track blockers with GitHub issue dependencies when available, falling back to a `Blocked by: #<n>` line. Claim a ready ticket by assigning it to yourself. On resolution, comment with the answer, close the ticket, and add a context pointer to the map.

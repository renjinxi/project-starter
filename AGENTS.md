# Repository agent rules

This file is the shared entry point for coding agents. Keep stable,
repository-specific product and architecture context here or in a document
linked from here.

## Iron rule

The primary `main` checkout is a read-only control surface. Every tracked
change starts in a linked worktree created from `origin/main`. Use the
`repo-worktree` skill before editing from `main`, and use `tmr` when the
isolated branch is ready to commit, push, and open as a GitHub pull request.

Small, urgent, and documentation-only changes follow the same boundary.

## Shared and local layers

- Commit team instructions, repository skills, and repeatable tools.
- Keep personal context in ignored `AGENTS.override.md` and `local/` files.
- `CLAUDE.md` points to this file; `.claude/skills` points to
  `.agents/skills`, so each instruction and skill has one source of truth.
- Keep credentials outside the repository and its local layer.

## Project context

Add the repository's purpose, scope, domain language, and non-obvious
constraints once they are known. Record stable facts, not active-task status.

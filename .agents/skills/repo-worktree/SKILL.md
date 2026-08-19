---
name: repo-worktree
description: Use when starting tracked-file work from a repository's primary main checkout, or when creating, locating, listing, or safely removing an isolated git worktree.
---

# Repository worktrees

The primary `main` checkout is a read-only control surface. Every tracked
change starts in a linked worktree based on `origin/main`; an existing
non-main worktree remains the current workspace.

## Start work

1. Run `git status --short --branch` and `git worktree list`.
2. If the current branch is `main`, choose a short kebab-case branch name with
   an honest prefix: `feat/`, `fix/`, `prototype/`, `docs/`, or `chore/`.
3. Run `bash tools/work/work.sh create <branch>` from the primary checkout.
4. Change directory to the printed workspace. Perform every tracked edit,
   commit, and push there.

If already inside a linked non-main worktree, continue there. Do not create a
nested worktree for the same task.

New worktrees default to `~/work/worktree/<repository>/<task>`. Set
`REPO_WORKTREE_ROOT` only when this repository needs a different local root.

## Locate and remove

```bash
bash tools/work/work.sh list
bash tools/work/work.sh open <keyword>
bash tools/work/work.sh remove <keyword>
```

`remove` succeeds only when the workspace is clean and every commit is pushed;
it preserves the local branch. After implementation is verified, use `$tmr`
to commit, push, and open the GitHub PR before removal.

## Iron rule

A tracked edit while `git branch --show-current` is `main` means stop and
create the worktree first. Task size and urgency do not change this boundary.

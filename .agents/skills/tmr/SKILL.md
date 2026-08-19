---
name: tmr
description: Use when the user says tmr, asks to finish or open a PR, or wants the current repository worktree committed and pushed to GitHub.
---

# tmr — commit, push, and open the PR

Finish one repository worktree as one focused GitHub pull request to `main`.

## Preflight

1. Resolve the repository root and current branch. Stop on `main`; `$tmr`
   runs only in a linked non-main worktree.
2. Fetch `origin/main`, then inspect status, staged and unstaged diffs,
   untracked files, and `git log origin/main..HEAD`.
3. Account for every changed file. Preserve unrelated or sensitive files and
   stage task files by explicit path. Broad staging commands are not a
   file-attribution decision.
4. Run verification appropriate to the changed behavior, or cite fresh
   verification from the current session.
5. Query PRs for the source branch:

   ```bash
   gh pr list --head "$(git branch --show-current)" --state all \
     --json number,state,url,title
   ```

   Push updates an open PR. A merged or closed PR means the branch is spent;
   use a new branch instead of silently reusing it.

Before external writes, show one compact plan with exact files, commit message,
verification evidence, source branch, and `main` target. Obtain one
confirmation unless the user already confirmed that exact plan.

## Execute

After confirmation:

1. Stage only the listed paths and inspect `git diff --cached`.
2. Commit with a focused Conventional Commit message under 72 characters.
3. Push explicitly with `git push -u origin <source-branch>`. Never
   force-push, bypass hooks, or amend without separate authorization.
4. Create one PR with `gh pr create --base main --head <source-branch>` when no
   open PR exists. Include `Summary` and `Verification` in its body.
5. Open the PR URL and report the commit, branch, verification, and URL.
   Report partial failure exactly rather than creating a duplicate PR.

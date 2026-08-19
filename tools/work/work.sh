#!/usr/bin/env bash

set -euo pipefail

die() {
  printf 'error: %s\n' "$*" >&2
  exit 1
}

find_root() {
  if [[ -n "${REPO_ROOT:-}" ]]; then
    printf '%s' "$REPO_ROOT"
    return
  fi
  git worktree list --porcelain 2>/dev/null \
    | sed -n 's/^worktree //p' \
    | head -n 1
}

repo_name() {
  local remote
  remote=$(git -C "$ROOT" remote get-url origin 2>/dev/null || true)
  if [[ -n "$remote" ]]; then
    remote="${remote%.git}"
    printf '%s' "${remote##*/}"
  else
    basename "$ROOT"
  fi
}

copy_local_layer() {
  local root="$1" workspace="$2"
  [[ -f "$root/AGENTS.override.md" ]] \
    && cp "$root/AGENTS.override.md" "$workspace/AGENTS.override.md"
  [[ -L "$root/CLAUDE.local.md" ]] \
    && cp -P "$root/CLAUDE.local.md" "$workspace/CLAUDE.local.md"
  if [[ -d "$root/local" ]]; then
    mkdir -p "$workspace/local"
    cp -R "$root/local/." "$workspace/local/"
  fi
}

create_worktree() {
  local branch="$1" task workspace
  [[ "$branch" != "main" ]] || die "main is the read-only primary checkout"
  git check-ref-format --branch "$branch" >/dev/null 2>&1 \
    || die "invalid branch name: $branch"

  task="${branch#*/}"
  task="${task//\//-}"
  workspace="$WORKTREE_ROOT/$task"

  [[ -z "$(git -C "$ROOT" status --porcelain --untracked-files=no)" ]] \
    || die "primary checkout has tracked changes; move or resolve them before creating a worktree"
  [[ ! -e "$workspace" ]] || die "workspace already exists: $workspace"
  git -C "$ROOT" show-ref --verify --quiet "refs/heads/$branch" \
    && die "branch already exists: $branch"

  git -C "$ROOT" fetch origin main --prune
  git -C "$ROOT" show-ref --verify --quiet refs/remotes/origin/main \
    || die "origin/main is unavailable"
  mkdir -p "$WORKTREE_ROOT"
  git -C "$ROOT" worktree add -b "$branch" "$workspace" origin/main
  copy_local_layer "$ROOT" "$workspace"

  printf 'workspace: %s\n' "$workspace"
  printf 'branch:    %s\n' "$branch"
  printf 'base:      origin/main\n'
  printf 'cd %s\n' "$workspace"
}

linked_worktrees() {
  local path="" branch=""
  git -C "$ROOT" worktree list --porcelain | while IFS= read -r line; do
    case "$line" in
      "worktree "*) path="${line#worktree }" ;;
      "branch refs/heads/"*)
        branch="${line#branch refs/heads/}"
        [[ "$path" != "$ROOT" ]] && printf '%s\t%s\n' "$branch" "$path"
        ;;
    esac
  done
}

list_worktrees() {
  local worktrees
  worktrees=$(linked_worktrees)
  if [[ -z "$worktrees" ]]; then
    printf '(no linked worktrees)\n'
    return
  fi
  printf '%-40s %s\n' "BRANCH" "PATH"
  while IFS=$'\t' read -r branch path; do
    [[ -n "$branch" ]] && printf '%-40s %s\n' "$branch" "$path"
  done <<<"$worktrees"
}

resolve_worktree() {
  local keyword="$1" count=0 found="" branch path
  while IFS=$'\t' read -r branch path; do
    [[ -n "$branch" ]] || continue
    case "$branch $path" in
      *"$keyword"*) count=$((count + 1)); found="$path" ;;
    esac
  done < <(linked_worktrees)
  [[ "$count" -gt 0 ]] || die "no worktree matched: $keyword"
  [[ "$count" -eq 1 ]] || die "multiple worktrees matched: $keyword"
  printf '%s\n' "$found"
}

has_unpushed_commits() {
  local workspace="$1" count
  if git -C "$workspace" rev-parse --abbrev-ref '@{upstream}' >/dev/null 2>&1; then
    count=$(git -C "$workspace" rev-list --count '@{upstream}..HEAD')
  else
    count=$(git -C "$workspace" rev-list --count HEAD --not --remotes)
  fi
  [[ "$count" -gt 0 ]]
}

remove_worktree() {
  local keyword="$1" workspace
  workspace=$(resolve_worktree "$keyword")
  [[ "$workspace" != "$ROOT" ]] || die "refusing to remove the primary checkout"
  [[ -e "$workspace/.git" ]] \
    || die "matched path is not a linked worktree: $workspace"
  [[ -z "$(git -C "$workspace" status --porcelain)" ]] \
    || die "worktree has uncommitted changes: $workspace"
  ! has_unpushed_commits "$workspace" \
    || die "worktree has unpushed commits: $workspace"

  git -C "$ROOT" worktree remove "$workspace"
  git -C "$ROOT" worktree prune
  printf 'removed: %s\n' "$workspace"
  printf 'local branch preserved\n'
}

usage() {
  printf '%s\n' \
    'Usage:' \
    '  tools/work/work.sh create <branch>' \
    '  tools/work/work.sh list' \
    '  tools/work/work.sh open <keyword>' \
    '  tools/work/work.sh remove <keyword>'
}

ROOT=$(find_root) || die "not inside a git checkout"
ROOT=$(cd "$ROOT" && pwd -P)
[[ -e "$ROOT/.git" ]] || die "not a git checkout: $ROOT"
REPO_NAME=$(repo_name)
WORKTREE_BASE="${WORKTREE_BASE:-${HOME:?}/work/worktree}"
WORKTREE_ROOT="${REPO_WORKTREE_ROOT:-$WORKTREE_BASE/$REPO_NAME}"

case "${1:-}" in
  create|new)
    [[ $# -eq 2 ]] || die "usage: work.sh create <branch>"
    create_worktree "$2"
    ;;
  list|ls)
    [[ $# -eq 1 ]] || die "usage: work.sh list"
    list_worktrees
    ;;
  open)
    [[ $# -eq 2 ]] || die "usage: work.sh open <keyword>"
    resolve_worktree "$2"
    ;;
  remove|rm)
    [[ $# -eq 2 ]] || die "usage: work.sh remove <keyword>"
    remove_worktree "$2"
    ;;
  -h|--help|help|"") usage ;;
  *) usage; exit 1 ;;
esac

#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
WORK_SCRIPT="$SCRIPT_DIR/work.sh"
TEST_TMP_BASE=$(cd "${TMPDIR:-/tmp}" && pwd -P)
TEST_TMP=$(mktemp -d "$TEST_TMP_BASE/repo-work-test.XXXXXX")
TEST_TMP=$(cd "$TEST_TMP" && pwd -P)

cleanup() {
  case "$TEST_TMP" in
    "$TEST_TMP_BASE"/repo-work-test.*)
      [[ -d "$TEST_TMP" ]] && rm -rf -- "$TEST_TMP"
      ;;
    *)
      printf 'refusing to clean unexpected test path: %s\n' "$TEST_TMP" >&2
      ;;
  esac
}
trap cleanup EXIT

fail() {
  printf 'FAIL: %s\n' "$1" >&2
  exit 1
}

assert_eq() {
  local expected="$1" actual="$2" message="$3"
  [[ "$actual" == "$expected" ]] \
    || fail "$message (expected '$expected', got '$actual')"
}

assert_contains() {
  local haystack="$1" needle="$2" message="$3"
  [[ "$haystack" == *"$needle"* ]] \
    || fail "$message (missing '$needle')"
}

REMOTE="$TEST_TMP/sample-project.git"
ROOT="$TEST_TMP/root"
WORKTREES="$TEST_TMP/worktrees"

git init --bare --quiet "$REMOTE"
git init --quiet --initial-branch=main "$ROOT"
git -C "$ROOT" config user.name "Worktree Test"
git -C "$ROOT" config user.email "worktree-test@example.invalid"
printf '# fixture\n' > "$ROOT/README.md"
printf 'local/\nAGENTS.override.md\nCLAUDE.local.md\n' > "$ROOT/.gitignore"
git -C "$ROOT" add README.md .gitignore
git -C "$ROOT" commit --quiet -m "initial"
git -C "$ROOT" remote add origin "$REMOTE"
git -C "$ROOT" push --quiet --set-upstream origin main

printf '# local iron law\n' > "$ROOT/AGENTS.override.md"
ln -s AGENTS.override.md "$ROOT/CLAUDE.local.md"
mkdir -p "$ROOT/local/context"
printf '# private context\n' > "$ROOT/local/context/note.md"

REPO_ROOT="$ROOT" REPO_WORKTREE_ROOT="$WORKTREES" \
  bash "$WORK_SCRIPT" create "feat/bedtime-flow"

CREATED="$WORKTREES/bedtime-flow"
[[ -d "$CREATED" ]] || fail "create should make the requested worktree"
assert_eq "feat/bedtime-flow" "$(git -C "$CREATED" branch --show-current)" \
  "create should check out the requested branch"
assert_eq "$(git -C "$ROOT" rev-parse origin/main)" "$(git -C "$CREATED" rev-parse HEAD)" \
  "create should start from origin/main"
[[ -f "$CREATED/AGENTS.override.md" ]] || fail "create should copy local agent instructions"
[[ -L "$CREATED/CLAUDE.local.md" ]] || fail "create should preserve the Claude local symlink"
[[ -f "$CREATED/local/context/note.md" ]] || fail "create should copy the ignored local layer"

printf 'PASS: create starts an isolated worktree from origin/main\n'

LIST_OUTPUT=$(REPO_ROOT="$ROOT" REPO_WORKTREE_ROOT="$WORKTREES" \
  bash "$WORK_SCRIPT" list)
assert_contains "$LIST_OUTPUT" "feat/bedtime-flow" "list should show the worktree branch"
assert_contains "$LIST_OUTPUT" "$CREATED" "list should show the worktree path"

OPEN_OUTPUT=$(REPO_ROOT="$ROOT" REPO_WORKTREE_ROOT="$WORKTREES" \
  bash "$WORK_SCRIPT" open "bedtime")
assert_eq "$CREATED" "$OPEN_OUTPUT" "open should resolve one matching workspace"

printf 'PASS: list and open derive workspace state from git metadata\n'

printf 'dirty\n' >> "$CREATED/README.md"
if REPO_ROOT="$ROOT" REPO_WORKTREE_ROOT="$WORKTREES" \
  bash "$WORK_SCRIPT" remove "bedtime" >/dev/null 2>&1; then
  fail "remove should refuse a worktree with uncommitted changes"
fi
[[ -d "$CREATED" ]] || fail "blocked remove should preserve the worktree"

git -C "$CREATED" add README.md
git -C "$CREATED" commit --quiet -m "test change"
if REPO_ROOT="$ROOT" REPO_WORKTREE_ROOT="$WORKTREES" \
  bash "$WORK_SCRIPT" remove "bedtime" >/dev/null 2>&1; then
  fail "remove should refuse a worktree with unpushed commits"
fi
[[ -d "$CREATED" ]] || fail "blocked remove should preserve unpushed commits"

git -C "$CREATED" push --quiet --set-upstream origin feat/bedtime-flow
REPO_ROOT="$ROOT" REPO_WORKTREE_ROOT="$WORKTREES" \
  bash "$WORK_SCRIPT" remove "bedtime"
[[ ! -e "$CREATED" ]] || fail "remove should delete the clean, pushed worktree"
git -C "$ROOT" show-ref --verify --quiet refs/heads/feat/bedtime-flow \
  || fail "remove should preserve the local branch"

printf 'PASS: remove blocks dirty or unpushed work and preserves the branch\n'

TEST_HOME="$TEST_TMP/home"
HOME="$TEST_HOME" REPO_ROOT="$ROOT" \
  bash "$WORK_SCRIPT" create "fix/default-root"
DEFAULT_CREATED="$TEST_HOME/work/worktree/sample-project/default-root"
[[ -d "$DEFAULT_CREATED" ]] \
  || fail "default path should be ~/work/worktree/<repository>/<task>"
git -C "$DEFAULT_CREATED" push --quiet --set-upstream origin fix/default-root
HOME="$TEST_HOME" REPO_ROOT="$ROOT" bash "$WORK_SCRIPT" remove "default-root"

printf 'PASS: default root is stable across repositories\n'

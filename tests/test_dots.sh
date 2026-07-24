#!/usr/bin/env bash
set -euo pipefail

# Test Suite for bin/dots CLI Helper
# Tests against pre-agreed seams: Sandbox ($TEST_HOME / $DOTFILES_REPO) & Dry-Run (--test)

PASS_COUNT=0
FAIL_COUNT=0

function assert_equals() {
  local expected="$1"
  local actual="$2"
  local msg="$3"
  if [[ "$expected" == "$actual" ]]; then
    echo "  ✅ PASS: $msg"
    PASS_COUNT=$((PASS_COUNT + 1))
  else
    echo "  ❌ FAIL: $msg (expected '$expected', got '$actual')"
    FAIL_COUNT=$((FAIL_COUNT + 1))
  fi
}

function assert_file_exists() {
  local path="$1"
  local msg="$2"
  if [[ -e "$path" ]]; then
    echo "  ✅ PASS: $msg"
    PASS_COUNT=$((PASS_COUNT + 1))
  else
    echo "  ❌ FAIL: $msg ($path does not exist)"
    FAIL_COUNT=$((FAIL_COUNT + 1))
  fi
}

function assert_symlink_to() {
  local link_path="$1"
  local expected_target="$2"
  local msg="$3"
  if [[ -L "$link_path" ]]; then
    local actual_target
    actual_target=$(readlink "$link_path")
    if [[ "$actual_target" == "$expected_target" ]]; then
      echo "  ✅ PASS: $msg"
      PASS_COUNT=$((PASS_COUNT + 1))
    else
      echo "  ❌ FAIL: $msg (symlink points to '$actual_target', expected '$expected_target')"
      FAIL_COUNT=$((FAIL_COUNT + 1))
    fi
  else
    echo "  ❌ FAIL: $msg ($link_path is not a symlink)"
    FAIL_COUNT=$((FAIL_COUNT + 1))
  fi
}

echo "========================================"
echo "🧪 Running tests/test_dots.sh"
echo "========================================"

# Setup Sandbox Seam environment
TEST_DIR=$(mktemp -d)
trap 'rm -rf "$TEST_DIR"' EXIT

export TEST_HOME="$TEST_DIR/home"
export DOTFILES_REPO="$TEST_DIR/repo"
export HOME="$TEST_HOME"

mkdir -p "$TEST_HOME/.config/zellij"
echo 'keybinds = "default"' > "$TEST_HOME/.config/zellij/config.kdl"
echo 'mytool = true' > "$TEST_HOME/.mytoolrc"

mkdir -p "$DOTFILES_REPO/bin"
# Copy bin/dots to DOTFILES_REPO if exists, else we are testing existing repo location
DOT_BIN="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/bin/dots"

if [[ ! -x "$DOT_BIN" ]]; then
  echo "❌ FAIL: $DOT_BIN is not found or not executable yet (RED phase expected if not implemented)"
  exit 1
fi

echo "--> Test 1: Dry-Run (--test) mode on dot add"
output=$("$DOT_BIN" --test add "$TEST_HOME/.config/zellij" 2>&1 || true)
assert_file_exists "$TEST_HOME/.config/zellij/config.kdl" "Original file still in HOME after --test"
if [[ ! -e "$DOTFILES_REPO/config/zellij/config.kdl" ]]; then
  echo "  ✅ PASS: No file moved to repo during --test"
  PASS_COUNT=$((PASS_COUNT + 1))
else
  echo "  ❌ FAIL: File was moved to repo during --test!"
  FAIL_COUNT=$((FAIL_COUNT + 1))
fi

echo "--> Test 2: dot add on App Config Module (~/.config/zellij)"
"$DOT_BIN" add "$TEST_HOME/.config/zellij"
assert_file_exists "$DOTFILES_REPO/config/zellij/config.kdl" "File moved to DOTFILES_REPO/config/zellij/config.kdl"
assert_symlink_to "$TEST_HOME/.config/zellij" "$DOTFILES_REPO/config/zellij" "HOME/.config/zellij is now symlinked to repo config/zellij"

echo "--> Test 3: dot add on Root Dotfile (~/.mytoolrc)"
"$DOT_BIN" add "$TEST_HOME/.mytoolrc"
assert_file_exists "$DOTFILES_REPO/.mytoolrc" "File moved to DOTFILES_REPO/.mytoolrc"
assert_symlink_to "$TEST_HOME/.mytoolrc" "$DOTFILES_REPO/.mytoolrc" "HOME/.mytoolrc is now symlinked to repo .mytoolrc"

echo "--> Test 4: dot add on nonexistent path"
if ! "$DOT_BIN" add "$TEST_HOME/.nonexistent" >/dev/null 2>&1; then
  echo "  ✅ PASS: dot add errored on nonexistent path as expected"
  PASS_COUNT=$((PASS_COUNT + 1))
else
  echo "  ❌ FAIL: dot add should fail on nonexistent path"
  FAIL_COUNT=$((FAIL_COUNT + 1))
fi

echo "--> Test 5: dot status across directories"
git -C "$DOTFILES_REPO" init -q
git -C "$DOTFILES_REPO" config user.name "Test"
git -C "$DOTFILES_REPO" config user.email "test@test.com"
status_output=$(cd "$TEST_HOME" && "$DOT_BIN" status 2>&1)
if echo "$status_output" | grep -q "On branch"; then
  echo "  ✅ PASS: dot status successfully ran git status inside DOTFILES_REPO from outside directory"
  PASS_COUNT=$((PASS_COUNT + 1))
else
  echo "  ❌ FAIL: dot status failed to run git status inside DOTFILES_REPO"
  FAIL_COUNT=$((FAIL_COUNT + 1))
fi

echo "========================================"
echo "Summary: $PASS_COUNT passed, $FAIL_COUNT failed"
if [[ $FAIL_COUNT -gt 0 ]]; then
  exit 1
fi

#!/usr/bin/env bash
set -euo pipefail

# Test Suite for install.sh Auto-Discovery Symlink Manager
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
echo "🧪 Running tests/test_install.sh"
echo "========================================"

# Setup Sandbox Seam environment
TEST_DIR=$(mktemp -d)
trap 'rm -rf "$TEST_DIR"' EXIT

export TEST_HOME="$TEST_DIR/home"
export DOTFILES_REPO="$TEST_DIR/repo"
export HOME="$TEST_HOME"

mkdir -p "$TEST_HOME/.config/zellij"
echo "old zshrc content" > "$TEST_HOME/.zshrc"
echo "old zellij content" > "$TEST_HOME/.config/zellij/config.kdl"

# Copy real repo structure to DOTFILES_REPO for isolated testing
cp -a "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)" "$DOTFILES_REPO"
rm -rf "$DOTFILES_REPO/tests" "$DOTFILES_REPO/.scratch"

# Create fake config apps inside repo
mkdir -p "$DOTFILES_REPO/config/zellij"
echo "repo zellij content" > "$DOTFILES_REPO/config/zellij/config.kdl"
mkdir -p "$DOTFILES_REPO/config/ghostty"
echo "repo ghostty content" > "$DOTFILES_REPO/config/ghostty/config"
echo "repo zshrc content" > "$DOTFILES_REPO/.zshrc"
echo "repo p10k content" > "$DOTFILES_REPO/.p10k.zsh"

echo "--> Test 1: Dry-Run (--test) mode on install.sh"
output=$("$DOTFILES_REPO/install.sh" --test 2>&1 || true)
assert_equals "old zshrc content" "$(cat "$TEST_HOME/.zshrc")" "Original .zshrc preserved after --test"
assert_equals "old zellij content" "$(cat "$TEST_HOME/.config/zellij/config.kdl")" "Original zellij config preserved after --test"
if [[ ! -e "$TEST_HOME/.local/bin/dot" ]]; then
  echo "  ✅ PASS: bin/dot not installed during --test"
  PASS_COUNT=$((PASS_COUNT + 1))
else
  echo "  ❌ FAIL: bin/dot was installed during --test!"
  FAIL_COUNT=$((FAIL_COUNT + 1))
fi

echo "--> Test 2: Actual execution inside Sandbox with -y / non-interactive"
"$DOTFILES_REPO/install.sh" -y

assert_symlink_to "$TEST_HOME/.zshrc" "$DOTFILES_REPO/.zshrc" "HOME/.zshrc symlinked to repo .zshrc"
assert_symlink_to "$TEST_HOME/.p10k.zsh" "$DOTFILES_REPO/.p10k.zsh" "HOME/.p10k.zsh symlinked to repo .p10k.zsh"
assert_symlink_to "$TEST_HOME/.config/zellij" "$DOTFILES_REPO/config/zellij" "HOME/.config/zellij symlinked to repo config/zellij"
assert_symlink_to "$TEST_HOME/.config/ghostty" "$DOTFILES_REPO/config/ghostty" "HOME/.config/ghostty symlinked to repo config/ghostty"
assert_symlink_to "$TEST_HOME/.local/bin/dot" "$DOTFILES_REPO/bin/dot" "bin/dot symlinked to HOME/.local/bin/dot"

echo "--> Test 3: Verify backups in dotfiles-trash/"
assert_file_exists "$TEST_HOME/dotfiles-trash/.zshrc" "Backup of .zshrc exists in dotfiles-trash"
assert_equals "old zshrc content" "$(cat "$TEST_HOME/dotfiles-trash/.zshrc")" "Backed up .zshrc contains original content"
assert_file_exists "$TEST_HOME/dotfiles-trash/.config/zellij/config.kdl" "Backup of zellij exists in dotfiles-trash"
assert_equals "old zellij content" "$(cat "$TEST_HOME/dotfiles-trash/.config/zellij/config.kdl")" "Backed up zellij config contains original content"

echo "--> Test 4: Verify PATH configuration in .zshrc"
if grep -q '\.local/bin' "$TEST_HOME/.zshrc" || grep -q '\.local/bin' "$DOTFILES_REPO/.zshrc"; then
  echo "  ✅ PASS: ~/.local/bin is configured in .zshrc PATH"
  PASS_COUNT=$((PASS_COUNT + 1))
else
  echo "  ❌ FAIL: ~/.local/bin not found in .zshrc PATH"
  FAIL_COUNT=$((FAIL_COUNT + 1))
fi

echo "========================================"
echo "Summary: $PASS_COUNT passed, $FAIL_COUNT failed"
if [[ $FAIL_COUNT -gt 0 ]]; then
  exit 1
fi

#!/usr/bin/env bash
set -euo pipefail

#
# Test & Interactive Mode Configuration
#
TEST_MODE=false
YES_MODE=false
TARGET_HOME="${TEST_HOME:-$HOME}"
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

for arg in "$@"; do
  if [[ "$arg" == "--test" || "$arg" == "-t" ]]; then
    TEST_MODE=true
    echo "🔍 Running in TEST MODE - No changes will be made"
    echo "----------------------------------------"
  elif [[ "$arg" == "--yes" || "$arg" == "-y" ]]; then
    YES_MODE=true
  fi
done

if [ "$TEST_MODE" = false ] && [ "$YES_MODE" = false ] && [ -t 0 ]; then
  echo "Are you sure you want to install these dotfiles? This will replace your existing dotfiles (they can be restored; check ~/dotfiles-trash directory)."
  read -p "(Y/n): " install_dotfiles
  if [ -n "$install_dotfiles" ] && [ "${install_dotfiles,,}" != "y" ]; then
    echo "Installation cancelled."
    exit 0
  fi
fi

#
# Plugin Installation
#
function install_zsh_plugins() {
  local zsh_custom="${ZSH_CUSTOM:-$TARGET_HOME/.oh-my-zsh/custom}"
  if [ "$TEST_MODE" = true ]; then
    echo "[TEST] Would install Zsh plugins:"
    echo "  • Would clone powerlevel10k theme to $zsh_custom/themes/powerlevel10k"
    echo "  • Would clone zsh-syntax-highlighting to $zsh_custom/plugins/zsh-syntax-highlighting"
    echo "  • Would clone zsh-autosuggestions to $zsh_custom/plugins/zsh-autosuggestions"
    return
  fi
  
  echo "Installing Zsh plugins..."
  mkdir -p "$zsh_custom/themes" "$zsh_custom/plugins"
  if [ ! -d "$zsh_custom/themes/powerlevel10k" ]; then
    git clone --depth=1 https://github.com/romkatv/powerlevel10k.git "$zsh_custom/themes/powerlevel10k" || true
  fi
  if [ ! -d "$zsh_custom/plugins/zsh-syntax-highlighting" ]; then
    git clone https://github.com/zsh-users/zsh-syntax-highlighting.git "$zsh_custom/plugins/zsh-syntax-highlighting" || true
  fi
  if [ ! -d "$zsh_custom/plugins/zsh-autosuggestions" ]; then
    git clone https://github.com/zsh-users/zsh-autosuggestions "$zsh_custom/plugins/zsh-autosuggestions" || true
  fi
}

#
# Dotfiles Management (Auto-Discovery Symlink Farm)
#
function link_dotfile() {
  local source_path="$REPO_DIR/$1"
  local target_path="$2"

  if [ "$TEST_MODE" = true ]; then
    echo "[TEST] Would symlink $source_path -> $target_path"
    if [ -e "$target_path" ] && [ ! -L "$target_path" ]; then
      echo "[TEST] Would backup existing $target_path to $TARGET_HOME/dotfiles-trash/"
    fi
    return
  fi

  # Backup existing file/dir if not already a symlink pointing to our repo
  if [ -e "$target_path" ] && [ ! -L "$target_path" ]; then
    local rel_target="${target_path#$TARGET_HOME/}"
    local backup_path="$TARGET_HOME/dotfiles-trash/$rel_target"
    mkdir -p "$(dirname "$backup_path")"
    mv "$target_path" "$backup_path"
    echo "📦 Backed up existing $target_path to $backup_path"
  fi

  mkdir -p "$(dirname "$target_path")"
  ln -sfn "$source_path" "$target_path"
  echo "🔗 Symlinked $target_path -> $source_path"
}

function install_dotfiles_and_configs() {
  if [ "$TEST_MODE" = true ]; then
    echo "[TEST] Would link dotfiles and configs:"
  else
    echo "Linking root dotfiles..."
  fi
  link_dotfile .zshrc "$TARGET_HOME/.zshrc"
  link_dotfile .p10k.zsh "$TARGET_HOME/.p10k.zsh"

  if [ "$TEST_MODE" = false ]; then
    echo "Linking application modules inside config/..."
  fi
  if [ -d "$REPO_DIR/config" ]; then
    for app in "$REPO_DIR/config/"*; do
      if [ -e "$app" ]; then
        local app_name
        app_name=$(basename "$app")
        link_dotfile "config/$app_name" "$TARGET_HOME/.config/$app_name"
      fi
    done
  fi

  # Install bin/dots helper
  if [ -f "$REPO_DIR/bin/dots" ]; then
    link_dotfile "bin/dots" "$TARGET_HOME/.local/bin/dots"
    chmod +x "$REPO_DIR/bin/dots"
    ensure_local_bin_in_path
  fi
}

function ensure_local_bin_in_path() {
  local zshrc_path="$TARGET_HOME/.zshrc"
  if [ "$TEST_MODE" = true ]; then
    echo "[TEST] Would verify/add ~/.local/bin to PATH in $zshrc_path"
    return
  fi

  if [ -e "$zshrc_path" ]; then
    if ! grep -q '\.local/bin' "$zshrc_path"; then
      echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$zshrc_path"
      echo "added ~/.local/bin to PATH in $zshrc_path"
    fi
  else
    echo 'export PATH="$HOME/.local/bin:$PATH"' > "$zshrc_path"
  fi
}

#
# Git Configuration
#
function set_git_credentials() {
  if [ "$TEST_MODE" = true ]; then
    echo "[TEST] Would prompt for Git credentials setup"
    return
  fi

  if [ "$YES_MODE" = true ] || [ ! -t 0 ]; then
    echo "Skipping Git credentials prompt in non-interactive / --yes mode."
    return
  fi

  echo "Would you like to set up Git credentials?"
  read -p "(Y/n): " set_git_creds
  if [ -z "$set_git_creds" ] || [ "${set_git_creds,,}" == "y" ]; then
    read -p "Git Username: " git_username
    read -p "Git Email: " git_useremail
    git config --global user.name "$git_username"
    git config --global user.email "$git_useremail"
    echo "Git credentials configured successfully."
  else
    echo "Skipping Git credentials setup."
  fi
}

#
# UI Elements
#
function print_completion_message() {
  echo ""
  echo "╔════════════════════════════════════════════╗"
  if [ "$TEST_MODE" = true ]; then
    echo "║           Test Run Complete!               ║"
    echo "║                                            ║"
    echo "║  ✓ All operations would succeed            ║"
    echo "║  ✓ No changes were actually made           ║"
    echo "║                                            ║"
    echo "║  Run without --test to apply changes!      ║"
  else
    echo "║           Installation Complete!           ║"
    echo "║                                            ║"
    echo "║  🚀 Your terminal is now supercharged! 🚀  ║"
    echo "║                                            ║"
    echo "║  • Powerlevel10k theme is ready            ║"
    echo "║  • ZSH plugins are installed               ║"
    echo "║  • Dotfiles auto-symlinked (config/*)      ║"
    echo "║  • bin/dots helper installed to PATH       ║"
    echo "║                                            ║"
    echo "║  Enjoy your enhanced terminal experience!  ║"
  fi
  echo "╚════════════════════════════════════════════╝"
  echo ""
}

#
# Main Installation Process
#
install_dotfiles_and_configs
install_zsh_plugins
set_git_credentials

if [ "$TEST_MODE" = false ]; then
  if [ -f "$TARGET_HOME/.zshrc" ] && [ "$YES_MODE" = false ] && [ -t 0 ]; then
    echo "Applying new configuration..."
    source "$TARGET_HOME/.zshrc" >/dev/null 2>&1 || true
  fi
else
  echo "[TEST] Would source ~/.zshrc to apply new configuration"
fi

print_completion_message

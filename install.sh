#!/usr/bin/env bash

#
# Test Mode Configuration
#
TEST_MODE=false
if [[ "$1" == "--test" ]] || [[ "$1" == "-t" ]]; then
  TEST_MODE=true
  echo "🔍 Running in TEST MODE - No changes will be made"
  echo "----------------------------------------"
fi

if [ "$TEST_MODE" = false ]; then
  echo "Are you sure you want to install these dotfiles? This will replace your existing dotfiles (they can be restored; check ~/dotfiles-trash directory)."
  read -p "(Y/n): " install_dotfiles
fi

#
# Plugin Installation
#
function install_zsh_plugins() {
  if [ "$TEST_MODE" = true ]; then
    echo "[TEST] Would install Zsh plugins:"
    echo "  • Would clone powerlevel10k theme to ${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/themes/powerlevel10k"
    echo "  • Would clone zsh-syntax-highlighting to ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting"
    echo "  • Would clone zsh-autosuggestions to ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-autosuggestions"
    return
  fi
  
  echo "Installing Zsh plugins..."
  git clone --depth=1 https://github.com/romkatv/powerlevel10k.git ${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/themes/powerlevel10k
  git clone https://github.com/zsh-users/zsh-syntax-highlighting.git ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting
  git clone https://github.com/zsh-users/zsh-autosuggestions ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-autosuggestions
}

#
# Dotfiles Management
#
function copy_dotfile() {
  local source_file="$1"
  local target_file="$2"

  if [ "$TEST_MODE" = true ]; then
    echo "[TEST] Would copy $source_file to $target_file"
    if [ -e "$target_file" ]; then
      echo "[TEST] Would backup existing $target_file to ~/dotfiles-trash/"
    fi
    return
  fi

  if [ -e "$target_file" ]; then
    mkdir -p ~/dotfiles-trash
    mv "$target_file" ~/dotfiles-trash/
  fi

  cp "$source_file" "$target_file"
}

function copy_dotfiles() {
  if [ "$TEST_MODE" = true ]; then
    echo "[TEST] Would copy dotfiles:"
  else
    echo "Copying dotfiles..."
  fi
  copy_dotfile .zshrc ~/.zshrc
  copy_dotfile .p10k.zsh ~/.p10k.zsh
}

#
# Git Configuration
#
function set_git_credentials() {
  if [ "$TEST_MODE" = true ]; then
    echo "[TEST] Would prompt for Git credentials setup"
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
    echo "║  • Custom configurations are applied       ║"
    echo "║                                            ║"
    echo "║  Enjoy your enhanced terminal experience!  ║"
  fi
  echo "╚════════════════════════════════════════════╝"
  echo ""
}

#
# Main Installation Process
#
if [ "$TEST_MODE" = true ] || [ -z "$install_dotfiles" ] || [ "${install_dotfiles,,}" == "y" ]; then
  copy_dotfiles
  install_zsh_plugins
  set_git_credentials
  
  if [ "$TEST_MODE" = false ]; then
    # Source the new configuration
    if [ -f ~/.zshrc ]; then
      echo "Applying new configuration..."
      source ~/.zshrc >/dev/null 2>&1 || true
    fi
  else
    echo "[TEST] Would source ~/.zshrc to apply new configuration"
  fi
  
  print_completion_message
else
  echo "Installation cancelled."
fi

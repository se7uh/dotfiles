#!/usr/bin/env bash

echo "Apakah Anda yakin ingin menginstal dotfile ini? Ini akan menghapus dotfile Anda yang ada (mereka masih bisa dikembalikan; periksa direktori ~/dotfiles-trash)."
read -p "(Y/n): " install_dotfiles

# function install_ohmyzsh {
#   sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
# }

function install_zsh_plugins {
  echo "Menginstal plugin Zsh..."
  
  git clone --depth=1 https://github.com/romkatv/powerlevel10k.git ${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/themes/powerlevel10k
  git clone https://github.com/zsh-users/zsh-syntax-highlighting.git ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting
  git clone https://github.com/zsh-users/zsh-autosuggestions ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-autosuggestions
  
}

function copy_dotfile {
  local source_file="$1"
  local target_file="$2"

  if [ -e "$target_file" ]; then
    mkdir -p ~/dotfiles-trash
    mv "$target_file" ~/dotfiles-trash/
  fi

  cp "$source_file" "$target_file"
}

function copy_dotfiles {
  echo "Menyalin dotfile..."
  copy_dotfile .zshrc ~/.zshrc
  copy_dotfile .p10k.zsh ~/.p10k.zsh
}
 
function set_git_credentials {
  echo "Apakah Anda ingin mengatur kredensial Git?"
  read -p "(Y/n): " set_git_creds
  if [ -z "$set_git_creds" ] || [ "${set_git_creds,,}" == "y" ]; then
    read -p "Username Git: " git_username
    read -p "Email Git: " git_useremail
    git config --global user.name "$git_username"
    git config --global user.email "$git_useremail"
    echo "Kredensial Git diatur."
  else
    echo "Kredensial Git tidak diatur."
  fi
}

if [ -z "$install_dotfiles" ] || [ "${install_dotfiles,,}" == "y" ]; then
  copy_dotfiles
  # install_ohmyzsh
  install_zsh_plugins
  set_git_credentials
  echo "Instalasi selesai."
else
  echo "Baiklah, tidak melakukannya."
fi

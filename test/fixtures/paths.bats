#!/usr/bin/env bats
# SPDX-License-Identifier: MIT
# Copyright (c) 2025 David Kristiansen

# Fixture: Simulated path list based on a realistic dotfiles setup.
# Use this to test filtering logic against complex, nested structures.


fixture_paths_dotfiles() {
    cat <<EOF
.config/asdf/config
.config/btop/btop.conf
.config/btop/themes/gruvbox_dark_v2.theme
.config/direnv/direnv.toml
.config/dunst/dunstrc
.config/environment.d/00-xdg.conf
.config/nvim/lua/david/config/autocmds.lua
.config/nvim/lua/david/plugins/colorscheme.lua
.config/nvim/lua/david/util/init.lua
.config/python/pythonrc
.config/rofi/config.rasi
.config/rofi/gruvbox-dark-hard.rasi
.config/rofi/kanagawa-dragon.rasi
.config/ruff/ruff.toml
.config/starship.toml
.config/sway/bar
.config/sway/colorscheme/gruvbox_dark_hard
.config/sway/colorscheme/kanagawa_dragon
.config/sway/config
.config/sway/ux
.config/sway/window_rules
.config/swaync/config.json
.config/swaync/style.css
.config/systemd/user/fcitx.service
.config/systemd/user/gammastep@.service
.config/systemd/user/kanshi.service
.config/systemd/user/swayidle.service
.config/systemd/user/teams-for-linux.service
.config/teams-for-linux/config.json
.config/tmux/tmux.conf
.config/translate-shell/init.trans
.config/waybar/conficonfig/zsh/.zshrc
.config/zsh/zsh_plugins.txt
.config/zsh/zsh_plugins.zsh
.config/zsh/zshrc.d/70-keybindings.zsh
.config/zsh/zshrc.d/80-dotfiles.zsh
.config/zsh/zshrc.d/90-uv-completion.zsh
.config/zsh/zshrc.d/90-zvm-widgets.zsh
.gitignore
.git/config
project/lib.c
project/lib.h
EOF
}



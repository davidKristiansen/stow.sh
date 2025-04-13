#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Copyright (c) 2025 David Kristiansen

# This condition always returns true and can be used to preserve extensions in stow paths
# Example: script.conf##exe.sh would match condition 'exe' and keep '.sh'
__stow_extension() {
    return 0
}

__stow_os () {
    _log debug 2 "Checking OS equals '$1'"
    os=$(grep -E "^NAME=" /etc/os-release)
    os="${os#*=}"
    os="${os//\"/}"
    os="${os,,}"
    [[ $os == "$1" ]]
}

__stow_shell () {
    _log debug 2 "Checking current shell matches '$1'"
    if [[ -z $SHELL ]]; then
        return $(__stow_exe "$1")
    fi
    [[ $(basename "$SHELL") == "$1" ]]
}

__stow_docker () {
    _log debug 2 "Checking for Docker environment"
    [[ -f /.dockerenv ]]
}

__stow_wsl () {
    _log debug 2 "Checking for WSL environment"
    lscpu | grep -qi 'Hypervisor vendor.*\\(microsoft\\|windows\\)'
}

__stow_exe () {
    _log debug 2 "Checking for executable '$1' in PATH"
    command -v "$1" &>/dev/null
}

__stow_wm () {
    __stow_exe "$1"
}


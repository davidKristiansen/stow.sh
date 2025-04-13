#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Copyright (c) 2025 David Kristiansen

# scan.sh — recursively list all candidate paths for stowing

# Usage:
#   __scan_tree <source_dir>
# Output:
#   Emits relative paths (relative to source_dir) line-by-line

__scan_tree() {
    local root="$1"
    local cwd

    if [[ ! -d "$root" ]]; then
        _log error "scan root is not a directory: $root"
        return 1
    fi

    cwd="$(pwd)"
    cd "$root" || return 1

    # Emit all files and symlinks, including dotfiles, recursively
    find . \( -type f -o -type l \) -print | \
    while IFS= read -r path; do
        # Strip leading ./
        printf '%s\n' "${path#./}"
    done | LC_ALL=C sort

    cd "$cwd" || return 1
}


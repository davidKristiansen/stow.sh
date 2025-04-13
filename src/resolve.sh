#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Copyright (c) 2025 David Kristiansen

# resolve.sh — resolve source, target, and relative path from stow candidate

# Usage:
#   __resolve_paths "nvim##exe.nvim/init.vim"
# Output:
#   Sets global vars:
#     RESOLVED_SOURCE   → full source path
#     RESOLVED_TARGET   → full target path
#     RESOLVED_RELPATH  → relative path from target to source

__resolve_paths() {
    local candidate="$1"
    local sanitized="$(__sanitize "$candidate")"

    RESOLVED_SOURCE="$_SOURCE/$candidate"
    RESOLVED_TARGET="$_TARGET/$sanitized"

    RESOLVED_RELPATH="$(
        realpath --relative-to="$(dirname "$RESOLVED_TARGET")" "$RESOLVED_SOURCE"
    )"

    _log debug 3 "Resolved source: $RESOLVED_SOURCE"
    _log debug 3 "Resolved target: $RESOLVED_TARGET"
    _log debug 3 "Relative path: $RESOLVED_RELPATH"
}


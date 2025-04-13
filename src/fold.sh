#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Copyright (c) 2025 David Kristiansen

# fold.sh — logic for smart folding decisions

# Given a candidate relative path from source root, find the deepest
# foldable parent (folder) that:
#  - exists as a symlink in the target, or
#  - could be folded as a single symlink
#
# Usage:
#   __fold_strategy "nvim/lua/init.vim"
# Returns:
#   stdout: the suggested fold point (e.g. "nvim/lua")
#   return code: 0 if folding is possible, 1 otherwise

__fold_strategy() {
    local candidate_path="$1"
    local sanitized_path="$(__sanitize "$candidate_path")"

    # Walk upward to find deepest existing directory in target
    local path="$sanitized_path"
    while [[ "$path" != "." ]]; do
        if [[ -L "$_TARGET/$path" ]]; then
            _log debug 2 "Found existing symlink in target: $_TARGET/$path"
            echo "$path"
            return 0
        fi

        if [[ -d "$_SOURCE/$path" && ! -e "$_TARGET/$path" ]]; then
            _log debug 2 "Can fold: $_TARGET/$path → $_SOURCE/$path"
            echo "$path"
            return 0
        fi

        path="$(dirname "$path")"
    done

    return 1
}


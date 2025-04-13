#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Copyright (c) 2025 David Kristiansen

# Strip conditions like ##os.linux or ##shell.bash from a path
# e.g. foo##os.linux/bar##wm.sway -> foo/bar
__sanitize() {
    local path="$1"
    local sanitized=""
    local token

    IFS='/' read -ra parts <<< "$path"
    for token in "${parts[@]}"; do
        sanitized+="${token%%##*}/"
    done
    sanitized="${sanitized%/}"
    _log debug 3 "Sanitized '$path' -> '$sanitized'"
    echo "$sanitized"
}


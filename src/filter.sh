#!/usr/bin/env bash
shopt -s globstar extglob 2> /dev/null # Enable ** and extglob support
# SPDX-License-Identifier: MIT
# Copyright (c) 2025 David Kristiansen

# filter.sh — generic path filtering utility

# Expects:
#   - ignore: (array of regex patterns, optional)
#   - ignore_glob: (array of glob patterns, optional)
#   - git_mode: (git aware mode, optional)
#   - stdin: newline-separated input paths

# Outputs:
#   - filtered list of paths to stdout

[[ "$(declare -p ignore 2> /dev/null)" =~ "declare -a" ]] || declare -a ignore=()
[[ "$(declare -p ignore_glob 2> /dev/null)" =~ "declare -a" ]] || declare -a ignore_glob=()

stow_sh::git_should_ignore() {
    local relpath="$1"
    local path="$2"
    local check_path output last_line

    # Always ignore .git/ directory explicitly
    if [[ "$path" == ".git"* ]]; then
        return 0
    fi

    if [[ "$relpath" == "." ]]; then
        check_path="$path"
    else
        check_path="$relpath/$path"
    fi

    if output=$(git check-ignore --verbose "$check_path" 2> /dev/null); then
        last_line=$(tail -n1 <<< "$output")
        if [[ "$last_line" =~ ^.*:[0-9]+:!.*$ ]]; then
            return 1  # explicitly re-included
        else
            return 0  # matched ignore pattern
        fi
    elif [[ $? -eq 1 ]]; then
        return 1  # not ignored
    else
        return 1  # unknown failure, default to keep
    fi
}

stow_sh::match_regex_ignore() {
    local path="$1"
    for pattern in "${ignore[@]}"; do
        [[ "$path" =~ $pattern ]] && return 0
    done
    return 1
}

stow_sh::match_glob_ignore() {
    local path="$1"
    for pattern in "${ignore_glob[@]}"; do
        [[ "$path" == $pattern ]] && return 0
    done
    return 1
}

stow_sh::filter_candidates() {
    local relpath="."
    if git_root=$(git rev-parse --show-toplevel 2> /dev/null); then
        relpath=$(realpath --relative-to="$git_root" .)
    fi

    local keep

    while IFS= read -r path; do
        keep=true

        if [[ "$git_mode" == true ]]; then
            if stow_sh::git_should_ignore "$relpath" "$path"; then
                keep=false
            fi
        fi

        if [[ $keep == true && ${#ignore[@]} -gt 0 ]]; then
            if stow_sh::match_regex_ignore "$path"; then
                keep=false
            fi
        fi

        if [[ $keep == true && ${#ignore_glob[@]} -gt 0 ]]; then
            if stow_sh::match_glob_ignore "$path"; then
                keep=false
            fi
        fi

        [[ $keep == true ]] && echo "$path"
    done
}

#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Copyright (c) 2025 David Kristiansen

__contains() {
    local test_variable="$1"
    shift
    local array=("$@")
    for element in "${array[@]}"; do
        if [[ "$test_variable" == "$element" ]]; then
            _log debug 3 "__contains: '$test_variable' matched '$element'"
            return 0
        fi
    done
    _log debug 3 "__contains: '$test_variable' not found"
    return 1
}

__check_conditions() {
    local candidate="$1"
    if [[ "$candidate" != *"##"* ]]; then
        _log debug 3 "No conditions to check for '$candidate'"
        return 0
    fi

    local condition_string="${candidate##*##}"
    IFS=',' read -r -a conditions <<< "$condition_string"

    for condition in "${conditions[@]}"; do
        local expected=0
        if [[ "$condition" == !* ]]; then
            condition="${condition:1}"
            expected=1
        fi
        IFS='.' read -r -a cond <<< "$condition"
        local func="__stow_${cond[0]}"
        "$func" "${cond[@]:1}"
        local result=$?
        if [[ "$result" -ne "$expected" ]]; then
            _log debug 2 "Condition '${condition}' not met for '$candidate'"
            return 1
        else
            _log debug 1 "Condition '${condition}' met for '$candidate'"
        fi
    done
    return 0
}

__unstow() {
    local path="$1"
    local target_path="$_TARGET/$(__sanitize "$path")"
    _log debug 1 "Unstowing: $path"

    if [[ ! -L "$target_path" ]]; then
        _log warn 1 "$target_path does not exist or is not a symlink"
        return 1
    fi
    if [[ "$dry_run" == false ]]; then
        rm "$target_path"
    fi
    _log info "$target_path removed"
}

__stow() {
    local path="$1"
    local source_path="$_SOURCE/$path"
    local target_path="$_TARGET/$(__sanitize "$path")"
    local relative_path="$(realpath -s --relative-to="$(dirname "$target_path")" "$source_path")"

    _log debug 1 "Preparing to stow: $path"
    _log debug 2 "Resolved source: $source_path"
    _log debug 2 "Resolved target: $target_path"
    _log debug 2 "Relative path: $relative_path"

    __contains "$path" "${ignore[@]}" && {
        _log debug 1 "$path ignored by pattern"
        return 1
    }

    __check_conditions "$path" || return 1

    if [[ ! -e "$source_path" ]]; then
        _log error "Source '$source_path' does not exist"
        return 1
    fi

    if [[ -e "$target_path" ]]; then
        if [[ "$force" == false ]]; then
            _log warn 1 "$target_path already exists. Use -f to overwrite"
            return 1
        fi
        __unstow "$path" || return $?
    fi

    if [[ ! -d "$(dirname "$target_path")" ]]; then
        if [[ "$dry_run" == false ]]; then
            mkdir -p "$(dirname "$target_path")"
        fi
        _log info "Created directory: $(dirname "$target_path")"
    fi

    (
        cd "$(dirname "$target_path")"
        if [[ "$dry_run" == false ]]; then
            ln -s "$relative_path" "$(basename "$target_path")"
        fi
    )
    _log info "$target_path -> $relative_path"
}

__walk_dir() {
    shopt -s nullglob dotglob

    local root_path="${1%/}"
    _log debug 1 "Walking directory: $root_path"

    for child in "$root_path"/*; do
        local candidate="${child#"$_SOURCE/"}"
        local source_path="$_SOURCE/$candidate"
        local target_path="$_TARGET/$(__sanitize "$candidate")"

        _log debug 3 "Found: $child"
        _log debug 2 "Candidate: $candidate"
        _log debug 3 "Source: $source_path"
        _log debug 3 "Target: $target_path"

        if [[ -f "$source_path" || -L "$target_path" || ! -d "$target_path" ]]; then
            stow_targets+=("$candidate")
            _log debug 1 "Added to stow_targets: $candidate"
            continue
        fi

        __walk_dir "$candidate"
    done
}

main() {
    parse_args "$@"
    setup_paths

    if [[ -n "${unstow_targets[*]:-}" ]]; then
        for path in "${unstow_targets[@]}"; do
            __unstow "$path"
        done
    fi

    if [[ -z "${stow_targets[*]:-}" && -z "${unstow_targets[*]:-}" ]]; then
        __walk_dir "$_SOURCE"
    fi

    for path in "${stow_targets[@]:-}"; do
        __stow "$path"
    done

    if [[ "$dry_run" == true ]]; then
        _log warn $'-n flag active — dry run mode: no filesystem changes were made.'
    fi

    _log debug 3 $'--- Final State ---
      debug='"$debug"$'
      dir='"$_SOURCE"$'
      target='"$_TARGET"$'
      force='"$force"$'
      dry_run='"$dry_run"$'
      ignore='"${ignore[*]}"$'
      stow_targets='"${stow_targets[*]}"$'
      unstow_targets='"${unstow_targets[*]}"''

}

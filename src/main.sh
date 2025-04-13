#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Copyright (c) 2025 David Kristiansen

# ======================================================
# stow.sh — A minimal GNU Stow-like dotfile manager
# ------------------------------------------------------
# This is the main entrypoint script. It parses arguments,
# sets up paths, scans for stowable candidates, filters them,
# and prepares the list for resolution and symlinking.
#
# All logic is modularized in src/*.sh and sourced here.
# ======================================================

set -euo pipefail

ROOT="${STOW_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)}"

# Source all required modules
source "$ROOT/log.sh"
source "$ROOT/args.sh"
source "$ROOT/scan.sh"
source "$ROOT/filter.sh"

main() {
    parse_args "$@"
    _log debug 3 "Raw args: $*"

    _log debug 2 "Setting up paths..."
    setup_paths

    if [[ ${#stow_targets[@]} -gt 0 ]]; then
        _log debug 1 "Using explicit stow targets — skipping scan."
        candidates=("${stow_targets[@]}")
    else
        _log debug 1 "Running scan + filter pipeline..."
        mapfile -t candidates < <( __scan_tree "$_SOURCE" | stow_sh::filter_candidates)
    fi

    _log debug 1 "Candidate list built with ${#candidates[@]} entries"

    if [[ $debug -ge 1 ]]; then
        _log info "Stow candidates:"
        for path in "${candidates[@]}"; do
            echo "  $path"
        done
    fi

}

main "$@"

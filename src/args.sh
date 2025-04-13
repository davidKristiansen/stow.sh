#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Copyright (c) 2025 David Kristiansen

force=false
debug=0
dry_run=false
color_mode="auto"
declare adopt=false
declare no_folding=false
declare -a defer=()
declare -a override=()
declare -a ignore=()
declare -a ignore_glob=()
declare -a stow_targets=()
declare -a unstow_targets=()
declare -a restow_targets=()

declare dir=""
declare target=""
declare git_mode=false

__usage() {
    echo
    echo "Usage: stow.sh [OPTIONS] [<directory>]"
    echo
    echo "Options:"
    echo "  -d DIR, --dir=DIR             Source directory (default: current directory)"
    echo "  -t DIR, --target=DIR          Target directory (default: parent of source)"
    echo "  -S PATH, --stow PATH          Stow the specified path (repeatable)"
    echo "  -D PATH, --delete PATH        Unstow the specified path (repeatable)"
    echo "  -R PATH, --restow PATH        Restow the specified path (repeatable)"
    echo "  -i REGEX, --ignore=REGEX      Ignore pattern (repeatable)"
    echo "  -I GLOB, --ignore-glob=GLOB   Ignore pattern (repeatable)"
    echo "  -g, --git                     Git aware mode"
    echo "  -f, --force                   Overwrite existing symlinks"
    echo "  -n, --no                      Dry-run mode (no filesystem changes)"
    echo "  -v, --verbose                 Increase verbosity (repeatable)"
    echo "      --verbose=N               Set verbosity level directly"
    echo "      --color=WHEN              Colorize output: never, always, auto"
    echo "  -h, --help                    Show this help and exit"
    echo "      --version                 Show version and exit"
    echo
    echo "Positional Arguments:"
    echo "  <directory>                   Fallback stow root if not using -S/-D/-R"
    exit "$1"
}

__find_gitignore_upwards() {
    local dir="$PWD"
    while [[ "$dir" != "/" ]]; do
        if [[ -f "$dir/.gitignore" ]]; then
            echo "$dir/.gitignore"
            return
        fi
        dir="$(dirname "$dir")"
    done
}

parse_args() {
    _log debug 3 "parse_args() invoked with args: $*"

    while [[ $# -gt 0 ]]; do
        # Expand and split any chained short options (e.g. -fn → -f -n)
        if [[ "$1" =~ ^-[^-] && "${#1}" -gt 2 ]]; then
            # Convert -abc to -a -b -c and prepend to $@
            expanded_short_opts=( )
            for ((i=1; i<${#1}; i++)); do
                expanded_short_opts+=("-${1:i:1}")
            done
            set -- "${expanded_short_opts[@]}" "${@:2}"
            continue
        fi
        case "$1" in
            -d|--dir)
                dir="$2"
                _log debug 2 "Set dir: $dir"
                shift 2
                ;;
            -t|--target)
                target="$2"
                _log debug 2 "Set target: $target"
                shift 2
                ;;
            -f|--force)
                force=true
                _log debug 2 "Enabled force mode"
                shift
                ;;
            -n|--no)
                dry_run=true
                _log debug 2 "Enabled dry-run mode"
                shift
                ;;
            -v)
                debug=$((debug + 1))
                _log debug 2 "Increased verbosity to $debug"
                shift
                ;;
            --verbose=*)
                debug="${1#*=}"
                _log debug 2 "Set verbosity level to $debug"
                shift
                ;;
            --color=*)
                color_mode="${1#*=}"
                _log debug 2 "Set color_mode=$color_mode"
                shift
                ;;
            -i|--ignore)
                if [[ -z "$2" ]]; then
                    _log warn "Empty pattern passed to --ignore"
                fi
                ignore+=("$2")
                _log debug 2 "Added ignore pattern: $2"
                shift 2
                ;;
            --ignore=*)
                if [[ -z "${1#*=}" ]]; then
                    _log warn "Empty pattern passed to --ignore"
                fi
                ignore+=("${1#*=}")
                _log debug 2 "Added ignore pattern: ${1#*=}"
                shift
                ;;
            -I|--ignore-glob)
                if [[ -z "$2" ]]; then
                    _log warn "Empty pattern passed to --ignore-glob"
                fi
                ignore_glob+=("$2")
                _log debug 2 "Added ignore-glob pattern: $2"
                shift 2
                ;;
            --ignore-glob=*)
                if [[ -z "${1#*=}" ]]; then
                    _log warn "Empty pattern passed to --ignore-glob"
                fi
                ignore_glob+=("${1#*=}")
                _log debug 2 "Added ignore-glob pattern: ${1#*=}"
                shift
                ;;
            -g|--git)
                git_mode=true
                _log debug 2 "Enabled git aware mode"
                shift
                ;;
            -S|--stow)
                stow_targets+=("$2")
                _log debug 2 "Added stow target: $2"
                shift 2
                ;;
            -D|--delete)
                unstow_targets+=("$2")
                _log debug 2 "Added unstow target: $2"
                shift 2
                ;;
            -R|--restow)
                restow_targets+=("$2")
                _log debug 2 "Added restow target: $2"
                shift 2
                ;;
            --adopt)
                adopt=true
                _log debug 2 "Enabled adopt mode"
                shift
                ;;
            --no-folding)
                no_folding=true
                _log debug 2 "Disabled folding"
                shift
                ;;
            --defer=*)
                defer+=("${1#*=}")
                _log debug 2 "Added defer pattern: ${1#*=}"
                shift
                ;;
            --override=*)
                override+=("${1#*=}")
                _log debug 2 "Added override pattern: ${1#*=}"
                shift
                ;;
            -h|--help)
                __usage 0
                ;;
            --version)
                echo "stow.sh version $STOW_SH_VERSION"
                exit 0
                ;;
            --)
                shift
                break
                ;;
            -*|--*)
                _log error "Unknown option: $1"
                __usage 1
                ;;
            *)
                break
                ;;
        esac
    done

    if [[ "$git_mode" == true ]]; then
      if ! git_root=$(git rev-parse --show-toplevel 2>/dev/null); then
          _log error "Cannot enable --git: not inside a git repository"
          exit 1
      fi

      expected_gitignore="$git_root/.gitignore"
      if [[ ! -f "$expected_gitignore" ]]; then
          _log error "No .gitignore found at git repo root: $expected_gitignore"
          exit 1
      fi

      ignore_git_file="$expected_gitignore"
      _log debug 2 "Git-aware mode: using gitignore from $ignore_git_file"
    fi


    if [[ $# -gt 1 ]]; then
        __usage 1
    elif [[ $# -eq 1 ]]; then
        stow_targets+=("$1")
        _log debug 2 "Added positional stow target: $1"
    fi
}

setup_paths() {
    _log debug 3 "setup_paths() with dir='$dir' and target='$target'"

    if [[ -z "$dir" ]]; then
        readonly _SOURCE="$(pwd)"
    else
        readonly _SOURCE="$(realpath "$dir")"
    fi

    if [[ -n "$target" ]]; then
        readonly _TARGET="$(realpath "$target")"
    else
        # default target is the parent of the source directory
        readonly _TARGET="$(dirname "$_SOURCE")"
    fi

    _log debug 2 "Using _SOURCE=$_SOURCE"
    _log debug 2 "Using _TARGET=$_TARGET"
}


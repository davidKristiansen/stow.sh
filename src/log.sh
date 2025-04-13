#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Copyright (c) 2025 David Kristiansen

: "${debug:=0}"
: "${color_mode:=auto}"

# Determine if we should use color
__supports_color() {
    [[ -t 1 ]] && tput colors &>/dev/null && [[ $(tput colors) -ge 8 ]]
}

__use_color=false
case "$color_mode" in
    always) __use_color=true ;;
    auto)   __supports_color && __use_color=true ;;
    never)  __use_color=false ;;
esac

# ANSI color codes
__c_reset="\033[0m"
__c_debug="\033[36m"  # cyan
__c_info="\033[32m"   # green
__c_warn="\033[33m"   # yellow
__c_error="\033[31m"  # red

_log() {
    local level="$1"
    local level_debug=1
    shift

    if [[ "$level" == "debug" ]]; then
        level_debug="$1"
        shift
    fi

    local message="$*"

    local prefix=""
    local color=""

    case "$level" in
        debug)
            if [[ "$debug" -lt "$level_debug" ]]; then return; fi
            prefix="[DEBUG]"
            color="$__c_debug"
            ;;
        info)
            prefix="[INFO]"
            color="$__c_info"
            ;;
        warn)
            prefix="[WARN]"
            color="$__c_warn"
            ;;
        error)
            prefix="[ERROR]"
            color="$__c_error"
            ;;
        *)
            prefix="[LOG]"
            ;;
    esac

    if [[ "$__use_color" == true ]]; then
        printf "%b %s\n" "${color}${prefix}${__c_reset}" "$message" >&2
    else
        printf "%s %s\n" "$prefix" "$message" >&2
    fi
}


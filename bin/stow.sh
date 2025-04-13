#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Copyright (c) 2025 David Kristiansen

set -euo pipefail

# Entrypoint for stow-style symlink manager

STOW_ROOT="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/.." && pwd)"

exec "${STOW_ROOT}/src/main.sh" "$@"


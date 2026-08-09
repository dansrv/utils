#!/usr/bin/env bash
# Start a FRESH Claude Code session at the repo root.
#
# This file used to be a byte-for-byte copy of resume-claude.sh, so it resumed
# the previous conversation instead of starting a new one. Dropping --resume is
# the entire difference between the two scripts.
#
# Extra arguments are forwarded:  new-claude -p "summarise HEAD"
set -euo pipefail

# The root of the repo you are STANDING IN, not the one this file is stored in:
# a single shared copy on PATH serves every repo, so the script's own location
# says nothing about which repo you meant. Outside a repo, stay put.
cd "$(git rev-parse --show-toplevel 2>/dev/null || printf '%s\n' "$PWD")"

exec claude --dangerously-skip-permissions "$@"

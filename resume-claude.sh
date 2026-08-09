#!/usr/bin/env bash
# Resume a previous Claude Code session at the repo root.
#
# No argument opens the interactive picker. A session id or search term is
# forwarded, as is anything else:
#     resume-claude                 # picker
#     resume-claude <session-id>    # straight to that session
#     resume-claude --fork-session  # resume into a new session id
#
# Sessions are scoped to the directory they were started in, which is why this
# cds to the repo root first — otherwise running it from a subdirectory shows an
# empty picker.
set -euo pipefail

# The root of the repo you are STANDING IN, not the one this file is stored in:
# a single shared copy on PATH serves every repo, so the script's own location
# says nothing about which repo you meant. Outside a repo, stay put.
cd "$(git rev-parse --show-toplevel 2>/dev/null || printf '%s\n' "$PWD")"

exec claude --resume --dangerously-skip-permissions "$@"

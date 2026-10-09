#!/usr/bin/env bash
# The Claude Code status line: renderer + installer, in claude-statusline.py.
# This wrapper only picks the interpreter. `install` bakes that interpreter's
# absolute path into ~/.claude/settings.json, so prefer the system python over
# whatever a venv or uv shim puts first on PATH: the status line runs outside
# any shell profile.
set -euo pipefail

# install.sh symlinks this file into ~/.local/bin, so BASH_SOURCE may be the
# link: follow it to the clone, where claude-statusline.py lives beside it.
# (A loop rather than readlink -f, which macOS only gained in 12.3.)
src="${BASH_SOURCE[0]}"
while [ -L "$src" ]; do
  dir="$(cd "$(dirname "$src")" && pwd)"
  src="$(readlink "$src")"
  case "$src" in /*) ;; *) src="$dir/$src" ;; esac
done
here="$(cd "$(dirname "$src")" && pwd)"

py=/usr/bin/python3
[ -x "$py" ] || py="$(command -v python3 || true)"
[ -n "$py" ] || { echo "python3 not found" >&2; exit 1; }
exec "$py" "$here/claude-statusline.py" "$@"

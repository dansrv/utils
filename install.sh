#!/usr/bin/env bash
# Linux / WSL / macOS installer: symlink the commands into ~/.local/bin (or the
# directory given as $1). Re-running is harmless. On Windows use install.ps1.
set -euo pipefail

case "$(uname -s)" in
  MINGW*|MSYS*|CYGWIN*)
    echo "This is Git Bash on Windows: run install.ps1 from PowerShell instead." >&2
    echo "It puts bin\ on the Windows user PATH, which Git Bash inherits." >&2
    exit 1 ;;
esac

if [ "${BASH_VERSINFO[0]}" -lt 4 ]; then
  echo "bash 4+ required (showgit uses mapfile); on macOS: brew install bash" >&2
  exit 1
fi

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
dest="${1:-$HOME/.local/bin}"
mkdir -p "$dest"

for cmd in showgit new-claude resume-claude claude-statusline; do
  ln -sfn "$here/$cmd.sh" "$dest/$cmd"
  echo "linked  $dest/$cmd -> $here/$cmd.sh"
done

case ":$PATH:" in
  *":$dest:"*) ;;
  *) echo "note: $dest is not on your PATH; add it in your shell rc file" ;;
esac

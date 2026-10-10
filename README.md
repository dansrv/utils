# utils

Small host-wide shell commands. One clone per machine, installed once, then `git pull` updates every command everywhere.

| Command | What it does |
|---|---|
| `showgit` | One-glance git dashboard for the repo you're standing in |
| `new-claude` | Start a fresh Claude Code session at the repo root |
| `resume-claude` | Resume a previous Claude Code session at the repo root |
| `claude-statusline` | The Claude Code status line: one tested renderer, and the installer that points Claude Code at it |

The real programs are the `*.sh` files at the top level. `bin/` holds thin per-shell shims that locate them relative to themselves, so the clone can live anywhere.

## Install

Clone to `~/utils` on every machine (any path works, `~/utils` is just the convention used below).

### Linux / WSL

```bash
git clone https://github.com/dansrv/utils.git ~/utils
~/utils/install.sh            # symlinks into ~/.local/bin
```

`install.sh` takes an optional target directory. Make sure it is on your `PATH`.

### Windows (PowerShell, cmd and Git Bash)

Requires [Git for Windows](https://git-scm.com); the scripts run under its `bash.exe`.

```powershell
git clone https://github.com/dansrv/utils.git $HOME\utils
& $HOME\utils\install.ps1     # adds utils\bin to the user PATH
```

Open a new terminal afterwards. All three shells read the same PATH entry: PowerShell runs the `.ps1` shims, cmd the `.cmd` shims, Git Bash the extensionless bash wrappers. If PowerShell refuses to run the shims, allow local scripts once:

```powershell
Set-ExecutionPolicy -Scope CurrentUser RemoteSigned
```

### macOS

Same as Linux, but `showgit` needs bash 4 (it uses `mapfile`) and macOS ships bash 3:

```bash
brew install bash
git clone https://github.com/dansrv/utils.git ~/utils
~/utils/install.sh
```

The scripts start with `#!/usr/bin/env bash`, so Homebrew's bash must come before `/bin` on your `PATH`.

## Update

```bash
git -C ~/utils pull
```

Nothing else; the symlinks and PATH entry point at the clone. The status line, once installed, also points at the clone, so a pull updates it too.

## Uninstall

Linux/macOS: delete the three symlinks from `~/.local/bin`. Windows: remove the `utils\bin` entry from your user PATH (Settings → System → About → Advanced system settings → Environment Variables). Then delete the clone.

## showgit

A read-only dashboard of what is going on in the current repo. Deliberately offline — it never fetches, so it is instant and honest about the last-known state on this box.

```
showgit            # the dashboard
showgit -c 25      # 25 commits instead of 12
showgit -n         # do not clear the screen (keeps scrollback)
showgit -a         # show empty sections too
showgit -h         # help
```

Sections, in order:

- **Identity** — repo, branch (red if detached), upstream with `↑ahead` / `↓behind` or "in sync"
- **Operation banner** — loud warning if a rebase / merge / cherry-pick / revert / bisect is mid-flight
- **WORKING TREE** — conflicted / staged / modified / untracked counts plus up to 15 status lines, coloured like `git status -s`
- **HISTORY** — `git log --graph --all` of the last N commits (stashes excluded)
- **BRANCHES** — shown when more than one exists; each marked "merged — safe to delete" or "N unmerged" vs main/master
- **STASHES / WORKTREES** — only when non-empty; these usually mean unfinished business

Colour and screen-clearing switch off automatically when output is piped.

## new-claude / resume-claude

Thin wrappers around the `claude` CLI. Both `cd` to the root of the repo you are standing in first — Claude Code sessions are scoped to their start directory, so this keeps every session for a repo in one bucket (and keeps `resume-claude`'s picker from showing up empty when run from a subdirectory). Outside a repo they stay in the current directory.

```bash
new-claude                     # fresh session at the repo root
new-claude -p "summarise HEAD" # extra args are forwarded to claude

resume-claude                  # interactive session picker
resume-claude <session-id>     # straight to that session
resume-claude --fork-session   # resume into a new session id
```

The only difference between the two scripts is the `--resume` flag.

## claude-statusline

Claude Code shows a status line by running a command you configure and printing its output, with a JSON snapshot of the session on the command's stdin ([docs](https://code.claude.com/docs/en/statusline)). `claude-statusline.py` is that command, kept here so every machine shows the same line and a `git pull` updates it.

```
Fable 5.1 (high effort) | ctx 11% | 5h 17% (53m) · 7d 5%
```

Model, effort level, context window used, then the five-hour usage window with the time until it resets and the seven-day window. Anything the session does not have yet (no rate limits before the first reply, no context figure right after `/compact`) is left out rather than shown as a placeholder.

```bash
claude-statusline install       # writes the statusLine key into ~/.claude/settings.json
claude-statusline show          # every fixture rendered in colour, plus what settings hold now
claude-statusline test          # the fixtures and the settings edit, offline, under a second
claude-statusline uninstall     # removes the key; the script stays
claude-statusline render        # what Claude Code runs: stdin JSON -> the line
```

`install` writes the absolute path of this clone and of `/usr/bin/python3` into settings (one plugin cannot do this: Claude Code drops a `statusLine` key from plugin settings, which is why this is a script here and not a plugin). It keeps every other key and their order, refuses to touch a settings file it cannot parse, and honours `CLAUDE_CONFIG_DIR`. Re-running it is harmless. Takes effect at the next assistant message in a running session. The countdown is computed when the line is redrawn, so between messages it is as stale as the last reply; Claude Code redraws it when the window actually resets.

To change the line, edit `render()` in `claude-statusline.py`, add or adjust a fixture, run `claude-statusline test`, commit, and `git pull` on the other machines. Verified on Linux, WSL and Windows (Claude Code runs the command through Git Bash there; the installer writes the Windows python path); macOS should work as is.

**Both pass `--dangerously-skip-permissions`**, which lets Claude Code edit files and run commands without asking. Only use them in repos you trust, and read the scripts before installing on a shared machine.

## Layout

```
showgit.sh, new-claude.sh, resume-claude.sh   the commands
claude-statusline.sh + claude-statusline.py   the status line (bash picks the interpreter, python does the rest)
bin/<cmd>        bash wrapper   (Git Bash on Windows)
bin/<cmd>.ps1    PowerShell shim
bin/<cmd>.cmd    cmd shim
bin/_gitbash.ps1 finds Git for Windows bash.exe for the .ps1 shims
install.sh       Linux / WSL / macOS: symlinks into ~/.local/bin
install.ps1      Windows: adds bin\ to the user PATH
.gitattributes   LF for bash files, CRLF for the Windows shims
```

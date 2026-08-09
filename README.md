# utils

Small host-wide shell commands, installed once via symlinks and shared across every repo on the box.

## Contents

| Command | Script | What it does |
|---|---|---|
| `showgit` | `showgit.sh` | One-glance git dashboard for the repo you're standing in |
| `new-claude` | `new-claude.sh` | Start a fresh Claude Code session at the repo root |
| `resume-claude` | `resume-claude.sh` | Resume a previous Claude Code session at the repo root |

## Install

Clone, then symlink into a directory on your `PATH` (the symlink name is the command name, so the `.sh` suffix disappears):

```bash
git clone git@github.com:dansrv/utils.git ~/utils

ln -s ~/utils/showgit.sh       ~/.local/bin/showgit
ln -s ~/utils/new-claude.sh    ~/.local/bin/new-claude
ln -s ~/utils/resume-claude.sh ~/.local/bin/resume-claude
```

Because the scripts run through symlinks, a `git pull` in `~/utils` updates every command immediately — there is no copy step.

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

The only difference between the two scripts is the `--resume` flag. Both pass `--dangerously-skip-permissions`, so use them on machines where you trust the repos you point them at.

#!/usr/bin/env bash
# One-glance view of what is going on in this repo.
#
#   showgit            # the dashboard
#   showgit -c 25      # 25 commits instead of 12
#   showgit -n         # do not clear the screen (keeps scrollback)
#   showgit -a         # show empty sections too
#
# Deliberately offline: no fetch, so it stays instant and honest about what is
# on this box. ahead/behind is measured against the last-known remote state.
set -euo pipefail

COMMITS=12
CLEAR=1
ALL=0

while (($#)); do
    case $1 in
        -c|--commits)
            if (($# < 2)); then
                printf 'showgit: -c needs a number\n' >&2; exit 2
            fi
            COMMITS=$2; shift 2 ;;
        -n|--no-clear) CLEAR=0; shift ;;
        -a|--all)      ALL=1; shift ;;
        # Print the header block, however long it grows — not a fixed range.
        -h|--help)     sed -n '2,${/^#/!q; s/^# \?//p;}' "$0"; exit 0 ;;
        *) printf 'showgit: unknown option %s (try -h)\n' "$1" >&2; exit 2 ;;
    esac
done

# `git log -n 0` and `-n abc` both print nothing and exit 0, so without this a
# typo silently produced an empty HISTORY section rather than an error.
#
# The arithmetic is deliberately kept off the raw string. Bash reads a
# leading-zero literal as OCTAL, so (( 008 )) is an error ("value too great for
# base") and (( 010 )) is 8 — while git reads -n 010 as ten, so the check and the
# command it guards would disagree about the same input. 10# forces base 10, and
# normalising here also keeps the heading honest ("last 8", not "last 008").
raw_commits=$COMMITS
if ! [[ $raw_commits =~ ^[0-9]+$ ]]; then
    printf 'showgit: -c needs a positive integer (got "%s")\n' "$raw_commits" >&2
    exit 2
fi
# Strip leading zeros before measuring, so "0000000001" is judged as one digit.
digits=$raw_commits
while [[ ${digits:0:1} == 0 && ${#digits} -gt 1 ]]; do digits=${digits:1}; done
if ((${#digits} > 9)); then
    # Guards the arithmetic below: bash integers are 64-bit and would wrap
    # silently on a long enough string. Said plainly, because such a value IS a
    # positive integer — it is just not a plausible number of commits.
    printf 'showgit: -c is unreasonably large (got "%s")\n' "$raw_commits" >&2
    exit 2
fi
COMMITS=$((10#$digits))
if ((COMMITS == 0)); then
    printf 'showgit: -c needs a positive integer (got "%s")\n' "$raw_commits" >&2
    exit 2
fi

if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    printf 'showgit: not inside a git repository (%s)\n' "$PWD" >&2
    exit 1
fi
cd "$(git rev-parse --show-toplevel)"

# Colour and clearing only when we are actually talking to a terminal.
if [[ -t 1 ]]; then
    B=$'\e[1m'; DIM=$'\e[2m'; R=$'\e[0m'
    RED=$'\e[31m'; GRN=$'\e[32m'; YEL=$'\e[33m'; CYA=$'\e[36m'
    COLOUR=always
else
    B=''; DIM=''; R=''; RED=''; GRN=''; YEL=''; CYA=''
    COLOUR=never
    CLEAR=0
fi
if ((CLEAR)); then clear; fi

WIDTH=$(tput cols 2>/dev/null || echo 100)
if ((WIDTH > 150)); then WIDTH=150; fi
if ((WIDTH < 60)); then WIDTH=60; fi

# tr(1) works on bytes, so it cannot paint a multibyte rule character.
rule() { local i s=''; for ((i = 0; i < WIDTH; i++)); do s+='─'; done
         printf '%s%s%s\n' "$DIM" "$s" "$R"; }
head2() { printf '\n%s%s%s%s%s%s\n' "$B" "$1" "$R" "$DIM" "${2:+  $2}" "$R"; }
count() { grep -c "$@" || true; }   # grep exits 1 on no match; 0 is the answer

# ── identity ────────────────────────────────────────────────────────────────
repo=${PWD##*/}
if branch=$(git symbolic-ref --quiet --short HEAD 2>/dev/null); then
    branch_c="${B}${CYA}${branch}${R}"
else
    branch="detached@$(git rev-parse --short HEAD 2>/dev/null || echo '?')"
    branch_c="${RED}${branch}${R}"
fi

if upstream=$(git rev-parse --abbrev-ref --symbolic-full-name '@{upstream}' 2>/dev/null); then
    read -r behind ahead < <(git rev-list --left-right --count "$upstream...HEAD" 2>/dev/null || echo '0 0')
    track="${DIM}→${R} ${upstream}"
    if ((ahead));  then track+="  ${GRN}↑${ahead}${R}"; fi
    if ((behind)); then track+="  ${RED}↓${behind}${R}"; fi
    if ((ahead == 0 && behind == 0)); then track+="  ${DIM}in sync${R}"; fi
else
    track="${DIM}(no upstream)${R}"
fi

printf '%s%s%s %s  %s\n' "$B" "$repo" "$R" "$branch_c" "$track"
if head_line=$(git log -1 --format='%h · last commit %cr by %an' 2>/dev/null); then
    printf '%s%s%s\n' "$DIM" "$head_line" "$R"
elif [[ -n $(git rev-list -n 1 --all 2>/dev/null) ]]; then
    # Unborn branch in a repo that does have history elsewhere — an orphan
    # branch, or a fresh branch not yet committed to. Saying "no commits yet"
    # here would be false about the repo.
    printf '%s%s%s\n' "$DIM" 'unborn branch — nothing committed on it yet' "$R"
else
    printf '%s%s%s\n' "$DIM" 'no commits yet' "$R"
fi

# ── an operation in progress trumps everything else ─────────────────────────
gitdir=$(git rev-parse --git-dir)
op=''
if [[ -d $gitdir/rebase-merge || -d $gitdir/rebase-apply ]]; then op='REBASE'; fi
if [[ -f $gitdir/MERGE_HEAD        ]]; then op='MERGE';       fi
if [[ -f $gitdir/CHERRY_PICK_HEAD  ]]; then op='CHERRY-PICK'; fi
if [[ -f $gitdir/REVERT_HEAD       ]]; then op='REVERT';      fi
if [[ -f $gitdir/BISECT_LOG        ]]; then op='BISECT';      fi
if [[ -n $op ]]; then
    printf '\n%s%s  ** %s in progress — finish or abort it before anything else **%s\n' \
        "$B" "$RED" "$op" "$R"
fi

# ── working tree ────────────────────────────────────────────────────────────
status=$(git status --porcelain=v1 2>/dev/null || true)
if [[ -n $status ]]; then
    # A conflicted path (UU, AA, DU …) is neither staged nor modified — counting
    # it as both, which the naive column test does, hides the one state that
    # actually needs attention.
    # One pass, explicit classes. Doing this with per-class regexes double-counts:
    # a conflict can be AA or AU, whose index column looks like an ordinary
    # staged add, so "subtract the conflicts afterwards" over-subtracts the UU
    # ones that were never counted in the first place.
    read -r conflicted staged unstaged untracked < <(awk '
        /^(DD|AU|UD|UA|DU|AA|UU)/ { c++; next }
        /^\?\?/                   { u++; next }
        /^!!/                     { next }
        { if (substr($0,1,1) != " ") s++
          if (substr($0,2,1) != " ") m++ }
        END { printf "%d %d %d %d\n", c+0, s+0, m+0, u+0 }
    ' <<<"$status")

    summary=''
    if ((conflicted)); then summary+="${RED}${B}${conflicted} conflicted${R}${DIM}  "; fi
    if ((staged));     then summary+="${GRN}${staged} staged${R}${DIM}  "; fi
    if ((unstaged));   then summary+="${YEL}${unstaged} modified${R}${DIM}  "; fi
    if ((untracked));  then summary+="${untracked} untracked"; fi
    head2 'WORKING TREE' "${summary%  }"

    # Index column green, worktree column yellow — the convention `git status -s`
    # uses with colour on. Conflicts are red across both columns.
    awk -v g="$GRN" -v y="$YEL" -v d="$DIM" -v rd="$RED" -v b="$B" -v r="$R" -v lim=15 '
        NR > lim { skipped++; next }
        /^(DD|AU|UD|UA|DU|AA|UU)/ { printf "  %s%s%s%s %s\n", b, rd, substr($0,1,2), r, substr($0,4); next }
        /^\?\?/  { printf "  %s?? %s%s\n", d, substr($0,4), r; next }
        { printf "  %s%s%s%s%s%s %s\n",
                 g, substr($0,1,1), r, y, substr($0,2,1), r, substr($0,4) }
        END { if (skipped) printf "  %s… and %d more%s\n", d, skipped, r }
    ' <<<"$status"
else
    head2 'WORKING TREE' "${GRN}clean${R}"
fi

# ── history ─────────────────────────────────────────────────────────────────
# Rendered FIRST, then checked — rather than predicting whether it will be empty.
# Two rounds of guessing the cause each missed another: `log --all` exits 0 and
# prints nothing when no refs exist; an orphan branch has an unborn HEAD but real
# history elsewhere; and `-n 0` / `-n <not a number>` also print nothing and exit
# 0. Asking the renderer what it produced cannot drift from what it renders.
#
# Truncate the SUBJECT with git's own %<() rather than cut(1): it is aware of
# both colour escapes and multibyte characters, so nothing is sliced in half.
subj=$((WIDTH - 28))
if ((subj < 24)); then subj=24; fi
# --exclude=refs/stash: plain --all drags the stash commits into the graph, which
# is noise here — they get their own section below.
# The sed strips the padding %<() adds after a short subject.
history=$(git -c color.ui=$COLOUR log --graph --exclude=refs/stash --all -n "$COMMITS" \
    --date=format:'%d%b %H:%M' \
    --format="%C(auto)%h%C(reset) %C(dim)%ad%C(reset)%C(auto)%d%C(reset) %<($subj,trunc)%s" \
    2>/dev/null | sed 's/[[:space:]]*$//') || true

if [[ -n $history ]]; then
    head2 'HISTORY' "last $COMMITS across all branches"
    printf '%s\n' "$history"
elif [[ -z $(git rev-list -n 1 --all 2>/dev/null) ]]; then
    head2 'HISTORY' "${DIM}nothing committed yet${R}"
else
    # Commits exist somewhere but none reached the graph. Not a state I can
    # currently produce, so it says what it knows instead of asserting a cause.
    head2 'HISTORY' "${DIM}no commits to show${R}"
fi

# ── branches ────────────────────────────────────────────────────────────────
mapfile -t branches < <(git for-each-ref --sort=-committerdate --format='%(refname:short)' refs/heads)
if ((${#branches[@]} > 1)) || ((ALL)); then
    base=''
    for cand in main master; do
        if git rev-parse --verify --quiet "$cand" >/dev/null 2>&1; then base=$cand; break; fi
    done
    if ((${#branches[@]} == 0)); then
        # -a in a repo with an unborn HEAD: the branch name lives in HEAD but has
        # no ref yet, so for-each-ref reports nothing. Say so, like every other
        # section does, rather than printing a bare heading.
        head2 'BRANCHES' "${DIM}none yet${R}"
    else
        head2 'BRANCHES' "${base:+merge status vs $base}"
        for b in "${branches[@]}"; do
            mark='  '
            if [[ $b == "$branch" ]]; then mark="${GRN}* ${R}"; fi
            state=''
            if [[ -n $base && $b != "$base" ]]; then
                if git merge-base --is-ancestor "$b" "$base" 2>/dev/null; then
                    state="${DIM}merged — safe to delete${R}"
                else
                    state="${YEL}$(git rev-list --count "$base..$b" 2>/dev/null || echo '?') unmerged${R}"
                fi
            fi
            printf '%s%-24s %s%-26s%s %s\n' "$mark" "$b" \
                "$DIM" "$(git log -1 --format='%h %cr' "$b")" "$R" "$state"
        done
    fi
fi

# ── things that usually mean unfinished business ────────────────────────────
stashes=$(git stash list 2>/dev/null || true)
if [[ -n $stashes ]] || ((ALL)); then
    head2 'STASHES' "$([[ -z $stashes ]] && printf '%s%s' "$DIM" "none$R")"
    if [[ -n $stashes ]]; then sed "s/^/  /" <<<"$stashes"; fi
fi

# Anything past the first line is a worktree beyond this checkout.
worktrees=$(git worktree list 2>/dev/null | tail -n +2 || true)
if [[ -n $worktrees ]] || ((ALL)); then
    head2 'WORKTREES' "$([[ -z $worktrees ]] && printf '%s%s' "$DIM" "none besides this one$R")"
    if [[ -n $worktrees ]]; then sed "s/^/  /" <<<"$worktrees"; fi
fi

rule

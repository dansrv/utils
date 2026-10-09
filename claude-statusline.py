#!/usr/bin/env python3
"""claude-statusline: the Claude Code status line, as one tested script.

Claude Code pipes a JSON snapshot of the session to a configured command on
every assistant message (and a few other triggers) and shows whatever the
command prints. This file is that command, plus the installer that points
Claude Code at it. Settings point at this file inside the clone, so
`git pull` updates the line everywhere; nothing is copied.

    claude-statusline render      stdin JSON -> one line (what Claude Code runs)
    claude-statusline install     write the statusLine key into user settings
    claude-statusline uninstall   remove the key (this file stays)
    claude-statusline show        render every fixture, in colour, plus settings
    claude-statusline test        assert every fixture; exit 1 on a mismatch

The line:

    Fable 5.1 (high effort) | ctx 11% | 5h 17% (53m) · 7d 5%

    model      model.display_name, bold cyan
    effort     effort.level, magenta inside dim parentheses
    ctx NN%    context_window.used_percentage, green < 50, bold yellow < 80,
               else bold red; a dim bar precedes it when anything came before
    5h NN%     rate_limits.five_hour.used_percentage, with the time until the
               window resets in parentheses (minutes rounded up, like the
               usage panel: 53m, 1h12m), from rate_limits.five_hour.resets_at
    7d NN%     rate_limits.seven_day.used_percentage
               the two windows are one dim group joined by " · ", led by a
               dim bar when anything came before

Rules: a part whose source is absent, null or the wrong type is omitted, never
shown as a placeholder. Percentages round half up. Bad or empty stdin prints
nothing and exits 0 (Claude Code then shows a blank line, which beats a
traceback in the bar). No subprocesses, no file reads beyond stdin: the script
runs on every message, so it must stay in the low milliseconds.

Payload reference: https://code.claude.com/docs/en/statusline
"""
import json
import os
import shlex
import subprocess
import sys
import tempfile
import time

__version__ = "1.0.0"

RST = "\033[0m"
DIM = "\033[2m"
BCYN = "\033[1;36m"
MAG = "\033[35m"
GRN = "\033[32m"
BYLW = "\033[1;33m"
BRED = "\033[1;31m"


# --------------------------------------------------------------------------- render

def get(d, *keys):
    for k in keys:
        d = d.get(k) if isinstance(d, dict) else None
    return d


def num(x):
    """float, or None for null / non-numeric. Booleans are not numbers here."""
    if isinstance(x, bool):
        return None
    try:
        return float(x)
    except (TypeError, ValueError):
        return None


def pct(x):
    """Whole percent, rounded half up."""
    return str(int(x + 0.5)) + "%"


def countdown(seconds):
    """Minutes remaining, rounded up, as 53m or 1h12m. Empty when nothing remains."""
    if seconds <= 0:
        return ""
    m = -int(-seconds // 60)
    return str(m) + "m" if m < 60 else str(m // 60) + "h" + str(m % 60) + "m"


def sep(parts):
    """The dim bar that leads a part when something rendered before it."""
    return DIM + "| " + RST if parts else ""


def render(data, now=None):
    """The status line for one payload, ANSI included; "" when nothing applies."""
    if not isinstance(data, dict):
        return ""
    now = time.time() if now is None else now
    parts = []

    model = get(data, "model", "display_name")
    if isinstance(model, str) and model.strip():
        parts.append(BCYN + model + RST)

    effort = get(data, "effort", "level")
    if isinstance(effort, str) and effort.strip():
        parts.append(DIM + "(" + RST + MAG + effort + RST + DIM + " effort)" + RST)

    ctx = num(get(data, "context_window", "used_percentage"))
    if ctx is not None:
        color = GRN if ctx < 50 else BYLW if ctx < 80 else BRED
        parts.append(sep(parts) + "ctx " + color + pct(ctx) + RST)

    items = []
    sess = num(get(data, "rate_limits", "five_hour", "used_percentage"))
    if sess is not None:
        item = "5h " + pct(sess)
        reset = num(get(data, "rate_limits", "five_hour", "resets_at"))
        left = countdown(reset - now) if reset is not None else ""
        if left:
            item += " (" + left + ")"
        items.append(item)
    week = num(get(data, "rate_limits", "seven_day", "used_percentage"))
    if week is not None:
        items.append("7d " + pct(week))
    if items:
        parts.append(DIM + ("| " if parts else "") + " · ".join(items) + RST)  # one dim run, bar included

    return " ".join(parts)


def cmd_render():
    try:
        data = json.load(sys.stdin)
    except Exception:
        return 0
    line = render(data)
    if line:
        print(line)
    return 0


# --------------------------------------------------------------------------- settings

def settings_path():
    base = os.environ.get("CLAUDE_CONFIG_DIR") or os.path.join(os.path.expanduser("~"), ".claude")
    return os.path.join(base, "settings.json")


def load_settings(path):
    if not os.path.exists(path):
        return {}
    with open(path, encoding="utf-8") as f:
        text = f.read()
    if not text.strip():
        return {}
    obj = json.loads(text)  # a parse error propagates: never overwrite what we cannot read
    if not isinstance(obj, dict):
        raise ValueError("settings.json is not a JSON object")
    return obj


def save_settings(path, obj):
    """Write atomically, keeping key order and Claude Code's indent."""
    os.makedirs(os.path.dirname(path), exist_ok=True)
    fd, tmp = tempfile.mkstemp(prefix=".settings.", suffix=".tmp", dir=os.path.dirname(path))
    try:
        with os.fdopen(fd, "w", encoding="utf-8") as f:
            json.dump(obj, f, indent=2, ensure_ascii=False)
            f.write("\n")
        os.replace(tmp, path)
    except BaseException:
        try:
            os.unlink(tmp)
        except OSError:
            pass
        raise


def status_line_command():
    """The command Claude Code will run: this interpreter, this file, absolute, quoted."""
    return " ".join(shlex.quote(p) for p in (sys.executable, os.path.realpath(__file__), "render"))


def cmd_install(dry_run):
    path = settings_path()
    try:
        settings = load_settings(path)
    except (ValueError, json.JSONDecodeError) as e:
        print("ABORT: cannot parse " + path + ": " + str(e) + "; nothing written", file=sys.stderr)
        return 2
    previous = settings.get("statusLine")
    wanted = {"type": "command", "command": status_line_command()}
    same = previous == wanted
    print("settings=" + path)
    print("command=" + wanted["command"])
    print("previous=" + (json.dumps(previous.get("command")) if isinstance(previous, dict) else "none"))
    if dry_run or same:
        print("written=0" + (" (unchanged)" if same else " (dry run)"))
    else:
        settings["statusLine"] = wanted
        save_settings(path, settings)
        print("written=1")
    if isinstance(previous, dict) and not same and "statusline-command.sh" in str(previous.get("command", "")):
        print("note: the old script " + str(previous.get("command")).split()[-1] + " is no longer used; delete it when ready")
    print("takes effect at the next assistant message in a running session; new sessions use it from the start")
    return 0


def cmd_uninstall():
    path = settings_path()
    try:
        settings = load_settings(path)
    except (ValueError, json.JSONDecodeError) as e:
        print("ABORT: cannot parse " + path + ": " + str(e) + "; nothing written", file=sys.stderr)
        return 2
    print("settings=" + path)
    if "statusLine" not in settings:
        print("written=0 (no statusLine key)")
        return 0
    del settings["statusLine"]
    save_settings(path, settings)
    print("written=1 (statusLine removed; this file is untouched)")
    return 0


# --------------------------------------------------------------------------- fixtures

NOW = 1_700_000_000  # fixed clock for the fixtures; `show` uses the real one


def _payload(ctx=11, sess=17, reset=NOW + 3180, week=5, model="Fable 5.1", effort="high"):
    d = {"model": {"display_name": model}, "effort": {"level": effort},
         "context_window": {"used_percentage": ctx, "remaining_percentage": None if ctx is None else 100 - ctx},
         "cost": {"total_cost_usd": 0.5, "total_duration_ms": 90000, "total_api_duration_ms": 30000}}
    if sess is not None or week is not None:
        d["rate_limits"] = {}
        if sess is not None:
            d["rate_limits"]["five_hour"] = {"used_percentage": sess, "resets_at": reset}
        if week is not None:
            d["rate_limits"]["seven_day"] = {"used_percentage": week, "resets_at": NOW + 300000}
    return d


FIXTURES = [
    # name, payload, expected visible text (ANSI stripped)
    ("full",            _payload(),                                   "Fable 5.1 (high effort) | ctx 11% | 5h 17% (53m) · 7d 5%"),
    ("reset-over-hour", _payload(reset=NOW + 4320),                   "Fable 5.1 (high effort) | ctx 11% | 5h 17% (1h12m) · 7d 5%"),
    ("reset-last-min",  _payload(reset=NOW + 45),                     "Fable 5.1 (high effort) | ctx 11% | 5h 17% (1m) · 7d 5%"),
    ("reset-passed",    _payload(reset=NOW - 10),                     "Fable 5.1 (high effort) | ctx 11% | 5h 17% · 7d 5%"),
    ("reset-absent",    _payload(reset=None),                         "Fable 5.1 (high effort) | ctx 11% | 5h 17% · 7d 5%"),
    ("ctx-warn",        _payload(ctx=62.5),                           "Fable 5.1 (high effort) | ctx 63% | 5h 17% (53m) · 7d 5%"),
    ("ctx-crit",        _payload(ctx=91),                             "Fable 5.1 (high effort) | ctx 91% | 5h 17% (53m) · 7d 5%"),
    ("first-call",      _payload(ctx=None, sess=None, week=None),     "Fable 5.1 (high effort)"),
    ("compacted",       _payload(ctx=None),                           "Fable 5.1 (high effort) | 5h 17% (53m) · 7d 5%"),
    ("no-limits",       _payload(sess=None, week=None),               "Fable 5.1 (high effort) | ctx 11%"),
    ("week-only",       _payload(sess=None),                          "Fable 5.1 (high effort) | ctx 11% | 7d 5%"),
    ("no-effort",       _payload(effort=None),                        "Fable 5.1 | ctx 11% | 5h 17% (53m) · 7d 5%"),
    ("ctx-only",        {"context_window": {"used_percentage": 11}},  "ctx 11%"),
    ("wrong-types",     {"model": {"display_name": " "}, "context_window": {"used_percentage": "lots"},
                         "rate_limits": {"five_hour": {"used_percentage": True}}}, ""),
    ("not-an-object",   [1, 2, 3],                                    ""),
]


def strip_ansi(s):
    import re
    return re.sub(r"\x1b\[[0-9;]*m", "", s)


def cmd_show():
    path = settings_path()
    try:
        current = load_settings(path).get("statusLine")
    except Exception as e:
        current = "unreadable: " + str(e)
    print("settings=" + path)
    print("statusLine=" + json.dumps(current))
    print("this=" + status_line_command())
    print()
    width = max(len(n) for n, _, _ in FIXTURES)
    for name, payload, _ in FIXTURES:
        print(name.ljust(width) + "  " + render(payload, now=NOW))
    return 0


def cmd_test():
    failed = 0
    for name, payload, expected in FIXTURES:
        got = strip_ansi(render(payload, now=NOW))
        ok = got == expected
        failed += not ok
        print(("ok    " if ok else "FAIL  ") + name + ("" if ok else "\n      want: " + expected + "\n      got:  " + got))
    # every ANSI run must be closed: the line never ends on an open colour
    for name, payload, _ in FIXTURES:
        line = render(payload, now=NOW)
        if line and not line.endswith(RST):
            failed += 1
            print("FAIL  " + name + ": line does not end with reset")
    # the real entry point on bad input: exit 0, no output
    for name, stdin in (("garbage", b"not json"), ("empty", b""), ("array", b"[1]")):
        r = subprocess.run([sys.executable, os.path.realpath(__file__), "render"],
                           input=stdin, capture_output=True, timeout=10)
        ok = r.returncode == 0 and r.stdout == b""
        failed += not ok
        print(("ok    " if ok else "FAIL  ") + "stdin-" + name + ("" if ok else ": exit %d out %r" % (r.returncode, r.stdout)))
    # the real entry point on the full fixture, live clock
    r = subprocess.run([sys.executable, os.path.realpath(__file__), "render"],
                       input=json.dumps(_payload(reset=int(time.time()) + 3180)).encode(), capture_output=True, timeout=10)
    got = strip_ansi(r.stdout.decode().rstrip("\n"))
    ok = r.returncode == 0 and got == FIXTURES[0][2]
    failed += not ok
    print(("ok    " if ok else "FAIL  ") + "stdin-full" + ("" if ok else ": got " + got))
    # the ~/.claude/settings.json edit, in a throwaway config dir
    with tempfile.TemporaryDirectory() as tmp:
        env = dict(os.environ, CLAUDE_CONFIG_DIR=tmp)
        p = os.path.join(tmp, "settings.json")
        with open(p, "w") as f:
            f.write('{\n  "model": "fable",\n  "statusLine": {\n    "type": "command",\n    "command": "bash /x/statusline-command.sh"\n  },\n  "theme": "dark"\n}\n')
        me = [sys.executable, os.path.realpath(__file__)]
        subprocess.run(me + ["install"], env=env, capture_output=True, check=True)
        after = json.load(open(p))
        ok = (list(after) == ["model", "statusLine", "theme"] and after["model"] == "fable" and after["theme"] == "dark"
              and after["statusLine"] == {"type": "command", "command": status_line_command()})
        failed += not ok
        print(("ok    " if ok else "FAIL  ") + "install keeps other keys and order" + ("" if ok else ": " + json.dumps(after)))
        r = subprocess.run(me + ["install"], env=env, capture_output=True, text=True)
        ok = "written=0 (unchanged)" in r.stdout
        failed += not ok
        print(("ok    " if ok else "FAIL  ") + "install twice is unchanged")
        subprocess.run(me + ["uninstall"], env=env, capture_output=True, check=True)
        after = json.load(open(p))
        ok = list(after) == ["model", "theme"]
        failed += not ok
        print(("ok    " if ok else "FAIL  ") + "uninstall removes only the key")
        with open(p, "w") as f:
            f.write("{ not json")
        r = subprocess.run(me + ["install"], env=env, capture_output=True, text=True)
        ok = r.returncode == 2 and open(p).read() == "{ not json"
        failed += not ok
        print(("ok    " if ok else "FAIL  ") + "install refuses an unparsable settings file")
        os.unlink(p)
        subprocess.run(me + ["install"], env=env, capture_output=True, check=True)
        ok = list(json.load(open(p))) == ["statusLine"]
        failed += not ok
        print(("ok    " if ok else "FAIL  ") + "install creates a missing settings file")
    # the bash wrapper reached through a symlink, as install.sh links it into ~/.local/bin
    wrapper = os.path.join(os.path.dirname(os.path.realpath(__file__)), "claude-statusline.sh")
    if os.name != "nt" and os.path.exists(wrapper):
        with tempfile.TemporaryDirectory() as tmp:
            os.makedirs(os.path.join(tmp, "a", "b"))
            links = {"absolute": wrapper, "relative": os.path.relpath(wrapper, os.path.join(tmp, "a", "b"))}
            for kind, target in links.items():
                link = os.path.join(tmp, "a", "b", "cs-" + kind)
                os.symlink(target, link)
                r = subprocess.run([link, "show"], capture_output=True, text=True, timeout=10, cwd=tmp)
                ok = r.returncode == 0 and "this=" in r.stdout
                failed += not ok
                print(("ok    " if ok else "FAIL  ") + "wrapper via " + kind + " symlink" + ("" if ok else ": " + r.stderr.strip()))
    print("failed: %d" % failed)
    return 1 if failed else 0


# --------------------------------------------------------------------------- main

def main(argv):
    cmd = argv[1] if len(argv) > 1 else "render"
    if cmd == "render":
        return cmd_render()
    if cmd == "install":
        return cmd_install(dry_run="--dry-run" in argv[2:])
    if cmd == "uninstall":
        return cmd_uninstall()
    if cmd == "show":
        return cmd_show()
    if cmd == "test":
        return cmd_test()
    if cmd in ("-h", "--help", "help"):
        print(__doc__.strip())
        return 0
    print("claude-statusline: unknown command " + cmd + " (render | install [--dry-run] | uninstall | show | test)", file=sys.stderr)
    return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv))

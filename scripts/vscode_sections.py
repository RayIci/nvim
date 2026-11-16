#!/usr/bin/env python3
"""Generate VS Code keybindings that step between the sections of a view container.

VS Code has no "focus next/previous section" command, and no command or API can
read which section is focused or which ones are collapsed. The only way to get
<C-j>/<C-k> between sections (Changes / Graph, SQLTools' Connections / Bookmarks /
Query History, Variables / Watch / Call Stack, ...) is one keybinding per pair of
sections, guarded by `focusedView` and `view.<id>.visible`. This script writes
those rules into a marked block of keybindings.json:

    // BEGIN generated sections
    // END generated sections

Sources:
  * built-in containers (Explorer, Source Control, Run and Debug, Testing): the
    BUILTIN table below. Some built-in sections have a focus command that isn't
    `<id>.focus`; the table names it, and the script checks the names against the
    installed VS Code so a renamed command fails loudly instead of silently.
  * every installed extension (WSL remote, Windows local and VS Code's built-in
    extensions): contributes.views / contributes.viewsContainers in package.json.

Sidebar containers get <C-j>/<C-k>; panel containers (sections side by side) get
<C-l>/<C-h>. Webview sections are skipped: keys can't reliably leave a webview.
Order is each container's default order; sections dragged elsewhere aren't seen.

Usage:  scripts/vscode_sections.py            write keybindings.json
        scripts/vscode_sections.py --dry-run  print the block, write nothing
Re-run after installing or removing an extension, or after a VS Code update.
"""

from __future__ import annotations

import argparse
import datetime
import glob
import json
import os
import re
import shutil
import sys

BEGIN = "// BEGIN generated sections"
END = "// END generated sections"

# Built-in containers: (view id, focus command or None for `<id>.focus`), top to bottom.
BUILTIN: dict[str, list[tuple[str, str | None]]] = {
    "explorer": [
        ("workbench.explorer.openEditorsView", "workbench.files.action.focusOpenEditorsView"),
        ("workbench.explorer.fileView", "workbench.explorer.fileView.focus"),
        ("outline", "outline.focus"),
        ("timeline", None),
    ],
    "scm": [
        ("workbench.scm.repositories", None),
        ("workbench.scm", None),
        ("workbench.scm.history", None),
    ],
    "debug": [
        ("workbench.debug.variablesView", "workbench.debug.action.focusVariablesView"),
        ("workbench.debug.watchExpressionsView", "workbench.debug.action.focusWatchView"),
        ("workbench.debug.callStackView", "workbench.debug.action.focusCallStackView"),
        ("workbench.debug.loadedScriptsView", None),
        ("workbench.debug.breakPointsView", "workbench.debug.action.focusBreakpointsView"),
    ],
    "test": [
        ("workbench.view.testing", None),
        ("workbench.view.testCoverage", None),
    ],
    "remote": [],
}
# focusCommand overrides in VS Code that aren't sidebar sections we chain.
IGNORED_OVERRIDES = {"workbench.action.focusCommentsPanel"}

# Per-view `when` for leaving it, when not plain `!inputFocus`. Changes: its list
# goes up to the commit box (hand-written rule), so stepping up leaves from the box.
UP_WHEN = {"workbench.scm": "inputFocus"}

# Containers whose own focus lands outside any section (Run and Debug focuses its
# start button): <C-j> / j from there go to the topmost open section.
ENTRY = {"debug": "activeViewlet == 'workbench.view.debug'"}

NAV = {"sidebar": ("ctrl+j", "ctrl+k"), "panel": ("ctrl+l", "ctrl+h")}


def windows_users() -> list[str]:
    return sorted(glob.glob("/mnt/c/Users/*/"))


def find_keybindings() -> str:
    for user in windows_users():
        path = os.path.join(user, "AppData/Roaming/Code/User/keybindings.json")
        if os.path.isfile(path):
            return path
    return os.path.expanduser("~/.config/Code/User/keybindings.json")


def find_vscode_app() -> str | None:
    """The newest VS Code install's resources/app (Windows install, seen from WSL)."""
    apps = []
    for user in windows_users():
        apps += glob.glob(os.path.join(user, "AppData/Local/Programs/Microsoft VS Code/*/resources/app"))
    apps += glob.glob("/mnt/c/Program Files/Microsoft VS Code/*/resources/app")
    apps += glob.glob("/usr/share/code/resources/app")
    apps = [a for a in apps if os.path.isfile(os.path.join(a, "out/vs/workbench/workbench.desktop.main.js"))]
    return max(apps, key=os.path.getmtime) if apps else None


def extension_dirs(app: str | None) -> list[str]:
    dirs = [os.path.expanduser("~/.vscode-server/extensions")]
    dirs += [os.path.join(u, ".vscode/extensions") for u in windows_users()]
    if app:
        dirs.append(os.path.join(app, "extensions"))
    return [d for d in dirs if os.path.isdir(d)]


def version_key(v: str) -> tuple[int, ...]:
    return tuple(int(x) for x in re.findall(r"\d+", v)[:4])


def load_extensions(dirs: list[str]) -> list[dict]:
    """Newest copy of each installed extension, skipping uninstalled (.obsolete) ones."""
    best: dict[str, dict] = {}
    for d in dirs:
        try:
            with open(os.path.join(d, ".obsolete"), encoding="utf-8") as f:
                obsolete = set(json.load(f))
        except (OSError, ValueError):
            obsolete = set()
        for pkg in glob.glob(os.path.join(d, "*/package.json")):
            if os.path.basename(os.path.dirname(pkg)) in obsolete:
                continue
            try:
                with open(pkg, encoding="utf-8-sig") as f:
                    j = json.load(f)
            except (OSError, ValueError):
                continue
            if not j.get("contributes", {}).get("views"):
                continue
            key = f"{j.get('publisher', '')}.{j.get('name', '')}".lower()
            if key not in best or version_key(j.get("version", "")) > version_key(best[key].get("version", "")):
                best[key] = j
    return [best[k] for k in sorted(best)]


def check_builtin(app: str | None) -> list[str]:
    """Check BUILTIN's focus commands and view ids against the installed VS Code."""
    if not app:
        return ["VS Code install not found: built-in focus commands not checked"]
    with open(os.path.join(app, "out/vs/workbench/workbench.desktop.main.js"), encoding="utf-8") as f:
        js = f.read()
    overrides = set(re.findall(r'focusCommand:\{id:"([^"]+)"', js))
    problems, warnings = [], []
    used = set()
    for views in BUILTIN.values():
        for view_id, cmd in views:
            if f'"{view_id}"' not in js:
                warnings.append(f"built-in view {view_id!r} not found in VS Code (renamed or removed?)")
            if cmd and cmd != f"{view_id}.focus":
                used.add(cmd)
                if cmd not in overrides:
                    problems.append(f"focus command {cmd!r} for {view_id!r} doesn't exist in VS Code")
    for cmd in sorted(overrides - used - IGNORED_OVERRIDES):
        if cmd.endswith(".focus") and any(cmd == f"{v}.focus" for vs in BUILTIN.values() for v, _ in vs):
            continue
        warnings.append(f"VS Code has a custom focus command {cmd!r} not in BUILTIN: check its view")
    if problems:
        sys.exit("error: " + "\n       ".join(problems) + "\nFix BUILTIN in " + __file__)
    return warnings


def collect(extensions: list[dict]) -> tuple[dict[str, list[tuple[str, str]]], dict[str, str]]:
    """Container id -> [(view id, focus command)], container id -> 'sidebar' | 'panel'."""
    location = {c: "sidebar" for c in BUILTIN}
    owned: dict[str, list[tuple[str, str]]] = {}
    guests: dict[str, list[tuple[str, str]]] = {}
    for ext in extensions:
        contributes = ext["contributes"]
        mine = set()
        for where, containers in (contributes.get("viewsContainers") or {}).items():
            for c in containers:
                mine.add(c["id"])
                location[c["id"]] = "panel" if where == "panel" else "sidebar"
        for container, views in contributes["views"].items():
            trees = [(v["id"], f"{v['id']}.focus") for v in views if v.get("type", "tree") == "tree" and v.get("id")]
            # The container's own extension orders its views first (as VS Code does).
            (owned if container in mine else guests).setdefault(container, []).extend(trees)
    sections = {c: [(v, cmd or f"{v}.focus") for v, cmd in views] for c, views in BUILTIN.items()}
    for container in list(owned) + list(guests):
        sections.setdefault(container, [])
    for container in sections:
        sections[container] += owned.get(container, []) + guests.get(container, [])
    return sections, location


def rule(key: str, cmd: str, when: str) -> str:
    return f'  {{ "key": "{key}", "command": "{cmd}", "when": "{when}" }},'


def generate(sections: dict[str, list[tuple[str, str]]], location: dict[str, str]) -> list[str]:
    out = []
    for container in sorted(sections, key=lambda c: (c not in BUILTIN, c)):
        views = sections[container]
        if len(views) < 2:
            continue
        where = location.get(container, "sidebar")
        down, up = NAV[where]
        out.append(f"  // {container} ({where}): " + " > ".join(v for v, _ in views))
        for i, (src, _) in enumerate(views):
            leave_down = f"focusedView == '{src}' && !inputFocus"
            leave_up = f"focusedView == '{src}' && {UP_WHEN.get(src, '!inputFocus')}"
            # Later rules win: list the farthest section first so the nearest open one wins.
            for tgt, cmd in reversed(views[i + 1:]):
                out.append(rule(down, cmd, f"{leave_down} && view.{tgt}.visible"))
            for tgt, cmd in views[:i]:
                out.append(rule(up, cmd, f"{leave_up} && view.{tgt}.visible"))
        if container in ENTRY:
            base = f"sideBarFocus && {ENTRY[container]} && focusedView == '' && !inputFocus && !listFocus"
            for key in (down, "j"):
                for tgt, cmd in reversed(views):
                    out.append(rule(key, cmd, f"{base} && view.{tgt}.visible"))
    return out


def splice(text: str, block: list[str]) -> str:
    lines = text.split("\n")
    starts = [i for i, l in enumerate(lines) if l.strip() == BEGIN]
    ends = [i for i, l in enumerate(lines) if l.strip() == END]
    if len(starts) != 1 or len(ends) != 1 or ends[0] < starts[0]:
        sys.exit(f"error: keybindings.json needs exactly one '{BEGIN}' ... '{END}' pair")
    return "\n".join(lines[: starts[0] + 1] + block + lines[ends[0] :])


def main() -> None:
    p = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    p.add_argument("--keybindings", default=None, help="keybindings.json (default: found under /mnt/c/Users)")
    p.add_argument("--dry-run", action="store_true", help="print the generated block, write nothing")
    args = p.parse_args()

    app = find_vscode_app()
    warnings = check_builtin(app)
    sections, location = collect(load_extensions(extension_dirs(app)))
    block = generate(sections, location)
    for w in warnings:
        print(f"warning: {w}", file=sys.stderr)

    if args.dry_run:
        print("\n".join(block))
        return
    path = args.keybindings or find_keybindings()
    with open(path, encoding="utf-8") as f:
        old = f.read()
    new = splice(old, block)
    if new == old:
        print(f"{path}: up to date")
        return
    backup = os.path.join(os.path.dirname(path), f"_backup_{datetime.date.today()}_pre-sections")
    if not os.path.exists(backup):
        os.makedirs(backup)
        shutil.copy2(path, backup)
    with open(path, "w", encoding="utf-8", newline="\n") as f:
        f.write(new)
    rules = sum(1 for l in block if l.lstrip().startswith("{"))
    containers = sum(1 for l in block if l.lstrip().startswith("//"))
    print(f"{path}: {rules} rules for {containers} containers")


if __name__ == "__main__":
    main()

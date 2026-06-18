#!/usr/bin/env python3
"""Verify every Remotes.Events.X referenced in the codebase is declared.

Reads src/ReplicatedStorage/Remotes.lua, extracts the quoted strings inside
the `local Events = { ... }` literal, then walks every other .lua file
collecting `Remotes.Events.<Name>` references. Fails loudly if anything is
referenced but not declared. Exits 0 on success, 1 on a mismatch.
"""
from __future__ import annotations
import pathlib
import re
import sys


def declared_events(path: str) -> set[str]:
    text = pathlib.Path(path).read_text()
    # Find `local Events = {` and walk forward counting braces so we stop at
    # the matching `}` and not at a `}` inside a comment.
    start = re.search(r"local\s+Events\s*=\s*\{", text)
    if not start:
        print(f"::error file={path}::Could not find 'local Events = {{' header")
        sys.exit(1)
    i = start.end()
    depth = 1
    while i < len(text) and depth > 0:
        c = text[i]
        if c == "{":
            depth += 1
        elif c == "}":
            depth -= 1
        i += 1
    body = text[start.end(): i - 1]
    return set(re.findall(r'"([A-Z][A-Za-z0-9]+)"', body))


def referenced_events(root: str) -> set[str]:
    out: set[str] = set()
    for p in pathlib.Path(root).rglob("*.lua"):
        if p.name == "Remotes.lua":
            continue
        for m in re.finditer(r"Remotes\.Events\.([A-Z][A-Za-z0-9]+)", p.read_text()):
            out.add(m.group(1))
    return out


def main() -> int:
    declared = declared_events("src/ReplicatedStorage/Remotes.lua")
    used = referenced_events("src")

    missing = sorted(used - declared)
    if missing:
        print("::error::These Remotes.Events.* are referenced but not declared in Remotes.lua:")
        for name in missing:
            print(f"  - {name}")
        return 1

    print(f"OK — {len(declared)} events declared, {len(used)} referenced; all resolve.")
    return 0


if __name__ == "__main__":
    sys.exit(main())

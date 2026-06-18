#!/usr/bin/env python3
"""Cross-file id consistency check.

Verifies that every monster SpeciesId and item ItemId / reward Id referenced
from LootData and QuestData is actually defined in MonsterData / ItemData.

Run from the repo root. Exits 0 on success, 1 if unknown ids are found.
"""
from __future__ import annotations
import pathlib
import re
import sys


def ids_from(path: str) -> set[str]:
    return set(re.findall(r'Id\s*=\s*"([^"]+)"', pathlib.Path(path).read_text()))


def main() -> int:
    monsters = ids_from("src/ReplicatedStorage/Modules/MonsterData.lua")
    items = ids_from("src/ReplicatedStorage/Modules/ItemData.lua")
    bad: list[str] = []

    # LootData: every Kind="Item" / "Monster" line has an Id referencing ItemData / MonsterData.
    loot_path = "src/ReplicatedStorage/Modules/LootData.lua"
    for line_no, line in enumerate(pathlib.Path(loot_path).read_text().splitlines(), 1):
        if 'Kind = "Item"' in line:
            m = re.search(r'Id\s*=\s*"([^"]+)"', line)
            if m and m.group(1) not in items:
                bad.append(f"{loot_path}:{line_no}: unknown item '{m.group(1)}'")
        if 'Kind = "Monster"' in line:
            m = re.search(r'Id\s*=\s*"([^"]+)"', line)
            if m and m.group(1) not in monsters:
                bad.append(f"{loot_path}:{line_no}: unknown monster '{m.group(1)}'")

    # QuestData: SpeciesId on CatchSpecies, ItemId on HaveItem, plus reward Items lists.
    qd_path = "src/ReplicatedStorage/Modules/QuestData.lua"
    qd = pathlib.Path(qd_path).read_text()
    for m in re.finditer(r'SpeciesId\s*=\s*"([^"]+)"', qd):
        if m.group(1) not in monsters:
            line = qd[: m.start()].count("\n") + 1
            bad.append(f"{qd_path}:{line}: unknown species '{m.group(1)}'")
    for m in re.finditer(r'ItemId\s*=\s*"([^"]+)"', qd):
        if m.group(1) not in items:
            line = qd[: m.start()].count("\n") + 1
            bad.append(f"{qd_path}:{line}: unknown item '{m.group(1)}'")
    # Reward item ids always appear as { Id = "...", Count = N } — the Count
    # key is the unique marker that tells us we're looking at a reward / item
    # stack rather than a quest / npc / objective definition.
    for m in re.finditer(r'\{\s*Id\s*=\s*"([^"]+)"\s*,\s*Count\s*=\s*\d+', qd):
        if m.group(1) not in items:
            line = qd[: m.start()].count("\n") + 1
            bad.append(f"{qd_path}:{line}: unknown reward item '{m.group(1)}'")

    if bad:
        print("::error::Unknown id references:")
        for b in bad:
            print(b)
        return 1

    print(f"OK — {len(monsters)} monsters, {len(items)} items; every id reference resolves.")
    return 0


if __name__ == "__main__":
    sys.exit(main())

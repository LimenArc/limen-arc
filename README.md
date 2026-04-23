# Monster Realm — Open-World Roblox Game

A Pokémon-style open-world Roblox game: explore a procedurally-populated map,
catch 30 different monsters with traps, battle them in real time, buy & sell
gear at a central market, and flip on a developer/mod menu for god-mode-style
testing.

## Running it

This project is laid out for [Rojo](https://rojo.space). From the repo root:

```
rojo serve default.project.json
```

Then open Roblox Studio and connect the Rojo plugin. A fresh place file works —
Rojo will populate it from `src/`.

## What's in the box

| Area | Files |
| --- | --- |
| World generation — biomes, caves, cabins, camps, market plaza | `src/ServerScriptService/WorldBuilder.server.lua` |
| 30 monster species (fire / water / grass / electric / rock / ground / psychic / dark / ice / ghost / flying / dragon mixes) | `src/ReplicatedStorage/Modules/MonsterData.lua` |
| Monster spawning tied to biome | `src/ServerScriptService/MonsterSpawner.server.lua` |
| Weapons, traps, consumables, market catalog | `src/ReplicatedStorage/Modules/ItemData.lua`, `MarketData.lua` |
| Real-time combat + trap capture | `src/ServerScriptService/CombatHandler.server.lua`, `TrapHandler.server.lua` |
| Backpack / inventory | `src/ReplicatedStorage/Modules/Inventory.lua`, `src/StarterGui/BackpackGui.client.lua` |
| Market (buy/sell) | `src/ServerScriptService/MarketHandler.server.lua`, `src/StarterGui/MarketGui.client.lua` |
| Mod menu (18 toggles) — speed, god mode, infinite stamina, ESP, noclip, infinite money, auto-catch, spawn-any-monster, day/night, weather, time-scale, damage mult, etc. | `src/ServerScriptService/ModMenuHandler.server.lua`, `src/StarterGui/ModMenuGui.client.lua` |

## Mod menu options

Toggle with `M`. Implemented flags:

1.  God mode
2.  Infinite stamina
3.  Speed hack (configurable multiplier)
4.  Jump boost
5.  No-clip
6.  Infinite money
7.  Instant capture
8.  Auto-catch nearby monster
9.  Damage multiplier
10. ESP — monsters (highlights through walls)
11. ESP — loot / chests
12. X-ray caves
13. Teleport to waypoint
14. Spawn any monster (picker)
15. Instant level up caught monsters
16. Weather control (clear / rain / storm / snow)
17. Time-of-day slider
18. Time-scale (fast/slow world)

The mod menu uses a server-side allow-list (`Config.ModMenuAllowedUserIds`) so
normal players can't turn it on — set your own UserId in
`src/ReplicatedStorage/Modules/GameConfig.lua` before publishing.

## Notes

- Map is procedurally built on server start, then persisted for the session.
  Regenerate by restarting the server.
- All monster/item data lives in ModuleScripts so you can add more without
  touching systems.
- Persistence uses `DataStoreService`. In Studio, enable
  "Allow HTTP Requests" + "Enable Studio Access to API Services" for saves to
  round-trip.

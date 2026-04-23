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

## Story: The Mire Plague

Long before, the Archipelago of Aethel was peopled. A pale fog drifted from a
cave no one remembered digging; anyone who breathed it turned into one of the
30 monster species. You are one of the few still-human survivors, answering the
scholars' beacon. Catch what the infected became, trade with who's left, and
choose how the plague ends.

Source: `Modules/QuestData.lua` (story, NPCs, 13 quests, 4 endings).

### The four endings

| Ending | Trigger |
| --- | --- |
| **The Cure** | Collect all 4 map fragments (from lucky blocks), talk to the Envoy at the last cave. |
| **The Warden's Pact** | Discover all 30 species, complete *The Compendium* with Elin. |
| **Ashes** | Refuse the cure — defeat 40 wild monsters, complete *Ashes* with the Envoy. |
| **Dominion** | Accumulate 10,000 lifetime coins after accepting *Dominion* from Tavi. |

Each ending plays a full-screen cutscene with tinted typography and writes
`EndingAchieved` to the player's save.

### NPCs

- **Tavi** (market, east stall) — offers the Beacon, Merchant's Muscle, and the
  Dominion hint.
- **Sagewind** (market, west stall) — starter healer, offers *First Catch*.
- **Marla** (first camp) — wants a Frostkit.
- **Bren** (first cabin) — the Last Farmer, wants 3 Sprout Cubs.
- **Elin** (first cave) — sealed scholar, offers the Census, Compendium,
  Fragment Hunt, Dark Count, and Cartographer quests.
- **Envoy at the Heart** (last cave, near a boss Boulderion named "Heart of the
  Mire") — the Cure and Ashes choice-point.

### Quest journal

Press `J` or tap the purple **QUEST** button to open the journal. Active and
completed quests appear with live objective progress. Dialogue panels open
automatically when you walk up to an NPC's proximity prompt.

## Lakes, rivers, boats

`WorldBuilder` lays down 4 lakes with sandy beaches and a meandering river from
each lake to the ocean edge. Every lake gets a wooden dock and a boat; 2 extra
boats sit on the ocean shore. Boats are `VehicleSeat` hulls — sit to drive,
WASD to steer (or the on-screen joystick on mobile). See
`BoatHandler.server.lua`.

## Chests & lucky blocks

- **Chests** spawn at every camp, cabin, and cave — ProximityPrompt "Open",
  rolls from `LootData.Chest` (coins, potions, traps, occasional weapon).
  Consumed on open.
- **Lucky blocks** are 40 glowing gold cubes scattered across the map with a
  floating `?` and a slow spin. Rolls from `LootData.LuckyBlock`: jackpot
  rewards (master trap, enchanted blade, rare monsters, big coin pots),
  mid-tier consumables, and a few duds (minor coin theft / teleport to spawn).
  Respawn 3 minutes after being opened.

See `LootHandler.server.lua` and `Modules/LootData.lua`.

## Trading

Press `T` (or tap the green **TRADE** button) near another player to send a
trade request. Accept/decline prompt slides down at the top. Sessions are
proximity-gated (32 studs), require both sides to **Lock** their offers, then
both sides to **Confirm**. Items and monsters are swapped atomically; server
re-validates against live inventory before applying, so swap-baiting fails.

`TradeHandler.server.lua` · `TradeGui.client.lua`

## Android / mobile support

The game is designed to run on Android Roblox. Every keyboard shortcut has a
touch equivalent:

| Key | Mobile |
| --- | --- |
| Click to attack | Tap the monster, or press **ATTACK** on the bar |
| `F` throw trap  | **CATCH** button on the bar |
| `1`–`5` trap picker | **TRAP** button cycles tiers |
| `B` backpack    | **BAG** button |
| `E` market      | **MARKET** button |
| `M` mod menu    | Round **MOD** button (top-right) |
| `T` trade       | Round **TRADE** button (top-right) |

The action bar (`MobileActionBar.client.lua`) auto-hides on desktop. Sliders
in the mod menu handle both mouse and touch drag. Combat input is routed
through `UserInputService` / camera raycasts rather than the legacy Mouse API
so taps register the same as clicks.

Boats use `VehicleSeat`, which Roblox automatically drives with the on-screen
joystick on mobile.

## Notes

- Map is procedurally built on server start, then persisted for the session.
  Regenerate by restarting the server.
- All monster/item data lives in ModuleScripts so you can add more without
  touching systems.
- Persistence uses `DataStoreService`. In Studio, enable
  "Allow HTTP Requests" + "Enable Studio Access to API Services" for saves to
  round-trip.

## Where this code lives

Source lives in this repo under `src/` and is synced via Rojo. The branch
`claude/pokemon-roblox-game-7yl0E` on GitHub has every file; pull it with
`git clone` and `git checkout claude/pokemon-roblox-game-7yl0E`.

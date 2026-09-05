# Limen Survival

A small browser-based first-person survival game (TypeScript + Vite + Three.js +
Rapier), built around one rule: **every tunable value lives in `GameConfig` and
is read fresh by the systems each frame.** The mod menu is just a UI bound to
that object — no cheat is a special case.

```
npm install
npm run dev        # http://localhost:5173
npm run build      # typecheck + production bundle
npm run smoke      # headless boot check (Playwright)
```

Controls: `WASD` move · `Space` jump · click to capture the mouse · `~` mod menu
· `Esc` close menu.

## Layout

| Path | What |
| --- | --- |
| `src/config/GameConfig.ts` | The config object, its defaults, snapshots, and editor metadata |
| `src/config/reactive.ts` | Deep proxy + path helpers used by the config |
| `src/core/Engine.ts` | Three.js renderer, Rapier world, fixed-step loop |
| `src/core/Input.ts` | Keyboard / pointer-lock input, suspended while a menu is open |
| `src/player/PlayerController.ts` | Rapier kinematic character controller |
| `src/ui/ModMenu.ts` | Docked tabbed panel (`~`) |
| `src/ui/controls.ts` | Two-way controls bound to config paths |
| `src/ui/tabs/tuning.ts` | Generic editor that walks the whole config |

## Build progress

- [x] **1** — Bootstrap, reactive `GameConfig`, generic tuning editor
- [ ] **2** — Terrain streaming + full FPS controller (flight, noclip, gravity)
- [ ] **3** — Resource nodes, inventory, hotbar, crafting
- [ ] **4** — Base building
- [ ] **5** — Survival meters, day/night, animals, loot crates, XP
- [ ] **6** — Save/load and presets

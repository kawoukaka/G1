# G1 — Roadmap

Each phase ends with a playable build and a short "keep / cut / change" review.
Estimates assume one developer part-time; adjust after Phase 0.

## Phase 0 — Systems prototype (this repo, programmer art) ✅

Goal: answer *"is the build → sustain → grow loop fun with zero art polish?"*

- [x] Godot 4 project, pixel-perfect settings, integer camera zoom
- [x] Iso 2:1 grid math, floor plates with auto-edges, y-sorted modules
- [x] Data-driven building catalogue (`data/buildings.json`)
- [x] Build / demolish tools, ghost preview, placement rules, drag-paint
- [x] Power / battery / brownout, O2, food, storage, housing, credits
- [x] Crew arrivals, suffocation & starvation, wandering crew sprites
- [x] HUD: resources, build palette, info panel, notifications, speed controls
- [x] JSON save / load
- [x] Placeholder sprite generator (`tools/gen_placeholders.py`)

**Exit review:** play 3× 20-minute sessions. Is the first 5 minutes clear? Where do
you idle? Which shortage felt unfair? Tune `buildings.json` before adding systems.

## Phase 1 — Core loop depth (2–4 weeks)

- [ ] Multi-tile modules (2×2, 3×2) with footprint-aware y-sorting
- [ ] Rotation for asymmetric modules (2 or 4 directions)
- [ ] Walls & doors (cosmetic first, rooms later) with iso autotiling
- [ ] Individual crew agents: AStarGrid2D pathfinding, jobs (operate, repair, haul)
- [ ] Crew needs: sleep, food, morale → productivity
- [ ] Power priorities (life support first) instead of global brownout
- [ ] Build queue: placed modules become blueprints that crew construct
- [ ] Overlays: power, O2, crew paths (toggle with F1–F4)

## Phase 2 — Art direction & pipeline (parallel with Phase 1, 2–3 weeks)

See [ART_PIPELINE.md](ART_PIPELINE.md).

- [ ] Lock palette (start from `art/palette/station.gpl`) and lighting direction
- [ ] Style tile: 1 floor, 1 wall, 3 modules, 1 crew — painted in Aseprite
- [ ] Retro Diffusion experiments: concept sheets & module variants, then hand cleanup
- [ ] Animated states: idle / working / offline (4–8 frames) via Aseprite tags
- [ ] Pixel UI kit: 9-slice panels, icons (16×16), pixel font
- [ ] Godot import presets & Aseprite → Godot export script

## Phase 3 — Content & progression (4–6 weeks)

- [ ] Research tree unlocking modules
- [ ] Trade ships & contracts at docks (credits ↔ resources)
- [ ] Events: meteor showers (hull breach), solar flares (power spike), visitors
- [ ] 10–15 modules total, 3 tiers
- [ ] Scenario goals / missions; sandbox mode

## Phase 4 — Feel & polish (ongoing)

- [ ] Audio: ambient hum, UI blips, alarms (chiptune / lo-fi)
- [ ] Juice: build dust, flicker on brownout, screen shake on breach
- [ ] Tutorial / first-time hints
- [ ] Settings: key rebinding, UI scale, colour-blind-safe overlays
- [ ] Performance pass: TileMapLayer or custom batching for 100×100+ stations

## Phase 5 — Vertical slice / demo

- [ ] 30–45 minute polished scenario
- [ ] Steam page assets (capsule art, GIFs), playtest builds (itch.io)

## Technical decisions so far

| Decision | Why | Revisit when |
|---|---|---|
| Godot 4.2, GDScript, GL Compatibility renderer | quick iteration, runs everywhere | need compute shaders / heavy VFX |
| `canvas_items` stretch @1280×720 + integer camera zoom | readable UI text with crisp pixel world | switching to a pixel font + pure `viewport` stretch for full retro |
| Model in `GameState` autoload, views listen to signals | trivial save/load, testable sim | sim grows → split into `Simulation` + `StationModel` classes |
| Floors drawn in one `_draw()` instead of TileMap | auto edge slabs, map built at runtime | need editor-painted maps or >10k tiles |
| JSON building data | designers can tune without code | need inheritance/variants → Godot `Resource` files |

# G1 — Game Design (working draft)

> Working title. Isometric 2D retro pixel-art space station builder / strategy game.

## 1. Pitch

You are the commander of a tiny orbital outpost. Plate the hull, wire up power,
keep the air breathable and the crew fed, and grow a lonely docking clamp into a
bustling station — one tile at a time. Think *Oxygen Not Included* systems depth
viewed through a *SimTower / Theme Hospital* isometric diorama, rendered in crunchy
16-bit pixels.

## 2. Design pillars

1. **Readable diorama** — the station is always legible at a glance: every module's
   state (powered, offline, starving) shows on the sprite itself, not only in menus.
2. **Interlocking needs** — power → life support → crew → income → expansion. Every
   new module solves one problem and creates another.
3. **Small decisions, visible consequences** — placement matters (edges, adjacency,
   later: rooms and pressure), and a bad call shows up as a flickering brownout
   rather than a hidden number.
4. **Cozy tension** — failure is slow and recoverable; panic comes from cascading
   shortages, not twitch reflexes. Pause-and-build is always allowed.

## 3. Core loop

```
 build modules ──► produce power / O2 / food ──► attract & sustain crew
      ▲                                                  │
      └────────── spend credits ◄── crew generate ◄──────┘
```

Moment-to-moment: pause → plan → place → unpause → watch the meters → react.
Session goal (prototype): reach **20 crew** without the station collapsing.

## 4. Systems (prototype scope ✅, later 🔜)

| System | Prototype | Later |
|---|---|---|
| Iso grid & building | ✅ 1×1 modules on floor plates, adjacency rule, edge rule (docks), drag-paint | 🔜 multi-tile modules, rotation, walls/doors, decks/layers |
| Power | ✅ supply vs demand, batteries buffer deficits, brownout disables consumers | 🔜 conduits/grids, priorities, reactors with fuel |
| Life support | ✅ O2 stock, hull leakage per floor tile, O2 generators | 🔜 rooms & pressurisation, breaches, temperature |
| Food | ✅ hydroponics → food stock | 🔜 kitchens, ingredients, morale effects |
| Crew | ✅ count-based: arrive via dock when housing+supplies allow; suffocate/starve | 🔜 individual agents with jobs, needs, skills, pathfinding |
| Economy | ✅ credits per crew per tick, build costs, 50% demolish refund | 🔜 trade ships, contracts, research tree |
| Events | — | 🔜 meteor showers, solar flares, visitors, faction requests |
| Save/Load | ✅ JSON (F5/F9) | 🔜 multiple slots, autosave, versioned migrations |

## 5. Resources

| Resource | Type | Source | Sink |
|---|---|---|---|
| Credits | stock | crew (1.5/crew/tick while O2 & food > 0) | construction |
| Power | flow | Command Core, Solar Arrays | most modules |
| Energy | stock | power surplus | power deficit |
| Oxygen | stock (capped by storage) | O2 Generator, Hydroponics | crew (0.5), hull leak (0.02/floor) |
| Food | stock (capped by storage) | Hydroponics | crew (0.25) |
| Crew | count (capped by housing) | Docking Port arrivals | suffocation / starvation |

All tuning lives in `game/data/buildings.json` and the constants at the top of
`game/scripts/autoload/game_state.gd`.

## 6. Buildings (prototype)

| Hotkey | Module | Cost | Effect | Rule |
|---|---|---|---|---|
| 1 | Floor | 10 | Deck plating; leaks a little O2 | must touch the station |
| 2 | Solar Array | 60 | +5 power | on floor |
| 3 | Battery | 50 | +60 energy capacity | on floor |
| 4 | O2 Generator | 90 | −3 power, +3 O2/tick | on floor |
| 5 | Hydroponics | 110 | −2 power, +2 food, +0.5 O2/tick | on floor |
| 6 | Crew Quarters | 120 | −1 power, +4 housing | on floor |
| 7 | Storage Bay | 50 | +80 storage (O2 & food) | on floor |
| 8 | Docking Port | 200 | −2 power, enables crew arrivals | station edge |
| — | Command Core | — | +4 power, +2 housing, +60 storage, +40 energy | start, indestructible |

### buildings.json field reference

| Field | Meaning |
|---|---|
| `id`, `name`, `desc` | identity / UI text |
| `cost` | credits to build |
| `sprite` | `res://` path to the sprite (see ART_PIPELINE.md for size/anchor rules) |
| `power` | + supplies, − consumes (per tick) |
| `produces` | `{ "oxygen": n, "food": n }` per tick; consumers produce only when powered |
| `housing`, `storage`, `battery` | capacity contributions |
| `dock` | enables crew arrivals |
| `edge` | must be placed on a floor tile next to open space |
| `buildable` / `demolishable` | default true |

## 7. Win / lose (prototype)

- **Goal:** 20 crew aboard.
- **Pressure:** O2 hits zero → one crew lost every 5 ticks; food zero → one lost every 10.
- No hard game over yet; an empty station can still recover if a dock is running.

## 8. Controls

| Input | Action |
|---|---|
| 1–8 / palette buttons | pick a module |
| LMB (hold to paint) | build |
| X | demolish tool (50% refund) |
| RMB / Esc | cancel tool |
| WASD / arrows / MMB drag | pan |
| Mouse wheel / pinch | zoom (integer steps 1×–6×) |
| Space | pause / resume |
| Tab | cycle speed 1× / 2× / 4× |
| F5 / F9 | save / load |

## 9. Open design questions

1. **Rooms vs. tiles** — do modules need enclosing walls to form pressurised rooms
   (ONI/RimWorld style), or stay as self-contained blocks (SimTower style)? Rooms
   add depth but cost a lot of UX and art (wall autotiling in iso).
2. **Individual crew vs. aggregate** — named crew with traits are great for stories
   but need pathfinding, jobs and lots of animation frames.
3. **Verticality** — multiple decks (layer switching) or a single sprawling deck?
4. **Win structure** — sandbox, scenario missions, or a campaign map of stations?
5. **Camera rotation** — iso games often skip it; it would 4× the art budget.

Recommendation for the next milestone: keep tiles-as-modules, add **multi-tile
modules + walls/doors as cosmetic boundaries**, and prototype **individual crew
with simple jobs** — that's the biggest jump in "feel" for the least art.

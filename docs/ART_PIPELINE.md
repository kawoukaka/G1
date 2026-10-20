# G1 — Art pipeline

The prototype ships with generated programmer art (`tools/gen_placeholders.py`).
Final art replaces those PNGs **in place** — keep the sizes and anchors below and no
code changes are needed.

## 1. Grid & projection

- **Projection:** 2:1 pixel isometric ("dimetric"). Lines step 2 px across, 1 px down.
- **Tile footprint:** 32 × 16 px diamond. Rows 7 and 8 are the full 32 px width;
  rows 0 and 15 are 4 px wide (see `diamond_span()` in the generator).
- **Light:** from the upper-left. Top face lightest, left face mid, right face darkest.
- **Outline:** 1 px inner outline in `ink` (#14121f) on module silhouettes. Floors
  have no outline, only darker bevels.

## 2. Sprite specs

| Asset | Size | Anchor (how the game places it) |
|---|---|---|
| Floor top | 32 × 16 | tile top-left |
| Floor side slabs (L/R) | 32 × 22 | tile top-left; drawn only where the floor has no neighbour |
| Module (1×1) | 32 × (16 + height) | the **bottom 16 rows are the footprint diamond**; game aligns the diamond's centre with the tile centre |
| Crew | 7 × 11 | bottom-centre pixel = feet |
| Cursor | 32 × 16 | tile top-left |
| UI icons (planned) | 16 × 16 | — |

Module heights used now: solar 3, dock 4, hydroponics 7, storage 10, O2 12,
battery 14, quarters 16, core 18. Anything up to ~48 px tall works; taller modules
just overlap the tiles behind them (y-sorting handles it).

**Multi-tile modules (Phase 1):** a W×H-tile module will be one sprite whose
footprint is the W×H diamond; anchor = centre of the footprint's front-most tile.
Plan for 2×2 = 64 × (32 + height).

## 3. Palette

`art/palette/station.gpl` (Aseprite/GIMP) and `station.hex` (Lospec format) — 24
colours: steel ramp, blues, teals, greens, warm accents, skin. Load in Aseprite via
*Palette → Load Palette*. Stay inside it; it is what makes mixed hand-made and
AI-made sprites look like one game. Extend deliberately (add a ramp, not a colour).

## 4. Aseprite workflow

1. One `.aseprite` file per module in `art/source/` (kept out of `game/` so Godot
   doesn't import it).
2. Layers: `outline`, `top`, `left`, `right`, `details`, `lights`. Use the
   **isometric grid** (View → Grid settings: 32 × 16 or a 2:1 line guide layer).
3. Animation via tags: `idle`, `working`, `offline` (same canvas size every frame).
4. Export: *File → Export Sprite Sheet* → horizontal strip, PNG, trimmed **off**,
   plus JSON data (Array, with tags) → `game/assets/sprites/buildings/<id>.png`.
   CLI equivalent for batch export:

```bash
aseprite -b art/source/solar.aseprite --sheet game/assets/sprites/buildings/solar.png --data game/assets/sprites/buildings/solar.json --format json-array --list-tags
```

5. Phase 2 task: small Godot import script that reads the JSON and builds
   `SpriteFrames` so animated modules drop straight in.

## 5. Retro Diffusion (AI) workflow

Retro Diffusion generates pixel art (Aseprite extension and web app). Treat it as a
**concept and base-layer generator, never final output**:

1. **Generate at the target resolution** (or an exact integer multiple and downscale
   with nearest-neighbour). Prompt with the projection explicitly, e.g.
   *"isometric pixel art, 2:1 dimetric, single sci-fi space station module, hydroponics
   bay, top-left lighting, transparent background, 32px tile footprint"*.
2. **Use reference images** — feed an existing module sprite as the init/reference
   image so new modules match proportions and lighting.
3. **Clean up in Aseprite** (budget 15–40 min per sprite):
   - re-quantise to `station.gpl` (*Sprite → Color Mode → Indexed* with the palette),
   - redraw the footprint diamond edges so they match the 2:1 spec exactly,
   - fix stray pixels, add the 1 px inner outline, check the anchor rows.
4. Keep the prompt, seed and model version in the `.aseprite` file's user data or a
   sidecar `.txt` for reproducibility.
5. **Licensing:** check the current Retro Diffusion terms for commercial use and keep
   a record of which assets were AI-assisted (storefronts such as Steam ask you to
   disclose AI-generated content).

## 6. Godot import settings

Already set project-wide: `default_texture_filter = Nearest`, snap 2D transforms to
pixels. For each PNG keep the default *Lossless* compression and mipmaps **off**.
Never scale sprites by non-integer factors; the camera only uses 1×, 2×, 3×, 4×, 6×.

## 7. Replacing placeholder art — checklist

- [ ] Same filename and path as the placeholder
- [ ] Width 32 (1×1 module); height = 16 + module height
- [ ] Bottom 16 rows contain the footprint diamond
- [ ] Only palette colours, transparent background, no anti-aliasing
- [ ] Looks right next to its neighbours at 1× and 3× zoom

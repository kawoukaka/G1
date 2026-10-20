#!/usr/bin/env python3
"""Generate placeholder isometric pixel-art sprites for the G1 prototype.

Programmer art: flat-shaded 2:1 iso blocks in the project palette. Replace the PNGs
with Aseprite / Retro Diffusion art later, keeping the sizes and anchors from
docs/ART_PIPELINE.md, and no code changes are needed.

Usage:  python3 tools/gen_placeholders.py      (requires Pillow)
"""
from __future__ import annotations

import math
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
SPRITES = ROOT / "game" / "assets" / "sprites"
PALETTE_DIR = ROOT / "art" / "palette"

PALETTE = {
    "void": "0b0a17", "ink": "14121f",
    "steel0": "2b2d42", "steel1": "4a4e69", "steel2": "8d99ae", "steel3": "c9d1dc", "white": "f8f9fa",
    "navy": "1d3557", "blue": "2f6fbf", "sky": "6fb3ff",
    "teal": "1f8a87", "cyan": "3fd0c9", "ice": "a6f6ef",
    "moss": "2d6a4f", "green": "52b788", "mint": "b7e4c7",
    "amber": "ffd166", "orange": "f4a259", "rust": "a8552a",
    "red": "e63946", "wine": "8d1d2c", "violet": "7b2cbf",
    "skin": "f1c27d", "skin_dk": "c68642",
}


def c(name: str) -> tuple[int, int, int, int]:
    h = PALETTE[name]
    return int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16), 255


TW, TH = 32, 16  # tile footprint


# --- 2:1 diamond geometry --------------------------------------------------

def diamond_span(row: int) -> tuple[int, int]:
    """Inclusive x-range of the 32x16 diamond on `row` (rows 7 and 8 are full width)."""
    half = 2 * (row + 1) if row < 8 else 2 * (16 - row)
    return 16 - half, 16 + half - 1


def lower_edge(x: int) -> int:
    """Lowest diamond row that contains column x."""
    return 8 + x // 2 if x < 16 else (47 - x) // 2


def top_uv(x: int, y: int) -> tuple[float, float]:
    """Pixel on the top face -> (u, v) in 0..1 along the tile's +x / +y axes."""
    a = (x + 0.5 - 16) / 16
    b = (y + 0.5) / 8
    return (a + b) / 2, (b - a) / 2


def hash01(x: int, y: int, seed: int = 0) -> float:
    n = (x * 374761393 + y * 668265263 + seed * 2147483647) & 0xFFFFFFFF
    n = (n ^ (n >> 13)) * 1274126177 & 0xFFFFFFFF
    return (n ^ (n >> 16)) / 0xFFFFFFFF


# --- Block builder ---------------------------------------------------------

def block(h, top, left, right, top_fn=None, side_fn=None, outline=True, rim="steel3"):
    """Iso box of height h. Image is 32 x (16 + h); bottom 16 rows are the footprint.

    top_fn(u, v, x, y) and side_fn(face, s, t, x, y) may return a palette name to
    override the base colour; face is "L" or "R", s runs 0..1 along the face, t 0..1 down.
    """
    img = Image.new("RGBA", (TW, TH + h), (0, 0, 0, 0))
    px = img.load()
    for x in range(TW):
        face = "L" if x < 16 else "R"
        s = x / 15 if face == "L" else (x - 16) / 15
        for k in range(h):
            y = lower_edge(x) + 1 + k
            t = k / max(h - 1, 1)
            name = side_fn(face, s, t, x, y) if side_fn else None
            px[x, y] = c(name or (left if face == "L" else right))
    for y in range(TH):
        x0, x1 = diamond_span(y)
        for x in range(x0, x1 + 1):
            u, v = top_uv(x, y)
            name = top_fn(u, v, x, y) if top_fn else None
            if name is None and rim and h > 0 and y == lower_edge(x):
                name = rim  # catch-light where the top meets the walls
            px[x, y] = c(name or top)
    if outline:
        add_inner_outline(img, c("ink"))
    return img


def add_inner_outline(img: Image.Image, color) -> None:
    w, h = img.size
    px = img.load()
    edge = []
    for y in range(h):
        for x in range(w):
            if px[x, y][3] == 0:
                continue
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                nx, ny = x + dx, y + dy
                if not (0 <= nx < w and 0 <= ny < h) or px[nx, ny][3] == 0:
                    edge.append((x, y))
                    break
    for x, y in edge:
        px[x, y] = color


def add_outer_outline(img: Image.Image, color) -> None:
    w, h = img.size
    px = img.load()
    edge = []
    for y in range(h):
        for x in range(w):
            if px[x, y][3] != 0:
                continue
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                nx, ny = x + dx, y + dy
                if 0 <= nx < w and 0 <= ny < h and px[nx, ny][3] != 0:
                    edge.append((x, y))
                    break
    for x, y in edge:
        px[x, y] = color


def dist(u, v, cu=0.5, cv=0.5):
    return math.hypot(u - cu, v - cv)


# --- Floors ----------------------------------------------------------------

def floor_top():
    def top(u, v, x, y):
        x0, x1 = diamond_span(y)
        if x in (x0, x1) or y in (0, 15):
            return "steel2" if y < 8 else "steel0"  # bevel: lit far edges, dark near edges
        if abs(u - 0.5) < 0.04 or abs(v - 0.5) < 0.04:
            return "steel0"  # panel seams
        for cu in (0.22, 0.78):
            for cv in (0.22, 0.78):
                if dist(u, v, cu, cv) < 0.05:
                    return "steel2"  # rivets
        return None
    return block(0, "steel1", "steel1", "steel1", top_fn=top, outline=False)


def floor_side(face: str):
    h = 6

    def side(f, s, t, x, y):
        if t == 0:
            return "steel1" if f == "L" else "steel0"
        if f == "L" and 0.4 < t < 0.8 and int(s * 8) % 2 == 0:
            return "navy"  # hull trim lights
        return None

    img = block(h, "steel1", "steel0", "ink", side_fn=side, outline=False, rim=None)
    px = img.load()
    for y in range(img.height):
        for x in range(TW):
            on_side = y > lower_edge(x)
            wrong_face = (x >= 16) if face == "L" else (x < 16)
            if not on_side or wrong_face:
                px[x, y] = (0, 0, 0, 0)
    return img


# --- Modules ---------------------------------------------------------------

def core():
    def top(u, v, x, y):
        d = dist(u, v)
        if d < 0.1:
            return "ice"
        if d < 0.18:
            return "cyan"
        if d < 0.24:
            return "steel1"
        return None

    def side(f, s, t, x, y):
        if 0.25 < t < 0.45 and (s * 5) % 1 < 0.55:
            return "cyan" if f == "L" else "teal"
        if t > 0.85:
            return "steel1" if f == "L" else "steel0"
        return None

    return block(18, "steel3", "steel2", "steel1", top, side)


def solar():
    def top(u, v, x, y):
        if (u * 4) % 1 < 0.12 or (v * 4) % 1 < 0.12:
            return "steel3"
        if (x + y) % 6 == 0:
            return "sky"  # glint
        return None

    return block(3, "blue", "steel1", "steel0", top)


def battery():
    def top(u, v, x, y):
        return "amber" if 0.25 < u < 0.75 and 0.25 < v < 0.75 else None

    def side(f, s, t, x, y):
        if t < 0.15:
            return "steel2" if f == "L" else "steel1"
        if f == "L" and 0.45 < t < 0.8 and 0.3 < s < 0.7:
            return "mint"  # charge meter
        if (s * 4) % 1 < 0.18:
            return "moss" if f == "L" else "ink"
        return None

    return block(14, "steel2", "green", "moss", top, side)


def o2_gen():
    def top(u, v, x, y):
        d = dist(u, v)
        if d < 0.24:
            ang = math.atan2(v - 0.5, u - 0.5)
            return "steel1" if int((ang + math.pi) / (math.pi / 3)) % 2 else "steel0"  # fan
        if d < 0.3:
            return "ice"
        return None

    def side(f, s, t, x, y):
        if 0.35 < t < 0.55:
            return "steel3" if f == "L" else "steel2"  # pipe
        if t > 0.85:
            return "steel1" if f == "L" else "steel0"
        return None

    return block(12, "steel2", "cyan", "teal", top, side)


def hydroponics():
    def top(u, v, x, y):
        if u < 0.12 or u > 0.88 or v < 0.12 or v > 0.88:
            return "steel3"  # glass rim
        r = hash01(x, y, 3)
        if r < 0.3:
            return "green"
        if r < 0.4:
            return "mint"
        return None

    def side(f, s, t, x, y):
        if 0.25 < t < 0.75 and (s * 3) % 1 < 0.7:
            return "green" if f == "L" else "moss"
        return None

    return block(7, "moss", "steel2", "steel1", top, side)


def quarters():
    def top(u, v, x, y):
        if abs(u - 0.5) < 0.05:
            return "steel2"  # roof ridge
        return None

    def side(f, s, t, x, y):
        col = (s * 4) % 1
        for lo, hi in ((0.18, 0.38), (0.55, 0.75)):
            if lo < t < hi and 0.25 < col < 0.75:
                lit = hash01(int(s * 4), int(lo * 10), 1 if f == "L" else 2) < 0.65
                return ("amber" if lit else "navy") if f == "L" else ("orange" if lit else "ink")
        return None

    return block(16, "steel3", "steel2", "steel1", top, side)


def storage():
    def top(u, v, x, y):
        if abs(u - 0.5) < 0.05 or abs(v - 0.5) < 0.05 or u < 0.08 or v < 0.08 or u > 0.92 or v > 0.92:
            return "rust"
        return None

    def side(f, s, t, x, y):
        if abs(t - 0.5) < 0.08 or (s * 2) % 1 < 0.1:
            return "rust" if f == "L" else "wine"
        return None

    return block(10, "amber", "orange", "rust", top, side)


def dock():
    def top(u, v, x, y):
        if u < 0.16 or u > 0.84 or v < 0.16 or v > 0.84:
            return "amber" if int((u + v) * 8) % 2 else "ink"  # hazard stripes
        d = dist(u, v)
        if 0.18 < d < 0.25:
            return "sky"  # landing ring
        return None

    return block(4, "steel1", "steel1", "steel0", top)


# --- Crew, cursor, background ----------------------------------------------

CREW_SHAPE = [
    ".HHH.",
    ".SSS.",
    ".SSS.",
    "BBBBB",
    "BBBBB",
    "SBBBS",
    ".BBB.",
    ".L.L.",
    ".L.L.",
]
CREW_VARIANTS = [("orange", "ink"), ("sky", "rust"), ("red", "amber"), ("green", "steel0")]


def crew(suit: str, hair: str):
    img = Image.new("RGBA", (7, 11), (0, 0, 0, 0))
    px = img.load()
    colors = {"H": hair, "S": "skin", "B": suit, "L": "steel0"}
    for y, row in enumerate(CREW_SHAPE):
        for x, ch in enumerate(row):
            if ch in colors:
                px[x + 1, y + 1] = c(colors[ch])
    add_outer_outline(img, c("ink"))
    return img


def cursor():
    img = Image.new("RGBA", (TW, TH), (0, 0, 0, 0))
    px = img.load()
    for y in range(TH):
        x0, x1 = diamond_span(y)
        for x in range(x0, x1 + 1):
            if x in (x0, x0 + 1, x1, x1 - 1) or y in (0, 15):
                px[x, y] = c("white")
    return img


BAYER4 = [[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]]


def planet(size=64):
    """Dithered gas giant, lit from the upper left."""
    ramp = ["navy", "violet", "blue", "sky", "ice"]
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    px = img.load()
    r = size / 2 - 1
    light = (-0.6, -0.6, 0.53)
    for y in range(size):
        for x in range(size):
            dx, dy = (x + 0.5 - size / 2) / r, (y + 0.5 - size / 2) / r
            dd = dx * dx + dy * dy
            if dd > 1:
                continue
            dz = math.sqrt(1 - dd)
            lum = max(0.0, dx * light[0] + dy * light[1] + dz * light[2])
            lum += 0.12 * math.sin(dy * 9 + math.sin(dx * 3))  # cloud bands
            level = lum * (len(ramp) - 1) + (BAYER4[y % 4][x % 4] / 16 - 0.5)
            px[x, y] = c(ramp[max(0, min(len(ramp) - 1, round(level)))])
    return img


# --- Palette export --------------------------------------------------------

def write_palettes():
    PALETTE_DIR.mkdir(parents=True, exist_ok=True)
    (PALETTE_DIR / "station.hex").write_text("\n".join(PALETTE.values()) + "\n")
    lines = ["GIMP Palette", "Name: G1 Station", "Columns: 8", "#"]
    for name, h in PALETTE.items():
        r, g, b, _ = c(name)
        lines.append(f"{r:3d} {g:3d} {b:3d}\t{name}")
    (PALETTE_DIR / "station.gpl").write_text("\n".join(lines) + "\n")


def save(img: Image.Image, rel: str) -> None:
    path = SPRITES / rel
    path.parent.mkdir(parents=True, exist_ok=True)
    img.save(path)
    print(f"  {rel:32s} {img.width}x{img.height}")


def main() -> None:
    print(f"Writing sprites to {SPRITES}")
    save(floor_top(), "tiles/floor_top.png")
    save(floor_side("L"), "tiles/floor_side_l.png")
    save(floor_side("R"), "tiles/floor_side_r.png")
    for name, fn in [("core", core), ("solar", solar), ("battery", battery), ("o2_gen", o2_gen),
                     ("hydroponics", hydroponics), ("quarters", quarters), ("storage", storage),
                     ("dock", dock)]:
        save(fn(), f"buildings/{name}.png")
    for i, (suit, hair) in enumerate(CREW_VARIANTS):
        save(crew(suit, hair), f"crew/crew_{i}.png")
    save(cursor(), "ui/cursor.png")
    save(planet(), "fx/planet.png")
    write_palettes()
    print("Palette written to art/palette/station.{gpl,hex}")


if __name__ == "__main__":
    main()

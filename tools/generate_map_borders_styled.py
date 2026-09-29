#!/usr/bin/env python3
from __future__ import annotations

import math
import random
from pathlib import Path
from xml.etree import ElementTree as ET

from PIL import Image, ImageDraw, ImageFilter

# ============================================================
# CONFIG
# ============================================================

ROOT = Path(__file__).resolve().parents[1]
OUT_DIR = ROOT / "assets" / "sprites" / "map_borders"
TSX_PATH = ROOT / "assets" / "maps" / "map_borders_styled.tsx"

SEED = 42
rng = random.Random(SEED)

# grille isométrique logique
GRID_W = 80
GRID_H = 40

# canvas sprite
W = 96
H = 104

# hauteur voulue de la falaise
FRONT_DEPTH = 34
SIDE_DEPTH = 22

# supersampling
SS = 4

# palette
COLORS = {
    "grass_top": (184, 221, 108, 255),
    "grass_top_2": (170, 210, 92, 255),
    "grass_lip": (121, 174, 70, 255),
    "grass_lip_dark": (94, 143, 55, 255),
    "earth": (120, 74, 42, 255),
    "earth_2": (140, 90, 54, 255),
    "earth_dark": (92, 54, 31, 255),
    "earth_shadow": (65, 38, 22, 255),
    "stone": (156, 148, 130, 255),
    "stone_2": (184, 176, 156, 255),
    "stone_dark": (116, 108, 95, 255),
    "flower_white": (250, 250, 240, 255),
    "flower_yellow": (232, 197, 74, 255),
    "leaf": (102, 161, 64, 255),
    "leaf_2": (80, 136, 52, 255),
    "shadow": (0, 0, 0, 40),
}

# centre du losange supérieur
CX = W // 2
CY = 26

# ============================================================
# UTILS
# ============================================================

def upscale(v: int) -> int:
    return v * SS

def P(x: float, y: float) -> tuple[int, int]:
    return (round(x * SS), round(y * SS))

def make_canvas() -> tuple[Image.Image, ImageDraw.ImageDraw]:
    img = Image.new("RGBA", (W * SS, H * SS), (0, 0, 0, 0))
    return img, ImageDraw.Draw(img)

def downsample(img: Image.Image) -> Image.Image:
    img = img.resize((W, H), Image.Resampling.LANCZOS)
    return img

def save(img: Image.Image, path: Path):
    path.parent.mkdir(parents=True, exist_ok=True)
    img.save(path)

def diamond_points(cx=CX, cy=CY, w=GRID_W, h=GRID_H):
    half_w = w / 2
    half_h = h / 2
    return [
        (cx, cy - half_h),        # top
        (cx + half_w, cy),        # right
        (cx, cy + half_h),        # bottom
        (cx - half_w, cy),        # left
    ]

def edge_point(a, b, t: float):
    return (a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t)

def jitter(c, amount=10):
    r, g, b, a = c
    return (
        max(0, min(255, r + rng.randint(-amount, amount))),
        max(0, min(255, g + rng.randint(-amount, amount))),
        max(0, min(255, b + rng.randint(-amount, amount))),
        a,
    )

# ============================================================
# BASE SHAPES
# ============================================================

def draw_top_ground(draw, variant=0):
    pts = [P(x, y) for x, y in diamond_points()]
    draw.polygon(pts, fill=COLORS["grass_top"])

    # texture douce
    for _ in range(120):
        x = rng.randint(CX - 32, CX + 32)
        y = rng.randint(CY - 16, CY + 16)
        draw.ellipse(
            [P(x - 1.2, y - 0.8), P(x + 1.2, y + 0.8)],
            fill=jitter(COLORS["grass_top_2"], 12),
        )

def draw_grass_lip(draw, segments: list[tuple[tuple[float, float], tuple[float, float]]]):
    for a, b in segments:
        length = math.dist(a, b)
        steps = max(6, int(length / 4))
        points = []
        for i in range(steps + 1):
            t = i / steps
            x, y = edge_point(a, b, t)
            amp = 2.2 if i % 2 == 0 else 1.0
            points.append(P(x, y + math.sin(t * math.pi * 6) * amp))
        draw.line(points, fill=COLORS["grass_lip"], width=upscale(2))
        draw.line(points, fill=COLORS["grass_lip_dark"], width=upscale(1))

        # petites touffes
        for i in range(0, steps + 1, 2):
            t = i / steps
            x, y = edge_point(a, b, t)
            tuft(draw, x, y, scale=0.9)

def tuft(draw, x, y, scale=1.0):
    n = rng.randint(3, 5)
    for _ in range(n):
        dx = rng.uniform(-2.5, 2.5) * scale
        h = rng.uniform(3, 6) * scale
        draw.line(
            [P(x, y), P(x + dx, y - h)],
            fill=jitter(COLORS["leaf"], 15),
            width=upscale(1),
        )

def flower(draw, x, y, scale=1.0):
    petal_r = 1.6 * scale
    for ang in [0, 72, 144, 216, 288]:
        px = x + math.cos(math.radians(ang)) * 2.2 * scale
        py = y + math.sin(math.radians(ang)) * 1.5 * scale
        draw.ellipse(
            [P(px - petal_r, py - petal_r), P(px + petal_r, py + petal_r)],
            fill=COLORS["flower_white"],
        )
    draw.ellipse(
        [P(x - 1.0 * scale, y - 1.0 * scale), P(x + 1.0 * scale, y + 1.0 * scale)],
        fill=COLORS["flower_yellow"],
    )

def rock(draw, x, y, scale=1.0):
    pts = [
        P(x - 7 * scale, y + 1 * scale),
        P(x - 4 * scale, y - 5 * scale),
        P(x + 2 * scale, y - 6 * scale),
        P(x + 7 * scale, y - 2 * scale),
        P(x + 6 * scale, y + 3 * scale),
        P(x, y + 5 * scale),
        P(x - 5 * scale, y + 4 * scale),
    ]
    draw.polygon(pts, fill=COLORS["stone"], outline=COLORS["stone_dark"])
    draw.line([P(x - 2 * scale, y - 1 * scale), P(x + 2 * scale, y + 1 * scale)],
              fill=COLORS["stone_2"], width=upscale(1))

def draw_earth_face(draw, poly, vertical_stripes=True):
    draw.polygon([P(x, y) for x, y in poly], fill=COLORS["earth"])

    min_x = min(x for x, _ in poly)
    max_x = max(x for x, _ in poly)
    min_y = min(y for _, y in poly)
    max_y = max(y for _, y in poly)

    # ombre générale
    draw.polygon([P(x, y) for x, y in poly], outline=COLORS["earth_dark"])

    # strates / blocs
    for _ in range(18):
        x0 = rng.uniform(min_x, max_x)
        y0 = rng.uniform(min_y, max_y)
        w = rng.uniform(5, 11)
        h = rng.uniform(2, 5)
        c = jitter(COLORS["earth_2"], 14)
        draw.rounded_rectangle(
            [P(x0 - w/2, y0 - h/2), P(x0 + w/2, y0 + h/2)],
            radius=upscale(1),
            fill=c,
        )

    if vertical_stripes:
        # cassures verticales discrètes
        for x in range(int(min_x) + 8, int(max_x), 10):
            draw.line([P(x, min_y + 3), P(x - 2, max_y - 2)],
                      fill=(88, 54, 33, 120), width=upscale(1))

    # petits points / mousse
    for _ in range(36):
        x = rng.uniform(min_x, max_x)
        y = rng.uniform(min_y, max_y)
        draw.ellipse([P(x - 0.8, y - 0.8), P(x + 0.8, y + 0.8)],
                     fill=(160, 116, 74, 110))

def draw_soft_shadow(draw):
    draw.ellipse(
        [P(CX - 28, CY + 20), P(CX + 28, CY + 28)],
        fill=COLORS["shadow"]
    )

# ============================================================
# PIECES
# ============================================================

def piece_polys(kind: str):
    top = diamond_points()
    top_t, top_r, top_b, top_l = top

    # points utiles
    front_left = top_l
    front_right = top_r
    bottom = top_b
    top_left = top_l
    top_right = top_r

    # façade avant = entre left -> bottom -> right
    front_poly = [
        (top_l[0], top_l[1]),
        (top_b[0], top_b[1]),
        (top_r[0], top_r[1]),
        (top_r[0], top_r[1] + FRONT_DEPTH),
        (top_b[0], top_b[1] + FRONT_DEPTH),
        (top_l[0], top_l[1] + FRONT_DEPTH),
    ]

    # façade gauche = entre top -> left -> bottom
    left_poly = [
        (top_t[0], top_t[1]),
        (top_l[0], top_l[1]),
        (top_b[0], top_b[1]),
        (top_b[0] - 8, top_b[1] + SIDE_DEPTH),
        (top_l[0] - 8, top_l[1] + SIDE_DEPTH),
        (top_t[0] - 8, top_t[1] + SIDE_DEPTH),
    ]

    # façade droite = entre top -> right -> bottom
    right_poly = [
        (top_t[0], top_t[1]),
        (top_r[0], top_r[1]),
        (top_b[0], top_b[1]),
        (top_b[0] + 8, top_b[1] + SIDE_DEPTH),
        (top_r[0] + 8, top_r[1] + SIDE_DEPTH),
        (top_t[0] + 8, top_t[1] + SIDE_DEPTH),
    ]

    data = {
        "ground": True,
        "front_face": None,
        "left_face": None,
        "right_face": None,
        "lip_segments": [],
        "rocks": [],
        "flowers": [],
    }

    if kind == "front":
        data["front_face"] = front_poly
        data["lip_segments"] = [(top_l, top_r)]
        data["rocks"] = [(CX - 18, CY + 20, 1.0), (CX + 16, CY + 19, 0.9)]

    elif kind == "front_left":
        data["front_face"] = [
            top_l,
            top_b,
            (CX, top_b[1]),
            (CX, top_b[1] + FRONT_DEPTH),
            (top_b[0], top_b[1] + FRONT_DEPTH),
            (top_l[0], top_l[1] + FRONT_DEPTH),
        ]
        data["left_face"] = [
            top_t,
            top_l,
            (CX - 12, CY),
            (CX - 16, CY + SIDE_DEPTH),
            (top_l[0] - 8, top_l[1] + SIDE_DEPTH),
            (top_t[0] - 8, top_t[1] + SIDE_DEPTH),
        ]
        data["lip_segments"] = [(top_t, top_l), (top_l, top_b)]
        data["rocks"] = [(CX - 28, CY + 12, 1.0)]

    elif kind == "front_right":
        data["front_face"] = [
            (CX, top_b[1]),
            top_b,
            top_r,
            (top_r[0], top_r[1] + FRONT_DEPTH),
            (top_b[0], top_b[1] + FRONT_DEPTH),
            (CX, top_b[1] + FRONT_DEPTH),
        ]
        data["right_face"] = [
            top_t,
            (CX + 12, CY),
            top_r,
            (top_r[0] + 8, top_r[1] + SIDE_DEPTH),
            (CX + 16, CY + SIDE_DEPTH),
            (top_t[0] + 8, top_t[1] + SIDE_DEPTH),
        ]
        data["lip_segments"] = [(top_t, top_r), (top_r, top_b)]
        data["rocks"] = [(CX + 28, CY + 12, 1.0)]

    elif kind == "left":
        data["left_face"] = left_poly
        data["lip_segments"] = [(top_t, top_l), (top_l, top_b)]
        data["flowers"] = [(CX - 24, CY - 2, 1.0), (CX - 14, CY + 10, 0.85)]

    elif kind == "right":
        data["right_face"] = right_poly
        data["lip_segments"] = [(top_t, top_r), (top_r, top_b)]
        data["flowers"] = [(CX + 18, CY + 2, 1.0), (CX + 28, CY + 12, 0.85)]

    elif kind == "left_rock":
        data["left_face"] = left_poly
        data["lip_segments"] = [(top_t, top_l), (top_l, top_b)]
        data["rocks"] = [(CX - 30, CY + 14, 1.0), (CX - 18, CY + 18, 0.85)]

    elif kind == "right_rock":
        data["right_face"] = right_poly
        data["lip_segments"] = [(top_t, top_r), (top_r, top_b)]
        data["rocks"] = [(CX + 28, CY + 14, 1.0), (CX + 18, CY + 19, 0.8)]

    elif kind == "front_rock":
        data["front_face"] = front_poly
        data["lip_segments"] = [(top_l, top_r)]
        data["rocks"] = [(CX - 16, CY + 20, 1.0), (CX + 12, CY + 21, 0.95), (CX + 26, CY + 18, 0.75)]

    else:
        raise ValueError(f"Unknown kind: {kind}")

    return data

def render_piece(kind: str) -> Image.Image:
    img, draw = make_canvas()
    draw_soft_shadow(draw)

    data = piece_polys(kind)

    if data["ground"]:
        draw_top_ground(draw)

    if data["left_face"] is not None:
        draw_earth_face(draw, data["left_face"])

    if data["right_face"] is not None:
        draw_earth_face(draw, data["right_face"])

    if data["front_face"] is not None:
        draw_earth_face(draw, data["front_face"], vertical_stripes=False)

    if data["lip_segments"]:
        draw_grass_lip(draw, data["lip_segments"])

    # petites pâquerettes / feuillage
    for x, y, scale in data["flowers"]:
        tuft(draw, x - 2, y + 2, scale=1.1 * scale)
        tuft(draw, x + 2, y + 1, scale=0.9 * scale)
        flower(draw, x, y, scale=scale)

    # rochers intégrés
    for x, y, scale in data["rocks"]:
        tuft(draw, x - 5 * scale, y + 2 * scale, scale=0.9 * scale)
        tuft(draw, x + 4 * scale, y + 1 * scale, scale=0.8 * scale)
        rock(draw, x, y, scale=scale)

    # léger flou puis netteté douce
    img = img.filter(ImageFilter.GaussianBlur(radius=0.15 * SS))
    img = downsample(img)

    return img

# ============================================================
# TSX
# ============================================================

def write_tsx(image_names: list[str]):
    root = ET.Element(
        "tileset",
        {
            "version": "1.10",
            "tiledversion": "1.11.2",
            "name": "map_borders_styled",
            "tilewidth": str(W),
            "tileheight": str(H),
            "tilecount": str(len(image_names)),
            "columns": "0",
            "objectalignment": "bottom",
        },
    )
    ET.SubElement(root, "tileoffset", {"x": "0", "y": "0"})

    for i, name in enumerate(image_names):
        tile = ET.SubElement(root, "tile", {"id": str(i)})
        ET.SubElement(
            tile,
            "image",
            {
                "source": f"../sprites/map_borders/{name}.png",
                "width": str(W),
                "height": str(H),
            },
        )

    TSX_PATH.parent.mkdir(parents=True, exist_ok=True)
    ET.ElementTree(root).write(TSX_PATH, encoding="utf-8", xml_declaration=True)

# ============================================================
# MAIN
# ============================================================

def main():
    OUT_DIR.mkdir(parents=True, exist_ok=True)

    names = [
        "map_border_front",
        "map_border_left",
        "map_border_right",
        "map_border_front_left",
        "map_border_front_right",
        "map_border_left_rock",
        "map_border_right_rock",
        "map_border_front_rock",
    ]

    kind_map = {
        "map_border_front": "front",
        "map_border_left": "left",
        "map_border_right": "right",
        "map_border_front_left": "front_left",
        "map_border_front_right": "front_right",
        "map_border_left_rock": "left_rock",
        "map_border_right_rock": "right_rock",
        "map_border_front_rock": "front_rock",
    }

    for name in names:
        img = render_piece(kind_map[name])
        save(img, OUT_DIR / f"{name}.png")
        print(f"✓ {OUT_DIR / f'{name}.png'}")

    write_tsx(names)
    print(f"✓ {TSX_PATH}")
    print("\nTerminé.")

if __name__ == "__main__":
    main()

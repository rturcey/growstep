#!/usr/bin/env python3

from __future__ import annotations

import math
import random
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageChops

ROOT = Path(__file__).resolve().parents[1]

OUT_DIR = ROOT / "assets" / "surface_sources"
OUT_DIR.mkdir(parents=True, exist_ok=True)

PREVIEW_DIR = ROOT / "docs" / "visual-review" / "texture-pass"
PREVIEW_DIR.mkdir(parents=True, exist_ok=True)

SIZE = 512

RNG = random.Random(20260926)


def clamp(v: float, lo: int = 0, hi: int = 255) -> int:
    return max(lo, min(hi, int(round(v))))


def lerp(a: float, b: float, t: float) -> float:
    return a + (b - a) * t


def mix(c1, c2, t: float):
    return tuple(clamp(lerp(a, b, t)) for a, b in zip(c1, c2))


def make_canvas(color):
    return Image.new("RGBA", (SIZE, SIZE), color)


def add_soft_mottle(img: Image.Image, colors, count: int, r_min: int, r_max: int, blur: float):
    layer = Image.new("RGBA", img.size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(layer, "RGBA")

    for _ in range(count):
        r = RNG.randint(r_min, r_max)
        x = RNG.randint(-r, img.width + r)
        y = RNG.randint(-r, img.height + r)
        color = RNG.choice(colors)
        alpha = RNG.randint(18, 55)
        draw.ellipse((x - r, y - r, x + r, y + r), fill=(*color, alpha))

    layer = layer.filter(ImageFilter.GaussianBlur(blur))
    img.alpha_composite(layer)


def add_speckles(img: Image.Image, colors, count: int, r_min: int, r_max: int, alpha_range=(30, 90)):
    layer = Image.new("RGBA", img.size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(layer, "RGBA")

    for _ in range(count):
        r = RNG.randint(r_min, r_max)
        x = RNG.randint(0, img.width - 1)
        y = RNG.randint(0, img.height - 1)
        color = RNG.choice(colors)
        alpha = RNG.randint(*alpha_range)
        draw.ellipse((x - r, y - r, x + r, y + r), fill=(*color, alpha))

    img.alpha_composite(layer)


def add_strokes(
    img: Image.Image,
    colors,
    count: int,
    length_min: int,
    length_max: int,
    width_min: int,
    width_max: int,
    angle_center_deg: float,
    angle_spread_deg: float,
    alpha_range=(35, 90),
):
    layer = Image.new("RGBA", img.size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(layer, "RGBA")

    for _ in range(count):
        x = RNG.randint(0, img.width)
        y = RNG.randint(0, img.height)
        length = RNG.randint(length_min, length_max)
        width = RNG.randint(width_min, width_max)
        angle = math.radians(angle_center_deg + RNG.uniform(-angle_spread_deg, angle_spread_deg))
        dx = math.cos(angle) * length
        dy = math.sin(angle) * length
        color = RNG.choice(colors)
        alpha = RNG.randint(*alpha_range)
        draw.line((x, y, x + dx, y + dy), fill=(*color, alpha), width=width)

    layer = layer.filter(ImageFilter.GaussianBlur(0.6))
    img.alpha_composite(layer)


def add_blade_tufts(img: Image.Image, base_y_bias: bool = False):
    layer = Image.new("RGBA", img.size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(layer, "RGBA")

    for _ in range(260):
        x = RNG.randint(0, img.width)
        y = RNG.randint(0, img.height)
        if base_y_bias:
            y = int((y * 0.4) + img.height * 0.35)

        blade_count = RNG.randint(4, 8)
        for _ in range(blade_count):
            length = RNG.randint(8, 18)
            angle = math.radians(RNG.uniform(-115, -65))
            dx = math.cos(angle) * length
            dy = math.sin(angle) * length
            color = RNG.choice(
                [
                    (147, 185, 83),
                    (160, 200, 92),
                    (126, 162, 71),
                    (186, 214, 108),
                ]
            )
            alpha = RNG.randint(90, 160)
            draw.line((x, y, x + dx, y + dy), fill=(*color, alpha), width=1)

    layer = layer.filter(ImageFilter.GaussianBlur(0.35))
    img.alpha_composite(layer)


def add_tiny_flower_dots(img: Image.Image, count: int):
    layer = Image.new("RGBA", img.size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(layer, "RGBA")

    for _ in range(count):
        x = RNG.randint(0, img.width - 1)
        y = RNG.randint(0, img.height - 1)
        petal = (245, 244, 232, RNG.randint(80, 160))
        center = (226, 198, 92, RNG.randint(120, 190))
        r = RNG.randint(1, 2)

        draw.ellipse((x - r, y - r, x + r, y + r), fill=petal)
        draw.ellipse((x, y, x + 1, y + 1), fill=center)

    layer = layer.filter(ImageFilter.GaussianBlur(0.2))
    img.alpha_composite(layer)


def add_furrows(img: Image.Image):
    layer = Image.new("RGBA", img.size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(layer, "RGBA")

    # Terre cultivée : lignes douces diagonales
    for row in range(-40, img.height + 60, 28):
        wobble = RNG.randint(-8, 8)
        color_dark = (109, 72, 40, RNG.randint(38, 56))
        color_light = (171, 118, 74, RNG.randint(28, 46))

        draw.line(
            (0, row + wobble, img.width, row - 34 + wobble),
            fill=color_dark,
            width=3,
        )
        draw.line(
            (0, row + 8 + wobble, img.width, row - 26 + wobble),
            fill=color_light,
            width=2,
        )

    layer = layer.filter(ImageFilter.GaussianBlur(0.7))
    img.alpha_composite(layer)


def add_root_threads(img: Image.Image, count: int):
    layer = Image.new("RGBA", img.size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(layer, "RGBA")

    for _ in range(count):
        x = RNG.randint(0, img.width)
        y = RNG.randint(0, img.height)
        segs = RNG.randint(3, 5)
        points = [(x, y)]
        px, py = x, y
        for _ in range(segs):
            px += RNG.randint(-28, 28)
            py += RNG.randint(-10, 18)
            points.append((px, py))
        draw.line(points, fill=(96, 61, 39, RNG.randint(40, 95)), width=1)

    layer = layer.filter(ImageFilter.GaussianBlur(0.45))
    img.alpha_composite(layer)


def overlay_vertical_gradient(img: Image.Image, top_rgba, bottom_rgba):
    grad = Image.new("RGBA", img.size)
    pixels = grad.load()

    for y in range(img.height):
        t = y / (img.height - 1)
        color = mix(top_rgba[:3], bottom_rgba[:3], t)
        alpha = clamp(lerp(top_rgba[3], bottom_rgba[3], t))
        for x in range(img.width):
            pixels[x, y] = (*color, alpha)

    img.alpha_composite(grad)


def build_grass():
    # Herbe plus proche de l’image de référence :
    # verte, lumineuse, chaude, douce.
    img = make_canvas((165, 205, 96, 255))

    add_soft_mottle(
        img,
        colors=[
            (186, 219, 111),
            (145, 185, 82),
            (198, 225, 128),
            (129, 170, 74),
        ],
        count=190,
        r_min=18,
        r_max=62,
        blur=8,
    )

    add_strokes(
        img,
        colors=[
            (196, 224, 125),
            (176, 208, 104),
            (136, 173, 78),
            (155, 194, 88),
        ],
        count=1700,
        length_min=6,
        length_max=14,
        width_min=1,
        width_max=2,
        angle_center_deg=-72,
        angle_spread_deg=24,
        alpha_range=(24, 58),
    )

    add_blade_tufts(img)
    add_tiny_flower_dots(img, count=110)
    add_speckles(
        img,
        colors=[(112, 149, 65), (206, 225, 136), (154, 188, 90)],
        count=900,
        r_min=1,
        r_max=2,
        alpha_range=(10, 35),
    )

    return img


def build_cultivated_soil():
    img = make_canvas((131, 89, 53, 255))

    add_soft_mottle(
        img,
        colors=[
            (151, 103, 62),
            (104, 66, 38),
            (171, 122, 79),
            (125, 79, 47),
        ],
        count=160,
        r_min=15,
        r_max=55,
        blur=7,
    )

    add_furrows(img)

    add_speckles(
        img,
        colors=[
            (95, 60, 35),
            (173, 128, 87),
            (122, 80, 49),
            (153, 106, 64),
        ],
        count=1500,
        r_min=1,
        r_max=3,
        alpha_range=(28, 90),
    )

    add_strokes(
        img,
        colors=[
            (172, 127, 87),
            (101, 65, 37),
            (151, 104, 67),
        ],
        count=420,
        length_min=8,
        length_max=26,
        width_min=1,
        width_max=2,
        angle_center_deg=-20,
        angle_spread_deg=22,
        alpha_range=(18, 46),
    )

    return img


def build_earth_border():
    # Terre de bordure / tranche d’îlot :
    # plus profonde, plus brune/rouge, plus dense que la terre cultivée.
    img = make_canvas((121, 77, 45, 255))

    overlay_vertical_gradient(
        img,
        top_rgba=(153, 102, 63, 46),
        bottom_rgba=(87, 52, 31, 84),
    )

    add_soft_mottle(
        img,
        colors=[
            (146, 95, 58),
            (101, 62, 38),
            (170, 116, 73),
            (86, 51, 31),
        ],
        count=170,
        r_min=18,
        r_max=70,
        blur=10,
    )

    add_speckles(
        img,
        colors=[
            (178, 128, 86),
            (92, 58, 35),
            (116, 73, 45),
            (74, 45, 28),
        ],
        count=1700,
        r_min=1,
        r_max=3,
        alpha_range=(22, 85),
    )

    add_root_threads(img, count=140)

    add_strokes(
        img,
        colors=[
            (88, 53, 32),
            (150, 101, 64),
            (108, 68, 41),
        ],
        count=300,
        length_min=10,
        length_max=24,
        width_min=1,
        width_max=2,
        angle_center_deg=10,
        angle_spread_deg=35,
        alpha_range=(14, 42),
    )

    return img


def make_preview(grass, soil, earth):
    tile_w = 220
    tile_h = 220
    margin = 28

    preview = Image.new(
        "RGBA",
        (margin * 4 + tile_w * 3, margin * 2 + tile_h),
        (236, 239, 226, 255),
    )
    draw = ImageDraw.Draw(preview)

    labels = [
        ("Herbe", grass),
        ("Terre cultivée", soil),
        ("Bordure terre / tranche", earth),
    ]

    for i, (label, tex) in enumerate(labels):
        x = margin + i * (tile_w + margin)
        y = 46

        sample = tex.resize((tile_w, tile_h), Image.Resampling.LANCZOS)
        preview.alpha_composite(sample, (x, y))

        draw.rounded_rectangle(
            (x - 2, y - 2, x + tile_w + 2, y + tile_h + 2),
            radius=12,
            outline=(150, 156, 132, 255),
            width=2,
        )
        draw.text((x, 14), label, fill=(49, 61, 46, 255))

    return preview


def main():
    grass = build_grass()
    soil = build_cultivated_soil()
    earth = build_earth_border()

    grass_path = OUT_DIR / "potager_texture_herbe_source.png"
    soil_path = OUT_DIR / "potager_texture_terre_cultivee_source.png"
    earth_path = OUT_DIR / "potager_texture_bordure_terre_source.png"

    grass.save(grass_path)
    soil.save(soil_path)
    earth.save(earth_path)

    preview = make_preview(grass, soil, earth)
    preview_path = PREVIEW_DIR / "potager_texture_preview.png"
    preview.save(preview_path)

    print("Textures générées :")
    print(f"  - {grass_path}")
    print(f"  - {soil_path}")
    print(f"  - {earth_path}")
    print(f"Preview :")
    print(f"  - {preview_path}")


if __name__ == "__main__":
    main()

#!/usr/bin/env python3

from __future__ import annotations

import math
import random
from pathlib import Path
from typing import Iterable

from PIL import Image, ImageDraw, ImageFilter, ImageOps


ROOT = Path(__file__).resolve().parents[1]

SPRITES = ROOT / "assets" / "sprites"
SURFACE = ROOT / "assets" / "surface_sources"
PREVIEW_DIR = ROOT / "docs" / "visual-review" / "texture-pass"

PREVIEW_DIR.mkdir(parents=True, exist_ok=True)

GRASS_TEX = SURFACE / "potager_texture_herbe_source.png"
EARTH_TEX = SURFACE / "potager_texture_bordure_terre_source.png"

GRASS_BORDER_PREFIX = "potager_newda_sol_bordure_herbe_tile_"
SKIRT_PREFIX = "potager_newda_sol_tranche_terre_tile_"

RNG = random.Random(20260926)


def clamp(v: float, lo: int = 0, hi: int = 255) -> int:
    return max(lo, min(hi, int(round(v))))


def require(path: Path):
    if not path.exists():
        raise SystemExit(f"Fichier manquant : {path}")


def sample_patch(
    texture: Image.Image,
    index: int,
    width: int = 80,
    height: int = 40,
    scale: int = 3,
) -> Image.Image:
    sw = width * scale
    sh = height * scale

    max_x = texture.width - sw
    max_y = texture.height - sh
    if max_x < 0 or max_y < 0:
        raise RuntimeError(
            f"Texture trop petite: {texture.size}, attendu au moins {sw}x{sh}"
        )

    x = (31 + index * 73) % (max_x + 1)
    y = (17 + index * 59) % (max_y + 1)

    patch = texture.crop((x, y, x + sw, y + sh))
    return patch.resize((width, height), Image.Resampling.LANCZOS)


def grayscale_luma(img: Image.Image) -> Image.Image:
    return ImageOps.grayscale(img.convert("RGBA"))


def preserve_shape_with_shading(
    old_tile: Image.Image,
    material: Image.Image,
    contrast: float = 1.0,
    brightness: float = 1.0,
) -> Image.Image:
    """
    Recolor while preserving the old tile silhouette + a big part of its internal shading.
    """
    old_rgba = old_tile.convert("RGBA")
    alpha = old_rgba.getchannel("A")
    luma = grayscale_luma(old_rgba)

    result = Image.new("RGBA", old_rgba.size, (0, 0, 0, 0))
    src = material.convert("RGBA").load()
    lum = luma.load()

    out = result.load()
    for y in range(old_rgba.height):
        for x in range(old_rgba.width):
            a = alpha.getpixel((x, y))
            if a == 0:
                continue

            shade = lum[x, y] / 255.0
            shade = ((shade - 0.5) * contrast) + 0.5
            shade *= brightness
            shade = max(0.0, min(1.3, shade))

            r, g, b, _ = src[x, y]
            out[x, y] = (
                clamp(r * shade),
                clamp(g * shade),
                clamp(b * shade),
                a,
            )

    return result


def alpha_bbox(alpha: Image.Image):
    return alpha.point(lambda p: 255 if p else 0).getbbox()


def top_profile(alpha: Image.Image) -> list[int | None]:
    w, h = alpha.size
    res: list[int | None] = []
    for x in range(w):
        y_found = None
        for y in range(h):
            if alpha.getpixel((x, y)) > 8:
                y_found = y
                break
        res.append(y_found)
    return res


def bottom_profile(alpha: Image.Image) -> list[int | None]:
    w, h = alpha.size
    res: list[int | None] = []
    for x in range(w):
        y_found = None
        for y in range(h - 1, -1, -1):
            if alpha.getpixel((x, y)) > 8:
                y_found = y
                break
        res.append(y_found)
    return res


def add_grass_fringe(tile: Image.Image, seed_index: int):
    alpha = tile.getchannel("A")
    profile = top_profile(alpha)

    layer = Image.new("RGBA", tile.size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(layer, "RGBA")
    local_rng = random.Random(7000 + seed_index)

    blade_colors = [
        (170, 205, 93),
        (155, 193, 88),
        (186, 216, 110),
        (132, 168, 76),
        (195, 223, 123),
    ]

    for x, y0 in enumerate(profile):
        if y0 is None:
            continue

        if local_rng.random() > 0.78:
            continue

        blade_count = 1 if local_rng.random() < 0.7 else 2
        for _ in range(blade_count):
            start_x = x + local_rng.uniform(-0.4, 0.4)
            start_y = y0 + local_rng.uniform(-0.5, 1.2)

            height = local_rng.randint(3, 7)
            lean = local_rng.uniform(-1.2, 1.2)

            end_x = start_x + lean
            end_y = start_y - height

            color = local_rng.choice(blade_colors)
            alpha_v = local_rng.randint(130, 210)
            draw.line(
                (start_x, start_y, end_x, end_y),
                fill=(*color, alpha_v),
                width=1,
            )

    layer = layer.filter(ImageFilter.GaussianBlur(0.25))
    tile.alpha_composite(layer)


def add_grass_top_light(tile: Image.Image):
    alpha = tile.getchannel("A")
    profile = top_profile(alpha)

    layer = Image.new("RGBA", tile.size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(layer, "RGBA")

    for x, y0 in enumerate(profile):
        if y0 is None:
            continue
        draw.point((x, y0), fill=(220, 236, 155, 150))
        if y0 + 1 < tile.height:
            draw.point((x, y0 + 1), fill=(192, 214, 118, 80))

    layer = layer.filter(ImageFilter.GaussianBlur(0.35))
    tile.alpha_composite(layer)


def add_earth_depth(tile: Image.Image):
    layer = Image.new("RGBA", tile.size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(layer, "RGBA")

    w, h = tile.size
    for y in range(h):
        t = y / max(1, h - 1)
        # Plus sombre vers le bas.
        alpha = clamp(10 + t * 55)
        draw.line((0, y, w, y), fill=(56, 32, 18, alpha), width=1)

    layer = layer.filter(ImageFilter.GaussianBlur(0.8))
    tile.alpha_composite(layer)


def add_root_threads(tile: Image.Image, seed_index: int):
    alpha = tile.getchannel("A")
    bbox = alpha_bbox(alpha)
    if bbox is None:
        return

    x0, y0, x1, y1 = bbox
    local_rng = random.Random(9000 + seed_index)

    layer = Image.new("RGBA", tile.size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(layer, "RGBA")

    for _ in range(12):
        sx = local_rng.randint(x0, max(x0, x1 - 1))
        sy = local_rng.randint(y0 + 2, max(y0 + 2, y1 - 2))

        pts = [(sx, sy)]
        px, py = sx, sy
        for _ in range(local_rng.randint(2, 4)):
            px += local_rng.randint(-8, 8)
            py += local_rng.randint(1, 5)
            pts.append((px, py))

        col = local_rng.choice(
            [
                (84, 51, 31, 65),
                (98, 61, 37, 55),
                (118, 80, 52, 42),
            ]
        )
        draw.line(pts, fill=col, width=1)

    layer = layer.filter(ImageFilter.GaussianBlur(0.35))
    # Clip by original alpha.
    masked = Image.new("RGBA", tile.size, (0, 0, 0, 0))
    masked.alpha_composite(layer)
    masked.putalpha(
        ImageChops_multiply(masked.getchannel("A"), alpha)
    )
    tile.alpha_composite(masked)


def add_small_stones(tile: Image.Image, seed_index: int):
    alpha = tile.getchannel("A")
    bbox = alpha_bbox(alpha)
    if bbox is None:
        return

    x0, y0, x1, y1 = bbox
    local_rng = random.Random(12000 + seed_index)

    layer = Image.new("RGBA", tile.size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(layer, "RGBA")

    for _ in range(18):
        x = local_rng.randint(x0, max(x0, x1 - 1))
        y = local_rng.randint(y0 + 4, max(y0 + 4, y1 - 1))
        r = local_rng.randint(1, 2)
        color = local_rng.choice(
            [
                (160, 122, 87, 70),
                (142, 101, 70, 62),
                (109, 71, 47, 58),
            ]
        )
        draw.ellipse((x - r, y - r, x + r, y + r), fill=color)

    layer = layer.filter(ImageFilter.GaussianBlur(0.2))
    masked = Image.new("RGBA", tile.size, (0, 0, 0, 0))
    masked.alpha_composite(layer)
    masked.putalpha(
        ImageChops_multiply(masked.getchannel("A"), alpha)
    )
    tile.alpha_composite(masked)


def add_bottom_ambient_shadow(tile: Image.Image):
    alpha = tile.getchannel("A")
    profile = bottom_profile(alpha)

    layer = Image.new("RGBA", tile.size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(layer, "RGBA")

    for x, yb in enumerate(profile):
        if yb is None:
            continue
        for k in range(3):
            y = yb - k
            if y >= 0:
                a = 38 - k * 10
                draw.point((x, y), fill=(52, 30, 18, max(0, a)))

    layer = layer.filter(ImageFilter.GaussianBlur(0.65))
    tile.alpha_composite(layer)


def ImageChops_multiply(a: Image.Image, b: Image.Image) -> Image.Image:
    return Image.eval(
        Image.merge("L", [a])[0],
        lambda v: v,
    ).point(lambda _: 0) if False else __import__("PIL.ImageChops").ImageChops.multiply(a, b)


def process_grass_border(path: Path, grass_tex: Image.Image, index: int):
    old = Image.open(path).convert("RGBA")
    material = sample_patch(grass_tex, index)
    new = preserve_shape_with_shading(
        old,
        material,
        contrast=1.18,
        brightness=1.02,
    )
    add_grass_top_light(new)
    add_grass_fringe(new, index)
    add_bottom_ambient_shadow(new)
    new.save(path, "PNG", optimize=True)
    print(f"✓ border {path.name}")


def process_skirt(path: Path, earth_tex: Image.Image, index: int):
    old = Image.open(path).convert("RGBA")
    material = sample_patch(earth_tex, 100 + index)
    new = preserve_shape_with_shading(
        old,
        material,
        contrast=1.12,
        brightness=0.98,
    )
    add_earth_depth(new)
    add_root_threads(new, index)
    add_small_stones(new, index)
    add_bottom_ambient_shadow(new)
    new.save(path, "PNG", optimize=True)
    print(f"✓ skirt  {path.name}")


def build_preview(paths: Iterable[Path], out_name: str):
    paths = list(paths)
    scale = 4
    tile_w, tile_h = 80 * scale, 40 * scale
    cols = 4
    rows = math.ceil(len(paths) / cols)

    preview = Image.new(
        "RGBA",
        (cols * tile_w + 32, rows * tile_h + 32),
        (237, 240, 229, 255),
    )

    for i, path in enumerate(paths):
        tile = Image.open(path).convert("RGBA").resize(
            (tile_w, tile_h),
            Image.Resampling.NEAREST,
        )
        x = 16 + (i % cols) * tile_w
        y = 16 + (i // cols) * tile_h
        preview.alpha_composite(tile, (x, y))

    out = PREVIEW_DIR / out_name
    preview.save(out, "PNG", optimize=True)
    print(f"✅ preview {out}")


def main():
    require(GRASS_TEX)
    require(EARTH_TEX)

    grass_tex = Image.open(GRASS_TEX).convert("RGBA")
    earth_tex = Image.open(EARTH_TEX).convert("RGBA")

    border_paths: list[Path] = []
    skirt_paths: list[Path] = []

    for i in range(12):
        path = SPRITES / f"{GRASS_BORDER_PREFIX}{i:02}.png"
        require(path)
        border_paths.append(path)

    for i in range(6):
        path = SPRITES / f"{SKIRT_PREFIX}{i:02}.png"
        require(path)
        skirt_paths.append(path)

    print("PREMIUM ISLAND EDGES")
    print("====================")

    for i, path in enumerate(border_paths):
        process_grass_border(path, grass_tex, i)

    for i, path in enumerate(skirt_paths):
        process_skirt(path, earth_tex, i)

    build_preview(border_paths, "premium_island_edges_borders.png")
    build_preview(skirt_paths, "premium_island_edges_skirts.png")

    print()
    print("✅ Terminé.")
    print("Aucun TMX modifié.")
    print("Aucun TSX modifié.")
    print("Seuls les PNG candidate ont été réécrits.")


if __name__ == "__main__":
    main()

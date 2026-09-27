#!/usr/bin/env python3

from __future__ import annotations

import json
import shutil
import xml.etree.ElementTree as ET
from pathlib import Path

from PIL import Image


ROOT = Path(__file__).resolve().parents[1]

SPRITES = ROOT / "assets" / "sprites"
MAPS = ROOT / "assets" / "maps"
SURFACE = ROOT / "assets" / "surface_sources"

CANDIDATE_MAP = MAPS / "potager_diorama_v1.tmx"
NEW_TSX = MAPS / "ground_new_da.tsx"

GRASS_TEXTURE = SURFACE / "potager_texture_herbe_source.png"
EARTH_TEXTURE = SURFACE / "potager_texture_terre_cultivee_source.png"
SKIRT_TEXTURE = SURFACE / "potager_texture_bordure_terre_source.png"


# ---------------------------------------------------------------------------
# Existing production ground ordering.
# We preserve EXACTLY the same tile ids:
#
#   0..11  grass edges
#  12..16  grass
#  17..27  cultivated earth
#  28..33  island earth skirt
#
# Because the order stays identical, potager_diorama_v1.tmx keeps all its
# existing GIDs. We only swap ground.tsx -> ground_new_da.tsx.
# ---------------------------------------------------------------------------

GROUPS = [
    {
        "start": 0,
        "count": 12,
        "old_prefix": "commun_sol_bordure_herbe_tile_",
        "new_prefix": "potager_newda_sol_bordure_herbe_tile_",
        "texture": GRASS_TEXTURE,
    },
    {
        "start": 12,
        "count": 5,
        "old_prefix": "commun_sol_herbe_tile_",
        "new_prefix": "potager_newda_sol_herbe_tile_",
        "texture": GRASS_TEXTURE,
    },
    {
        "start": 17,
        "count": 11,
        "old_prefix": "commun_sol_terre_tile_",
        "new_prefix": "potager_newda_sol_terre_tile_",
        "texture": EARTH_TEXTURE,
    },
    {
        "start": 28,
        "count": 6,
        "old_prefix": "commun_sol_tranche_terre_tile_",
        "new_prefix": "potager_newda_sol_tranche_terre_tile_",
        "texture": SKIRT_TEXTURE,
    },
]


def require(path: Path):
    if not path.exists():
        raise SystemExit(f"Fichier manquant : {path}")


def texture_patch(
    texture: Image.Image,
    index: int,
    width: int = 80,
    height: int = 40,
) -> Image.Image:
    """
    Sample a deterministic 160x80 area, then downsample to 80x40.

    This avoids obvious repetition and gives a softer painted result.
    """

    source_w = width * 2
    source_h = height * 2

    max_x = texture.width - source_w
    max_y = texture.height - source_h

    if max_x < 0 or max_y < 0:
        raise ValueError(
            f"Texture source too small: {texture.size}"
        )

    # Deterministic pseudo-random offsets.
    x = (37 + index * 83) % (max_x + 1)
    y = (19 + index * 61) % (max_y + 1)

    patch = texture.crop(
        (
            x,
            y,
            x + source_w,
            y + source_h,
        )
    )

    return patch.resize(
        (width, height),
        Image.Resampling.LANCZOS,
    )


def apply_mask(
    material: Image.Image,
    mask_source: Image.Image,
) -> Image.Image:
    """
    Keep EXACTLY the existing tile alpha geometry.

    Only the RGB material changes.
    """

    if material.size != mask_source.size:
        raise ValueError(
            f"size mismatch: material={material.size}, mask={mask_source.size}"
        )

    result = material.convert("RGBA")

    old_alpha = mask_source.convert("RGBA").getchannel("A")

    result.putalpha(old_alpha)

    return result


def generate_tiles():
    textures = {
        GRASS_TEXTURE: Image.open(GRASS_TEXTURE).convert("RGBA"),
        EARTH_TEXTURE: Image.open(EARTH_TEXTURE).convert("RGBA"),
        SKIRT_TEXTURE: Image.open(SKIRT_TEXTURE).convert("RGBA"),
    }

    generated: list[str] = []

    global_index = 0

    for group in GROUPS:
        texture = textures[group["texture"]]

        for local_index in range(group["count"]):
            old_name = f'{group["old_prefix"]}{local_index:02}.png'
            new_name = f'{group["new_prefix"]}{local_index:02}.png'

            old_path = SPRITES / old_name
            new_path = SPRITES / new_name

            require(old_path)

            old_tile = Image.open(old_path).convert("RGBA")

            if old_tile.size != (80, 40):
                raise ValueError(
                    f"{old_name}: expected 80x40, got {old_tile.size}"
                )

            material = texture_patch(
                texture,
                global_index,
            )

            result = apply_mask(
                material,
                old_tile,
            )

            result.save(
                new_path,
                "PNG",
                optimize=True,
            )

            generated.append(new_name)

            print(
                f"✓ tile {global_index:02}: "
                f"{old_name} -> {new_name}"
            )

            global_index += 1

    if len(generated) != 34:
        raise RuntimeError(
            f"Expected 34 tiles, got {len(generated)}"
        )

    return generated


def write_tsx(generated: list[str]):
    tileset = ET.Element(
        "tileset",
        {
            "version": "1.10",
            "tiledversion": "1.11.2",
            "name": "ground_new_da",
            "tilewidth": "80",
            "tileheight": "40",
            "tilecount": str(len(generated)),
            "columns": "0",
            "objectalignment": "bottom",
        },
    )

    for tile_id, image_name in enumerate(generated):
        tile = ET.SubElement(
            tileset,
            "tile",
            {
                "id": str(tile_id),
            },
        )

        ET.SubElement(
            tile,
            "image",
            {
                "source": f"../sprites/{image_name}",
                "width": "80",
                "height": "40",
            },
        )

    ET.indent(
        tileset,
        space="  ",
    )

    tree = ET.ElementTree(tileset)

    tree.write(
        NEW_TSX,
        encoding="utf-8",
        xml_declaration=True,
    )

    # Match repo formatting convention.
    with NEW_TSX.open("ab") as f:
        f.write(b"\n")

    print()
    print(f"✅ TSX écrit : {NEW_TSX}")


def patch_candidate_map():
    tree = ET.parse(
        CANDIDATE_MAP
    )

    root = tree.getroot()

    ground_ref = None

    for tileset in root.findall("tileset"):
        if tileset.get("firstgid") == "1":
            ground_ref = tileset
            break

    if ground_ref is None:
        raise RuntimeError(
            "Candidate map has no firstgid=1 tileset"
        )

    old_source = ground_ref.get("source")

    if old_source not in (
        "ground.tsx",
        "ground_new_da.tsx",
    ):
        raise RuntimeError(
            f"Unexpected candidate ground source: {old_source}"
        )

    ground_ref.set(
        "source",
        "ground_new_da.tsx",
    )

    ET.indent(
        tree,
        space="  ",
    )

    tree.write(
        CANDIDATE_MAP,
        encoding="utf-8",
        xml_declaration=True,
    )

    print()
    print(
        "✅ potager_diorama_v1.tmx : "
        "ground.tsx -> ground_new_da.tsx"
    )


def build_preview(generated: list[str]):
    preview_dir = (
        ROOT
        / "docs"
        / "visual-review"
        / "texture-pass"
    )

    preview_dir.mkdir(
        parents=True,
        exist_ok=True,
    )

    scale = 4

    tile_w = 80 * scale
    tile_h = 40 * scale

    columns = 6
    rows = 6

    canvas = Image.new(
        "RGBA",
        (
            columns * tile_w,
            rows * tile_h,
        ),
        (235, 239, 225, 255),
    )

    for i, name in enumerate(generated):
        tile = Image.open(
            SPRITES / name
        ).convert("RGBA")

        tile = tile.resize(
            (
                tile_w,
                tile_h,
            ),
            Image.Resampling.NEAREST,
        )

        x = (i % columns) * tile_w
        y = (i // columns) * tile_h

        canvas.alpha_composite(
            tile,
            (x, y),
        )

    path = (
        preview_dir
        / "ground_new_da_tiles.png"
    )

    canvas.save(
        path,
        "PNG",
        optimize=True,
    )

    print(
        f"✅ preview : {path}"
    )


def sanity_check_production():
    """
    Make absolutely sure production still points to ground.tsx.
    """

    prod = MAPS / "potager.tmx"

    require(prod)

    tree = ET.parse(prod)

    root = tree.getroot()

    first = root.find("tileset")

    if first is None:
        raise RuntimeError(
            "potager.tmx has no tileset"
        )

    if first.get("source") != "ground.tsx":
        raise RuntimeError(
            "STOP: potager.tmx no longer references ground.tsx"
        )

    print(
        "✅ potager.tmx untouched"
    )


def main():
    print("NEW DA — GROUND MATERIAL PASS")
    print("=============================")
    print()

    for source in (
        GRASS_TEXTURE,
        EARTH_TEXTURE,
        SKIRT_TEXTURE,
        CANDIDATE_MAP,
    ):
        require(source)

    sanity_check_production()

    generated = generate_tiles()

    write_tsx(
        generated,
    )

    patch_candidate_map()

    build_preview(
        generated,
    )

    print()
    print("================================")
    print("✅ NEW DA GROUND READY")
    print("================================")
    print()
    print("Production:")
    print("  assets/maps/potager.tmx")
    print("  -> unchanged")
    print()
    print("Candidate:")
    print("  assets/maps/potager_diorama_v1.tmx")
    print("  -> ground_new_da.tsx")
    print()
    print("Open the candidate map in Tiled.")
    print("No GID remapping was required.")


if __name__ == "__main__":
    main()

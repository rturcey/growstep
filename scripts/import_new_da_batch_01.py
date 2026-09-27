#!/usr/bin/env python3

from __future__ import annotations

import io
import json
import math
import sys
import xml.etree.ElementTree as ET
from collections import deque
from pathlib import Path
from zipfile import ZIP_DEFLATED, ZIP_STORED, ZipFile

import yaml
from PIL import Image


ROOT = Path(__file__).resolve().parents[1]

ATLAS = ROOT / "assets/reference/new_da_atlas.png"

SOURCES = ROOT / "assets/sprite_sources"
SPRITES = ROOT / "assets/sprites"
EXPORT_3X = ROOT / "assets/sprite_exports/3.0x"
EXPORT_2X = ROOT / "assets/sprite_exports/2.0x"

MANIFEST = SPRITES / "manifest.json"
AUDIT = ROOT / "assets/maps/palette_audit.json"

ALPHA_THRESHOLD = 10
MASTER_MARGIN = 8  # 4x pixels


# ---------------------------------------------------------------------------
# Each ROI contains exactly one wanted subject plus, in a few cases, fragments
# from a neighbour. Component rules below explicitly reject those fragments.
#
# source ROI = x0, y0, x1, y1 in the 1448x1086 generated reference atlas.
# ---------------------------------------------------------------------------

ASSETS = [
    {
        "id": "potager_decor_arche_fleurie_statique_ordinaire_00",
        "roi": (0, 20, 310, 390),
        "component_mode": "largest",
        "canvas_1x": (112, 104),
        "max_visible_1x": (104, 96),
        "footprint_grid": [1.5, 0.5],
        "size_class": "large_decor",
        "palette_roles": [
            "bois_chaud",
            "feuillage_sauge",
            "blanc_floral",
        ],
    },
    {
        "id": "potager_decor_arbre_nichoir_statique_ordinaire_00",
        "roi": (280, 0, 620, 440),
        # Keep main tree + disconnected vegetation at its own base,
        # while rejecting little fragments touching the left crop boundary.
        "component_mode": "large_non_border",
        "min_component_pixels": 1000,
        "canvas_1x": (140, 150),
        "max_visible_1x": (132, 142),
        "footprint_grid": [1.5, 1.5],
        "size_class": "tree",
        "palette_roles": [
            "bois_chaud",
            "feuillage_sauge",
            "feuillage_profond",
            "blanc_floral",
        ],
    },
    {
        "id": "potager_decor_pommier_fruits_statique_ordinaire_00",
        "roi": (600, 0, 970, 460),
        "component_mode": "large_non_border",
        "min_component_pixels": 700,
        "canvas_1x": (140, 150),
        "max_visible_1x": (132, 142),
        "footprint_grid": [1.5, 1.5],
        "size_class": "tree",
        "palette_roles": [
            "bois_chaud",
            "feuillage_sauge",
            "feuillage_profond",
            "rouge_fruit",
        ],
    },
    {
        "id": "potager_decor_banc_parc_statique_ordinaire_00",
        "roi": (0, 375, 290, 615),
        "component_mode": "largest",
        "canvas_1x": (104, 72),
        "max_visible_1x": (96, 64),
        "footprint_grid": [1.5, 0.5],
        "size_class": "large_decor",
        "palette_roles": [
            "bois_chaud",
        ],
    },
    {
        "id": "potager_decor_bain_oiseaux_statique_ordinaire_00",
        "roi": (300, 380, 475, 615),
        "component_mode": "largest",
        "canvas_1x": (80, 80),
        "max_visible_1x": (72, 72),
        "footprint_grid": [1.0, 1.0],
        "size_class": "small_decor",
        "palette_roles": [
            "pierre_creme",
            "bleu_doux",
        ],
    },
]


def flood_components(image: Image.Image):
    alpha = image.getchannel("A")
    width, height = image.size
    px = alpha.load()

    visited = bytearray(width * height)

    components = []

    def index(x, y):
        return y * width + x

    for sy in range(height):
        for sx in range(width):
            key = index(sx, sy)

            if visited[key]:
                continue

            visited[key] = 1

            if px[sx, sy] <= ALPHA_THRESHOLD:
                continue

            q = deque([(sx, sy)])
            points = []

            min_x = max_x = sx
            min_y = max_y = sy

            while q:
                x, y = q.popleft()
                points.append((x, y))

                min_x = min(min_x, x)
                max_x = max(max_x, x)
                min_y = min(min_y, y)
                max_y = max(max_y, y)

                for nx, ny in (
                    (x - 1, y),
                    (x + 1, y),
                    (x, y - 1),
                    (x, y + 1),
                ):
                    if nx < 0 or ny < 0 or nx >= width or ny >= height:
                        continue

                    nkey = index(nx, ny)

                    if visited[nkey]:
                        continue

                    visited[nkey] = 1

                    if px[nx, ny] > ALPHA_THRESHOLD:
                        q.append((nx, ny))

            components.append(
                {
                    "points": points,
                    "count": len(points),
                    "bbox": (
                        min_x,
                        min_y,
                        max_x + 1,
                        max_y + 1,
                    ),
                }
            )

    return components


def touches_border(component, size):
    width, height = size
    x0, y0, x1, y1 = component["bbox"]

    return (
        x0 <= 0
        or y0 <= 0
        or x1 >= width
        or y1 >= height
    )


def isolate(image: Image.Image, config: dict) -> Image.Image:
    components = flood_components(image)

    if not components:
        raise RuntimeError(f'{config["id"]}: no visible component')

    components.sort(
        key=lambda c: c["count"],
        reverse=True,
    )

    mode = config["component_mode"]

    if mode == "largest":
        selected = [components[0]]

    elif mode == "large_non_border":
        minimum = config["min_component_pixels"]

        selected = [
            component
            for component in components
            if (
                component["count"] >= minimum
                and not touches_border(component, image.size)
            )
        ]

        # Main sprite must always survive even if its alpha happens to touch a
        # crop boundary by one anti-aliased pixel.
        if components[0] not in selected:
            selected.insert(0, components[0])

    else:
        raise ValueError(mode)

    mask = Image.new(
        "L",
        image.size,
        0,
    )
    mask_px = mask.load()

    for component in selected:
        for x, y in component["points"]:
            mask_px[x, y] = image.getchannel("A").getpixel((x, y))

    result = Image.new(
        "RGBA",
        image.size,
        (0, 0, 0, 0),
    )
    result.paste(
        image,
        (0, 0),
        mask,
    )

    bbox = result.getchannel("A").getbbox()

    if bbox is None:
        raise RuntimeError(f'{config["id"]}: empty isolated sprite')

    # Add a little clean transparent breathing room.
    x0, y0, x1, y1 = bbox

    x0 = max(0, x0 - 4)
    y0 = max(0, y0 - 4)
    x1 = min(result.width, x1 + 4)
    y1 = min(result.height, y1 + 4)

    return result.crop((x0, y0, x1, y1))


def fit_to_master(
    isolated: Image.Image,
    config: dict,
):
    canvas_1x = config["canvas_1x"]
    max_visible_1x = config["max_visible_1x"]

    canvas_size = (
        canvas_1x[0] * 4,
        canvas_1x[1] * 4,
    )

    max_visible = (
        max_visible_1x[0] * 4,
        max_visible_1x[1] * 4,
    )

    factor = min(
        max_visible[0] / isolated.width,
        max_visible[1] / isolated.height,
    )

    visible_size = (
        max(1, round(isolated.width * factor)),
        max(1, round(isolated.height * factor)),
    )

    resized = isolated.resize(
        visible_size,
        Image.Resampling.LANCZOS,
    )

    master = Image.new(
        "RGBA",
        canvas_size,
        (0, 0, 0, 0),
    )

    # Growstep sprites are bottom/contact aligned.
    x = (master.width - resized.width) // 2
    y = master.height - resized.height - MASTER_MARGIN

    master.alpha_composite(
        resized,
        (x, y),
    )

    bbox = master.getchannel("A").getbbox()

    if bbox is None:
        raise RuntimeError(f'{config["id"]}: empty normalized master')

    # Contact centered horizontally, ground-aligned.
    anchor = [
        master.width // 2,
        bbox[3] - 1,
    ]

    return master, anchor


def png_bytes(image: Image.Image):
    buffer = io.BytesIO()

    image.save(
        buffer,
        "PNG",
        optimize=True,
    )

    return buffer.getvalue()


def write_ora(sprite_id: str, master: Image.Image):
    destination = SOURCES / f"{sprite_id}.ora"

    image = ET.Element(
        "image",
        {
            "w": str(master.width),
            "h": str(master.height),
            "name": sprite_id,
            "version": "0.0.1",
        },
    )

    stack = ET.SubElement(image, "stack")

    ET.SubElement(
        stack,
        "layer",
        {
            "name": "art",
            "src": "data/art.png",
            "x": "0",
            "y": "0",
            "opacity": "1.0",
            "visibility": "visible",
            "composite-op": "svg:src-over",
        },
    )

    payload = png_bytes(master)

    with ZipFile(destination, "w") as archive:
        archive.writestr(
            "mimetype",
            b"image/openraster",
            compress_type=ZIP_STORED,
        )

        archive.writestr(
            "stack.xml",
            ET.tostring(
                image,
                encoding="utf-8",
                xml_declaration=True,
            ),
            compress_type=ZIP_DEFLATED,
        )

        archive.writestr(
            "data/art.png",
            payload,
            compress_type=ZIP_DEFLATED,
        )

        archive.writestr(
            "mergedimage.png",
            payload,
            compress_type=ZIP_DEFLATED,
        )


def write_yaml(
    config: dict,
    anchor: list[int],
):
    data = {
        "id": config["id"],
        "canvas_1x": list(config["canvas_1x"]),
        "anchor_4x": anchor,
        "footprint_grid": config["footprint_grid"],
        "size_class": config["size_class"],
        "projection": "isometric_80x40",
        "light": "upper_left",
        "shadow": "separate_contact",
        "palette_roles": config["palette_roles"],
        "state": config.get("state", "statique"),
        "variant": "ordinaire",
        "frames": 1,
    }

    destination = SOURCES / f'{config["id"]}.yaml'

    destination.write_text(
        yaml.safe_dump(
            data,
            sort_keys=False,
            allow_unicode=True,
        ),
        encoding="utf-8",
    )


def write_exports(
    sprite_id: str,
    master: Image.Image,
):
    master.save(
        SPRITES / f"{sprite_id}.png",
        "PNG",
        optimize=True,
    )

    for scale, destination in (
        (3, EXPORT_3X),
        (2, EXPORT_2X),
    ):
        size = (
            master.width * scale // 4,
            master.height * scale // 4,
        )

        master.resize(
            size,
            Image.Resampling.LANCZOS,
        ).save(
            destination / f"{sprite_id}.png",
            "PNG",
            optimize=True,
        )


def main():
    if not ATLAS.exists():
        raise SystemExit(
            f"Missing atlas: {ATLAS}\n"
            "Copy the generated reference atlas there first."
        )

    for directory in (
        SOURCES,
        SPRITES,
        EXPORT_3X,
        EXPORT_2X,
    ):
        directory.mkdir(
            parents=True,
            exist_ok=True,
        )

    atlas = Image.open(ATLAS).convert("RGBA")

    if atlas.size != (1448, 1086):
        raise SystemExit(
            f"Unexpected atlas dimensions: {atlas.size}; "
            "expected 1448x1086"
        )

    manifest = json.loads(
        MANIFEST.read_text(encoding="utf-8")
    )

    audit = json.loads(
        AUDIT.read_text(encoding="utf-8")
    )

    print("NEW DA — BATCH 01")
    print("=================")

    created = []

    for config in ASSETS:
        sprite_id = config["id"]

        x0, y0, x1, y1 = config["roi"]

        source = atlas.crop(
            (x0, y0, x1, y1)
        )

        isolated = isolate(
            source,
            config,
        )

        master, anchor = fit_to_master(
            isolated,
            config,
        )

        write_ora(
            sprite_id,
            master,
        )

        write_yaml(
            config,
            anchor,
        )

        write_exports(
            sprite_id,
            master,
        )

        alpha = master.getchannel("A")
        runtime_bbox = alpha.point(
            lambda value: 255 if value > 32 else 0
        ).getbbox()

        manifest[f"{sprite_id}.png"] = {
            "width": master.width,
            "height": master.height,
            "bbox": list(runtime_bbox),
            "anchor": anchor,
            "shadow": "separate_contact",
        }

        # Not inserted into palettes yet. Batch 02 will only happen after
        # visual validation of these five.
        audit[f"{sprite_id}.png"] = {
            "status": "excluded",
        }

        created.append(sprite_id)

        print(
            f"✓ {sprite_id}\n"
            f"  canvas={master.width}x{master.height}"
            f" anchor={anchor}"
        )

    MANIFEST.write_text(
        json.dumps(
            manifest,
            indent=2,
            ensure_ascii=False,
        )
        + "\n",
        encoding="utf-8",
    )

    AUDIT.write_text(
        json.dumps(
            audit,
            indent=2,
            ensure_ascii=False,
        )
        + "\n",
        encoding="utf-8",
    )

    print()
    print("Targeted validation")
    print("-------------------")

    # Validate ONLY our five new sprites. The repository still contains
    # historical validator debt unrelated to this batch.
    sys.path.insert(
        0,
        str(ROOT / "scripts"),
    )

    from validate_sprites import validate_sheet

    fresh_manifest = json.loads(
        MANIFEST.read_text(encoding="utf-8")
    )

    errors = []

    for sprite_id in created:
        errors.extend(
            validate_sheet(
                SOURCES / f"{sprite_id}.yaml",
                ROOT,
                fresh_manifest,
            )
        )

    if errors:
        print()
        print("❌ TARGETED VALIDATION FAILED")

        for error in errors:
            print(error)

        raise SystemExit(1)

    print("✅ all 5 sprites satisfy the Growstep sprite contract")

    print()
    print("Inspect these five files visually:")
    for sprite_id in created:
        print(f"  assets/sprites/{sprite_id}.png")

    print()
    print("Do NOT integrate them into Tiled yet.")


if __name__ == "__main__":
    main()

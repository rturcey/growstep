#!/usr/bin/env python3

from __future__ import annotations

import colorsys
import json
import sys
from pathlib import Path

from PIL import Image, ImageFilter

from import_new_da_batch_01 import (
    ROOT,
    SOURCES,
    SPRITES,
    EXPORT_3X,
    EXPORT_2X,
    MANIFEST,
    AUDIT,
    fit_to_master,
    write_ora,
    write_yaml,
    write_exports,
)


SHEET = ROOT / "assets/reference/plants/potager_growth_sheet.png"

PREFIX = "potager_plante_tomate"

# Crops vérifiés sur la planche 1448×1086.
#
# On cadre volontairement AUTOUR DE LA PLANTE et pas autour du bac.
STAGES = [
    {
        "state": "graine_germee",
        "bbox": (320, 60, 430, 170),
    },
    {
        "state": "jeune",
        "bbox": (530, 10, 715, 175),
    },
    {
        "state": "presque_mature",
        "bbox": (790, 0, 1010, 180),
    },
    {
        "state": "recoltable",
        "bbox": (1090, 0, 1320, 190),
    },
]


def is_green(r: int, g: int, b: int) -> bool:
    h, s, v = colorsys.rgb_to_hsv(
        r / 255,
        g / 255,
        b / 255,
    )

    return (
        0.17 <= h <= 0.48
        and s >= 0.22
        and v >= 0.14
    )


def is_red_fruit(r: int, g: int, b: int) -> bool:
    # Beaucoup plus strict qu'un simple hue rouge :
    # évite de conserver le bois brun du bac.
    return (
        r >= 145
        and g <= 105
        and b <= 95
        and r >= g * 1.75
        and r - b >= 55
    )


def is_yellow_flower(
    r: int,
    g: int,
    b: int,
) -> bool:
    h, s, v = colorsys.rgb_to_hsv(
        r / 255,
        g / 255,
        b / 255,
    )

    return (
        0.10 <= h <= 0.18
        and s >= 0.55
        and v >= 0.70
    )


def is_support_brown(
    r: int,
    g: int,
    b: int,
) -> bool:
    h, s, v = colorsys.rgb_to_hsv(
        r / 255,
        g / 255,
        b / 255,
    )

    return (
        0.03 <= h <= 0.15
        and s >= 0.25
        and 0.18 <= v <= 0.90
    )


def dilate(
    mask: list[list[bool]],
    radius: int,
) -> list[list[bool]]:
    height = len(mask)
    width = len(mask[0])

    result = [
        [False] * width
        for _ in range(height)
    ]

    points = [
        (x, y)
        for y in range(height)
        for x in range(width)
        if mask[y][x]
    ]

    r2 = radius * radius

    for x, y in points:
        for yy in range(
            max(0, y - radius),
            min(height, y + radius + 1),
        ):
            for xx in range(
                max(0, x - radius),
                min(width, x + radius + 1),
            ):
                if (
                    (xx - x) ** 2
                    + (yy - y) ** 2
                    <= r2
                ):
                    result[yy][xx] = True

    return result


def remove_small_components(
    mask: list[list[bool]],
    minimum: int = 15,
) -> list[list[bool]]:
    height = len(mask)
    width = len(mask[0])

    visited = set()
    result = [
        [False] * width
        for _ in range(height)
    ]

    for y in range(height):
        for x in range(width):
            if not mask[y][x]:
                continue

            if (x, y) in visited:
                continue

            stack = [(x, y)]
            visited.add((x, y))

            component = []

            while stack:
                px, py = stack.pop()
                component.append((px, py))

                for nx, ny in (
                    (px - 1, py),
                    (px + 1, py),
                    (px, py - 1),
                    (px, py + 1),
                ):
                    if not (
                        0 <= nx < width
                        and 0 <= ny < height
                    ):
                        continue

                    if not mask[ny][nx]:
                        continue

                    if (nx, ny) in visited:
                        continue

                    visited.add((nx, ny))
                    stack.append((nx, ny))

            if len(component) < minimum:
                continue

            for px, py in component:
                result[py][px] = True

    return result


def extract_tomato(
    source: Image.Image,
) -> Image.Image:
    """
    Isole le pied de tomate de la planche.

    Le bac/terre/contour ne sont PAS copiés dans le sprite final.
    """

    source = source.convert("RGBA")

    width, height = source.size
    pixels = source.load()

    plant = [
        [False] * width
        for _ in range(height)
    ]

    supports = [
        [False] * width
        for _ in range(height)
    ]

    center_x = width / 2

    for y in range(height):
        for x in range(width):
            r, g, b, a = pixels[x, y]

            if a <= 10:
                continue

            green = is_green(r, g, b)
            red = is_red_fruit(r, g, b)

            # Fleurs jaunes seulement dans la partie haute.
            yellow = (
                y < height * 0.62
                and is_yellow_flower(r, g, b)
            )

            keep = green or red or yellow

            # Dans le bas du crop, les coins sont presque toujours
            # l'herbe décorative / le cadre du bac.
            if (
                y >= height * 0.60
                and (
                    x < width * 0.18
                    or x > width * 0.82
                )
            ):
                keep = False

            if keep:
                plant[y][x] = True

            # Tuteur central de la tomate.
            #
            # Très étroit volontairement pour ne pas récupérer
            # les bordures bois du bac.
            if (
                abs(x - center_x)
                <= max(3, width * 0.035)
                and y < height * 0.86
                and is_support_brown(r, g, b)
            ):
                supports[y][x] = True

    near_plant = dilate(
        plant,
        radius=6,
    )

    combined = [
        [
            plant[y][x]
            or (
                supports[y][x]
                and near_plant[y][x]
            )
            for x in range(width)
        ]
        for y in range(height)
    ]

    combined = remove_small_components(
        combined,
        minimum=15,
    )

    mask = Image.new(
        "L",
        (width, height),
        0,
    )

    mask_pixels = mask.load()

    for y in range(height):
        for x in range(width):
            if combined[y][x]:
                mask_pixels[x, y] = 255

    # Anti-aliasing très léger des bords.
    mask = mask.filter(
        ImageFilter.GaussianBlur(0.35)
    )

    result = Image.new(
        "RGBA",
        source.size,
        (0, 0, 0, 0),
    )

    result.paste(
        source,
        (0, 0),
        mask,
    )

    bbox = result.getchannel("A").getbbox()

    if bbox is None:
        raise RuntimeError(
            "Extraction tomate vide"
        )

    left, top, right, bottom = bbox

    margin = 6

    left = max(0, left - margin)
    top = max(0, top - margin)
    right = min(width, right + margin)
    bottom = min(height, bottom + margin)

    return result.crop(
        (left, top, right, bottom)
    )


def main():
    if not SHEET.exists():
        raise SystemExit(
            f"Planche absente : {SHEET}\n\n"
            "Place la planche potager générée sous :\n"
            "assets/reference/plants/potager_growth_sheet.png"
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

    sheet = Image.open(
        SHEET
    ).convert("RGBA")

    if sheet.size != (1448, 1086):
        raise SystemExit(
            f"Dimensions inattendues : {sheet.size}; "
            "attendu : 1448x1086"
        )

    manifest = json.loads(
        MANIFEST.read_text(
            encoding="utf-8"
        )
    )

    audit = json.loads(
        AUDIT.read_text(
            encoding="utf-8"
        )
    )

    created = []

    print("NEW DA — TOMATE 4 STADES")
    print("========================")

    for stage in STAGES:
        state = stage["state"]

        sprite_id = (
            f"{PREFIX}_{state}_ordinaire_00"
        )

        crop = sheet.crop(
            stage["bbox"]
        )

        isolated = extract_tomato(
            crop
        )

        config = {
            "id": sprite_id,

            # 80×80 logique :
            # compatible small_plant et assez généreux pour le
            # pied mature sans le rendre énorme à l'écran.
            "canvas_1x": (80, 80),

            "max_visible_1x": (72, 72),

            "footprint_grid": [0.5, 0.5],

            "size_class": "small_plant",

            "palette_roles": [
                "feuillage_sauge",
                "feuillage_profond",
                "rouge_fruit",
                "jaune",
            ],

            "state": state,
        }

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

        runtime_bbox = (
            master
            .getchannel("A")
            .point(
                lambda value:
                255 if value > 32 else 0
            )
            .getbbox()
        )

        if runtime_bbox is None:
            raise RuntimeError(
                f"{sprite_id}: aucun pixel visible"
            )

        manifest[
            f"{sprite_id}.png"
        ] = {
            "width": master.width,
            "height": master.height,
            "bbox": list(runtime_bbox),
            "anchor": anchor,
            "shadow": "separate_contact",
        }

        # Les cultures sont dynamiques :
        # elles ne doivent pas entrer dans les palettes Tiled.
        audit[
            f"{sprite_id}.png"
        ] = {
            "status": "outside_tiled",
        }

        created.append(sprite_id)

        print(
            f"✓ {state:16} "
            f"{isolated.width}x{isolated.height} "
            f"-> {master.width}x{master.height}"
        )

    MANIFEST.write_text(
        json.dumps(
            manifest,
            indent=2,
            ensure_ascii=False,
        ) + "\n",
        encoding="utf-8",
    )

    AUDIT.write_text(
        json.dumps(
            audit,
            indent=2,
            ensure_ascii=False,
        ) + "\n",
        encoding="utf-8",
    )

    # Validation ciblée.
    sys.path.insert(
        0,
        str(ROOT / "scripts"),
    )

    from validate_sprites import validate_sheet

    fresh_manifest = json.loads(
        MANIFEST.read_text(
            encoding="utf-8"
        )
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
        print("❌ VALIDATION FAILED")

        for error in errors:
            print(error)

        raise SystemExit(1)

    print()
    print("✅ Tomate : 4 stades importés.")
    print()
    print("À vérifier :")

    for sprite_id in created:
        print(
            f"  assets/sprites/{sprite_id}.png"
        )

    print()
    print(
        "Le runtime n'a PAS encore été modifié. "
        "On le fera une fois toutes les espèces importées."
    )


if __name__ == "__main__":
    main()

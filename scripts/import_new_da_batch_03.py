#!/usr/bin/env python3

from __future__ import annotations

import json
import sys
from pathlib import Path

from PIL import Image

from import_new_da_batch_01 import (
    ROOT,
    ATLAS,
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


# Bounding boxes vérifiées directement sur l'atlas 1448x1086.
ASSETS = [
    {
        "id": "potager_decor_hortensia_rose_statique_ordinaire_00",
        "bbox": (31, 618, 224, 761),
        "canvas_1x": (72, 60),
        "max_visible_1x": (64, 52),
        "footprint_grid": [1.0, 0.5],
        "size_class": "small_decor",
        "palette_roles": [
            "rose",
            "feuillage_sauge",
            "feuillage_profond",
        ],
    },
    {
        "id": "potager_decor_lavande_massif_statique_ordinaire_00",
        "bbox": (240, 613, 412, 760),
        "canvas_1x": (68, 60),
        "max_visible_1x": (60, 52),
        "footprint_grid": [1.0, 0.5],
        "size_class": "small_decor",
        "palette_roles": [
            "violet",
            "feuillage_sauge",
            "feuillage_profond",
        ],
    },
    {
        "id": "potager_decor_marguerites_massif_statique_ordinaire_00",
        "bbox": (429, 627, 603, 770),
        "canvas_1x": (68, 58),
        "max_visible_1x": (60, 50),
        "footprint_grid": [1.0, 0.5],
        "size_class": "small_decor",
        "palette_roles": [
            "blanc_floral",
            "jaune",
            "feuillage_sauge",
            "feuillage_profond",
        ],
    },
    {
        "id": "potager_decor_fleurs_jaunes_massif_statique_ordinaire_00",
        "bbox": (610, 631, 815, 768),
        "canvas_1x": (76, 58),
        "max_visible_1x": (68, 50),
        "footprint_grid": [1.0, 0.5],
        "size_class": "small_decor",
        "palette_roles": [
            "jaune",
            "feuillage_sauge",
            "feuillage_profond",
        ],
    },
    {
        "id": "potager_decor_fraisier_massif_statique_ordinaire_00",
        "bbox": (828, 622, 1011, 768),
        "canvas_1x": (72, 60),
        "max_visible_1x": (64, 52),
        "footprint_grid": [1.0, 0.5],
        "size_class": "small_decor",
        "palette_roles": [
            "rouge_fruit",
            "blanc_floral",
            "feuillage_sauge",
            "feuillage_profond",
        ],
    },
]


def crop_exact(atlas: Image.Image, bbox):
    x0, y0, x1, y1 = bbox

    # 4 px de marge transparente propre.
    crop = atlas.crop((x0, y0, x1, y1))

    result = Image.new(
        "RGBA",
        (crop.width + 8, crop.height + 8),
        (0, 0, 0, 0),
    )

    result.alpha_composite(crop, (4, 4))

    return result


def main():
    if not ATLAS.exists():
        raise SystemExit(f"Atlas introuvable : {ATLAS}")

    for directory in (
        SOURCES,
        SPRITES,
        EXPORT_3X,
        EXPORT_2X,
    ):
        directory.mkdir(parents=True, exist_ok=True)

    atlas = Image.open(ATLAS).convert("RGBA")

    if atlas.size != (1448, 1086):
        raise SystemExit(
            f"Dimensions atlas inattendues : {atlas.size}; "
            "attendu : 1448x1086"
        )

    manifest = json.loads(
        MANIFEST.read_text(encoding="utf-8")
    )

    audit = json.loads(
        AUDIT.read_text(encoding="utf-8")
    )

    created = []

    print("NEW DA — BATCH 03")
    print("=================")

    for config in ASSETS:
        sprite_id = config["id"]

        source = crop_exact(
            atlas,
            config["bbox"],
        )

        master, anchor = fit_to_master(
            source,
            config,
        )

        write_ora(sprite_id, master)
        write_yaml(config, anchor)
        write_exports(sprite_id, master)

        alpha = master.getchannel("A")

        runtime_bbox = alpha.point(
            lambda value: 255 if value > 32 else 0
        ).getbbox()

        if runtime_bbox is None:
            raise RuntimeError(
                f"{sprite_id}: sprite vide"
            )

        manifest[f"{sprite_id}.png"] = {
            "width": master.width,
            "height": master.height,
            "bbox": list(runtime_bbox),
            "anchor": anchor,
            "shadow": "separate_contact",
        }

        audit[f"{sprite_id}.png"] = {
            "status": "excluded",
        }

        created.append(sprite_id)

        print(
            f"✓ {sprite_id}\n"
            f"  source={config['bbox']}\n"
            f"  canvas={master.width}x{master.height}"
            f" anchor={anchor}"
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

    print()
    print("✅ Lot 3 validé techniquement.")
    print()
    print("À inspecter :")

    for sprite_id in created:
        print(f"  assets/sprites/{sprite_id}.png")


if __name__ == "__main__":
    main()

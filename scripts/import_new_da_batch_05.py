#!/usr/bin/env python3

from __future__ import annotations

import json
import sys

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
    isolate,
    fit_to_master,
    write_ora,
    write_yaml,
    write_exports,
)


ASSETS = [
    {
        "id": "potager_sol_pas_pierre_a_statique_ordinaire_00",
        "bbox": (398, 811, 506, 897),

        "canvas_1x": (80, 40),
        "max_visible_1x": (68, 34),

        "footprint_grid": [1.0, 1.0],
        "size_class": "terrain_cell",

        "palette_roles": [
            "pierre_creme",
            "herbe_principale",
        ],
    },

    {
        "id": "potager_sol_pas_pierre_b_statique_ordinaire_00",
        "bbox": (509, 810, 627, 896),

        "canvas_1x": (80, 40),
        "max_visible_1x": (70, 34),

        "footprint_grid": [1.0, 1.0],
        "size_class": "terrain_cell",

        "palette_roles": [
            "pierre_creme",
            "herbe_principale",
        ],
    },

    {
        "id": "potager_sol_pas_pierre_c_statique_ordinaire_00",
        "bbox": (628, 793, 788, 912),

        "canvas_1x": (80, 40),
        "max_visible_1x": (72, 34),

        "footprint_grid": [1.0, 1.0],
        "size_class": "terrain_cell",

        "palette_roles": [
            "pierre_creme",
            "herbe_principale",
        ],
    },

    {
        "id": "potager_decor_cadre_bac_bois_vide_statique_ordinaire_00",

        # BBOX COMPLETE du sprite.
        "bbox": (962, 771, 1178, 929),

        # On supprime uniquement les composantes étrangères
        # qui mordent dans le rectangle.
        "component_mode": "largest",

        "canvas_1x": (168, 104),
        "max_visible_1x": (156, 94),

        "footprint_grid": [2.0, 2.0],
        "size_class": "deep_cultivation_surround",

        "palette_roles": [
            "bois_chaud",
            "herbe_principale",
            "feuillage_sauge",
        ],
    },

    {
        "id": "potager_decor_bac_terre_bois_statique_ordinaire_00",

        # BBOX COMPLETE du sprite.
        "bbox": (1204, 774, 1420, 933),

        "component_mode": "largest",

        "canvas_1x": (168, 104),
        "max_visible_1x": (156, 94),

        "footprint_grid": [2.0, 2.0],
        "size_class": "deep_cultivation_surround",

        "palette_roles": [
            "bois_chaud",
            "terre_culture",
            "herbe_principale",
        ],
    },
]


def crop_exact(atlas: Image.Image, bbox):
    x0, y0, x1, y1 = bbox

    source = atlas.crop(
        (x0, y0, x1, y1)
    )

    result = Image.new(
        "RGBA",
        (
            source.width + 8,
            source.height + 8,
        ),
        (0, 0, 0, 0),
    )

    result.alpha_composite(
        source,
        (4, 4),
    )

    return result


def main():
    if not ATLAS.exists():
        raise SystemExit(
            f"Atlas introuvable : {ATLAS}"
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

    atlas = Image.open(
        ATLAS
    ).convert("RGBA")

    if atlas.size != (1448, 1086):
        raise SystemExit(
            f"Dimensions atlas inattendues : {atlas.size}; "
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

    print("NEW DA — BATCH 05")
    print("=================")

    for config in ASSETS:
        sprite_id = config["id"]

        source = crop_exact(
            atlas,
            config["bbox"],
        )

        # Pour les deux bacs :
        # conserve toute la composante principale,
        # supprime uniquement les pixels des sprites voisins.
        if config.get("component_mode"):
            source = isolate(
                source,
                config,
            )

        master, anchor = fit_to_master(
            source,
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
            f"  canvas={master.width}x{master.height}\n"
            f"  footprint={config['footprint_grid']}\n"
            f"  anchor={anchor}"
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
        print("❌ TARGETED VALIDATION FAILED")

        for error in errors:
            print(error)

        raise SystemExit(1)

    print()
    print("✅ Lot 5 validé techniquement.")

    for sprite_id in created:
        print(
            f"  assets/sprites/{sprite_id}.png"
        )


if __name__ == "__main__":
    main()

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
        "id": "potager_decor_tulipes_rouges_statique_ordinaire_00",
        "bbox": (1037, 607, 1197, 761),

        "canvas_1x": (60, 64),
        "max_visible_1x": (52, 56),

        "footprint_grid": [0.5, 0.5],
        "size_class": "small_decor",

        "palette_roles": [
            "rouge_fruit",
            "feuillage_sauge",
            "feuillage_profond",
        ],
    },

    {
        "id": "potager_decor_buisson_marguerites_statique_ordinaire_00",
        "bbox": (1218, 615, 1426, 766),

        "canvas_1x": (76, 60),
        "max_visible_1x": (68, 52),

        "footprint_grid": [1.0, 0.5],
        "size_class": "small_decor",

        "palette_roles": [
            "feuillage_sauge",
            "feuillage_profond",
            "blanc_floral",
            "jaune",
        ],
    },

    {
        "id": "potager_decor_rochers_vegetation_00_statique_ordinaire_00",

        # La composante alpha continue vers le bac situé en dessous.
        # On coupe volontairement avant cette zone parasite.
        "bbox": (14, 759, 215, 890),

        "canvas_1x": (72, 56),
        "max_visible_1x": (64, 48),

        "footprint_grid": [1.0, 0.5],
        "size_class": "small_decor",

        "palette_roles": [
            "pierre_creme",
            "feuillage_sauge",
            "feuillage_profond",
        ],
    },

    {
        "id": "potager_decor_rochers_vegetation_01_statique_ordinaire_00",
        "bbox": (229, 789, 388, 906),

        "canvas_1x": (64, 52),
        "max_visible_1x": (56, 44),

        "footprint_grid": [1.0, 0.5],
        "size_class": "small_decor",

        "palette_roles": [
            "pierre_creme",
            "feuillage_sauge",
            "feuillage_profond",
        ],
    },

    {
        "id": "potager_decor_portail_bois_statique_ordinaire_00",

        # ROI volontairement large.
        # Le reliquat voisin est ensuite supprimé grâce à isolate/largest.
        "bbox": (930, 260, 1140, 450),

        "component_mode": "largest",

        "canvas_1x": (76, 68),
        "max_visible_1x": (68, 60),

        "footprint_grid": [1.0, 0.5],
        "size_class": "small_decor",

        "palette_roles": [
            "bois_chaud",
            "feuillage_sauge",
            "blanc_floral",
        ],
    },
]


def crop_exact(atlas: Image.Image, bbox):
    x0, y0, x1, y1 = bbox

    source = atlas.crop(
        (x0, y0, x1, y1)
    )

    # Marge transparente propre autour du sprite.
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

    print("NEW DA — BATCH 04")
    print("=================")

    for config in ASSETS:
        sprite_id = config["id"]

        source = crop_exact(
            atlas,
            config["bbox"],
        )

        # Certains assets ont besoin d'un nettoyage supplémentaire.
        # Pour le portail, on ne garde que la composante alpha principale.
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

        # On ne branche pas encore automatiquement dans Tiled.
        audit[f"{sprite_id}.png"] = {
            "status": "excluded",
        }

        created.append(sprite_id)

        print(
            f"✓ {sprite_id}\n"
            f"  source={config['bbox']}\n"
            f"  canvas={master.width}x{master.height}\n"
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

    # Validation ciblée uniquement sur les 5 nouveaux sprites.
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
    print("✅ Lot 4 validé techniquement.")
    print()
    print("Sprites à inspecter :")

    for sprite_id in created:
        print(
            f"  assets/sprites/{sprite_id}.png"
        )


if __name__ == "__main__":
    main()

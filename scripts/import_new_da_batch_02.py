#!/usr/bin/env python3

from __future__ import annotations

import json
import sys
from pathlib import Path

from PIL import Image

# On réutilise volontairement le pipeline validé du batch 01.
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
        "id": "potager_decor_arrosoir_bleu_statique_ordinaire_00",

        # Arrosoir seul.
        # Le ROI mord légèrement sur le tonneau, mais isolate(largest)
        # conserve uniquement l'arrosoir dans cette zone.
        "roi": (470, 450, 645, 585),

        "component_mode": "largest",

        "canvas_1x": (52, 44),
        "max_visible_1x": (46, 38),

        "footprint_grid": [0.5, 0.5],
        "size_class": "small_decor",

        "palette_roles": [
            "bleu_doux",
        ],
    },

    {
        "id": "potager_decor_tonneau_pompe_statique_ordinaire_00",

        # Tonneau + pompe, objet unique.
        # L'arrosoir peut apparaître dans le ROI mais constitue
        # une composante alpha indépendante et plus petite.
        "roi": (600, 400, 795, 635),

        "component_mode": "largest",

        "canvas_1x": (64, 72),
        "max_visible_1x": (56, 64),

        "footprint_grid": [1.0, 1.0],
        "size_class": "small_decor",

        "palette_roles": [
            "bois_chaud",
            "pierre_creme",
        ],
    },

    {
        "id": "potager_decor_panier_pommes_statique_ordinaire_00",

        "roi": (775, 450, 920, 605),

        "component_mode": "largest",

        "canvas_1x": (48, 48),
        "max_visible_1x": (42, 42),

        "footprint_grid": [0.5, 0.5],
        "size_class": "small_decor",

        "palette_roles": [
            "bois_chaud",
            "rouge_fruit",
        ],
    },

    {
        "id": "potager_decor_jardiniere_bois_statique_ordinaire_00",

        # Caisse en bois remplie de feuillage.
        "roi": (900, 435, 1100, 620),

        "component_mode": "largest",

        "canvas_1x": (68, 58),
        "max_visible_1x": (60, 50),

        "footprint_grid": [1.0, 0.5],
        "size_class": "small_decor",

        "palette_roles": [
            "bois_chaud",
            "feuillage_sauge",
            "feuillage_profond",
        ],
    },

    {
        "id": "potager_decor_pot_marguerites_statique_ordinaire_00",

        "roi": (1080, 435, 1220, 605),

        "component_mode": "largest",

        "canvas_1x": (48, 52),
        "max_visible_1x": (40, 46),

        "footprint_grid": [0.5, 0.5],
        "size_class": "small_decor",

        "palette_roles": [
            "bois_chaud",
            "feuillage_sauge",
            "blanc_floral",
        ],
    },
]


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

    print("NEW DA — BATCH 02")
    print("=================")

    for config in ASSETS:
        sprite_id = config["id"]

        x0, y0, x1, y1 = config["roi"]

        roi = atlas.crop(
            (x0, y0, x1, y1)
        )

        isolated = isolate(
            roi,
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

        if runtime_bbox is None:
            raise RuntimeError(
                f"{sprite_id}: sprite vide après normalisation"
            )

        manifest[f"{sprite_id}.png"] = {
            "width": master.width,
            "height": master.height,
            "bbox": list(runtime_bbox),
            "anchor": anchor,
            "shadow": "separate_contact",
        }

        # Pas encore dans Tiled :
        # validation visuelle d'abord.
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

    # Validation ciblée uniquement sur les 5 nouveaux sprites.
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
    print("✅ Les 5 sprites satisfont le contrat Growstep.")
    print()
    print("À inspecter :")

    for sprite_id in created:
        print(
            f"  assets/sprites/{sprite_id}.png"
        )


if __name__ == "__main__":
    main()

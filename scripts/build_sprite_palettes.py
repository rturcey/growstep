#!/usr/bin/env python3

from __future__ import annotations

import argparse
import xml.etree.ElementTree as ET
from collections import defaultdict
from pathlib import Path

from PIL import Image


ROOT = Path(__file__).resolve().parents[1]

SPRITES = ROOT / "assets" / "sprites"
MAPS = ROOT / "assets" / "maps"

DEFAULT_MAP = MAPS / "potager_diorama_v1.tmx"

GENERATED_PREFIX = "palette_"


# ---------------------------------------------------------------------------
# Classification
# ---------------------------------------------------------------------------

def category(name: str) -> str:
    n = name.lower()

    # ------------------------------------------------------------
    # PLANTES DYNAMIQUES
    # ------------------------------------------------------------

    if n.startswith("potager_plante_"):
        return "plants_potager"

    if n.startswith("fleurs_plante_"):
        return "plants_fleurs"

    if n.startswith("verger_arbre_"):
        return "plants_verger"

    # ------------------------------------------------------------
    # TERRAIN / CULTURE
    # ------------------------------------------------------------

    if n.startswith("potager_newda_sol_"):
        return "terrain_new_da"

    if (
        "bordure_parcelle" in n
        or "bordure_bac" in n
        or "cadre_bac" in n
        or "bac_terre" in n
    ):
        return "cultivation"

    if (
        "pas_pierre" in n
        or "dalles_chemin" in n
        or "_path_" in n
        or "_chemin_" in n
    ):
        return "paths"

    # ------------------------------------------------------------
    # ROCHERS
    # ------------------------------------------------------------

    if (
        "rocher" in n
        or "rochers" in n
        or "pierre" in n
    ):
        return "decor_rocks"

    # ------------------------------------------------------------
    # STRUCTURES
    # ------------------------------------------------------------

    if any(
        key in n
        for key in (
            "arche",
            "portail",
            "barriere",
            "cloture",
            "pergola",
            "treillis",
            "cabane",
            "station",
            "nichoir",
        )
    ):
        return "decor_structures"

    # ------------------------------------------------------------
    # PROPS / MOBILIER
    # ------------------------------------------------------------

    if any(
        key in n
        for key in (
            "banc",
            "bain_oiseaux",
            "fontaine",
            "arrosoir",
            "tonneau",
            "pompe",
            "panier",
            "pot_",
            "pot_de_",
            "caisse",
            "outil",
        )
    ):
        return "decor_props"

    # ------------------------------------------------------------
    # VEGETATION DECORATIVE
    # ------------------------------------------------------------

    if any(
        key in n
        for key in (
            "arbre_",
            "pommier_fruits",
            "hortensia",
            "lavande_massif",
            "marguerite",
            "fleurs_",
            "fleur_",
            "fraisier_massif",
            "tulipe",
            "buisson",
            "arbuste",
            "vegetation",
            "herbe_",
        )
    ):
        return "decor_vegetation"

    # ------------------------------------------------------------
    # Sols historiques non New DA
    # ------------------------------------------------------------

    if (
        "_sol_" in n
        or n.startswith("commun_sol_")
    ):
        return "terrain_legacy"

    return "misc"


# ---------------------------------------------------------------------------
# Files
# ---------------------------------------------------------------------------

def sprite_files() -> list[Path]:
    return sorted(
        SPRITES.glob("*.png"),
        key=lambda path: path.name.lower(),
    )


def image_size(path: Path) -> tuple[int, int]:
    with Image.open(path) as image:
        return image.size


# ---------------------------------------------------------------------------
# TSX
# ---------------------------------------------------------------------------

def build_tsx(
    category_name: str,
    sprites: list[Path],
) -> Path:

    infos = [
        (
            path,
            *image_size(path),
        )
        for path in sprites
    ]

    max_w = max(
        width
        for _, width, _ in infos
    )

    max_h = max(
        height
        for _, _, height in infos
    )

    tileset = ET.Element(
        "tileset",
        {
            "version": "1.10",
            "tiledversion": "1.11.2",

            "name": category_name,

            "tilewidth": str(max_w),
            "tileheight": str(max_h),

            "tilecount": str(len(infos)),
            "columns": "0",

            "objectalignment": "bottom",
        },
    )

    for tile_id, (path, width, height) in enumerate(infos):

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
                "source": f"../sprites/{path.name}",
                "width": str(width),
                "height": str(height),
            },
        )

    ET.indent(
        tileset,
        space="  ",
    )

    output = (
        MAPS
        / f"{GENERATED_PREFIX}{category_name}.tsx"
    )

    ET.ElementTree(
        tileset
    ).write(
        output,
        encoding="utf-8",
        xml_declaration=True,
    )

    with output.open("ab") as fh:
        fh.write(b"\n")

    return output


# ---------------------------------------------------------------------------
# MAP
# ---------------------------------------------------------------------------

def tileset_count(path: Path) -> int:

    root = ET.parse(
        path
    ).getroot()

    count = root.get(
        "tilecount"
    )

    if count:
        return int(count)

    tiles = root.findall(
        "tile"
    )

    if not tiles:
        return 0

    return (
        max(
            int(tile.get("id", "0"))
            for tile in tiles
        )
        + 1
    )


def next_gid(root: ET.Element) -> int:

    result = 1

    for ref in root.findall(
        "tileset"
    ):
        source = ref.get(
            "source"
        )

        if not source:
            continue

        path = MAPS / source

        if not path.exists():
            continue

        firstgid = int(
            ref.get(
                "firstgid",
                "1",
            )
        )

        count = tileset_count(
            path
        )

        result = max(
            result,
            firstgid + count,
        )

    return result


def attach_palettes(
    map_path: Path,
    palettes: list[Path],
):

    tree = ET.parse(
        map_path
    )

    root = tree.getroot()

    existing_sources = {
        ref.get("source")
        for ref in root.findall("tileset")
    }

    gid = next_gid(
        root
    )

    for palette in palettes:

        if palette.name in existing_sources:
            print(
                f"  ↪ déjà attachée : {palette.name}"
            )
            continue

        ref = ET.Element(
            "tileset",
            {
                "firstgid": str(gid),
                "source": palette.name,
            },
        )

        # Placer les palettes avant les layers.
        children = list(root)

        last_tileset_index = max(
            (
                i
                for i, child in enumerate(children)
                if child.tag == "tileset"
            ),
            default=-1,
        )

        root.insert(
            last_tileset_index + 1,
            ref,
        )

        count = tileset_count(
            palette
        )

        print(
            f"  + {palette.name}"
            f"  firstgid={gid}"
            f"  ({count} sprites)"
        )

        gid += count

    ET.indent(
        tree,
        space="  ",
    )

    tree.write(
        map_path,
        encoding="utf-8",
        xml_declaration=True,
    )


# ---------------------------------------------------------------------------
# MAIN
# ---------------------------------------------------------------------------

def main():

    parser = argparse.ArgumentParser()

    parser.add_argument(
        "--map",
        type=Path,
        default=DEFAULT_MAP,
    )

    parser.add_argument(
        "--tsx-only",
        action="store_true",
    )

    args = parser.parse_args()

    if not SPRITES.exists():
        raise SystemExit(
            f"Introuvable : {SPRITES}"
        )

    grouped = defaultdict(list)

    for sprite in sprite_files():

        grouped[
            category(sprite.name)
        ].append(sprite)

    print(
        "GROWSTEP — SPRITE PALETTES"
    )

    print(
        "=========================="
    )

    palettes = []

    # Ordre voulu dans Tiled.
    order = [
        "plants_potager",
        "plants_fleurs",
        "plants_verger",

        "cultivation",

        "decor_structures",
        "decor_props",
        "decor_vegetation",
        "decor_rocks",

        "paths",

        "terrain_new_da",
        "terrain_legacy",

        "misc",
    ]

    for name in order:

        sprites = grouped.get(
            name,
            [],
        )

        if not sprites:
            continue

        path = build_tsx(
            name,
            sprites,
        )

        palettes.append(
            path
        )

        print(
            f"✓ {name:<20} "
            f"{len(sprites):>3} sprites"
        )

    print()

    if not args.tsx_only:

        print(
            f"Ajout à {args.map.relative_to(ROOT)}"
        )

        attach_palettes(
            args.map,
            palettes,
        )

    print()
    print(
        "✅ Palettes générées."
    )

    print()
    print(
        "Recharge complètement Tiled."
    )


if __name__ == "__main__":
    main()

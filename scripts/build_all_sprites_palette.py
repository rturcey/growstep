#!/usr/bin/env python3

from __future__ import annotations

import argparse
import json
import xml.etree.ElementTree as ET
from pathlib import Path

from PIL import Image


ROOT = Path(__file__).resolve().parents[1]

SPRITES = ROOT / "assets" / "sprites"
MAPS = ROOT / "assets" / "maps"
MANIFEST = SPRITES / "manifest.json"

TSX = MAPS / "all_sprites.tsx"
DEFAULT_MAP = MAPS / "potager_diorama_v1.tmx"


def natural_key(name: str):
    return name.lower()


def sprite_files() -> list[Path]:
    return sorted(
        [
            path
            for path in SPRITES.glob("*.png")
            if path.is_file()
        ],
        key=lambda p: natural_key(p.name),
    )


def image_size(path: Path, manifest: dict) -> tuple[int, int]:
    meta = manifest.get(path.name)

    if meta:
        width = meta.get("width")
        height = meta.get("height")

        if isinstance(width, int) and isinstance(height, int):
            return width, height

    with Image.open(path) as image:
        return image.size


def build_tsx():
    if not SPRITES.exists():
        raise SystemExit(
            f"Dossier sprites introuvable : {SPRITES}"
        )

    manifest = {}

    if MANIFEST.exists():
        manifest = json.loads(
            MANIFEST.read_text(
                encoding="utf-8"
            )
        )

    sprites = sprite_files()

    if not sprites:
        raise SystemExit(
            "Aucun PNG trouvé dans assets/sprites/"
        )

    sizes = [
        (
            path,
            *image_size(path, manifest),
        )
        for path in sprites
    ]

    max_w = max(width for _, width, _ in sizes)
    max_h = max(height for _, _, height in sizes)

    tileset = ET.Element(
        "tileset",
        {
            "version": "1.10",
            "tiledversion": "1.11.2",
            "name": "all_sprites",
            "tilewidth": str(max_w),
            "tileheight": str(max_h),
            "tilecount": str(len(sizes)),
            "columns": "0",
            "objectalignment": "bottom",
        },
    )
    if category_name in {
        "plants_potager",
        "plants_fleurs",
        "plants_verger",
    }:
        ET.SubElement(
            tileset,
            "tileoffset",
            {
                "x": "40",
                "y": "20",
            },
        )

    for tile_id, (path, width, height) in enumerate(sizes):
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

    ET.ElementTree(
        tileset
    ).write(
        TSX,
        encoding="utf-8",
        xml_declaration=True,
    )

    with TSX.open("ab") as fh:
        fh.write(b"\n")

    print(
        f"✅ {TSX.relative_to(ROOT)}"
    )

    print(
        f"✅ {len(sizes)} sprites dans la palette"
    )

    return len(sizes)


def tileset_count(source: Path) -> int:
    tree = ET.parse(source)
    root = tree.getroot()

    count = root.get("tilecount")

    if count is not None:
        return int(count)

    tiles = root.findall("tile")

    if tiles:
        return (
            max(
                int(tile.get("id", "0"))
                for tile in tiles
            )
            + 1
        )

    return 0


def compute_next_gid(
    map_root: ET.Element,
) -> int:
    next_gid = 1

    for ref in map_root.findall("tileset"):
        firstgid = int(
            ref.get("firstgid", "1")
        )

        source = ref.get("source")

        if not source:
            continue

        tsx = MAPS / source

        if not tsx.exists():
            print(
                f"⚠️ tileset absent : {tsx}"
            )
            continue

        count = tileset_count(
            tsx
        )

        next_gid = max(
            next_gid,
            firstgid + count,
        )

    return next_gid


def attach_to_map(
    map_path: Path,
):
    if not map_path.exists():
        raise SystemExit(
            f"Map introuvable : {map_path}"
        )

    tree = ET.parse(
        map_path
    )

    root = tree.getroot()

    existing = None

    for tileset in root.findall(
        "tileset"
    ):
        if (
            tileset.get("source")
            == TSX.name
        ):
            existing = tileset
            break

    if existing is not None:
        print(
            f"✅ {TSX.name} déjà présent "
            f"dans {map_path.name}"
        )
        return

    next_gid = compute_next_gid(
        root
    )

    ref = ET.Element(
        "tileset",
        {
            "firstgid": str(next_gid),
            "source": TSX.name,
        },
    )

    tilesets = root.findall(
        "tileset"
    )

    if tilesets:
        children = list(root)
        last_index = max(
            children.index(node)
            for node in tilesets
        )

        root.insert(
            last_index + 1,
            ref,
        )
    else:
        root.insert(
            0,
            ref,
        )

    ET.indent(
        tree,
        space="  ",
    )

    tree.write(
        map_path,
        encoding="utf-8",
        xml_declaration=True,
    )

    print(
        f"✅ Palette ajoutée à {map_path.relative_to(ROOT)}"
    )

    print(
        f"   firstgid={next_gid}"
    )


def main():
    parser = argparse.ArgumentParser()

    parser.add_argument(
        "--map",
        type=Path,
        default=DEFAULT_MAP,
        help=(
            "TMX auquel ajouter la palette "
            "(défaut: potager_diorama_v1.tmx)"
        ),
    )

    parser.add_argument(
        "--tsx-only",
        action="store_true",
        help=(
            "Génère uniquement all_sprites.tsx "
            "sans modifier la map"
        ),
    )

    args = parser.parse_args()

    print(
        "ALL SPRITES — TILED PALETTE"
    )
    print(
        "==========================="
    )

    count = build_tsx()

    if not args.tsx_only:
        attach_to_map(
            args.map
        )

    print()
    print(
        f"✅ Terminé : {count} sprites."
    )
    print()
    print(
        "Recharge complètement la map dans Tiled."
    )


if __name__ == "__main__":
    main()

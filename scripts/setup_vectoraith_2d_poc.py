#!/usr/bin/env python3

from __future__ import annotations

import json
import shutil
import subprocess
import xml.etree.ElementTree as ET
from pathlib import Path

from PIL import Image, ImageDraw


ROOT = Path(__file__).resolve().parents[1]

KIT = (
    ROOT
    / "vectoraith_tileset_farming_sim_essentials"
    / "Original"
    / "32x32"
    / "Tilesets (Compact)"
)

DEST = ROOT / "assets" / "sprites" / "vectoraith_2d"
MAPS = ROOT / "assets" / "maps"
AUDIT = ROOT / "docs" / "vectoraith-audit"

TILE = 32

MAP_W = 20
MAP_H = 20


FILES = {
    "terrain": "vectoraith_tileset_farmingsims_terrain_summer_expanded_32x32.png",
    "crops": "vectoraith_tileset_farmingsims_crops_32x32.png",
    "crops_dense": "vectoraith_tileset_farmingsims_crops_dense_32x32.png",
    "details": "vectoraith_tileset_farmingsims_details_32x32.png",
    "orchard": "vectoraith_tileset_farmingsims_orchard_32x32.png",
    "buildings": "vectoraith_tileset_farmingsims_buildings_32x32.png",
}


# ============================================================
# UTILS
# ============================================================

def verify_branch():
    try:
        branch = subprocess.check_output(
            [
                "git",
                "branch",
                "--show-current",
            ],
            cwd=ROOT,
            text=True,
        ).strip()

    except Exception:
        return

    if branch != "refactor_potager":
        raise SystemExit(
            f"\nTu es sur '{branch}'.\n"
            "Passe d'abord sur :\n\n"
            "  git switch refactor_potager\n"
        )


def verify_sources():
    if not KIT.exists():
        raise SystemExit(
            f"Kit introuvable :\n{KIT}"
        )

    for filename in FILES.values():
        path = KIT / filename

        if not path.exists():
            raise SystemExit(
                f"Fichier absent :\n{path}"
            )


# ============================================================
# COPY ONLY THE USEFUL PACK
# ============================================================

def copy_assets():
    DEST.mkdir(
        parents=True,
        exist_ok=True,
    )

    for role, filename in FILES.items():
        source = KIT / filename

        target = (
            DEST
            / f"{role}.png"
        )

        shutil.copy2(
            source,
            target,
        )

        print(
            f"✓ {role:<12} "
            f"{target.relative_to(ROOT)}"
        )


# ============================================================
# TSX
# ============================================================

def create_tsx(
    role: str,
):
    image_path = (
        DEST
        / f"{role}.png"
    )

    image = Image.open(
        image_path
    )

    width, height = image.size

    if (
        width % TILE != 0
        or height % TILE != 0
    ):
        raise RuntimeError(
            f"{role}: dimensions incompatibles "
            f"{width}x{height}"
        )

    columns = (
        width // TILE
    )

    rows = (
        height // TILE
    )

    count = (
        columns * rows
    )

    tsx_path = (
        MAPS
        / f"vectoraith_{role}.tsx"
    )

    root = ET.Element(
        "tileset",
        {
            "version": "1.10",
            "tiledversion": "1.11.2",
            "name": f"vectoraith_{role}",
            "tilewidth": str(TILE),
            "tileheight": str(TILE),
            "tilecount": str(count),
            "columns": str(columns),
            "objectalignment": "bottom",
        },
    )

    ET.SubElement(
        root,
        "image",
        {
            "source":
                f"../sprites/vectoraith_2d/{role}.png",

            "width":
                str(width),

            "height":
                str(height),
        },
    )

    ET.indent(
        root,
        space="  ",
    )

    ET.ElementTree(
        root
    ).write(
        tsx_path,
        encoding="utf-8",
        xml_declaration=True,
    )

    return {
        "role": role,
        "tsx": tsx_path,
        "columns": columns,
        "rows": rows,
        "count": count,
    }


# ============================================================
# ANNOTATED AUDIT SHEETS
# ============================================================

def annotate(
    role: str,
):
    source = Image.open(
        DEST
        / f"{role}.png"
    ).convert(
        "RGBA"
    )

    scale = 2

    preview = source.resize(
        (
            source.width * scale,
            source.height * scale,
        ),
        Image.Resampling.NEAREST,
    )

    draw = ImageDraw.Draw(
        preview
    )

    columns = (
        source.width // TILE
    )

    rows = (
        source.height // TILE
    )

    cell = (
        TILE * scale
    )

    for row in range(rows):
        for col in range(columns):

            x = (
                col * cell
            )

            y = (
                row * cell
            )

            tile_id = (
                row * columns
                + col
            )

            draw.rectangle(
                (
                    x,
                    y,
                    x + cell - 1,
                    y + cell - 1,
                ),
                outline=(
                    255,
                    0,
                    255,
                    100,
                ),
                width=1,
            )

            # label background
            draw.rectangle(
                (
                    x + 1,
                    y + 1,
                    x + 29,
                    y + 13,
                ),
                fill=(
                    0,
                    0,
                    0,
                    180,
                ),
            )

            draw.text(
                (
                    x + 3,
                    y + 1,
                ),
                str(
                    tile_id
                ),
                fill="white",
            )

    AUDIT.mkdir(
        parents=True,
        exist_ok=True,
    )

    target = (
        AUDIT
        / f"{role}_ids.png"
    )

    preview.save(
        target,
        "PNG",
        optimize=True,
    )

    print(
        f"✓ audit {target.relative_to(ROOT)}"
    )


# ============================================================
# TMX HELPERS
# ============================================================

def csv_layer(
    layer_id,
    name,
    values,
):
    layer = ET.Element(
        "layer",
        {
            "id": str(layer_id),
            "name": name,
            "width": str(MAP_W),
            "height": str(MAP_H),
        },
    )

    data = ET.SubElement(
        layer,
        "data",
        {
            "encoding": "csv",
        },
    )

    rows = []

    for y in range(
        MAP_H
    ):
        start = (
            y * MAP_W
        )

        rows.append(
            ",".join(
                str(v)
                for v
                in values[
                    start:
                    start + MAP_W
                ]
            )
        )

    data.text = (
        "\n"
        + ",\n".join(rows)
        + "\n"
    )

    return layer


# ============================================================
# MAP
# ============================================================

def build_map(
    tilesets,
):
    map_path = (
        MAPS
        / "potager_2d_poc.tmx"
    )

    root = ET.Element(
        "map",
        {
            "version": "1.10",
            "tiledversion": "1.11.2",

            "orientation":
                "orthogonal",

            "renderorder":
                "right-down",

            "width":
                str(MAP_W),

            "height":
                str(MAP_H),

            "tilewidth":
                str(TILE),

            "tileheight":
                str(TILE),

            "infinite":
                "0",

            "backgroundcolor":
                "#cadba4",
        },
    )

    firstgid = 1

    gids = {}

    for info in tilesets:
        role = info[
            "role"
        ]

        gids[
            role
        ] = firstgid

        ET.SubElement(
            root,
            "tileset",
            {
                "firstgid":
                    str(firstgid),

                "source":
                    info[
                        "tsx"
                    ].name,
            },
        )

        firstgid += info[
            "count"
        ]

    # ========================================================
    # Ground
    #
    # Terrain tile 0 is grass in this actual VectoRaith sheet.
    # ========================================================

    grass_gid = (
        gids[
            "terrain"
        ]
    )

    ground = [
        grass_gid
        for _ in range(
            MAP_W
            * MAP_H
        )
    ]

    root.append(
        csv_layer(
            1,
            "ground",
            ground,
        )
    )

    # Empty authoring layers.
    root.append(
        csv_layer(
            2,
            "terrain_details",
            [
                0
                for _ in range(
                    MAP_W
                    * MAP_H
                )
            ],
        )
    )

    root.append(
        csv_layer(
            3,
            "paths",
            [
                0
                for _ in range(
                    MAP_W
                    * MAP_H
                )
            ],
        )
    )

    root.append(
        csv_layer(
            4,
            "soil",
            [
                0
                for _ in range(
                    MAP_W
                    * MAP_H
                )
            ],
        )
    )

    # ========================================================
    # Plot positions
    # ========================================================

    plots = ET.SubElement(
        root,
        "objectgroup",
        {
            "id": "5",
            "name": "plots",
        },
    )

    plot_positions = [
        (6, 6),
        (9, 6),
        (12, 6),

        (6, 9),
        (12, 9),

        (6, 12),
        (9, 12),
        (12, 12),
    ]

    next_object_id = 1

    for index, (
        grid_x,
        grid_y,
    ) in enumerate(
        plot_positions
    ):
        obj = ET.SubElement(
            plots,
            "object",
            {
                "id":
                    str(
                        next_object_id
                    ),

                "name":
                    f"plot_{index}",

                "class":
                    "plot",

                "x":
                    str(
                        grid_x
                        * TILE
                        + TILE / 2
                    ),

                "y":
                    str(
                        grid_y
                        * TILE
                        + TILE / 2
                    ),
            },
        )

        ET.SubElement(
            obj,
            "point",
        )

        props = ET.SubElement(
            obj,
            "properties",
        )

        ET.SubElement(
            props,
            "property",
            {
                "name":
                    "gridX",

                "type":
                    "int",

                "value":
                    str(grid_x),
            },
        )

        ET.SubElement(
            props,
            "property",
            {
                "name":
                    "gridY",

                "type":
                    "int",

                "value":
                    str(grid_y),
            },
        )

        next_object_id += 1

    # ========================================================
    # Normal visual layers
    # ========================================================

    ET.SubElement(
        root,
        "objectgroup",
        {
            "id": "6",
            "name": "decor_back",
        },
    )

    ET.SubElement(
        root,
        "objectgroup",
        {
            "id": "7",
            "name": "plants",
        },
    )

    ET.SubElement(
        root,
        "objectgroup",
        {
            "id": "8",
            "name": "decor_front",
        },
    )

    root.set(
        "nextlayerid",
        "9",
    )

    root.set(
        "nextobjectid",
        str(
            next_object_id
        ),
    )

    ET.indent(
        root,
        space="  ",
    )

    ET.ElementTree(
        root
    ).write(
        map_path,
        encoding="utf-8",
        xml_declaration=True,
    )

    print()
    print(
        f"✓ map {map_path.relative_to(ROOT)}"
    )


# ============================================================
# INDEX
# ============================================================

def write_index(
    tilesets,
):
    data = {
        "source": str(
            KIT.relative_to(ROOT)
        ),

        "tile_size":
            TILE,

        "style":
            "Original",

        "resolution":
            "32x32",

        "tilesets": {
            info[
                "role"
            ]: {
                "columns":
                    info[
                        "columns"
                    ],

                "rows":
                    info[
                        "rows"
                    ],

                "tile_count":
                    info[
                        "count"
                    ],
            }
            for info
            in tilesets
        },
    }

    AUDIT.mkdir(
        parents=True,
        exist_ok=True,
    )

    target = (
        AUDIT
        / "vectoraith_index.json"
    )

    target.write_text(
        json.dumps(
            data,
            indent=2,
        )
        + "\n",
        encoding="utf-8",
    )


# ============================================================
# MAIN
# ============================================================

def main():
    print()
    print(
        "GROWSTEP — VECTORAITH 2D POC"
    )
    print(
        "============================="
    )
    print()

    verify_branch()
    verify_sources()

    print(
        "Sources :"
    )

    print(
        "  vectoraith_tileset_farming_sim_essentials/"
        "Original/32x32/Tilesets (Compact)"
    )

    print()

    copy_assets()

    print()
    print(
        "Création des palettes Tiled..."
    )

    tilesets = []

    for role in FILES:
        tilesets.append(
            create_tsx(
                role
            )
        )

    print(
        f"✓ {len(tilesets)} palettes"
    )

    print()
    print(
        "Création des planches avec IDs..."
    )

    for role in FILES:
        annotate(
            role
        )

    write_index(
        tilesets
    )

    build_map(
        tilesets
    )

    print()
    print(
        "============================="
    )

    print(
        "✅ POC TILED PRÊT"
    )

    print(
        "============================="
    )

    print()
    print(
        "Ouvre :"
    )

    print()
    print(
        "  tiled assets/maps/"
        "potager_2d_poc.tmx"
    )

    print()
    print(
        "Palettes disponibles :"
    )

    for role in FILES:
        print(
            f"  vectoraith_{role}"
        )

    print()
    print(
        "Planches annotées :"
    )

    print(
        "  docs/vectoraith-audit/"
        "*_ids.png"
    )

    print()
    print(
        "L'ancien potager ISO n'a pas été modifié."
    )


if __name__ == "__main__":
    main()

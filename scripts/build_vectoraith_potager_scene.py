#!/usr/bin/env python3

from __future__ import annotations

import json
import shutil
import subprocess
import xml.etree.ElementTree as ET
from pathlib import Path

from PIL import Image, ImageDraw


ROOT = Path(__file__).resolve().parents[1]

MAPS = ROOT / "assets" / "maps"
SPRITES = ROOT / "assets" / "sprites" / "vectoraith_2d"
AUDIT = ROOT / "docs" / "vectoraith-audit"

MAP = MAPS / "potager_2d_poc.tmx"

W = 20
H = 20
TILE = 32


ROLES = [
    "terrain",
    "crops",
    "crops_dense",
    "details",
    "orchard",
    "buildings",
]


CROPS = [
    # name, stage ids
    ("corn",       [24, 25, 26, 27]),
    ("cabbage",    [52, 53, 54, 55]),
    ("strawberry", [80, 81, 82, 83]),
    ("carrot",     [112, 113, 114, 115]),
    ("tomato",     [144, 145, 146, 147]),
    ("pepper",     [152, 153, 154, 155]),
    ("eggplant",   [212, 213, 214, 215]),
    ("pumpkin",    [240, 241, 242, 243]),
]


PLOTS = [
    (0, 4, 4),
    (1, 9, 4),
    (2, 14, 4),

    (3, 4, 9),
    (4, 14, 9),

    (5, 4, 14),
    (6, 9, 14),
    (7, 14, 14),
]


def verify():
    for role in ROLES:
        tsx = MAPS / f"vectoraith_{role}.tsx"
        png = SPRITES / f"{role}.png"

        if not tsx.exists():
            raise SystemExit(
                f"Missing {tsx}\n"
                "Lance d'abord setup_vectoraith_2d_poc.py"
            )

        if not png.exists():
            raise SystemExit(
                f"Missing {png}"
            )


def tilecount(tsx: Path) -> int:
    return int(
        ET.parse(tsx)
        .getroot()
        .get("tilecount")
    )


# ============================================================
# GROWSTEP SOIL
# ============================================================

def create_soil():
    """
    The pack has good grass/path tiles but no sufficiently
    distinctive Growstep cultivation bed for our use.

    We derive it from terrain tile 35 so it remains stylistically
    consistent with VectoRaith, then turn it into darker tilled soil.
    """

    source = Image.open(
        SPRITES / "terrain.png"
    ).convert("RGBA")

    tile_id = 35

    col = tile_id % 16
    row = tile_id // 16

    soil = source.crop(
        (
            col * TILE,
            row * TILE,
            (col + 1) * TILE,
            (row + 1) * TILE,
        )
    )

    pixels = soil.load()

    for y in range(TILE):
        for x in range(TILE):
            r, g, b, a = pixels[x, y]

            if a == 0:
                continue

            lum = (
                r * 0.35
                + g * 0.50
                + b * 0.15
            )

            nr = min(
                255,
                int(65 + lum * 0.48),
            )

            ng = min(
                255,
                int(35 + lum * 0.29),
            )

            nb = min(
                255,
                int(20 + lum * 0.18),
            )

            pixels[x, y] = (
                nr,
                ng,
                nb,
                a,
            )

    # Very light pixel-art furrows.
    draw = ImageDraw.Draw(
        soil,
        "RGBA",
    )

    for y in (
        7,
        15,
        23,
    ):
        draw.line(
            (2, y, 29, y),
            fill=(91, 50, 30, 125),
            width=1,
        )

        draw.line(
            (3, y + 1, 28, y + 1),
            fill=(181, 119, 66, 75),
            width=1,
        )

    output = (
        SPRITES
        / "soil_growstep.png"
    )

    soil.save(
        output,
        "PNG",
        optimize=True,
    )

    tsx = (
        MAPS
        / "vectoraith_soil_growstep.tsx"
    )

    root = ET.Element(
        "tileset",
        {
            "version": "1.10",
            "tiledversion": "1.11.2",
            "name": "vectoraith_soil_growstep",
            "tilewidth": "32",
            "tileheight": "32",
            "tilecount": "1",
            "columns": "0",
        },
    )

    tile = ET.SubElement(
        root,
        "tile",
        {
            "id": "0",
        },
    )

    ET.SubElement(
        tile,
        "image",
        {
            "source":
                "../sprites/vectoraith_2d/"
                "soil_growstep.png",

            "width": "32",
            "height": "32",
        },
    )

    ET.indent(
        root,
        space="  ",
    )

    ET.ElementTree(root).write(
        tsx,
        encoding="utf-8",
        xml_declaration=True,
    )

    return tsx


# ============================================================
# TMX HELPERS
# ============================================================

def blank():
    return [
        0
        for _ in range(
            W * H
        )
    ]


def set_tile(
    values,
    x,
    y,
    gid,
):
    if (
        0 <= x < W
        and 0 <= y < H
    ):
        values[
            y * W + x
        ] = gid


def layer(
    layer_id,
    name,
    values,
):
    node = ET.Element(
        "layer",
        {
            "id": str(layer_id),
            "name": name,
            "width": str(W),
            "height": str(H),
        },
    )

    data = ET.SubElement(
        node,
        "data",
        {
            "encoding": "csv",
        },
    )

    rows = []

    for y in range(H):
        start = y * W

        rows.append(
            ",".join(
                str(v)
                for v in values[
                    start:start + W
                ]
            )
        )

    data.text = (
        "\n"
        + ",\n".join(rows)
        + "\n"
    )

    return node


def property_node(
    parent,
    name,
    value,
    type_name=None,
):
    attrs = {
        "name": name,
        "value": str(value),
    }

    if type_name:
        attrs["type"] = type_name

    ET.SubElement(
        parent,
        "property",
        attrs,
    )


# ============================================================
# MAP
# ============================================================

def build_map(
    soil_tsx,
):
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
                str(W),

            "height":
                str(H),

            "tilewidth":
                str(TILE),

            "tileheight":
                str(TILE),

            "infinite":
                "0",

            "backgroundcolor":
                "#d8e7b5",
        },
    )

    map_props = ET.SubElement(
        root,
        "properties",
    )

    property_node(
        map_props,
        "growstepView",
        "orthogonal",
    )

    property_node(
        map_props,
        "sourcePack",
        "VectoRaith Farming Sim Essentials",
    )

    # --------------------------------------------------------
    # TILESETS
    # --------------------------------------------------------

    firstgid = 1

    firstgids = {}

    for role in ROLES:
        tsx = (
            MAPS
            / f"vectoraith_{role}.tsx"
        )

        firstgids[
            role
        ] = firstgid

        ET.SubElement(
            root,
            "tileset",
            {
                "firstgid":
                    str(firstgid),

                "source":
                    tsx.name,
            },
        )

        firstgid += tilecount(
            tsx
        )

    firstgids[
        "soil"
    ] = firstgid

    ET.SubElement(
        root,
        "tileset",
        {
            "firstgid":
                str(firstgid),

            "source":
                soil_tsx.name,
        },
    )

    def gid(
        role,
        local_id,
    ):
        return (
            firstgids[
                role
            ]
            + local_id
        )

    # --------------------------------------------------------
    # GROUND
    # --------------------------------------------------------

    ground = blank()

    grass_variants = [
        1,
        1,
        1,
        1,
        1,
        2,
        16,
        17,
        18,
    ]

    for y in range(H):
        for x in range(W):

            selector = (
                x * 17
                + y * 31
                + x * y * 3
            ) % len(
                grass_variants
            )

            set_tile(
                ground,
                x,
                y,
                gid(
                    "terrain",
                    grass_variants[
                        selector
                    ],
                ),
            )

    root.append(
        layer(
            1,
            "ground",
            ground,
        )
    )

    # --------------------------------------------------------
    # PATH
    # --------------------------------------------------------

    paths = blank()

    path_cells = set()

    # Main crossing lanes.
    for y in range(
        3,
        17,
    ):
        path_cells.add(
            (7, y)
        )

        path_cells.add(
            (12, y)
        )

    for x in range(
        3,
        17,
    ):
        path_cells.add(
            (x, 7)
        )

        path_cells.add(
            (x, 12)
        )

    # Central little plaza.
    for y in range(
        8,
        12,
    ):
        for x in range(
            8,
            12,
        ):
            path_cells.add(
                (x, y)
            )

    for x, y in path_cells:
        set_tile(
            paths,
            x,
            y,
            gid(
                "terrain",
                35,
            ),
        )

    root.append(
        layer(
            2,
            "paths",
            paths,
        )
    )

    # --------------------------------------------------------
    # CULTIVATION SOIL
    # --------------------------------------------------------

    soil = blank()

    for _, px, py in PLOTS:
        for dy in range(2):
            for dx in range(2):
                set_tile(
                    soil,
                    px + dx,
                    py + dy,
                    gid(
                        "soil",
                        0,
                    ),
                )

    root.append(
        layer(
            3,
            "soil",
            soil,
        )
    )

    # --------------------------------------------------------
    # ORCHARD / LARGE TREES
    #
    # Composite 3×3 trees from the real orchard sheet.
    # --------------------------------------------------------

    orchard = blank()

    def composite(
        x,
        y,
        ids,
    ):
        for dy, row_ids in enumerate(
            ids
        ):
            for dx, local_id in enumerate(
                row_ids
            ):
                set_tile(
                    orchard,
                    x + dx,
                    y + dy,
                    gid(
                        "orchard",
                        local_id,
                    ),
                )

    # Apple tree.
    composite(
        1,
        1,
        [
            [8, 9, 10],
            [24, 25, 26],
            [40, 41, 42],
        ],
    )

    # Orange / golden fruit tree.
    composite(
        16,
        1,
        [
            [56, 57, 58],
            [72, 73, 74],
            [88, 89, 90],
        ],
    )

    root.append(
        layer(
            4,
            "orchard_preview",
            orchard,
        )
    )

    # --------------------------------------------------------
    # CROPS
    # --------------------------------------------------------

    plants = blank()

    for (
        plot,
        (
            species,
            stages,
        ),
    ) in zip(
        PLOTS,
        CROPS,
    ):

        _, px, py = plot

        mature_id = (
            stages[-1]
        )

        # Four plants in each 2×2 cultivation bed.
        for dy in range(2):
            for dx in range(2):
                set_tile(
                    plants,
                    px + dx,
                    py + dy,
                    gid(
                        "crops_dense",
                        mature_id,
                    ),
                )

    root.append(
        layer(
            5,
            "plants_preview",
            plants,
        )
    )

    # --------------------------------------------------------
    # DECOR
    # --------------------------------------------------------

    decor = blank()

    decorations = [
        # rocks
        (2, 7, 65),
        (17, 7, 66),
        (2, 16, 67),
        (17, 16, 80),
        (3, 17, 81),
        (16, 17, 82),

        # flowers / bushes
        (2, 11, 96),
        (17, 11, 100),
        (3, 3, 104),
        (16, 3, 112),
        (2, 13, 116),
        (17, 13, 120),
    ]

    for x, y, tile_id in decorations:
        set_tile(
            decor,
            x,
            y,
            gid(
                "details",
                tile_id,
            ),
        )

    root.append(
        layer(
            6,
            "decor",
            decor,
        )
    )

    # --------------------------------------------------------
    # LOGICAL PLOTS
    # --------------------------------------------------------

    plots = ET.SubElement(
        root,
        "objectgroup",
        {
            "id": "7",
            "name": "plots",
        },
    )

    next_object = 1

    for (
        plot,
        crop,
    ) in zip(
        PLOTS,
        CROPS,
    ):

        plot_id, px, py = (
            plot
        )

        species, stages = crop

        obj = ET.SubElement(
            plots,
            "object",
            {
                "id":
                    str(next_object),

                "name":
                    f"plot_{plot_id}",

                "class":
                    "plot",

                # center of the 2×2 bed
                "x":
                    str(
                        (
                            px + 1
                        )
                        * TILE
                    ),

                "y":
                    str(
                        (
                            py + 1
                        )
                        * TILE
                    ),
            },
        )

        ET.SubElement(
            obj,
            "point",
        )

        properties = ET.SubElement(
            obj,
            "properties",
        )

        property_node(
            properties,
            "gridX",
            px,
            "int",
        )

        property_node(
            properties,
            "gridY",
            py,
            "int",
        )

        property_node(
            properties,
            "species",
            species,
        )

        property_node(
            properties,
            "stage0Tile",
            stages[0],
            "int",
        )

        property_node(
            properties,
            "stage1Tile",
            stages[1],
            "int",
        )

        property_node(
            properties,
            "stage2Tile",
            stages[2],
            "int",
        )

        property_node(
            properties,
            "stage3Tile",
            stages[3],
            "int",
        )

        next_object += 1

    root.set(
        "nextlayerid",
        "8",
    )

    root.set(
        "nextobjectid",
        str(next_object),
    )

    ET.indent(
        root,
        space="  ",
    )

    ET.ElementTree(
        root
    ).write(
        MAP,
        encoding="utf-8",
        xml_declaration=True,
    )

    # Also save the useful crop mapping independently.
    catalog = {
        species: {
            "tileset":
                "crops_dense",

            "stages":
                stages,
        }
        for species, stages
        in CROPS
    }

    (
        AUDIT
        / "crop_catalog.json"
    ).write_text(
        json.dumps(
            catalog,
            indent=2,
        )
        + "\n",
        encoding="utf-8",
    )


# ============================================================
# EXPORT
# ============================================================

def export_preview():
    tiled = (
        shutil.which("tiled")
        or shutil.which("Tiled")
    )

    if tiled is None:
        print(
            "⚠ Tiled CLI introuvable : pas de PNG exporté."
        )
        return

    output = (
        AUDIT
        / "potager_2d_poc.png"
    )

    subprocess.run(
        [
            tiled,
            "--export-map",
            str(MAP),
            str(output),
        ],
        cwd=ROOT,
        check=False,
    )

    if output.exists():
        print(
            "✓",
            output.relative_to(ROOT),
        )


def main():
    verify()

    AUDIT.mkdir(
        parents=True,
        exist_ok=True,
    )

    soil_tsx = create_soil()

    build_map(
        soil_tsx
    )

    export_preview()

    print()
    print(
        "✅ Growstep 2D POC généré"
    )

    print()
    print(
        "Ouvre :"
    )

    print(
        "  tiled assets/maps/"
        "potager_2d_poc.tmx"
    )

    print()
    print(
        "Crop catalog :"
    )

    print(
        "  docs/vectoraith-audit/"
        "crop_catalog.json"
    )


if __name__ == "__main__":
    main()

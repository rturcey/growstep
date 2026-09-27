#!/usr/bin/env python3

from __future__ import annotations

import importlib.util
import json
import math
import random
import xml.etree.ElementTree as ET
from pathlib import Path

from PIL import Image, ImageDraw


ROOT = Path(__file__).resolve().parents[1]

SPRITES = ROOT / "assets" / "sprites"
MAPS = ROOT / "assets" / "maps"

BASE_SCRIPT = ROOT / "scripts" / "rebuild_potager_square.py"

MAP = MAPS / "potager_square_v1.tmx"
MANIFEST_PATH = SPRITES / "manifest.json"

EDGE_TSX = MAPS / "palette_island_edges.tsx"

PREVIEW = (
    ROOT
    / "docs"
    / "visual-review"
    / "potager-square-v1"
    / "potager_square_v1.png"
)

# Logical visible island.
MIN_GRID = -2
MAX_GRID = 2

# Exposure flags.
NW = 1
NE = 2
SE = 4
SW = 8

# Generated sprite at 4x.
S = 4

LOGICAL_W = 128
LOGICAL_H = 104

PNG_W = LOGICAL_W * S
PNG_H = LOGICAL_H * S

# Tile contact inside the large sprite.
CONTACT_X = 64
CONTACT_Y = 20

POSSIBLE_MASKS = [
    NW,
    NE,
    SE,
    SW,
    NW | NE,
    NE | SE,
    NW | SW,
    SE | SW,
]


# ============================================================
# BASE / UNDO WRONG PASS
# ============================================================

def load_base():
    spec = importlib.util.spec_from_file_location(
        "growstep_square_base",
        BASE_SCRIPT,
    )

    if spec is None or spec.loader is None:
        raise RuntimeError(
            f"Cannot import {BASE_SCRIPT}"
        )

    module = importlib.util.module_from_spec(spec)

    spec.loader.exec_module(module)

    return module


def undo_wrong_premium_attempt():
    """
    Remove assets created by the previous misunderstanding.

    The important part is that base.main() is run immediately
    afterwards, which regenerates the original square terrain
    and original path layer cleanly.
    """

    wrong_tsx = (
        MAPS
        / "potager_square_paths_premium.tsx"
    )

    if wrong_tsx.exists():
        wrong_tsx.unlink()

    for path in SPRITES.glob(
        "potager_square_path_*.png"
    ):
        path.unlink()

    print(
        "✓ previous wrong path/border pass removed"
    )


# ============================================================
# DRAWING HELPERS
# ============================================================

def sp(value):
    return round(value * S)


def pt(x, y):
    return (
        sp(x),
        sp(y),
    )


def polygon(draw, points, fill):
    draw.polygon(
        [
            pt(x, y)
            for x, y in points
        ],
        fill=fill,
    )


def line(
    draw,
    points,
    fill,
    width=1,
):
    draw.line(
        [
            pt(x, y)
            for x, y in points
        ],
        fill=fill,
        width=max(
            1,
            sp(width),
        ),
        joint="curve",
    )


def ellipse(
    draw,
    box,
    fill,
):
    draw.ellipse(
        tuple(
            sp(v)
            for v in box
        ),
        fill=fill,
    )


# ============================================================
# CLIFF / EARTH WALL
# ============================================================

def irregular_bottom(
    rng,
    x1,
    y1,
    x2,
    y2,
    count=6,
):
    values = []

    for index in range(
        count + 1
    ):
        t = index / count

        x = (
            x1
            + (
                x2
                - x1
            )
            * t
        )

        y = (
            y1
            + (
                y2
                - y1
            )
            * t
            + rng.uniform(
                -2.0,
                2.0,
            )
        )

        values.append(
            (
                x,
                y,
            )
        )

    return values


def draw_earth_wall(
    image,
    side,
    rng,
):
    draw = ImageDraw.Draw(
        image,
        "RGBA",
    )

    # MUCH larger than the previous incorrect little line.
    #
    # Top edge follows the actual 80x40 diamond.
    # Bottom extends far below the ground contact.
    if side == SW:
        top_a = (24, 20)
        top_b = (64, 40)

        bottom_a = (15, 61)
        bottom_b = (58, 88)

    else:
        top_a = (64, 40)
        top_b = (104, 20)

        bottom_a = (70, 88)
        bottom_b = (113, 61)

    bottom = irregular_bottom(
        rng,
        bottom_b[0],
        bottom_b[1],
        bottom_a[0],
        bottom_a[1],
    )

    wall = [
        top_a,
        top_b,
        *bottom,
    ]

    # Dark foundation.
    polygon(
        draw,
        wall,
        (
            83,
            55,
            37,
            255,
        ),
    )

    # Main warm earth.
    inset_bottom = [
        (
            x,
            y - 5,
        )
        for x, y in bottom
    ]

    body = [
        top_a,
        top_b,
        *inset_bottom,
    ]

    polygon(
        draw,
        body,
        (
            136,
            91,
            54,
            255,
        ),
    )

    # Warm top highlight.
    line(
        draw,
        [
            top_a,
            top_b,
        ],
        (
            179,
            126,
            69,
            255,
        ),
        2.0,
    )

    # --------------------------------------------------------
    # Large masonry / compacted-soil blocks.
    # --------------------------------------------------------

    segment_count = 4

    for index in range(
        1,
        segment_count,
    ):
        t = (
            index
            / segment_count
        )

        tx = (
            top_a[0]
            + (
                top_b[0]
                - top_a[0]
            )
            * t
        )

        ty = (
            top_a[1]
            + (
                top_b[1]
                - top_a[1]
            )
            * t
        )

        bx = (
            bottom_a[0]
            + (
                bottom_b[0]
                - bottom_a[0]
            )
            * t
        )

        by = (
            bottom_a[1]
            + (
                bottom_b[1]
                - bottom_a[1]
            )
            * t
        )

        bx += rng.uniform(
            -2,
            2,
        )

        by += rng.uniform(
            -2,
            2,
        )

        line(
            draw,
            [
                (
                    tx,
                    ty + 2,
                ),
                (
                    bx,
                    by - 3,
                ),
            ],
            (
                91,
                59,
                39,
                180,
            ),
            1.2,
        )

        line(
            draw,
            [
                (
                    tx + 1.5,
                    ty + 2,
                ),
                (
                    bx + 1.5,
                    by - 3,
                ),
            ],
            (
                173,
                119,
                69,
                90,
            ),
            0.8,
        )

    # Two strata give the reference's chunky retaining-wall feel.
    for level in (
        0.38,
        0.70,
    ):
        a = (
            top_a[0]
            + (
                bottom_a[0]
                - top_a[0]
            )
            * level,
            top_a[1]
            + (
                bottom_a[1]
                - top_a[1]
            )
            * level,
        )

        b = (
            top_b[0]
            + (
                bottom_b[0]
                - top_b[0]
            )
            * level,
            top_b[1]
            + (
                bottom_b[1]
                - top_b[1]
            )
            * level,
        )

        line(
            draw,
            [
                a,
                b,
            ],
            (
                82,
                54,
                37,
                145,
            ),
            1.1,
        )

    # Little soil texture.
    for _ in range(20):
        t = rng.random()

        x = (
            top_a[0]
            + (
                top_b[0]
                - top_a[0]
            )
            * t
        )

        y_top = (
            top_a[1]
            + (
                top_b[1]
                - top_a[1]
            )
            * t
        )

        y = (
            y_top
            + rng.uniform(
                9,
                38,
            )
        )

        ellipse(
            draw,
            (
                x,
                y,
                x + rng.uniform(
                    0.8,
                    1.7,
                ),
                y + rng.uniform(
                    0.6,
                    1.3,
                ),
            ),
            (
                74,
                49,
                34,
                rng.randint(
                    55,
                    115,
                ),
            ),
        )


# ============================================================
# GRASS LIP
# ============================================================

def side_points(side):
    if side == NW:
        return (
            (24, 20),
            (64, 0),
        )

    if side == NE:
        return (
            (64, 0),
            (104, 20),
        )

    if side == SE:
        return (
            (64, 40),
            (104, 20),
        )

    return (
        (24, 20),
        (64, 40),
    )


def draw_grass_lip(
    image,
    side,
    rng,
):
    draw = ImageDraw.Draw(
        image,
        "RGBA",
    )

    a, b = side_points(
        side
    )

    points = []

    for index in range(17):
        t = index / 16

        x = (
            a[0]
            + (
                b[0]
                - a[0]
            )
            * t
        )

        y = (
            a[1]
            + (
                b[1]
                - a[1]
            )
            * t
        )

        # Natural overgrown contour.
        y += rng.choice(
            [
                -1.8,
                -1.0,
                -0.5,
                0,
                0,
                0.5,
            ]
        )

        points.append(
            (
                x,
                y,
            )
        )

    # Deep green underside.
    line(
        draw,
        points,
        (
            70,
            111,
            49,
            255,
        ),
        5,
    )

    # Rich green body.
    line(
        draw,
        points,
        (
            125,
            177,
            72,
            255,
        ),
        3.5,
    )

    # Light exposed top.
    line(
        draw,
        [
            (
                x,
                y - 1.3,
            )
            for x, y in points
        ],
        (
            187,
            218,
            109,
            240,
        ),
        1.2,
    )

    # Hanging grass.
    if side in (
        SE,
        SW,
    ):
        for index in range(
            1,
            16,
            2,
        ):
            x, y = points[index]

            length = rng.uniform(
                2,
                7,
            )

            lean = rng.uniform(
                -2,
                2,
            )

            line(
                draw,
                [
                    (
                        x,
                        y,
                    ),
                    (
                        x + lean,
                        y + length,
                    ),
                ],
                (
                    81,
                    135,
                    53,
                    230,
                ),
                rng.uniform(
                    0.6,
                    1.1,
                ),
            )


# ============================================================
# ROCKS — THIS IS THE "IDEM POUR LES PIERRES"
#
# These are border rocks, not path stepping stones.
# ============================================================

def irregular_rock_points(
    rng,
    cx,
    cy,
    rx,
    ry,
    count=9,
):

    result = []

    for index in range(count):
        angle = (
            math.tau
            * index
            / count
        )

        radius = rng.uniform(
            0.82,
            1.08,
        )

        result.append(
            (
                cx
                + math.cos(
                    angle
                )
                * rx
                * radius,

                cy
                + math.sin(
                    angle
                )
                * ry
                * radius,
            )
        )

    return result


def draw_rock(
    image,
    rng,
    cx,
    cy,
    rx,
    ry,
):
    draw = ImageDraw.Draw(
        image,
        "RGBA",
    )

    rock = irregular_rock_points(
        rng,
        cx,
        cy,
        rx,
        ry,
    )

    shadow = [
        (
            x + 2,
            y + 3,
        )
        for x, y in rock
    ]

    polygon(
        draw,
        shadow,
        (
            61,
            67,
            52,
            105,
        ),
    )

    polygon(
        draw,
        rock,
        (
            132,
            137,
            116,
            255,
        ),
    )

    inner = [
        (
            cx
            + (
                x - cx
            )
            * 0.78
            - 1.2,

            cy
            + (
                y - cy
            )
            * 0.70
            - 1.7,
        )
        for x, y in rock
    ]

    polygon(
        draw,
        inner,
        (
            166,
            172,
            145,
            255,
        ),
    )

    line(
        draw,
        [
            (
                cx - rx * 0.45,
                cy - ry * 0.25,
            ),
            (
                cx - rx * 0.10,
                cy - ry * 0.55,
            ),
            (
                cx + rx * 0.32,
                cy - ry * 0.36,
            ),
        ],
        (
            207,
            210,
            181,
            190,
        ),
        1,
    )


def draw_rocks_for_side(
    image,
    side,
    rng,
):
    if side == SW:
        positions = [
            (
                24,
                58,
                8,
                7,
            ),
            (
                34,
                66,
                11,
                9,
            ),
        ]

    elif side == SE:
        positions = [
            (
                94,
                58,
                8,
                7,
            ),
            (
                82,
                69,
                11,
                9,
            ),
        ]

    elif side == NW:
        positions = [
            (
                33,
                14,
                7,
                5,
            ),
        ]

    else:
        positions = [
            (
                95,
                14,
                7,
                5,
            ),
        ]

    for values in positions:
        draw_rock(
            image,
            rng,
            *values,
        )


# ============================================================
# FLOWERS / BORDER VEGETATION
# ============================================================

def draw_border_flowers(
    image,
    side,
    rng,
):
    draw = ImageDraw.Draw(
        image,
        "RGBA",
    )

    a, b = side_points(
        side
    )

    for index in (
        4,
        9,
        13,
    ):
        t = index / 16

        x = (
            a[0]
            + (
                b[0]
                - a[0]
            )
            * t
        )

        y = (
            a[1]
            + (
                b[1]
                - a[1]
            )
            * t
        )

        y -= rng.uniform(
            2,
            5,
        )

        # Stem
        line(
            draw,
            [
                (
                    x,
                    y + 4,
                ),
                (
                    x,
                    y,
                ),
            ],
            (
                62,
                112,
                51,
                230,
            ),
            0.8,
        )

        # White petals.
        for angle in (
            0,
            math.pi / 2,
            math.pi,
            math.pi * 1.5,
        ):
            px = (
                x
                + math.cos(
                    angle
                )
                * 1.7
            )

            py = (
                y
                + math.sin(
                    angle
                )
                * 1.7
            )

            ellipse(
                draw,
                (
                    px - 1,
                    py - 0.8,
                    px + 1,
                    py + 0.8,
                ),
                (
                    246,
                    241,
                    212,
                    240,
                ),
            )

        ellipse(
            draw,
            (
                x - 0.8,
                y - 0.8,
                x + 0.8,
                y + 0.8,
            ),
            (
                230,
                186,
                69,
                255,
            ),
        )


# ============================================================
# EDGE SPRITE
# ============================================================

def make_edge_sprite(
    mask,
    variant,
):

    rng = random.Random(
        20260927
        + mask * 100
        + variant
    )

    image = Image.new(
        "RGBA",
        (
            PNG_W,
            PNG_H,
        ),
        (
            0,
            0,
            0,
            0,
        ),
    )

    # Front / visible cliff faces.
    for side in (
        SW,
        SE,
    ):
        if mask & side:
            draw_earth_wall(
                image,
                side,
                rng,
            )

    # Grass lip on every exposed map edge.
    for side in (
        NW,
        NE,
        SE,
        SW,
    ):
        if mask & side:
            draw_grass_lip(
                image,
                side,
                rng,
            )

    if variant == 1:
        # Big border rock masses.
        for side in (
            NW,
            NE,
            SE,
            SW,
        ):
            if mask & side:
                draw_rocks_for_side(
                    image,
                    side,
                    rng,
                )

    elif variant == 2:
        # Flowering / lush variant.
        for side in (
            NW,
            NE,
            SE,
            SW,
        ):
            if mask & side:
                draw_border_flowers(
                    image,
                    side,
                    rng,
                )

    return image


# ============================================================
# GENERATE EDGE ASSETS + MANIFEST
# ============================================================

def asset_name(
    mask,
    variant,
):
    variant_name = [
        "naturelle",
        "rochers",
        "fleurie",
    ][variant]

    return (
        "potager_bordure_ilot_"
        f"{mask:02x}_"
        f"{variant_name}_"
        "statique_ordinaire_00.png"
    )


def build_edge_assets():

    manifest = json.loads(
        MANIFEST_PATH.read_text(
            encoding="utf-8"
        )
    )

    names = []

    for mask in POSSIBLE_MASKS:

        for variant in range(3):

            name = asset_name(
                mask,
                variant,
            )

            image = make_edge_sprite(
                mask,
                variant,
            )

            image.save(
                SPRITES / name,
                "PNG",
                optimize=True,
            )

            manifest[name] = {
                "width": PNG_W,
                "height": PNG_H,

                "bbox": [
                    0,
                    0,
                    PNG_W,
                    PNG_H,
                ],

                # The grid cell ground contact.
                "anchor": [
                    CONTACT_X * S,
                    CONTACT_Y * S,
                ],

                "shadow": "none",
            }

            names.append(
                name
            )

    MANIFEST_PATH.write_text(
        json.dumps(
            manifest,
            indent=2,
            ensure_ascii=False,
        )
        + "\n",
        encoding="utf-8",
    )

    print(
        f"✓ island border sprites: {len(names)}"
    )

    return names, manifest


# ============================================================
# TILED PALETTE
# ============================================================

def build_edge_tileset(
    names,
):
    root = ET.Element(
        "tileset",
        {
            "version": "1.10",
            "tiledversion": "1.11.2",
            "name": "island_edges",
            "tilewidth": str(PNG_W),
            "tileheight": str(PNG_H),
            "tilecount": str(
                len(names)
            ),
            "columns": "0",
            "objectalignment": "bottom",
        },
    )

    lookup = {}

    for tile_id, name in enumerate(
        names
    ):
        lookup[name] = tile_id

        tile = ET.SubElement(
            root,
            "tile",
            {
                "id": str(tile_id),
            },
        )

        ET.SubElement(
            tile,
            "image",
            {
                "source":
                    f"../sprites/{name}",

                "width":
                    str(PNG_W),

                "height":
                    str(PNG_H),
            },
        )

    ET.indent(
        root,
        space="  ",
    )

    ET.ElementTree(
        root
    ).write(
        EDGE_TSX,
        encoding="utf-8",
        xml_declaration=True,
    )

    print(
        "✓ palette_island_edges.tsx"
    )

    return lookup


# ============================================================
# PATCH TMX
# ============================================================

def tsx_count(
    path,
):
    root = ET.parse(
        path
    ).getroot()

    value = root.get(
        "tilecount"
    )

    if value:
        return int(value)

    ids = [
        int(
            tile.get(
                "id",
                "0",
            )
        )
        for tile
        in root.findall(
            "tile"
        )
    ]

    return (
        max(ids) + 1
        if ids
        else 0
    )


def exposure_mask(
    i,
    j,
):
    mask = 0

    if i == MIN_GRID:
        mask |= NW

    if j == MIN_GRID:
        mask |= NE

    if i == MAX_GRID:
        mask |= SE

    if j == MAX_GRID:
        mask |= SW

    return mask


def choose_variant(
    i,
    j,
    mask,
):
    # Deterministic art direction:
    #
    # - a few substantial rock masses;
    # - some flowers;
    # - most border remains natural.
    rocky = {
        (-2, 1),
        (2, 0),
        (2, 2),
        (1, 2),
    }

    flowering = {
        (-2, -1),
        (-1, -2),
        (0, 2),
        (2, -1),
    }

    if (
        i,
        j,
    ) in rocky:
        return 1

    if (
        i,
        j,
    ) in flowering:
        return 2

    return 0


def add_properties(
    parent,
    values,
):
    props = ET.SubElement(
        parent,
        "properties",
    )

    for key, value in values.items():

        attrs = {
            "name": key,
        }

        if isinstance(
            value,
            float,
        ):
            attrs[
                "type"
            ] = "float"

            attrs[
                "value"
            ] = f"{value:g}"

        elif isinstance(
            value,
            int,
        ):
            attrs[
                "type"
            ] = "int"

            attrs[
                "value"
            ] = str(value)

        else:
            attrs[
                "value"
            ] = str(value)

        ET.SubElement(
            props,
            "property",
            attrs,
        )


def patch_map(
    base,
    tile_ids,
):

    tree = ET.parse(
        MAP
    )

    root = tree.getroot()

    # --------------------------------------------------------
    # Add edge tileset after existing palettes.
    # --------------------------------------------------------

    next_gid = 1

    for ref in root.findall(
        "tileset"
    ):
        path = (
            MAPS
            / ref.get(
                "source"
            )
        )

        if not path.exists():
            continue

        next_gid = max(
            next_gid,
            int(
                ref.get(
                    "firstgid"
                )
            )
            + tsx_count(
                path
            ),
        )

    edge_firstgid = next_gid

    edge_ref = ET.Element(
        "tileset",
        {
            "firstgid":
                str(
                    edge_firstgid
                ),

            "source":
                EDGE_TSX.name,
        },
    )

    children = list(
        root
    )

    tileset_indices = [
        index
        for index, child
        in enumerate(
            children
        )
        if child.tag
        == "tileset"
    ]

    root.insert(
        (
            max(
                tileset_indices
            )
            + 1
            if tileset_indices
            else 0
        ),
        edge_ref,
    )

    # --------------------------------------------------------
    # Real dedicated outer-map layer.
    # --------------------------------------------------------

    edge_group = ET.Element(
        "objectgroup",
        {
            "id":
                root.get(
                    "nextlayerid",
                    "100",
                ),

            "name":
                "edge_overlays",
        },
    )

    object_id = int(
        root.get(
            "nextobjectid",
            "1000",
        )
    )

    for i in range(
        MIN_GRID,
        MAX_GRID + 1,
    ):
        for j in range(
            MIN_GRID,
            MAX_GRID + 1,
        ):

            mask = exposure_mask(
                i,
                j,
            )

            if mask == 0:
                continue

            variant = choose_variant(
                i,
                j,
                mask,
            )

            name = asset_name(
                mask,
                variant,
            )

            tile_id = tile_ids[
                name
            ]

            x, y = base.grid_to_tiled(
                i,
                j,
            )

            obj = ET.SubElement(
                edge_group,
                "object",
                {
                    "id":
                        str(
                            object_id
                        ),

                    "name":
                        (
                            "island_edge_"
                            f"{i}_{j}"
                        ),

                    "class":
                        "island_edge",

                    "gid":
                        str(
                            edge_firstgid
                            + tile_id
                        ),

                    "x":
                        f"{x:g}",

                    "y":
                        f"{y:g}",

                    # Source PNG is 4x.
                    "width":
                        str(
                            LOGICAL_W
                        ),

                    "height":
                        str(
                            LOGICAL_H
                        ),
                },
            )

            # Front edges should naturally render above
            # interior content at the very front of the map.
            front = bool(
                mask
                & (
                    SE
                    | SW
                )
            )

            add_properties(
                obj,
                {
                    "gridCol":
                        float(i),

                    "gridRow":
                        float(j),

                    "zBias":
                        (
                            8.0
                            if front
                            else -4.0
                        ),
                },
            )

            object_id += 1

    # Place edge_overlays after props but before plots if possible.
    children = list(
        root
    )

    insert_index = len(
        children
    )

    for index, child in enumerate(
        children
    ):
        if (
            child.tag
            == "objectgroup"
            and child.get(
                "name"
            )
            == "plots"
        ):
            insert_index = index
            break

    root.insert(
        insert_index,
        edge_group,
    )

    root.set(
        "nextobjectid",
        str(
            object_id
        ),
    )

    root.set(
        "nextlayerid",
        str(
            int(
                root.get(
                    "nextlayerid",
                    "100",
                )
            )
            + 1
        ),
    )

    ET.indent(
        root,
        space="  ",
    )

    tree.write(
        MAP,
        encoding="utf-8",
        xml_declaration=True,
    )

    print(
        "✓ outer island border automatically placed"
    )


# ============================================================
# PREVIEW INCLUDING edge_overlays
# ============================================================

def object_properties(
    obj,
):
    values = {}

    props = obj.find(
        "properties"
    )

    if props is None:
        return values

    for prop in props.findall(
        "property"
    ):
        values[
            prop.get(
                "name"
            )
        ] = prop.get(
            "value"
        )

    return values


def render_edge_without_shadow(
    base,
    canvas,
    obj,
    gids,
    manifest,
):

    gid = int(
        obj.get(
            "gid"
        )
    )

    path = gids[
        gid
    ]

    metadata = manifest[
        path.name
    ]

    props = object_properties(
        obj
    )

    i = float(
        props[
            "gridCol"
        ]
    )

    j = float(
        props[
            "gridRow"
        ]
    )

    contact_x, contact_y = (
        base.grid_to_artboard(
            i,
            j,
        )
    )

    width = float(
        obj.get(
            "width"
        )
    )

    height = float(
        obj.get(
            "height"
        )
    )

    image = Image.open(
        path
    ).convert(
        "RGBA"
    )

    image = image.resize(
        (
            round(
                width
            ),
            round(
                height
            ),
        ),
        Image.Resampling.LANCZOS,
    )

    anchor = metadata[
        "anchor"
    ]

    ax = (
        anchor[0]
        / metadata[
            "width"
        ]
    )

    ay = (
        anchor[1]
        / metadata[
            "height"
        ]
    )

    x = round(
        contact_x
        - image.width
        * ax
    )

    y = round(
        contact_y
        - image.height
        * ay
    )

    canvas.alpha_composite(
        image,
        (
            x,
            y,
        ),
    )


def render_preview(
    base,
    manifest,
):

    root = ET.parse(
        MAP
    ).getroot()

    gids = base.load_gid_table()

    canvas = Image.new(
        "RGBA",
        (
            base.ARTBOARD_W,
            base.ARTBOARD_H,
        ),
        (
            228,
            235,
            213,
            255,
        ),
    )

    layers = {
        layer.get(
            "name"
        ): layer
        for layer
        in root.findall(
            "layer"
        )
    }

    for name in (
        "ground",
        "path",
        "planter_edges_back",
    ):
        layer = layers.get(
            name
        )

        if layer is not None:
            base.render_tile_layer(
                canvas,
                layer,
                gids,
            )

    sortable = []

    allowed_groups = {
        "floor_decor",
        "vegetation",
        "rocks",
        "structures",
        "props",
        "edge_overlays",
        "preview_plants",
    }

    for group in root.findall(
        "objectgroup"
    ):
        group_name = group.get(
            "name"
        )

        if (
            group_name
            not in allowed_groups
        ):
            continue

        for obj in group.findall(
            "object"
        ):
            if obj.get(
                "gid"
            ) is None:
                continue

            props = object_properties(
                obj
            )

            if (
                "gridCol"
                not in props
                or "gridRow"
                not in props
            ):
                continue

            _, contact_y = (
                base.grid_to_artboard(
                    float(
                        props[
                            "gridCol"
                        ]
                    ),
                    float(
                        props[
                            "gridRow"
                        ]
                    ),
                )
            )

            z_bias = float(
                props.get(
                    "zBias",
                    "0",
                )
            )

            sortable.append(
                (
                    contact_y
                    + z_bias,

                    int(
                        obj.get(
                            "id"
                        )
                    ),

                    group_name,
                    obj,
                )
            )

    sortable.sort(
        key=lambda item: (
            item[0],
            item[1],
        )
    )

    for (
        _,
        _,
        group_name,
        obj,
    ) in sortable:

        if (
            group_name
            == "edge_overlays"
        ):
            render_edge_without_shadow(
                base,
                canvas,
                obj,
                gids,
                manifest,
            )

        else:
            base.render_sprite_object(
                canvas,
                obj,
                gids,
                manifest,
            )

    front = layers.get(
        "planter_edges_front"
    )

    if front is not None:
        base.render_tile_layer(
            canvas,
            front,
            gids,
        )

    PREVIEW.parent.mkdir(
        parents=True,
        exist_ok=True,
    )

    review = canvas.resize(
        (
            base.ARTBOARD_W
            * 2,

            base.ARTBOARD_H
            * 2,
        ),
        Image.Resampling.LANCZOS,
    )

    review.save(
        PREVIEW,
        "PNG",
        optimize=True,
    )

    print(
        f"✓ preview: {PREVIEW.relative_to(ROOT)}"
    )


# ============================================================
# MAIN
# ============================================================

def main():

    if not BASE_SCRIPT.exists():
        raise SystemExit(
            f"Missing {BASE_SCRIPT}"
        )

    print()
    print(
        "GROWSTEP — REAL ISLAND EDGES"
    )
    print(
        "============================"
    )
    print()

    # --------------------------------------------------------
    # 1. Undo my previous misunderstanding.
    # --------------------------------------------------------

    undo_wrong_premium_attempt()

    # --------------------------------------------------------
    # 2. Clean rebuild of the square map.
    #
    # This restores:
    # - normal path stones
    # - normal terrain tiles
    # - normal rock scale
    # - no bogus parcel-border enhancement
    # --------------------------------------------------------

    base = load_base()

    base.main()

    print()
    print(
        "BUILDING ACTUAL MAP BORDER"
    )
    print(
        "--------------------------"
    )

    # --------------------------------------------------------
    # 3. Build the ACTUAL island/map perimeter.
    # --------------------------------------------------------

    names, manifest = (
        build_edge_assets()
    )

    tile_ids = (
        build_edge_tileset(
            names
        )
    )

    patch_map(
        base,
        tile_ids,
    )

    # --------------------------------------------------------
    # 4. Render final visual review.
    # --------------------------------------------------------

    render_preview(
        base,
        manifest,
    )

    print()
    print(
        "============================"
    )

    print(
        "✅ REAL MAP BORDER READY"
    )

    print(
        "============================"
    )

    print()
    print(
        "Map:"
    )

    print(
        "  assets/maps/"
        "potager_square_v1.tmx"
    )

    print()
    print(
        "Tiled palette:"
    )

    print(
        "  palette_island_edges"
    )

    print()
    print(
        "Dedicated layer:"
    )

    print(
        "  edge_overlays"
    )

    print()
    print(
        "Preview:"
    )

    print(
        "  docs/visual-review/"
        "potager-square-v1/"
        "potager_square_v1.png"
    )

    print()
    print(
        "IMPORTANT:"
    )

    print(
        "  path stones were restored;"
    )

    print(
        "  parcel borders were restored;"
    )

    print(
        "  only the OUTER MAP BORDER "
        "received the premium treatment."
    )


if __name__ == "__main__":
    main()

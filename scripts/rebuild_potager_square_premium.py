#!/usr/bin/env python3

from __future__ import annotations

import importlib.util
import json
import random
import re
import xml.etree.ElementTree as ET
from pathlib import Path

from PIL import Image, ImageChops, ImageDraw


ROOT = Path(__file__).resolve().parents[1]

SPRITES = ROOT / "assets" / "sprites"
MAPS = ROOT / "assets" / "maps"

BASE_SCRIPT = (
    ROOT
    / "scripts"
    / "rebuild_potager_square.py"
)

MAP = (
    MAPS
    / "potager_square_v1.tmx"
)

PATH_TSX = (
    MAPS
    / "potager_square_paths_premium.tsx"
)

MANIFEST = (
    SPRITES
    / "manifest.json"
)

W = 80
H = 40


# ============================================================
# LOAD BASE REBUILDER
# ============================================================

def load_base():
    spec = importlib.util.spec_from_file_location(
        "growstep_square_base",
        BASE_SCRIPT,
    )

    module = importlib.util.module_from_spec(
        spec
    )

    assert spec.loader

    spec.loader.exec_module(
        module
    )

    return module


# ============================================================
# STRICT DIAMOND MASK
# ============================================================

def diamond_mask():
    img = Image.new(
        "L",
        (W, H),
        0,
    )

    draw = ImageDraw.Draw(
        img
    )

    draw.polygon(
        [
            (40, 0),
            (79, 20),
            (40, 39),
            (0, 20),
        ],
        fill=255,
    )

    return img


MASK = diamond_mask()


def clip_to_diamond(
    image: Image.Image,
):
    alpha = image.getchannel(
        "A"
    )

    image.putalpha(
        ImageChops.multiply(
            alpha,
            MASK,
        )
    )


# ============================================================
# PREMIUM TERRAIN EDGES
# ============================================================

EDGE_RE = re.compile(
    r"potager_square_"
    r"(grass|earth)_"
    r"edge_([0-9a-f]{2})_"
    r"(low|high)\.png$"
)


NW = 1
NE = 2
SE = 4
SW = 8


def line(
    draw,
    xy,
    fill,
    width=1,
):
    draw.line(
        xy,
        fill=fill,
        width=width,
    )


def jitter(
    rng,
    value,
    amount,
):
    return (
        value
        + rng.randint(
            -amount,
            amount,
        )
    )


def front_wall_polygon(
    side,
    depth,
):

    if side == SW:
        return [
            (0, 20),
            (40, 39),
            (40, 39 - depth),
            (depth * 2, 20),
        ]

    return [
        (40, 39),
        (79, 20),
        (79 - depth * 2, 20),
        (40, 39 - depth),
    ]


def paint_block_wall(
    overlay,
    side,
    *,
    material,
    depth,
    seed,
):
    rng = random.Random(
        seed
    )

    draw = ImageDraw.Draw(
        overlay,
        "RGBA",
    )

    poly = front_wall_polygon(
        side,
        depth,
    )

    if material == "grass":
        base = (
            112,
            73,
            44,
            245,
        )

        dark = (
            72,
            48,
            33,
            180,
        )

        light = (
            151,
            101,
            57,
            150,
        )

    else:
        base = (
            113,
            72,
            44,
            240,
        )

        dark = (
            69,
            43,
            29,
            185,
        )

        light = (
            151,
            100,
            61,
            135,
        )

    draw.polygon(
        poly,
        fill=base,
    )

    # --------------------------------------------------------
    # Gros blocs de terre / roche.
    # L'effet est volontairement beaucoup plus marqué
    # que dans la version précédente.
    # --------------------------------------------------------

    if side == SW:
        top_a = (
            2,
            20,
        )

        top_b = (
            40,
            38,
        )

        bottom_a = (
            depth * 2 + 2,
            20,
        )

        bottom_b = (
            40,
            38 - depth,
        )

    else:
        top_a = (
            40,
            38,
        )

        top_b = (
            78,
            20,
        )

        bottom_a = (
            40,
            38 - depth,
        )

        bottom_b = (
            78 - depth * 2,
            20,
        )

    segments = (
        4
        if depth >= 11
        else 3
    )

    for index in range(
        1,
        segments,
    ):
        t = (
            index
            / segments
        )

        x1 = (
            top_a[0]
            + (
                top_b[0]
                - top_a[0]
            )
            * t
        )

        y1 = (
            top_a[1]
            + (
                top_b[1]
                - top_a[1]
            )
            * t
        )

        x2 = (
            bottom_a[0]
            + (
                bottom_b[0]
                - bottom_a[0]
            )
            * t
        )

        y2 = (
            bottom_a[1]
            + (
                bottom_b[1]
                - bottom_a[1]
            )
            * t
        )

        x1 = jitter(
            rng,
            round(x1),
            1,
        )

        y1 = jitter(
            rng,
            round(y1),
            1,
        )

        x2 = jitter(
            rng,
            round(x2),
            1,
        )

        y2 = jitter(
            rng,
            round(y2),
            1,
        )

        line(
            draw,
            (
                x1,
                y1,
                x2,
                y2,
            ),
            dark,
            1,
        )

        line(
            draw,
            (
                x1 + 1,
                y1,
                x2 + 1,
                y2,
            ),
            light,
            1,
        )

    # Horizontal cracks / strata.
    for level in range(
        1,
        3,
    ):
        t = (
            level
            / 3
        )

        ax = (
            poly[0][0]
            + (
                poly[3][0]
                - poly[0][0]
            )
            * t
        )

        ay = (
            poly[0][1]
            + (
                poly[3][1]
                - poly[0][1]
            )
            * t
        )

        bx = (
            poly[1][0]
            + (
                poly[2][0]
                - poly[1][0]
            )
            * t
        )

        by = (
            poly[1][1]
            + (
                poly[2][1]
                - poly[1][1]
            )
            * t
        )

        line(
            draw,
            (
                jitter(
                    rng,
                    round(ax),
                    1,
                ),
                jitter(
                    rng,
                    round(ay),
                    1,
                ),
                jitter(
                    rng,
                    round(bx),
                    1,
                ),
                jitter(
                    rng,
                    round(by),
                    1,
                ),
            ),
            (
                75,
                47,
                32,
                105,
            ),
            1,
        )


def paint_grass_lip(
    overlay,
    side,
    depth,
    seed,
):
    rng = random.Random(
        seed
    )

    draw = ImageDraw.Draw(
        overlay,
        "RGBA",
    )

    if side == SW:
        start = (
            1,
            20,
        )

        end = (
            40,
            39,
        )

    else:
        start = (
            40,
            39,
        )

        end = (
            79,
            20,
        )

    points = []

    count = 14

    for index in range(
        count + 1
    ):
        t = (
            index
            / count
        )

        x = (
            start[0]
            + (
                end[0]
                - start[0]
            )
            * t
        )

        y = (
            start[1]
            + (
                end[1]
                - start[1]
            )
            * t
        )

        points.append(
            (
                round(x),
                round(
                    y
                    - rng.choice(
                        (
                            0,
                            0,
                            1,
                            1,
                            2,
                        )
                    )
                ),
            )
        )

    # Dark rim beneath grass.
    line(
        draw,
        points,
        (
            82,
            117,
            48,
            220,
        ),
        4,
    )

    # Main grass lip.
    line(
        draw,
        points,
        (
            144,
            189,
            79,
            255,
        ),
        3,
    )

    # Sunlit top.
    line(
        draw,
        [
            (
                x,
                y - 1,
            )
            for x, y in points
        ],
        (
            196,
            222,
            116,
            220,
        ),
        1,
    )

    # Tiny hanging grass accents.
    for index in range(
        2,
        count,
        3,
    ):
        x, y = points[
            index
        ]

        length = (
            2
            + rng.randint(
                0,
                2,
            )
        )

        line(
            draw,
            (
                x,
                y,
                x - 1,
                y + length,
            ),
            (
                93,
                143,
                54,
                210,
            ),
            1,
        )


def paint_back_lip(
    overlay,
    side,
):
    draw = ImageDraw.Draw(
        overlay,
        "RGBA",
    )

    if side == NW:
        points = [
            (0, 20),
            (40, 0),
        ]

    else:
        points = [
            (40, 0),
            (79, 20),
        ]

    line(
        draw,
        points,
        (
            107,
            147,
            59,
            210,
        ),
        3,
    )

    line(
        draw,
        [
            (
                x,
                y + 1,
            )
            for x, y in points
        ],
        (
            191,
            218,
            111,
            170,
        ),
        1,
    )


def upgrade_terrain():

    changed = 0

    for path in sorted(
        SPRITES.glob(
            "potager_square_*_edge_*_*.png"
        )
    ):
        match = EDGE_RE.match(
            path.name
        )

        if not match:
            continue

        material = match.group(
            1
        )

        exposure = int(
            match.group(2),
            16,
        )

        level = match.group(
            3
        )

        image = Image.open(
            path
        ).convert(
            "RGBA"
        )

        overlay = Image.new(
            "RGBA",
            image.size,
            (
                0,
                0,
                0,
                0,
            ),
        )

        # MUCH larger than old version.
        depth = (
            14
            if level == "high"
            else 9
        )

        seed = sum(
            ord(c)
            for c in path.name
        )

        for side in (
            SW,
            SE,
        ):
            if not (
                exposure
                & side
            ):
                continue

            paint_block_wall(
                overlay,
                side,
                material=material,
                depth=depth,
                seed=seed + side,
            )

            if material == "grass":
                paint_grass_lip(
                    overlay,
                    side,
                    depth,
                    seed + 100 + side,
                )

        for side in (
            NW,
            NE,
        ):
            if (
                exposure
                & side
                and material
                == "grass"
            ):
                paint_back_lip(
                    overlay,
                    side,
                )

        clip_to_diamond(
            overlay
        )

        image.alpha_composite(
            overlay
        )

        clip_to_diamond(
            image
        )

        image.save(
            path,
            "PNG",
            optimize=True,
        )

        changed += 1

    print(
        f"✓ premium borders: {changed} tiles"
    )


# ============================================================
# PREMIUM STEPPING STONES
# ============================================================

def irregular_stone(
    rng,
    cx,
    cy,
    rx,
    ry,
):
    points = []

    count = 10

    for index in range(
        count
    ):
        angle = (
            math_tau
            * index
            / count
        )

        radius = (
            0.86
            + rng.random()
            * 0.25
        )

        x = (
            cx
            + math_cos(angle)
            * rx
            * radius
        )

        y = (
            cy
            + math_sin(angle)
            * ry
            * radius
        )

        points.append(
            (
                round(x),
                round(y),
            )
        )

    return points


from math import (
    cos as math_cos,
    sin as math_sin,
    tau as math_tau,
)


def draw_stone(
    canvas,
    rng,
    cx,
    cy,
    rx,
    ry,
):

    # Separate shadow layer.
    draw = ImageDraw.Draw(
        canvas,
        "RGBA",
    )

    poly = irregular_stone(
        rng,
        cx,
        cy,
        rx,
        ry,
    )

    shadow = [
        (
            x + 1,
            y + 2,
        )
        for x, y in poly
    ]

    draw.polygon(
        shadow,
        fill=(
            91,
            83,
            61,
            105,
        ),
    )

    # Dark underside.
    draw.polygon(
        poly,
        fill=(
            180,
            172,
            136,
            255,
        ),
    )

    # Main cream stone.
    inner = []

    for x, y in poly:
        inner.append(
            (
                round(
                    cx
                    + (
                        x
                        - cx
                    )
                    * 0.89
                ),
                round(
                    cy
                    + (
                        y
                        - cy
                    )
                    * 0.84
                    - 1
                ),
            )
        )

    draw.polygon(
        inner,
        fill=(
            222,
            215,
            174,
            255,
        ),
    )

    # Warm highlight toward upper-left.
    highlight = [
        (
            round(
                cx
                + (
                    x
                    - cx
                )
                * 0.70
                - 1
            ),
            round(
                cy
                + (
                    y
                    - cy
                )
                * 0.58
                - 2
            ),
        )
        for x, y in poly[
            :5
        ]
    ]

    if len(highlight) >= 3:
        draw.line(
            highlight,
            fill=(
                247,
                240,
                200,
                205,
            ),
            width=1,
        )

    # Small cracks / scratches.
    if rng.random() < 0.75:
        draw.line(
            (
                cx - 2,
                cy,
                cx + 1,
                cy + 1,
                cx + 4,
                cy,
            ),
            fill=(
                154,
                146,
                114,
                115,
            ),
            width=1,
        )

    if rng.random() < 0.45:
        draw.ellipse(
            (
                cx + rx * 0.25,
                cy - 1,
                cx + rx * 0.25 + 1,
                cy,
            ),
            fill=(
                151,
                142,
                108,
                110,
            ),
        )


def make_path_tile(
    variant,
):
    rng = random.Random(
        9000 + variant
    )

    canvas = Image.new(
        "RGBA",
        (
            W,
            H,
        ),
        (
            0,
            0,
            0,
            0,
        ),
    )

    layouts = [
        [
            (40, 20, 25, 11),
        ],
        [
            (29, 19, 18, 9),
            (53, 22, 16, 8),
        ],
        [
            (24, 22, 15, 8),
            (46, 17, 17, 9),
            (62, 23, 11, 6),
        ],
        [
            (35, 18, 22, 10),
            (59, 23, 12, 6),
        ],
        [
            (23, 19, 13, 7),
            (43, 22, 19, 9),
            (65, 19, 10, 6),
        ],
        [
            (40, 20, 28, 12),
        ],
        [
            (28, 22, 18, 9),
            (54, 18, 18, 9),
        ],
        [
            (21, 22, 12, 6),
            (40, 18, 17, 9),
            (61, 22, 13, 7),
        ],
    ]

    for (
        cx,
        cy,
        rx,
        ry,
    ) in layouts[
        variant
        % len(layouts)
    ]:

        draw_stone(
            canvas,
            rng,
            cx,
            cy,
            rx,
            ry,
        )

    clip_to_diamond(
        canvas
    )

    return canvas


def build_paths():

    entries = []

    for variant in range(
        8
    ):
        name = (
            "potager_square_path_"
            f"{variant:02}.png"
        )

        image = make_path_tile(
            variant
        )

        image.save(
            SPRITES / name,
            "PNG",
            optimize=True,
        )

        entries.append(
            name
        )

    root = ET.Element(
        "tileset",
        {
            "version": "1.10",
            "tiledversion": "1.11.2",
            "name":
                "potager_square_paths_premium",
            "tilewidth": "80",
            "tileheight": "40",
            "tilecount":
                str(
                    len(entries)
                ),
            "columns": "0",
            "objectalignment": "bottom",
        },
    )

    for tile_id, name in enumerate(
        entries
    ):
        tile = ET.SubElement(
            root,
            "tile",
            {
                "id": str(
                    tile_id
                ),
            },
        )

        ET.SubElement(
            tile,
            "image",
            {
                "source":
                    f"../sprites/{name}",
                "width": "80",
                "height": "40",
            },
        )

    ET.indent(
        root,
        space="  ",
    )

    ET.ElementTree(
        root
    ).write(
        PATH_TSX,
        encoding="utf-8",
        xml_declaration=True,
    )

    print(
        "✓ premium stepping stones: "
        f"{len(entries)} variants"
    )


# ============================================================
# PATCH MAP TO PREMIUM PATH
# ============================================================

def tsx_count(
    path,
):
    root = ET.parse(
        path
    ).getroot()

    if root.get(
        "tilecount"
    ):
        return int(
            root.get(
                "tilecount"
            )
        )

    ids = [
        int(
            node.get(
                "id"
            )
        )
        for node
        in root.findall(
            "tile"
        )
    ]

    return (
        max(ids) + 1
        if ids
        else 0
    )


def patch_map():

    tree = ET.parse(
        MAP
    )

    root = tree.getroot()

    path_ref = None

    for ref in root.findall(
        "tileset"
    ):
        if (
            ref.get("source")
            == PATH_TSX.name
        ):
            path_ref = ref
            break

    if path_ref is None:

        next_gid = 1

        for ref in root.findall(
            "tileset"
        ):
            source = (
                MAPS
                / ref.get(
                    "source"
                )
            )

            if not source.exists():
                continue

            next_gid = max(
                next_gid,
                int(
                    ref.get(
                        "firstgid"
                    )
                )
                + tsx_count(
                    source
                ),
            )

        path_ref = ET.Element(
            "tileset",
            {
                "firstgid":
                    str(
                        next_gid
                    ),
                "source":
                    PATH_TSX.name,
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

        insert_at = (
            max(
                tileset_indices
            )
            + 1
            if tileset_indices
            else 0
        )

        root.insert(
            insert_at,
            path_ref,
        )

    firstgid = int(
        path_ref.get(
            "firstgid"
        )
    )

    path_layer = next(
        (
            layer
            for layer
            in root.findall(
                "layer"
            )
            if layer.get(
                "name"
            )
            == "path"
        ),
        None,
    )

    if path_layer is not None:

        node = path_layer.find(
            "data"
        )

        if (
            node is not None
            and node.text
        ):
            values = [
                int(
                    part.strip()
                )
                for part
                in node.text.replace(
                    "\n",
                    "",
                ).split(
                    ","
                )
                if part.strip()
            ]

            for index, gid in enumerate(
                values
            ):
                if gid == 0:
                    continue

                row = (
                    index
                    // int(
                        root.get(
                            "width"
                        )
                    )
                )

                col = (
                    index
                    % int(
                        root.get(
                            "width"
                        )
                    )
                )

                variant = (
                    col * 5
                    + row * 3
                ) % 8

                values[
                    index
                ] = (
                    firstgid
                    + variant
                )

            width = int(
                root.get(
                    "width"
                )
            )

            height = int(
                root.get(
                    "height"
                )
            )

            rows = []

            for row in range(
                height
            ):
                start = (
                    row
                    * width
                )

                rows.append(
                    ",".join(
                        str(value)
                        for value
                        in values[
                            start:
                            start
                            + width
                        ]
                    )
                )

            node.text = (
                "\n"
                + ",\n".join(
                    rows
                )
                + "\n"
            )

    # --------------------------------------------------------
    # Make the decorative rock feel less tiny too.
    # --------------------------------------------------------

    for group in root.findall(
        "objectgroup"
    ):
        for obj in group.findall(
            "object"
        ):
            if obj.get(
                "name"
            ) != "east_upper_rock":
                continue

            width = float(
                obj.get(
                    "width",
                    "0",
                )
            )

            height = float(
                obj.get(
                    "height",
                    "0",
                )
            )

            obj.set(
                "width",
                f"{width * 1.28:.2f}",
            )

            obj.set(
                "height",
                f"{height * 1.28:.2f}",
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
        "✓ map switched to premium stones"
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
        "GROWSTEP — PREMIUM SQUARE REBUILD"
    )
    print(
        "================================"
    )
    print()

    base = load_base()

    # First rebuild everything cleanly.
    base.main()

    print()
    print(
        "UPGRADING ART"
    )
    print(
        "-------------"
    )

    upgrade_terrain()

    build_paths()

    patch_map()

    # Re-render preview using the renderer
    # from the base generator.
    manifest = json.loads(
        MANIFEST.read_text(
            encoding="utf-8"
        )
    )

    base.render_preview(
        manifest
    )

    print()
    print(
        "================================"
    )
    print(
        "✅ PREMIUM MAP READY"
    )
    print(
        "================================"
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
        "Preview:"
    )
    print(
        "  docs/visual-review/"
        "potager-square-v1/"
        "potager_square_v1.png"
    )


if __name__ == "__main__":
    main()

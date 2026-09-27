#!/usr/bin/env python3

from __future__ import annotations

import copy
import csv
import io
import json
import math
import xml.etree.ElementTree as ET
from pathlib import Path

from PIL import Image, ImageDraw


ROOT = Path(__file__).resolve().parents[1]

MAPS = ROOT / "assets" / "maps"
SPRITES = ROOT / "assets" / "sprites"
MANIFEST_PATH = SPRITES / "manifest.json"

SOURCE_MAP = MAPS / "potager_diorama_v1.tmx"
OUTPUT_MAP = MAPS / "potager_diorama_v2.tmx"
SCENE_TSX = MAPS / "potager_scene_v2.tsx"

PREVIEW_DIR = ROOT / "docs" / "visual-review" / "potager-v2"
PREVIEW = PREVIEW_DIR / "potager_diorama_v2.png"
LAYOUT_JSON = PREVIEW_DIR / "layout.json"

MAP_W = 14
MAP_H = 14
TILE_W = 80
TILE_H = 40

ARTBOARD_W = 390
ARTBOARD_H = 450

GRID_ORIGIN_X = 195
GRID_ORIGIN_Y = 230

TILED_ORIGIN_COL = 7
TILED_ORIGIN_ROW = 9


# ============================================================
# GAMEPLAY PLOTS
# ============================================================

PLOTS = [
    # index, i, j, kind
    (0, -3.5, -0.5, "earth"),
    (1,  1.0, -1.0, "planter"),
    (2,  0.5,  3.5, "earth"),
    (3,  3.5,  0.5, "earth"),
    (4, -2.0, -2.0, "planter"),
    (5, -1.0,  1.0, "planter"),
    (6,  2.0,  2.0, "planter"),
    (7, -0.5, -3.5, "earth"),
]


# ============================================================
# HELPERS
# ============================================================

def grid_to_artboard(i: float, j: float) -> tuple[float, float]:
    return (
        GRID_ORIGIN_X + (i - j) * TILE_W / 2,
        GRID_ORIGIN_Y + (i + j) * TILE_H / 2,
    )


def grid_to_tiled(i: float, j: float) -> tuple[float, float]:
    return (
        (i + TILED_ORIGIN_COL + 0.5) * TILE_H,
        (j + TILED_ORIGIN_ROW + 0.5) * TILE_H,
    )


def tsx_count(path: Path) -> int:
    root = ET.parse(path).getroot()

    if root.get("tilecount"):
        return int(root.get("tilecount"))

    ids = [
        int(tile.get("id", "0"))
        for tile in root.findall("tile")
    ]

    return max(ids) + 1 if ids else 0


def write_csv_layer(values: list[int]) -> str:
    rows = []

    for y in range(MAP_H):
        row = values[y * MAP_W:(y + 1) * MAP_W]
        rows.append(",".join(str(value) for value in row))

    return "\n" + ",\n".join(rows) + "\n"


def blank_layer() -> list[int]:
    return [0] * (MAP_W * MAP_H)


def set_tile(
    data: list[int],
    i: int,
    j: int,
    gid: int,
):
    col = i + TILED_ORIGIN_COL
    row = j + TILED_ORIGIN_ROW

    if not (0 <= col < MAP_W and 0 <= row < MAP_H):
        raise ValueError(
            f"grid ({i},{j}) -> tile ({col},{row}) outside map"
        )

    data[row * MAP_W + col] = gid


def add_properties(
    parent: ET.Element,
    values: dict[str, object],
):
    properties = ET.SubElement(
        parent,
        "properties",
    )

    for key, value in values.items():
        if isinstance(value, float):
            attrs = {
                "name": key,
                "type": "float",
                "value": f"{value:g}",
            }

        elif isinstance(value, int):
            attrs = {
                "name": key,
                "type": "int",
                "value": str(value),
            }

        else:
            attrs = {
                "name": key,
                "value": str(value),
            }

        ET.SubElement(
            properties,
            "property",
            attrs,
        )


# ============================================================
# SPRITE CHOICE
# ============================================================

def choose(
    manifest: dict,
    *names: str,
) -> str:

    for name in names:
        if name in manifest and (SPRITES / name).exists():
            return name

    raise RuntimeError(
        "Aucun asset trouvé parmi :\n  "
        + "\n  ".join(names)
    )


def select_assets(manifest: dict) -> dict[str, str]:

    return {
        # Gros volumes
        "tree_west": choose(
            manifest,
            "potager_decor_arbre_nichoir_statique_ordinaire_00.png",
            "potager_decor_arbre_canopee_ouest_statique_ordinaire_00.png",
        ),

        "tree_east": choose(
            manifest,
            "potager_decor_pommier_fruits_statique_ordinaire_00.png",
            "verger_arbre_pommier_recoltable_ordinaire_00.png",
            "potager_decor_arbre_canopee_est_statique_ordinaire_00.png",
        ),

        # Structure
        "arch": choose(
            manifest,
            "potager_decor_arche_fleurie_statique_ordinaire_00.png",
            "potager_decor_arche_diagonale_statique_ordinaire_00.png",
        ),

        "bench": choose(
            manifest,
            "potager_decor_banc_parc_statique_ordinaire_00.png",
            "potager_decor_banc_jardin_statique_ordinaire_00.png",
            "potager_decor_banc_bois_statique_ordinaire_00.png",
        ),

        # Point focal
        "fountain": choose(
            manifest,
            "potager_decor_bain_oiseaux_statique_ordinaire_00.png",
            "potager_decor_fontaine_pierre_statique_ordinaire_00.png",
        ),

        # Props
        "watering": choose(
            manifest,
            "potager_decor_arrosoir_bleu_statique_ordinaire_00.png",
            "potager_decor_arrosoir_metal_statique_ordinaire_00.png",
        ),

        "barrel": choose(
            manifest,
            "potager_decor_tonneau_pompe_statique_ordinaire_00.png",
            "commun_decor_tonneau_bois_statique_ordinaire_00.png",
        ),

        "basket": choose(
            manifest,
            "potager_decor_panier_pommes_statique_ordinaire_00.png",
            "potager_decor_cagette_legumes_statique_ordinaire_00.png",
            "potager_decor_caisse_semis_statique_ordinaire_00.png",
        ),

        # Vegetation
        "hydrangea": choose(
            manifest,
            "potager_decor_hortensia_rose_statique_ordinaire_00.png",
            "commun_decor_bosquet_haut_statique_ordinaire_01.png",
            "commun_decor_bosquet_haut_statique_ordinaire_00.png",
        ),

        "lavender": choose(
            manifest,
            "potager_decor_lavande_massif_statique_ordinaire_00.png",
            "commun_decor_fleurs_blanches_statique_ordinaire_00.png",
        ),

        "yellow_flowers": choose(
            manifest,
            "potager_decor_fleurs_jaunes_massif_statique_ordinaire_00.png",
            "commun_decor_fleurs_jaunes_statique_ordinaire_00.png",
        ),

        "rocks": choose(
            manifest,
            "potager_decor_rochers_vegetation_statique_ordinaire_00.png",
            "commun_decor_rochers_herbe_statique_ordinaire_00.png",
        ),

        # Preview dynamique
        "tomato": choose(
            manifest,
            "potager_plante_tomate_recoltable_ordinaire_00.png",
        ),

        "carrot": choose(
            manifest,
            "potager_plante_carotte_recoltable_ordinaire_00.png",
        ),

        "zucchini": choose(
            manifest,
            "potager_plante_courgette_recoltable_ordinaire_00.png",
        ),
    }


# ============================================================
# DEDICATED MAP PALETTE
# ============================================================

def build_scene_tsx(
    manifest: dict,
    assets: dict[str, str],
) -> dict[str, int]:

    names = list(
        dict.fromkeys(
            assets.values()
        )
    )

    tilewidth = max(
        manifest[name]["width"]
        for name in names
    )

    tileheight = max(
        manifest[name]["height"]
        for name in names
    )

    root = ET.Element(
        "tileset",
        {
            "version": "1.10",
            "tiledversion": "1.11.2",
            "name": "potager_scene_v2",
            "tilewidth": str(tilewidth),
            "tileheight": str(tileheight),
            "tilecount": str(len(names)),
            "columns": "0",
            "objectalignment": "bottom",
        },
    )

    ids = {}

    for tile_id, name in enumerate(names):
        ids[name] = tile_id

        tile = ET.SubElement(
            root,
            "tile",
            {"id": str(tile_id)},
        )

        ET.SubElement(
            tile,
            "image",
            {
                "source": f"../sprites/{name}",
                "width": str(manifest[name]["width"]),
                "height": str(manifest[name]["height"]),
            },
        )

    ET.indent(
        root,
        space="  ",
    )

    ET.ElementTree(root).write(
        SCENE_TSX,
        encoding="utf-8",
        xml_declaration=True,
    )

    with SCENE_TSX.open("ab") as fh:
        fh.write(b"\n")

    return ids


# ============================================================
# TMX
# ============================================================

def copy_base_layer(
    source_root: ET.Element,
    name: str,
    layer_id: int,
) -> ET.Element:

    source = next(
        layer
        for layer in source_root.findall("layer")
        if layer.get("name") == name
    )

    result = copy.deepcopy(source)

    result.set(
        "id",
        str(layer_id),
    )

    return result


def new_tile_layer(
    layer_id: int,
    name: str,
    values: list[int],
    *,
    offset_y: float = 0,
) -> ET.Element:

    attrs = {
        "id": str(layer_id),
        "name": name,
        "width": str(MAP_W),
        "height": str(MAP_H),
    }

    if offset_y:
        attrs["offsety"] = f"{offset_y:g}"

    layer = ET.Element(
        "layer",
        attrs,
    )

    data = ET.SubElement(
        layer,
        "data",
        {
            "encoding": "csv",
        },
    )

    data.text = write_csv_layer(
        values
    )

    return layer


def add_tile_object(
    group: ET.Element,
    *,
    object_id: int,
    name: str,
    group_class: str,
    asset: str,
    grid_i: float,
    grid_j: float,
    scale: float,
    scene_firstgid: int,
    scene_ids: dict[str, int],
    manifest: dict,
    force_type: str | None = None,
    opacity: float = 1,
    z_bias: float = 0,
):

    meta = manifest[asset]

    width = meta["width"] / 4 * scale
    height = meta["height"] / 4 * scale

    x, y = grid_to_tiled(
        grid_i,
        grid_j,
    )

    attrs = {
        "id": str(object_id),
        "name": name,
        "gid": str(
            scene_firstgid
            + scene_ids[asset]
        ),
        "x": f"{x:g}",
        "y": f"{y:g}",
        "width": f"{width:.2f}",
        "height": f"{height:.2f}",
    }

    if force_type:
        attrs["type"] = force_type
    else:
        attrs["class"] = group_class

    obj = ET.SubElement(
        group,
        "object",
        attrs,
    )

    props = {
        "gridCol": float(grid_i),
        "gridRow": float(grid_j),
    }

    if opacity != 1:
        props["opacity"] = float(opacity)

    if z_bias:
        props["zBias"] = float(z_bias)

    add_properties(
        obj,
        props,
    )


def build_map(
    manifest: dict,
    assets: dict[str, str],
    scene_ids: dict[str, int],
):

    source_root = ET.parse(
        SOURCE_MAP
    ).getroot()

    root = ET.Element(
        "map",
        {
            "version": "1.10",
            "tiledversion": "1.11.2",
            "orientation": "isometric",
            "renderorder": "right-down",
            "width": str(MAP_W),
            "height": str(MAP_H),
            "tilewidth": str(TILE_W),
            "tileheight": str(TILE_H),
            "infinite": "0",
        },
    )

    # --------------------------------------------------------
    # Minimal clean tileset set
    # --------------------------------------------------------

    ground_source = (
        "ground_new_da.tsx"
        if (MAPS / "ground_new_da.tsx").exists()
        else "ground.tsx"
    )

    required_tsx = [
        ground_source,
        "paths_diorama.tsx",
        "bed_edges.tsx",
        "planter_edges.tsx",
        SCENE_TSX.name,
    ]

    firstgids = {}

    gid = 1

    for source in required_tsx:
        path = MAPS / source

        if not path.exists():
            raise FileNotFoundError(path)

        firstgids[source] = gid

        ET.SubElement(
            root,
            "tileset",
            {
                "firstgid": str(gid),
                "source": source,
            },
        )

        gid += tsx_count(
            path
        )

    scene_firstgid = firstgids[
        SCENE_TSX.name
    ]

    # --------------------------------------------------------
    # Terrain
    # --------------------------------------------------------

    next_layer_id = 1

    for layer_name in (
        "skirt",
        "earth",
        "ground",
    ):
        root.append(
            copy_base_layer(
                source_root,
                layer_name,
                next_layer_id,
            )
        )

        next_layer_id += 1

    # --------------------------------------------------------
    # Stepping path
    # --------------------------------------------------------

    path = blank_layer()

    path_gid = firstgids[
        "paths_diorama.tsx"
    ]

    # An asymmetric central route.
    path_cells = [
        (-1, -3),
        (0, -2),
        (0, -1),
        (0, 0),
        (1, 0),
        (1, 1),
        (1, 2),
    ]

    for index, (i, j) in enumerate(path_cells):
        set_tile(
            path,
            i,
            j,
            path_gid + index % 5,
        )

    root.append(
        new_tile_layer(
            next_layer_id,
            "path",
            path,
        )
    )

    next_layer_id += 1

    # --------------------------------------------------------
    # Cultivation
    #
    # Half-half plots = direct earth.
    # Integer plots   = raised planters.
    # --------------------------------------------------------

    bed_edges = blank_layer()
    bed_edges_half = blank_layer()

    planter_back = blank_layer()
    planter_front = blank_layer()

    bed_first = firstgids[
        "bed_edges.tsx"
    ]

    planter_first = firstgids[
        "planter_edges.tsx"
    ]

    # role 14 = all four low edges
    BED_ALL = bed_first + 14

    # roles from inventory:
    # id 2  = nw_ne
    # id 11 = se_sw
    PLANTER_BACK = planter_first + 2
    PLANTER_FRONT = planter_first + 11

    for _, i, j, kind in PLOTS:

        if kind == "earth":
            # Every earth plot is on half-half coordinates.
            # Shift a tile layer by +20 px vertically.
            tile_i = math.floor(i)
            tile_j = math.floor(j)

            set_tile(
                bed_edges_half,
                tile_i,
                tile_j,
                BED_ALL,
            )

        else:
            set_tile(
                planter_back,
                int(i),
                int(j),
                PLANTER_BACK,
            )

            set_tile(
                planter_front,
                int(i),
                int(j),
                PLANTER_FRONT,
            )

    root.append(
        new_tile_layer(
            next_layer_id,
            "bed_edges",
            bed_edges,
        )
    )
    next_layer_id += 1

    root.append(
        new_tile_layer(
            next_layer_id,
            "bed_edges_half",
            bed_edges_half,
            offset_y=20,
        )
    )
    next_layer_id += 1

    root.append(
        new_tile_layer(
            next_layer_id,
            "planter_edges_back",
            planter_back,
        )
    )
    next_layer_id += 1

    # --------------------------------------------------------
    # Visual object groups
    # --------------------------------------------------------

    object_id = 1

    groups = {}

    for group_name in (
        "floor_decor",
        "vegetation",
        "rocks",
        "structures",
        "props",
        "edge_overlays",
    ):
        group = ET.SubElement(
            root,
            "objectgroup",
            {
                "id": str(next_layer_id),
                "name": group_name,
            },
        )

        groups[group_name] = group
        next_layer_id += 1

    # Big masses remain at the back/perimeter.
    placements = [
        (
            "vegetation",
            "west_tree",
            assets["tree_west"],
            -4.0,
            -2.0,
            0.80,
        ),
        (
            "vegetation",
            "east_tree",
            assets["tree_east"],
            -0.5,
            -4.5,
            0.72,
        ),
        (
            "vegetation",
            "west_hydrangea",
            assets["hydrangea"],
            -3.5,
            0.5,
            0.88,
        ),
        (
            "vegetation",
            "east_lavender",
            assets["lavender"],
            3.0,
            -1.0,
            0.82,
        ),
        (
            "floor_decor",
            "front_flowers",
            assets["yellow_flowers"],
            1.5,
            3.5,
            0.85,
        ),

        # Structural punctuation.
        (
            "structures",
            "garden_arch",
            assets["arch"],
            2.5,
            3.5,
            0.72,
        ),
        (
            "structures",
            "east_bench",
            assets["bench"],
            4.0,
            2.0,
            0.82,
        ),

        # Small functional props around edges.
        (
            "props",
            "bird_bath",
            assets["fountain"],
            2.5,
            -2.0,
            0.72,
        ),
        (
            "props",
            "west_barrel",
            assets["barrel"],
            -3.0,
            0.5,
            0.78,
        ),
        (
            "props",
            "watering_can",
            assets["watering"],
            3.0,
            0.0,
            0.82,
        ),
        (
            "props",
            "harvest_basket",
            assets["basket"],
            -1.5,
            3.0,
            0.80,
        ),

        # Runtime contract requires this exact object name.
        (
            "props",
            "east_upper_rock",
            assets["rocks"],
            1.5,
            -3.5,
            0.75,
        ),
    ]

    for (
        group_name,
        name,
        asset,
        i,
        j,
        scale,
    ) in placements:

        add_tile_object(
            groups[group_name],
            object_id=object_id,
            name=name,
            group_class=group_name,
            asset=asset,
            grid_i=i,
            grid_j=j,
            scale=scale,
            scene_firstgid=scene_firstgid,
            scene_ids=scene_ids,
            manifest=manifest,
            force_type=(
                "prop"
                if name == "east_upper_rock"
                else None
            ),
        )

        object_id += 1

    # --------------------------------------------------------
    # Plot gameplay anchors
    # --------------------------------------------------------

    plots_group = ET.SubElement(
        root,
        "objectgroup",
        {
            "id": str(next_layer_id),
            "name": "plots",
        },
    )

    next_layer_id += 1

    for index, i, j, _ in PLOTS:

        x, y = grid_to_tiled(
            i,
            j,
        )

        obj = ET.SubElement(
            plots_group,
            "object",
            {
                "id": str(object_id),
                "name": f"plot_{index}",
                "class": "plot",
                "x": f"{x:g}",
                "y": f"{y:g}",
            },
        )

        ET.SubElement(
            obj,
            "point",
        )

        add_properties(
            obj,
            {
                "gridCol": float(i),
                "gridRow": float(j),
            },
        )

        object_id += 1

    # --------------------------------------------------------
    # Hidden authoring preview plants
    #
    # Runtime ignores this group. Toggle it in Tiled if wanted.
    # --------------------------------------------------------

    preview_group = ET.SubElement(
        root,
        "objectgroup",
        {
            "id": str(next_layer_id),
            "name": "preview_plants",
            "visible": "0",
        },
    )

    next_layer_id += 1

    crop_cycle = [
        assets["tomato"],
        assets["carrot"],
        assets["zucchini"],
    ]

    for index, i, j, _ in PLOTS:

        crop = crop_cycle[
            index % len(crop_cycle)
        ]

        add_tile_object(
            preview_group,
            object_id=object_id,
            name=f"preview_crop_{index}",
            group_class="preview_plant",
            asset=crop,
            grid_i=i,
            grid_j=j,
            scale=0.90,
            scene_firstgid=scene_firstgid,
            scene_ids=scene_ids,
            manifest=manifest,
        )

        object_id += 1

    # Front planter walls MUST be last among tile layers from
    # the runtime's perspective because GardenGame rerenders
    # this exact named layer after plants.
    root.append(
        new_tile_layer(
            next_layer_id,
            "planter_edges_front",
            planter_front,
        )
    )

    next_layer_id += 1

    root.set(
        "nextlayerid",
        str(next_layer_id),
    )

    root.set(
        "nextobjectid",
        str(object_id),
    )

    ET.indent(
        root,
        space="  ",
    )

    ET.ElementTree(
        root
    ).write(
        OUTPUT_MAP,
        encoding="utf-8",
        xml_declaration=True,
    )

    with OUTPUT_MAP.open("ab") as fh:
        fh.write(b"\n")


# ============================================================
# PREVIEW RENDERER
# ============================================================

def load_gid_images(
    map_root: ET.Element,
):
    result = {}

    for tileset_ref in map_root.findall(
        "tileset"
    ):
        firstgid = int(
            tileset_ref.get("firstgid")
        )

        tsx = MAPS / tileset_ref.get(
            "source"
        )

        tsx_root = ET.parse(
            tsx
        ).getroot()

        tile_offset = tsx_root.find(
            "tileoffset"
        )

        off_x = (
            int(tile_offset.get("x", "0"))
            if tile_offset is not None
            else 0
        )

        off_y = (
            int(tile_offset.get("y", "0"))
            if tile_offset is not None
            else 0
        )

        for tile in tsx_root.findall(
            "tile"
        ):
            image = tile.find(
                "image"
            )

            if image is None:
                continue

            gid = (
                firstgid
                + int(tile.get("id"))
            )

            source = (
                tsx.parent
                / image.get("source")
            ).resolve()

            result[gid] = (
                source,
                off_x,
                off_y,
            )

    return result


def render_tile_layer(
    canvas: Image.Image,
    layer: ET.Element,
    gid_images: dict,
):

    data = layer.find("data")

    if data is None or not data.text:
        return

    values = [
        int(value.strip())
        for value
        in data.text.replace(
            "\n",
            "",
        ).split(",")
        if value.strip()
    ]

    offset_x = float(
        layer.get("offsetx", "0")
    )

    offset_y = float(
        layer.get("offsety", "0")
    )

    # Same transform as PotagerGridAdapter.tileMapOffset()
    map_offset_x = (
        GRID_ORIGIN_X
        - (
            TILED_ORIGIN_COL
            - TILED_ORIGIN_ROW
            + MAP_H
        )
        * TILE_W
        / 2
    )

    map_offset_y = (
        GRID_ORIGIN_Y
        - (
            TILED_ORIGIN_COL
            + TILED_ORIGIN_ROW
            + 1
        )
        * TILE_H
        / 2
    )

    for index, gid in enumerate(values):

        if gid == 0:
            continue

        if gid not in gid_images:
            continue

        col = index % MAP_W
        row = index // MAP_W

        cx = (
            (col - row + MAP_H)
            * TILE_W
            / 2
            + map_offset_x
            + offset_x
        )

        cy = (
            (col + row + 1)
            * TILE_H
            / 2
            + map_offset_y
            + offset_y
        )

        path, tx, ty = gid_images[gid]

        tile = Image.open(
            path
        ).convert("RGBA")

        x = round(
            cx
            - tile.width / 2
            + tx
        )

        y = round(
            cy
            - tile.height / 2
            + ty
        )

        canvas.alpha_composite(
            tile,
            (x, y),
        )


def object_grid(
    obj: ET.Element,
) -> tuple[float, float]:

    props = obj.find(
        "properties"
    )

    values = {}

    if props is not None:
        for prop in props.findall(
            "property"
        ):
            values[
                prop.get("name")
            ] = prop.get("value")

    return (
        float(values["gridCol"]),
        float(values["gridRow"]),
    )


def draw_object(
    canvas: Image.Image,
    draw: ImageDraw.ImageDraw,
    obj: ET.Element,
    gid_images: dict,
    manifest: dict,
):

    gid = int(
        obj.get("gid")
    )

    source, _, _ = gid_images[
        gid
    ]

    asset = source.name

    meta = manifest[
        asset
    ]

    width = float(
        obj.get("width")
    )

    height = float(
        obj.get("height")
    )

    i, j = object_grid(
        obj
    )

    contact_x, contact_y = grid_to_artboard(
        i,
        j,
    )

    # Contact shadow similar to runtime.
    shadow_w = max(
        8,
        width * 0.55,
    )

    shadow_h = max(
        3,
        min(
            10,
            height * 0.10,
        ),
    )

    draw.ellipse(
        (
            contact_x - shadow_w / 2 + 2,
            contact_y - shadow_h / 2 + 1,
            contact_x + shadow_w / 2 + 2,
            contact_y + shadow_h / 2 + 1,
        ),
        fill=(68, 82, 59, 38),
    )

    sprite = Image.open(
        source
    ).convert("RGBA")

    sprite = sprite.resize(
        (
            max(1, round(width)),
            max(1, round(height)),
        ),
        Image.Resampling.LANCZOS,
    )

    anchor_x = (
        meta["anchor"][0]
        / meta["width"]
    )

    anchor_y = (
        meta["anchor"][1]
        / meta["height"]
    )

    x = round(
        contact_x
        - width * anchor_x
    )

    y = round(
        contact_y
        - height * anchor_y
    )

    canvas.alpha_composite(
        sprite,
        (x, y),
    )


def render_preview(
    manifest: dict,
):
    root = ET.parse(
        OUTPUT_MAP
    ).getroot()

    gid_images = load_gid_images(
        root
    )

    canvas = Image.new(
        "RGBA",
        (
            ARTBOARD_W,
            ARTBOARD_H,
        ),
        (
            228,
            235,
            213,
            255,
        ),
    )

    draw = ImageDraw.Draw(
        canvas,
        "RGBA",
    )

    # Terrain/cultivation before dynamic content.
    initial_tile_layers = [
        "skirt",
        "earth",
        "ground",
        "path",
        "bed_edges",
        "bed_edges_half",
        "planter_edges_back",
    ]

    layer_by_name = {
        layer.get("name"): layer
        for layer in root.findall("layer")
    }

    for name in initial_tile_layers:
        layer = layer_by_name.get(
            name
        )

        if layer is not None:
            render_tile_layer(
                canvas,
                layer,
                gid_images,
            )

    # Runtime-like Y sorting of environment + sample crops.
    entries = []

    visible_groups = {
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
        if group.get("name") not in visible_groups:
            continue

        for obj in group.findall(
            "object"
        ):
            if obj.get("gid") is None:
                continue

            i, j = object_grid(
                obj
            )

            _, contact_y = grid_to_artboard(
                i,
                j,
            )

            entries.append(
                (
                    contact_y,
                    int(obj.get("id")),
                    obj,
                )
            )

    entries.sort(
        key=lambda item: (
            item[0],
            item[1],
        )
    )

    for _, _, obj in entries:
        draw_object(
            canvas,
            draw,
            obj,
            gid_images,
            manifest,
        )

    # Raised planter front wall after plants.
    front = layer_by_name.get(
        "planter_edges_front"
    )

    if front is not None:
        render_tile_layer(
            canvas,
            front,
            gid_images,
        )

    PREVIEW_DIR.mkdir(
        parents=True,
        exist_ok=True,
    )

    # Phone-review scale.
    preview = canvas.resize(
        (
            ARTBOARD_W * 2,
            ARTBOARD_H * 2,
        ),
        Image.Resampling.LANCZOS,
    )

    preview.save(
        PREVIEW,
        "PNG",
        optimize=True,
    )


# ============================================================
# CONTRACT VALIDATION
# ============================================================

def validate_output():

    root = ET.parse(
        OUTPUT_MAP
    ).getroot()

    props = next(
        g
        for g in root.findall("objectgroup")
        if g.get("name") == "props"
    )

    rocks = [
        obj
        for obj in props.findall("object")
        if obj.get("name") == "east_upper_rock"
    ]

    if len(rocks) != 1:
        raise RuntimeError(
            "Runtime contract: east_upper_rock missing"
        )

    plots = next(
        g
        for g in root.findall("objectgroup")
        if g.get("name") == "plots"
    )

    if len(
        plots.findall("object")
    ) != 8:
        raise RuntimeError(
            "Runtime contract: expected 8 plot anchors"
        )

    if not any(
        layer.get("name")
        == "planter_edges_front"
        for layer in root.findall("layer")
    ):
        raise RuntimeError(
            "Missing planter_edges_front"
        )


def main():

    if not SOURCE_MAP.exists():
        raise SystemExit(
            f"Missing {SOURCE_MAP}"
        )

    manifest = json.loads(
        MANIFEST_PATH.read_text(
            encoding="utf-8"
        )
    )

    assets = select_assets(
        manifest
    )

    print(
        "POTAGER DIORAMA V2"
    )
    print(
        "=================="
    )

    for role, asset in assets.items():
        print(
            f"{role:16} -> {asset}"
        )

    scene_ids = build_scene_tsx(
        manifest,
        assets,
    )

    build_map(
        manifest,
        assets,
        scene_ids,
    )

    validate_output()

    render_preview(
        manifest
    )

    PREVIEW_DIR.mkdir(
        parents=True,
        exist_ok=True,
    )

    LAYOUT_JSON.write_text(
        json.dumps(
            {
                "plots": [
                    {
                        "index": index,
                        "gridCol": i,
                        "gridRow": j,
                        "kind": kind,
                    }
                    for index, i, j, kind
                    in PLOTS
                ],
                "assets": assets,
            },
            indent=2,
            ensure_ascii=False,
        )
        + "\n",
        encoding="utf-8",
    )

    print()
    print(
        f"✅ map:     {OUTPUT_MAP.relative_to(ROOT)}"
    )
    print(
        f"✅ palette: {SCENE_TSX.relative_to(ROOT)}"
    )
    print(
        f"✅ preview: {PREVIEW.relative_to(ROOT)}"
    )
    print()
    print(
        "Production potager.tmx and candidate v1 are untouched."
    )


if __name__ == "__main__":
    main()

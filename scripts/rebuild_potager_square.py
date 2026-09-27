#!/usr/bin/env python3

from __future__ import annotations

import json
import math
import re
import shutil
import xml.etree.ElementTree as ET
from collections import defaultdict
from pathlib import Path

from PIL import Image, ImageChops, ImageDraw, ImageStat


ROOT = Path(__file__).resolve().parents[1]

SPRITES = ROOT / "assets" / "sprites"
SURFACES = ROOT / "assets" / "surface_sources"
MAPS = ROOT / "assets" / "maps"
LIB = ROOT / "lib" / "garden"

MANIFEST_PATH = SPRITES / "manifest.json"
GAME_DART = LIB / "garden_game.dart"

MAP_NAME = "potager_square_v1.tmx"
OUT_MAP = MAPS / MAP_NAME

TERRAIN_TSX = MAPS / "potager_square_terrain.tsx"

PREVIEW_DIR = ROOT / "docs" / "visual-review" / "potager-square-v1"
PREVIEW = PREVIEW_DIR / "potager_square_v1.png"

MAP_W = 18
MAP_H = 18

TILE_W = 80
TILE_H = 40

# On garde le même repère logique que le runtime actuel.
ORIGIN_X = 195
ORIGIN_Y = 230

TILED_ORIGIN_COL = 7
TILED_ORIGIN_ROW = 9

ARTBOARD_W = 390
ARTBOARD_H = 450

NW = 1
NE = 2
SE = 4
SW = 8


# ============================================================
# NOUVELLE COMPOSITION DES 8 PARCELLES
#
# Elles sont toutes sur des CASES ENTIÈRES.
#
#      2       .       0
#
#  4       .       .       1
#
#          FONTAINE
#
#  6       .       .       3
#
#      7       .       5
#
# Le dessin écran est isométrique, donc la disposition réelle
# apparaîtra en diamant/carré isométrique.
# ============================================================

PLOTS = [
    # index, gridI, gridJ, kind
    (0, -1, -2, "planter"),
    (1,  1, -2, "earth"),
    (2, -2, -1, "earth"),
    (3,  2, -1, "planter"),
    (4, -2,  1, "planter"),
    (5,  2,  1, "earth"),
    (6, -1,  2, "earth"),
    (7,  1,  2, "planter"),
]

PLOT_COORDS = {
    (i, j): (index, kind)
    for index, i, j, kind in PLOTS
}


# ============================================================
# BASIC HELPERS
# ============================================================

def require(path: Path):
    if not path.exists():
        raise RuntimeError(f"Missing: {path}")


def grid_to_artboard(i: float, j: float) -> tuple[float, float]:
    return (
        ORIGIN_X + (i - j) * TILE_W / 2,
        ORIGIN_Y + (i + j) * TILE_H / 2,
    )


def grid_to_tiled(i: float, j: float) -> tuple[float, float]:
    return (
        (i + TILED_ORIGIN_COL + 0.5) * TILE_H,
        (j + TILED_ORIGIN_ROW + 0.5) * TILE_H,
    )


def tile_index(i: int, j: int) -> int:
    col = i + TILED_ORIGIN_COL
    row = j + TILED_ORIGIN_ROW

    if not (
        0 <= col < MAP_W
        and 0 <= row < MAP_H
    ):
        raise RuntimeError(
            f"Logical tile ({i},{j}) -> ({col},{row}) outside map"
        )

    return row * MAP_W + col


def blank_layer():
    return [0] * (MAP_W * MAP_H)


def set_tile(data, i, j, gid):
    data[tile_index(i, j)] = gid


def csv_data(values):
    lines = []

    for row in range(MAP_H):
        start = row * MAP_W
        lines.append(
            ",".join(
                str(v)
                for v in values[start:start + MAP_W]
            )
        )

    return "\n" + ",\n".join(lines) + "\n"


def tsx_count(path: Path) -> int:
    root = ET.parse(path).getroot()

    if root.get("tilecount"):
        return int(root.get("tilecount"))

    ids = [
        int(tile.get("id", "0"))
        for tile in root.findall("tile")
    ]

    return max(ids) + 1 if ids else 0


def add_properties(parent, values):
    props = ET.SubElement(
        parent,
        "properties",
    )

    for name, value in values.items():
        attrs = {
            "name": name,
        }

        if isinstance(value, bool):
            attrs["type"] = "bool"
            attrs["value"] = (
                "true" if value else "false"
            )

        elif isinstance(value, int):
            attrs["type"] = "int"
            attrs["value"] = str(value)

        elif isinstance(value, float):
            attrs["type"] = "float"
            attrs["value"] = f"{value:g}"

        else:
            attrs["value"] = str(value)

        ET.SubElement(
            props,
            "property",
            attrs,
        )


# ============================================================
# PATCH RUNTIME
# ============================================================

def patch_runtime():
    require(GAME_DART)

    text = GAME_DART.read_text(
        encoding="utf-8"
    )

    original = text

    backup = GAME_DART.with_suffix(
        ".dart.before_square_map"
    )

    if not backup.exists():
        shutil.copy2(
            GAME_DART,
            backup,
        )

    # --------------------------------------------------------
    # Field
    # --------------------------------------------------------

    if "_terrainOwnsPlots" not in text:

        old = (
            "  late final bool _hasPaintedTiledGround;\n"
        )

        new = (
            "  late final bool _hasPaintedTiledGround;\n"
            "  late final bool _terrainOwnsPlots;\n"
        )

        if old not in text:
            raise RuntimeError(
                "Cannot patch _terrainOwnsPlots field"
            )

        text = text.replace(
            old,
            new,
            1,
        )

    # --------------------------------------------------------
    # Read TMX property
    # --------------------------------------------------------

    if "terrainOwnsPlots')" not in text:

        pattern = re.compile(
            r"(_hasPaintedTiledGround\s*=\s*"
            r"\(_tileMap\.map\.layerByName\('ground'\)\s+as\s+TileLayer\)"
            r"\s*\.data!\s*"
            r"\.any\(\(gid\)\s*=>\s*gid\s*!=\s*0\);)",
            re.MULTILINE,
        )

        match = pattern.search(text)

        if not match:
            raise RuntimeError(
                "Cannot locate _hasPaintedTiledGround assignment"
            )

        replacement = (
            match.group(1)
            + "\n"
            + "    _terrainOwnsPlots =\n"
            + "        _tileMap.map.properties"
            + ".getValue<bool>('terrainOwnsPlots') ?? false;"
        )

        text = (
            text[:match.start()]
            + replacement
            + text[match.end():]
        )

    # --------------------------------------------------------
    # Runtime anchors from Tiled
    # --------------------------------------------------------

    if "List<Offset> _runtimeAnchorsFor" not in text:

        marker = (
            "  List<GardenSpriteObject> get _potagerObjects"
        )

        index = text.find(marker)

        if index < 0:
            raise RuntimeError(
                "Cannot locate _potagerObjects"
            )

        method = """\
  List<Offset> _runtimeAnchorsFor(ZoneType zone) {
    if (zone != ZoneType.potager || !_terrainOwnsPlots) {
      return anchorsFor(zone);
    }

    final contacts = _tiledObjects.plotContacts;

    if (contacts.length != ZoneType.potager.maxSlots) {
      return PotagerPlots.contacts;
    }

    return List<Offset>.generate(
      ZoneType.potager.maxSlots,
      (index) => contacts['plot_$index'] ?? PotagerPlots.contacts[index],
      growable: false,
    );
  }

"""

        text = (
            text[:index]
            + method
            + text[index:]
        )

    # --------------------------------------------------------
    # Hit-test anchors
    # --------------------------------------------------------

    old = (
        "    final anchors = anchorsFor(currentZone);"
    )

    new = (
        "    final anchors = _runtimeAnchorsFor(currentZone);"
    )

    if old in text:
        text = text.replace(
            old,
            new,
            1,
        )

    # --------------------------------------------------------
    # Draw anchors
    # --------------------------------------------------------

    old = (
        "    final anchors = anchorsFor(zone);"
    )

    new = (
        "    final anchors = _runtimeAnchorsFor(zone);"
    )

    if old in text:
        text = text.replace(
            old,
            new,
            1,
        )

    # --------------------------------------------------------
    # Old procedural soil patches
    # --------------------------------------------------------

    old = """\
      for (final plot in PotagerPlots.visible(snapshot.zones[zone]!.length)) {
        PotagerComposition.drawSoilPlot(canvas, plot.contact);
      }
"""

    new = """\
      if (!_terrainOwnsPlots) {
        for (final plot in PotagerPlots.visible(snapshot.zones[zone]!.length)) {
          PotagerComposition.drawSoilPlot(canvas, plot.contact);
        }
      }
"""

    if old in text:
        text = text.replace(
            old,
            new,
            1,
        )

    if text != original:
        GAME_DART.write_text(
            text,
            encoding="utf-8",
        )

        print("✓ runtime patched")
    else:
        print("✓ runtime already patched")


# ============================================================
# TERRAIN
# ============================================================

def diamond_mask():
    image = Image.new(
        "L",
        (80, 40),
        0,
    )

    ImageDraw.Draw(image).polygon(
        [
            (40, 0),
            (79, 20),
            (40, 39),
            (0, 20),
        ],
        fill=255,
    )

    return image


DIAMOND = diamond_mask()


def source_texture(
    preferred: Path,
    fallback: Path,
) -> Image.Image:

    if preferred.exists():
        return Image.open(
            preferred
        ).convert("RGB")

    require(fallback)

    # Fallback : agrandissement d'une ancienne tile.
    return Image.open(
        fallback
    ).convert("RGB").resize(
        (512, 512),
        Image.Resampling.BICUBIC,
    )


def make_material(
    source: Image.Image,
    target: tuple[int, int, int],
    variant: int,
) -> Image.Image:

    crop_w = min(
        400,
        source.width,
    )

    crop_h = min(
        200,
        source.height,
    )

    max_x = source.width - crop_w
    max_y = source.height - crop_h

    x = (
        (variant * 73 + 31)
        % (max_x + 1)
        if max_x
        else 0
    )

    y = (
        (variant * 47 + 17)
        % (max_y + 1)
        if max_y
        else 0
    )

    crop = source.crop(
        (
            x,
            y,
            x + crop_w,
            y + crop_h,
        )
    )

    crop = crop.resize(
        (80, 40),
        Image.Resampling.LANCZOS,
    )

    stats = ImageStat.Stat(crop)
    mean = stats.mean

    result = Image.new(
        "RGBA",
        (80, 40),
        (0, 0, 0, 0),
    )

    src = crop.load()
    dst = result.load()

    bias = (
        -2,
        0,
        2,
        1,
    )[variant % 4]

    for yy in range(40):
        for xx in range(80):
            pixel = src[xx, yy]

            rgb = []

            for c in range(3):
                detail = (
                    pixel[c] - mean[c]
                ) * 0.18

                value = round(
                    target[c]
                    + bias
                    + detail
                )

                rgb.append(
                    max(
                        0,
                        min(
                            255,
                            value,
                        ),
                    )
                )

            dst[xx, yy] = (
                rgb[0],
                rgb[1],
                rgb[2],
                255,
            )

    result.putalpha(
        DIAMOND
    )

    return result


def side_polygon(side: int, depth: int):

    if side == NW:
        return [
            (0, 20),
            (40, 0),
            (40, 3),
            (5, 20),
        ]

    if side == NE:
        return [
            (40, 0),
            (79, 20),
            (74, 20),
            (40, 3),
        ]

    if side == SE:
        return [
            (79, 20),
            (40, 39),
            (40, 39 - depth),
            (79 - depth * 2, 20),
        ]

    return [
        (40, 39),
        (0, 20),
        (depth * 2, 20),
        (40, 39 - depth),
    ]


def make_terrain_tile(
    material_name: str,
    source: Image.Image,
    exposure: int,
    high: bool,
    variant: int,
) -> Image.Image:

    if material_name == "grass":

        base = make_material(
            source,
            (166, 205, 96),
            variant,
        )

        upper = (
            218,
            233,
            148,
            150,
        )

        lower = (
            105,
            73,
            44,
            220,
        )

    else:

        base = make_material(
            source,
            (132, 88, 52),
            variant,
        )

        upper = (
            176,
            129,
            83,
            135,
        )

        lower = (
            88,
            55,
            34,
            215,
        )

    detail = Image.new(
        "RGBA",
        (80, 40),
        (0, 0, 0, 0),
    )

    draw = ImageDraw.Draw(
        detail,
        "RGBA",
    )

    depth = 9 if high else 5

    for side in (
        NW,
        NE,
        SE,
        SW,
    ):
        if not (
            exposure & side
        ):
            continue

        if side in (
            NW,
            NE,
        ):
            draw.polygon(
                side_polygon(
                    side,
                    2,
                ),
                fill=upper,
            )

        else:
            draw.polygon(
                side_polygon(
                    side,
                    depth,
                ),
                fill=lower,
            )

    detail.putalpha(
        ImageChops.multiply(
            detail.getchannel("A"),
            DIAMOND,
        )
    )

    base.alpha_composite(
        detail
    )

    # Hard guarantee:
    # no pixel can escape the 80x40 diamond.
    base.putalpha(
        DIAMOND
    )

    return base


def build_terrain():

    grass = source_texture(
        SURFACES
        / "potager_texture_herbe_source.png",

        SPRITES
        / "commun_sol_herbe_tile_00.png",
    )

    earth = source_texture(
        SURFACES
        / "potager_texture_terre_cultivee_source.png",

        SPRITES
        / "commun_sol_terre_tile_00.png",
    )

    images = []
    lookup = {}

    for material_name, source in (
        ("grass", grass),
        ("earth", earth),
    ):

        for variant in range(4):

            name = (
                f"potager_square_"
                f"{material_name}_"
                f"interior_{variant:02}.png"
            )

            img = make_terrain_tile(
                material_name,
                source,
                0,
                False,
                variant,
            )

            lookup[
                (
                    material_name,
                    0,
                    False,
                    variant,
                )
            ] = len(images)

            images.append(
                (
                    name,
                    img,
                )
            )

        for exposure in range(
            1,
            16,
        ):

            for high in (
                False,
                True,
            ):

                variant = (
                    exposure
                    + int(high)
                ) % 4

                level = (
                    "high"
                    if high
                    else "low"
                )

                name = (
                    f"potager_square_"
                    f"{material_name}_"
                    f"edge_{exposure:02x}_"
                    f"{level}.png"
                )

                img = make_terrain_tile(
                    material_name,
                    source,
                    exposure,
                    high,
                    variant,
                )

                lookup[
                    (
                        material_name,
                        exposure,
                        high,
                        variant,
                    )
                ] = len(images)

                # Convenience alias independent
                # of generated variant.
                lookup[
                    (
                        material_name,
                        exposure,
                        high,
                        None,
                    )
                ] = len(images)

                images.append(
                    (
                        name,
                        img,
                    )
                )

    for name, image in images:

        # Absolute alpha guard.
        outside = ImageChops.subtract(
            image.getchannel("A"),
            DIAMOND,
        )

        if outside.getbbox() is not None:
            raise RuntimeError(
                f"{name}: alpha outside tile"
            )

        image.save(
            SPRITES / name,
            "PNG",
            optimize=True,
        )

    tsx = ET.Element(
        "tileset",
        {
            "version": "1.10",
            "tiledversion": "1.11.2",
            "name": "potager_square_terrain",
            "tilewidth": "80",
            "tileheight": "40",
            "tilecount": str(
                len(images)
            ),
            "columns": "0",
            "objectalignment": "bottom",
        },
    )

    for tile_id, (
        name,
        _,
    ) in enumerate(images):

        tile = ET.SubElement(
            tsx,
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
                "width": "80",
                "height": "40",
            },
        )

    ET.indent(
        tsx,
        space="  ",
    )

    ET.ElementTree(
        tsx
    ).write(
        TERRAIN_TSX,
        encoding="utf-8",
        xml_declaration=True,
    )

    print(
        f"✓ terrain: {len(images)} autonomous tiles"
    )

    return lookup


# ============================================================
# AUTHORING PALETTES
# ============================================================

def classify_sprite(name: str) -> str | None:

    n = name.lower()

    # Surface tiles are not object sprites.
    if "_tile_" in n:
        return None

    if n.startswith(
        "potager_square_"
    ):
        return None

    if n.startswith(
        "potager_plante_"
    ):
        return "plants_potager"

    if n.startswith(
        "fleurs_plante_"
    ):
        return "plants_fleurs"

    if n.startswith(
        "verger_arbre_"
    ):
        return "plants_verger"

    if any(
        key in n
        for key in (
            "rocher",
            "rochers",
        )
    ):
        return "rocks"

    if any(
        key in n
        for key in (
            "arche",
            "portail",
            "cloture",
            "barriere",
            "treillis",
            "pergola",
        )
    ):
        return "structures"

    if any(
        key in n
        for key in (
            "banc",
            "fontaine",
            "bain_oiseaux",
            "arrosoir",
            "tonneau",
            "pompe",
            "panier",
            "cagette",
            "caisse",
            "outil",
            "stockage",
            "etagere",
        )
    ):
        return "props"

    if any(
        key in n
        for key in (
            "hortensia",
            "lavande_massif",
            "marguerite",
            "fleurs_jaunes",
            "fleurs_blanches",
            "buisson",
            "bosquet",
            "vegetation",
            "touffe_herbe",
            "trefle",
            "arbre_nichoir",
            "pommier_fruits",
            "canopee",
        )
    ):
        return "vegetation"

    if any(
        key in n
        for key in (
            "bac_potager",
            "cadre_culture",
            "cadre_bac",
        )
    ):
        return "cultivation"

    return None


def make_collection_tsx(
    category: str,
    files: list[Path],
):
    infos = []

    for path in files:
        with Image.open(path) as image:
            infos.append(
                (
                    path.name,
                    image.width,
                    image.height,
                )
            )

    max_w = max(
        info[1]
        for info in infos
    )

    max_h = max(
        info[2]
        for info in infos
    )

    root = ET.Element(
        "tileset",
        {
            "version": "1.10",
            "tiledversion": "1.11.2",
            "name": category,
            "tilewidth": str(max_w),
            "tileheight": str(max_h),
            "tilecount": str(
                len(infos)
            ),
            "columns": "0",
            "objectalignment": "bottom",
        },
    )

    ids = {}

    for tile_id, (
        name,
        width,
        height,
    ) in enumerate(infos):

        ids[name] = tile_id

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
                "width": str(width),
                "height": str(height),
            },
        )

    ET.indent(
        root,
        space="  ",
    )

    path = MAPS / (
        f"palette_{category}.tsx"
    )

    ET.ElementTree(
        root
    ).write(
        path,
        encoding="utf-8",
        xml_declaration=True,
    )

    return path, ids


def build_palettes():

    groups = defaultdict(list)

    for path in sorted(
        SPRITES.glob("*.png")
    ):
        category = classify_sprite(
            path.name
        )

        if category:
            groups[
                category
            ].append(path)

    preferred_order = [
        "plants_potager",
        "plants_fleurs",
        "plants_verger",
        "cultivation",
        "structures",
        "props",
        "vegetation",
        "rocks",
    ]

    palettes = {}

    asset_lookup = {}

    for category in preferred_order:

        files = groups.get(
            category,
            [],
        )

        if not files:
            continue

        path, ids = make_collection_tsx(
            category,
            files,
        )

        palettes[
            category
        ] = (
            path,
            ids,
        )

        for asset, tile_id in ids.items():
            asset_lookup[
                asset
            ] = (
                category,
                tile_id,
            )

        print(
            f"✓ palette {category}: {len(files)}"
        )

    return palettes, asset_lookup


# ============================================================
# CHOOSE SCENE ASSETS
# ============================================================

def pick(
    manifest,
    *names,
    required=True,
):

    for name in names:

        if (
            name in manifest
            and (
                SPRITES / name
            ).exists()
        ):
            return name

    if required:
        raise RuntimeError(
            "Missing scene asset. Tried:\n"
            + "\n".join(names)
        )

    return None


def scene_assets(manifest):

    return {
        "tree_west": pick(
            manifest,
            "potager_decor_arbre_nichoir_statique_ordinaire_00.png",
            "potager_decor_arbre_canopee_ouest_statique_ordinaire_00.png",
        ),

        "tree_east": pick(
            manifest,
            "potager_decor_pommier_fruits_statique_ordinaire_00.png",
            "potager_decor_arbre_canopee_est_statique_ordinaire_00.png",
        ),

        "arch": pick(
            manifest,
            "potager_decor_arche_fleurie_statique_ordinaire_00.png",
            "potager_decor_arche_diagonale_statique_ordinaire_00.png",
            "potager_decor_arche_grille_statique_ordinaire_00.png",
        ),

        "bench": pick(
            manifest,
            "potager_decor_banc_parc_statique_ordinaire_00.png",
            "potager_decor_banc_jardin_statique_ordinaire_00.png",
            "potager_decor_banc_bois_statique_ordinaire_00.png",
        ),

        "fountain": pick(
            manifest,
            "potager_decor_bain_oiseaux_statique_ordinaire_00.png",
            "potager_decor_fontaine_pierre_statique_ordinaire_00.png",
        ),

        "watering": pick(
            manifest,
            "potager_decor_arrosoir_bleu_statique_ordinaire_00.png",
            "potager_decor_arrosoir_metal_statique_ordinaire_00.png",
        ),

        "barrel": pick(
            manifest,
            "potager_decor_tonneau_pompe_statique_ordinaire_00.png",
            "commun_decor_tonneau_bois_statique_ordinaire_00.png",
        ),

        "basket": pick(
            manifest,
            "potager_decor_panier_pommes_statique_ordinaire_00.png",
            "potager_decor_cagette_legumes_statique_ordinaire_00.png",
            "potager_decor_caisse_semis_statique_ordinaire_00.png",
        ),

        "hydrangea": pick(
            manifest,
            "potager_decor_hortensia_rose_statique_ordinaire_00.png",
            "commun_decor_bosquet_haut_statique_ordinaire_01.png",
            "commun_decor_bosquet_haut_statique_ordinaire_00.png",
        ),

        "lavender": pick(
            manifest,
            "potager_decor_lavande_massif_statique_ordinaire_00.png",
            "commun_decor_fleurs_blanches_statique_ordinaire_00.png",
        ),

        "flowers": pick(
            manifest,
            "potager_decor_fleurs_jaunes_massif_statique_ordinaire_00.png",
            "commun_decor_fleurs_jaunes_statique_ordinaire_00.png",
        ),

        "rock": pick(
            manifest,
            "potager_decor_rochers_vegetation_statique_ordinaire_00.png",
            "commun_decor_rochers_herbe_statique_ordinaire_00.png",
        ),
    }


# ============================================================
# MAP
# ============================================================

def make_tile_layer(
    layer_id,
    name,
    data,
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

    node = ET.SubElement(
        layer,
        "data",
        {
            "encoding": "csv",
        },
    )

    node.text = csv_data(
        data
    )

    return layer


def add_object(
    group,
    object_id,
    name,
    asset,
    i,
    j,
    scale,
    gid_for_asset,
    manifest,
    *,
    class_name=None,
):

    meta = manifest[
        asset
    ]

    # Images sources are authored 4x.
    width = (
        meta["width"]
        / 4
        * scale
    )

    height = (
        meta["height"]
        / 4
        * scale
    )

    x, y = grid_to_tiled(
        i,
        j,
    )

    attrs = {
        "id": str(object_id),
        "name": name,
        "gid": str(
            gid_for_asset(asset)
        ),
        "x": f"{x:g}",
        "y": f"{y:g}",
        "width": f"{width:.2f}",
        "height": f"{height:.2f}",
    }

    if class_name:
        attrs["class"] = class_name

    obj = ET.SubElement(
        group,
        "object",
        attrs,
    )

    add_properties(
        obj,
        {
            "gridCol": float(i),
            "gridRow": float(j),
        },
    )


def terrain_exposure(i, j):

    exposure = 0

    # Neighbor mapping around the diamond.
    neighbors = [
        (
            NW,
            (i - 1, j),
        ),
        (
            NE,
            (i, j - 1),
        ),
        (
            SE,
            (i + 1, j),
        ),
        (
            SW,
            (i, j + 1),
        ),
    ]

    for flag, (
        ni,
        nj,
    ) in neighbors:

        if not (
            -2 <= ni <= 2
            and -2 <= nj <= 2
        ):
            exposure |= flag

    return exposure


def mature_crop_assets(
    manifest,
):

    crops = []

    for name in sorted(
        manifest
    ):
        if (
            name.startswith(
                "potager_plante_"
            )
            and "_recoltable_" in name
            and (
                SPRITES / name
            ).exists()
        ):
            crops.append(
                name
            )

    return crops


def build_map(
    terrain_lookup,
    palettes,
    asset_lookup,
    manifest,
    scene,
):

    # --------------------------------------------------------
    # Tilesets
    # --------------------------------------------------------

    root = ET.Element(
        "map",
        {
            "version": "1.10",
            "tiledversion": "1.11.2",
            "orientation": "isometric",
            "renderorder": "right-down",
            "width": str(MAP_W),
            "height": str(MAP_H),
            "tilewidth": "80",
            "tileheight": "40",
            "infinite": "0",
        },
    )

    add_properties(
        root,
        {
            "terrainOwnsPlots": True,
        },
    )

    firstgid = {}

    gid = 1

    def attach(path):
        nonlocal gid

        firstgid[
            path.name
        ] = gid

        ET.SubElement(
            root,
            "tileset",
            {
                "firstgid": str(gid),
                "source": path.name,
            },
        )

        gid += tsx_count(
            path
        )

    attach(
        TERRAIN_TSX
    )

    path_tsx = None

    for candidate in (
        MAPS / "paths_diorama.tsx",
        MAPS / "paths.tsx",
    ):
        if candidate.exists():
            path_tsx = candidate
            attach(
                candidate
            )
            break

    planter_tsx = (
        MAPS
        / "planter_edges.tsx"
    )

    require(
        planter_tsx
    )

    attach(
        planter_tsx
    )

    for category in [
        "plants_potager",
        "plants_fleurs",
        "plants_verger",
        "cultivation",
        "structures",
        "props",
        "vegetation",
        "rocks",
    ]:
        if category in palettes:
            attach(
                palettes[
                    category
                ][0]
            )

    def gid_for_asset(asset):

        if asset not in asset_lookup:
            raise RuntimeError(
                f"{asset} has no category palette"
            )

        category, tile_id = (
            asset_lookup[
                asset
            ]
        )

        path = palettes[
            category
        ][0]

        return (
            firstgid[
                path.name
            ]
            + tile_id
        )

    # --------------------------------------------------------
    # GROUND
    # --------------------------------------------------------

    ground = blank_layer()

    terrain_first = (
        firstgid[
            TERRAIN_TSX.name
        ]
    )

    for i in range(
        -2,
        3,
    ):
        for j in range(
            -2,
            3,
        ):

            plot = PLOT_COORDS.get(
                (i, j)
            )

            variant = (
                abs(
                    i * 7
                    + j * 11
                )
                % 4
            )

            if plot:

                _, kind = plot

                # One complete earth tile,
                # entirely contained in the cell.
                local_id = terrain_lookup[
                    (
                        "earth",
                        15,
                        False,
                        None,
                    )
                ]

            else:

                exposure = terrain_exposure(
                    i,
                    j,
                )

                if exposure:

                    # Alternate high/low border,
                    # but ALWAYS inside the diamond.
                    high = (
                        (i + j)
                        % 3
                        == 0
                    )

                    local_id = terrain_lookup[
                        (
                            "grass",
                            exposure,
                            high,
                            None,
                        )
                    ]

                else:

                    local_id = terrain_lookup[
                        (
                            "grass",
                            0,
                            False,
                            variant,
                        )
                    ]

            set_tile(
                ground,
                i,
                j,
                terrain_first
                + local_id,
            )

    layer_id = 1

    root.append(
        make_tile_layer(
            layer_id,
            "ground",
            ground,
        )
    )

    layer_id += 1

    # --------------------------------------------------------
    # PATH
    # --------------------------------------------------------

    if path_tsx:

        path = blank_layer()

        path_first = (
            firstgid[
                path_tsx.name
            ]
        )

        # Central circulation only on free grass.
        route = [
            (0, -2),
            (0, -1),
            (-1, 0),
            (0, 0),
            (1, 0),
            (0, 1),
            (0, 2),
        ]

        count = tsx_count(
            path_tsx
        )

        for index, (
            i,
            j,
        ) in enumerate(route):

            if (
                i,
                j,
            ) in PLOT_COORDS:
                continue

            set_tile(
                path,
                i,
                j,
                path_first
                + (
                    index
                    % count
                ),
            )

        root.append(
            make_tile_layer(
                layer_id,
                "path",
                path,
            )
        )

        layer_id += 1

    # --------------------------------------------------------
    # RAISED PLANTERS
    # --------------------------------------------------------

    planter_back = blank_layer()
    planter_front = blank_layer()

    planter_first = (
        firstgid[
            planter_tsx.name
        ]
    )

    # Existing mask ordering:
    # 2  = NW + NE
    # 11 = SE + SW
    BACK_ID = 2
    FRONT_ID = 11

    for _, i, j, kind in PLOTS:

        if kind != "planter":
            continue

        set_tile(
            planter_back,
            i,
            j,
            planter_first
            + BACK_ID,
        )

        set_tile(
            planter_front,
            i,
            j,
            planter_first
            + FRONT_ID,
        )

    root.append(
        make_tile_layer(
            layer_id,
            "planter_edges_back",
            planter_back,
        )
    )

    layer_id += 1

    # --------------------------------------------------------
    # OBJECT GROUPS
    # --------------------------------------------------------

    groups = {}

    for name in [
        "floor_decor",
        "vegetation",
        "rocks",
        "structures",
        "props",
    ]:

        groups[name] = ET.SubElement(
            root,
            "objectgroup",
            {
                "id": str(layer_id),
                "name": name,
            },
        )

        layer_id += 1

    object_id = 1

    placements = [
        # group, id, asset, gridI, gridJ, scale

        (
            "vegetation",
            "west_tree",
            scene["tree_west"],
            -2.5,
            -1.5,
            0.64,
        ),

        (
            "vegetation",
            "east_tree",
            scene["tree_east"],
            0.5,
            -2.5,
            0.62,
        ),

        (
            "vegetation",
            "west_hydrangea",
            scene["hydrangea"],
            -2.2,
            0.1,
            0.76,
        ),

        (
            "vegetation",
            "east_lavender",
            scene["lavender"],
            1.9,
            -0.1,
            0.72,
        ),

        (
            "floor_decor",
            "front_flowers",
            scene["flowers"],
            0.3,
            2.25,
            0.70,
        ),

        (
            "structures",
            "garden_arch",
            scene["arch"],
            2.15,
            1.55,
            0.58,
        ),

        (
            "props",
            "garden_bench",
            scene["bench"],
            -1.3,
            2.2,
            0.68,
        ),

        (
            "props",
            "bird_bath",
            scene["fountain"],
            0,
            0,
            0.66,
        ),

        (
            "props",
            "utility_barrel",
            scene["barrel"],
            -2.0,
            0.0,
            0.70,
        ),

        (
            "props",
            "watering_can",
            scene["watering"],
            1.55,
            0.25,
            0.72,
        ),

        (
            "props",
            "harvest_basket",
            scene["basket"],
            -0.35,
            2.15,
            0.68,
        ),

        # Runtime parser sentinel:
        (
            "props",
            "east_upper_rock",
            scene["rock"],
            2.2,
            -1.75,
            0.58,
        ),
    ]

    for (
        group,
        name,
        asset,
        i,
        j,
        scale,
    ) in placements:

        add_object(
            groups[group],
            object_id,
            name,
            asset,
            i,
            j,
            scale,
            gid_for_asset,
            manifest,
            class_name=(
                "prop"
                if name
                == "east_upper_rock"
                else None
            ),
        )

        object_id += 1

    # --------------------------------------------------------
    # PLOTS
    # --------------------------------------------------------

    plots = ET.SubElement(
        root,
        "objectgroup",
        {
            "id": str(layer_id),
            "name": "plots",
        },
    )

    layer_id += 1

    for index, i, j, kind in PLOTS:

        x, y = grid_to_tiled(
            i,
            j,
        )

        obj = ET.SubElement(
            plots,
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
                "gridCol":
                    float(i),
                "gridRow":
                    float(j),
                "plotKind":
                    kind,
            },
        )

        object_id += 1

    # --------------------------------------------------------
    # PREVIEW PLANTS
    # --------------------------------------------------------

    preview = ET.SubElement(
        root,
        "objectgroup",
        {
            "id": str(layer_id),
            "name": "preview_plants",
            "visible": "0",
        },
    )

    layer_id += 1

    crops = mature_crop_assets(
        manifest
    )

    if crops:

        for position, (
            index,
            i,
            j,
            kind,
        ) in enumerate(PLOTS):

            asset = crops[
                position
                % len(crops)
            ]

            if asset not in asset_lookup:
                continue

            add_object(
                preview,
                object_id,
                f"preview_plant_{index}",
                asset,
                i,
                j,
                0.82,
                gid_for_asset,
                manifest,
            )

            # Explicit semantic relation.
            obj = preview.findall(
                "object"
            )[-1]

            props = obj.find(
                "properties"
            )

            ET.SubElement(
                props,
                "property",
                {
                    "name":
                        "plotId",
                    "value":
                        f"plot_{index}",
                },
            )

            object_id += 1

    # --------------------------------------------------------
    # FRONT WALL — LAST
    # --------------------------------------------------------

    root.append(
        make_tile_layer(
            layer_id,
            "planter_edges_front",
            planter_front,
        )
    )

    layer_id += 1

    root.set(
        "nextlayerid",
        str(layer_id),
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
        OUT_MAP,
        encoding="utf-8",
        xml_declaration=True,
    )

    print(
        f"✓ map: {OUT_MAP.relative_to(ROOT)}"
    )


# ============================================================
# PREVIEW RENDERER
# ============================================================

def load_gid_table():

    map_root = ET.parse(
        OUT_MAP
    ).getroot()

    result = {}

    for ref in map_root.findall(
        "tileset"
    ):

        first = int(
            ref.get("firstgid")
        )

        path = MAPS / ref.get(
            "source"
        )

        tsx = ET.parse(
            path
        ).getroot()

        for tile in tsx.findall(
            "tile"
        ):

            image = tile.find(
                "image"
            )

            if image is None:
                continue

            result[
                first
                + int(
                    tile.get("id")
                )
            ] = (
                path.parent
                / image.get("source")
            ).resolve()

    return result


def render_tile_layer(
    canvas,
    layer,
    gids,
):

    node = layer.find(
        "data"
    )

    if (
        node is None
        or not node.text
    ):
        return

    values = [
        int(part.strip())
        for part
        in node.text.replace(
            "\n",
            "",
        ).split(",")
        if part.strip()
    ]

    # Same math as PotagerGridAdapter.
    map_offset_x = (
        ORIGIN_X
        - (
            TILED_ORIGIN_COL
            - TILED_ORIGIN_ROW
            + MAP_H
        )
        * 40
    )

    map_offset_y = (
        ORIGIN_Y
        - (
            TILED_ORIGIN_COL
            + TILED_ORIGIN_ROW
            + 1
        )
        * 20
    )

    for index, gid in enumerate(
        values
    ):

        if not gid:
            continue

        source = gids.get(
            gid
        )

        if source is None:
            continue

        col = index % MAP_W
        row = index // MAP_W

        cx = (
            (
                col
                - row
                + MAP_H
            )
            * 40
            + map_offset_x
        )

        cy = (
            (
                col
                + row
                + 1
            )
            * 20
            + map_offset_y
        )

        image = Image.open(
            source
        ).convert("RGBA")

        canvas.alpha_composite(
            image,
            (
                round(
                    cx
                    - image.width
                    / 2
                ),
                round(
                    cy
                    - image.height
                    / 2
                ),
            ),
        )


def object_properties(obj):

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
            prop.get("name")
        ] = prop.get(
            "value"
        )

    return values


def render_sprite_object(
    canvas,
    obj,
    gids,
    manifest,
):

    gid = int(
        obj.get("gid")
    )

    asset_path = gids[
        gid
    ]

    name = asset_path.name

    meta = manifest[
        name
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
        grid_to_artboard(
            i,
            j,
        )
    )

    full_width = float(
        obj.get("width")
    )

    full_height = float(
        obj.get("height")
    )

    bbox = meta[
        "bbox"
    ]

    visible_w = (
        (
            bbox[2]
            - bbox[0]
        )
        * full_width
        / meta["width"]
    )

    visible_h = (
        (
            bbox[3]
            - bbox[1]
        )
        * full_height
        / meta["height"]
    )

    anchor = meta.get(
        "anchor",
        [
            (
                bbox[0]
                + bbox[2]
            )
            / 2,
            bbox[3],
        ],
    )

    anchor_x = (
        anchor[0]
        - bbox[0]
    ) / (
        bbox[2]
        - bbox[0]
    )

    anchor_y = (
        anchor[1]
        - bbox[1]
    ) / (
        bbox[3]
        - bbox[1]
    )

    source = Image.open(
        asset_path
    ).convert("RGBA")

    crop = source.crop(
        tuple(bbox)
    )

    crop = crop.resize(
        (
            max(
                1,
                round(visible_w),
            ),
            max(
                1,
                round(visible_h),
            ),
        ),
        Image.Resampling.LANCZOS,
    )

    # Contact shadow.
    shadow = Image.new(
        "RGBA",
        canvas.size,
        (0, 0, 0, 0),
    )

    sd = ImageDraw.Draw(
        shadow,
        "RGBA",
    )

    sw = max(
        8,
        visible_w * 0.55,
    )

    sh = max(
        3,
        min(
            9,
            visible_h * 0.08,
        ),
    )

    sd.ellipse(
        (
            contact_x
            - sw / 2,
            contact_y
            - sh / 2,
            contact_x
            + sw / 2,
            contact_y
            + sh / 2,
        ),
        fill=(
            60,
            75,
            52,
            40,
        ),
    )

    canvas.alpha_composite(
        shadow
    )

    x = round(
        contact_x
        - crop.width
        * anchor_x
    )

    y = round(
        contact_y
        - crop.height
        * anchor_y
    )

    canvas.alpha_composite(
        crop,
        (
            x,
            y,
        ),
    )


def render_preview(
    manifest,
):

    root = ET.parse(
        OUT_MAP
    ).getroot()

    gids = load_gid_table()

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

    layers = {
        layer.get("name"):
            layer
        for layer
        in root.findall("layer")
    }

    for name in (
        "ground",
        "path",
        "planter_edges_back",
    ):

        if name in layers:
            render_tile_layer(
                canvas,
                layers[name],
                gids,
            )

    # Runtime-like Y depth.
    objects = []

    runtime_groups = {
        "floor_decor",
        "vegetation",
        "rocks",
        "structures",
        "props",
        "preview_plants",
    }

    for group in root.findall(
        "objectgroup"
    ):

        if group.get(
            "name"
        ) not in runtime_groups:
            continue

        for obj in group.findall(
            "object"
        ):

            if not obj.get(
                "gid"
            ):
                continue

            props = object_properties(
                obj
            )

            if (
                "gridCol" not in props
                or "gridRow" not in props
            ):
                continue

            _, y = grid_to_artboard(
                float(
                    props["gridCol"]
                ),
                float(
                    props["gridRow"]
                ),
            )

            objects.append(
                (
                    y,
                    int(
                        obj.get(
                            "id"
                        )
                    ),
                    obj,
                )
            )

    objects.sort(
        key=lambda value: (
            value[0],
            value[1],
        )
    )

    for _, _, obj in objects:
        render_sprite_object(
            canvas,
            obj,
            gids,
            manifest,
        )

    # Raised planter front walls cover plant bases.
    if "planter_edges_front" in layers:
        render_tile_layer(
            canvas,
            layers[
                "planter_edges_front"
            ],
            gids,
        )

    PREVIEW_DIR.mkdir(
        parents=True,
        exist_ok=True,
    )

    review = canvas.resize(
        (
            ARTBOARD_W * 2,
            ARTBOARD_H * 2,
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
# VALIDATION
# ============================================================

def validate():

    root = ET.parse(
        OUT_MAP
    ).getroot()

    assert (
        root.get("orientation")
        == "isometric"
    )

    assert (
        int(root.get("width"))
        == 18
    )

    assert (
        int(root.get("height"))
        == 18
    )

    layers = {
        layer.get("name")
        for layer
        in root.findall("layer")
    }

    assert "ground" in layers
    assert "planter_edges_back" in layers
    assert "planter_edges_front" in layers

    # The old terrain system must be gone.
    assert "skirt" not in layers
    assert "earth" not in layers
    assert "bed_edges" not in layers
    assert "bed_edges_half" not in layers

    plots = next(
        group
        for group
        in root.findall(
            "objectgroup"
        )
        if group.get("name")
        == "plots"
    )

    assert len(
        plots.findall(
            "object"
        )
    ) == 8

    coords = set()

    for obj in plots.findall(
        "object"
    ):

        props = object_properties(
            obj
        )

        i = float(
            props["gridCol"]
        )

        j = float(
            props["gridRow"]
        )

        # Strict whole-cell plots.
        assert i.is_integer()
        assert j.is_integer()

        coords.add(
            (
                i,
                j,
            )
        )

    assert len(coords) == 8

    props = next(
        group
        for group
        in root.findall(
            "objectgroup"
        )
        if group.get("name")
        == "props"
    )

    rock = [
        obj
        for obj
        in props.findall(
            "object"
        )
        if obj.get("name")
        == "east_upper_rock"
    ]

    assert len(rock) == 1

    print("✓ structural validation")


# ============================================================
# MAIN
# ============================================================

def main():

    require(
        MANIFEST_PATH
    )

    manifest = json.loads(
        MANIFEST_PATH.read_text(
            encoding="utf-8"
        )
    )

    print()
    print(
        "GROWSTEP — POTAGER SQUARE REBUILD"
    )
    print(
        "================================"
    )
    print()

    patch_runtime()

    terrain_lookup = (
        build_terrain()
    )

    palettes, asset_lookup = (
        build_palettes()
    )

    scene = scene_assets(
        manifest
    )

    print()
    print("Scene assets:")

    for role, asset in scene.items():
        print(
            f"  {role:<14} {asset}"
        )

    print()

    build_map(
        terrain_lookup,
        palettes,
        asset_lookup,
        manifest,
        scene,
    )

    validate()

    render_preview(
        manifest
    )

    print()
    print(
        "================================"
    )
    print(
        "✅ POTAGER SQUARE READY"
    )
    print(
        "================================"
    )

    print()
    print(
        f"Tiled map:\n  assets/maps/{MAP_NAME}"
    )

    print()
    print(
        "Visual review:\n"
        "  docs/visual-review/"
        "potager-square-v1/"
        "potager_square_v1.png"
    )

    print()
    print(
        "Runtime backup:\n"
        "  lib/garden/"
        "garden_game.dart.before_square_map"
    )

    print()
    print(
        "Run the candidate in Flutter with:"
    )

    print(
        "  flutter run "
        "--dart-define="
        "GROWSTEP_POTAGER_MAP="
        "potager_square_v1.tmx"
    )

    print()
    print(
        "Open in Tiled with:"
    )

    print(
        "  tiled "
        "assets/maps/"
        "potager_square_v1.tmx"
    )


if __name__ == "__main__":
    main()

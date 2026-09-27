#!/usr/bin/env python3
"""
Generate a compact 30x30 Growstep potager map using the Sunnyside World pack.

Run from the Growstep repository root:
    python3 tools/generate_sunnyside_potager.py

Optional:
    python3 tools/generate_sunnyside_potager.py \
        --output assets/maps/sunnyside_potager_compact.tmx \
        --seed 20260928

Why 30x30?
- This variant intentionally expands the authored map to 30x30.
- Recommended runtime renderTileSize: 12 px, yielding a 360x360 map inside the 390x450 artboard.
- the eight crop anchors are spaced more generously while keeping the 3 / 2 / 3 Growstep layout.

The generator:
- reuses assets/maps/sunnyside_tileset.tsx;
- uses the dominant grass/path tiles from Sunnyside's original example room;
- uses the real Sunnyside soil/crop PNGs already copied under assets/sprites;
- optionally copies a few original Sunnyside decor strips (trees/mushrooms/bird)
  into assets/sprites/sunnyside/tileset/, which is already declared in pubspec.yaml;
- emits a normal finite TMX editable in Tiled.

No generated art is introduced: every visible sprite comes from the Sunnyside pack.
"""

from __future__ import annotations

import argparse
import random
import shutil
import struct
import xml.etree.ElementTree as ET
from pathlib import Path


MAP_W = 30
MAP_H = 30
TILE = 16

# Main atlas: assets/maps/sunnyside_tileset.tsx has firstgid=1 in the TMX.
# These local IDs are taken from layers in Sunnyside's own GameMaker example:
# - land: 193 is by far the dominant base land tile
# - paths: 460 is the most-used path tile
MAIN_FIRST_GID = 1
GRASS_LOCAL_ID = 193
PATH_LOCAL_IDS = (460, 463, 449)
GRASS_GID = MAIN_FIRST_GID + GRASS_LOCAL_ID

# Saved/runtime slot order in lib/garden/potager_sprites.dart.
# Coordinates are tile-grid intersections relative to the 20x20 map.
PLOTS = [
    (7, 7),    # plot_0 back-left
    (15, 7),   # plot_1 back-center
    (23, 7),   # plot_2 back-right
    (10, 15),  # plot_3 middle-left
    (20, 15),  # plot_4 middle-right
    (7, 23),   # plot_5 front-left
    (15, 23),  # plot_6 front-center
    (23, 23),  # plot_7 front-right
]

PREVIEW_CROPS = [
    "carrot_05.png",
    "pumpkin_05.png",
    "cabbage_05.png",
    "sunflower_05.png",
    "cauliflower_05.png",
    "kale_05.png",
    "beetroot_05.png",
    "wheat_05.png",
]

SOILS = [
    "soil_00.png",
    "soil_01.png",
    "soil_03.png",
    "soil_04.png",
]

# Source files kept in the purchased pack -> runtime copies.
PACK_INNER = Path(
    "Sunnyside_World_ASSET_PACK_V2.1/"
    "Sunnyside_World_ASSET_PACK_V2.1/"
    "Sunnyside_World_Assets"
)

DECOR = {
    "broadleaf": {
        "source": PACK_INNER / "Elements/Plants/spr_deco_tree_01_strip4.png",
        "target": Path("assets/sprites/sunnyside/tileset/spr_deco_tree_01_strip4.png"),
        "frames": 4,
    },
    "pine": {
        "source": PACK_INNER / "Elements/Plants/spr_deco_tree_02_strip4.png",
        "target": Path("assets/sprites/sunnyside/tileset/spr_deco_tree_02_strip4.png"),
        "frames": 4,
    },
    "mushroom": {
        "source": PACK_INNER / "Elements/Plants/spr_deco_mushroom_red_01_strip4.png",
        "target": Path("assets/sprites/sunnyside/tileset/spr_deco_mushroom_red_01_strip4.png"),
        "frames": 4,
    },
    "bird": {
        "source": PACK_INNER / "Elements/Animals/spr_deco_bird_01_strip4.png",
        "target": Path("assets/sprites/sunnyside/tileset/spr_deco_bird_01_strip4.png"),
        "frames": 4,
    },
}


def png_size(path: Path, fallback: tuple[int, int]) -> tuple[int, int]:
    """Read PNG width/height without Pillow."""
    try:
        with path.open("rb") as f:
            header = f.read(24)
        if header[:8] != b"\x89PNG\r\n\x1a\n":
            return fallback
        return struct.unpack(">II", header[16:24])
    except FileNotFoundError:
        return fallback


def empty_grid() -> list[list[int]]:
    return [[0 for _ in range(MAP_W)] for _ in range(MAP_H)]


def csv_data(grid: list[list[int]]) -> str:
    return "\n" + "\n".join(
        ",".join(str(v) for v in row) + ("," if y < MAP_H - 1 else "")
        for y, row in enumerate(grid)
    ) + "\n"


def add_tile_layer(
    root: ET.Element,
    layer_id: int,
    name: str,
    grid: list[list[int]],
    *,
    offsetx: int = 0,
    offsety: int = 0,
    opacity: float | None = None,
) -> ET.Element:
    attrs = {
        "id": str(layer_id),
        "name": name,
        "width": str(MAP_W),
        "height": str(MAP_H),
    }
    if offsetx:
        attrs["offsetx"] = str(offsetx)
    if offsety:
        attrs["offsety"] = str(offsety)
    if opacity is not None:
        attrs["opacity"] = str(opacity)

    layer = ET.SubElement(root, "layer", attrs)
    data = ET.SubElement(layer, "data", {"encoding": "csv"})
    data.text = csv_data(grid)
    return layer


def add_image_collection_tileset(
    root: ET.Element,
    firstgid: int,
    name: str,
    image_paths: list[Path],
    repo_root: Path,
    *,
    default_size: tuple[int, int] = (16, 16),
) -> int:
    ts = ET.SubElement(
        root,
        "tileset",
        {
            "firstgid": str(firstgid),
            "version": "1.10",
            "tiledversion": "1.11.2",
            "name": name,
            "tilewidth": str(default_size[0]),
            "tileheight": str(default_size[1]),
            "tilecount": str(len(image_paths)),
            "columns": "0",
            "objectalignment": "bottom",
        },
    )
    for tile_id, rel in enumerate(image_paths):
        w, h = png_size(repo_root / rel, default_size)
        tile = ET.SubElement(ts, "tile", {"id": str(tile_id)})
        ET.SubElement(
            tile,
            "image",
            {
                "source": "../" + rel.as_posix().removeprefix("assets/"),
                "width": str(w),
                "height": str(h),
            },
        )
    return firstgid + len(image_paths)


def add_strip_tileset(
    root: ET.Element,
    firstgid: int,
    name: str,
    rel: Path,
    repo_root: Path,
    frames: int,
    *,
    fallback: tuple[int, int],
) -> tuple[int, int]:
    w, h = png_size(repo_root / rel, fallback)
    frame_w = max(1, w // frames)
    ts = ET.SubElement(
        root,
        "tileset",
        {
            "firstgid": str(firstgid),
            "version": "1.10",
            "tiledversion": "1.11.2",
            "name": name,
            "tilewidth": str(frame_w),
            "tileheight": str(h),
            "tilecount": str(frames),
            "columns": str(frames),
            "objectalignment": "bottom",
        },
    )
    ET.SubElement(
        ts,
        "image",
        {
            "source": "../" + rel.as_posix().removeprefix("assets/"),
            "width": str(w),
            "height": str(h),
        },
    )
    return firstgid + frames, firstgid


def copy_decor(repo_root: Path, enabled: bool) -> dict[str, bool]:
    status: dict[str, bool] = {}
    for key, spec in DECOR.items():
        src = repo_root / spec["source"]
        dst = repo_root / spec["target"]
        if enabled and src.exists():
            dst.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(src, dst)
            status[key] = True
        else:
            status[key] = dst.exists()
    return status


def make_path(seed: int) -> list[list[int]]:
    """Organic entrance path with short branches toward all eight plots."""
    rng = random.Random(seed)
    grid = empty_grid()

    cells: set[tuple[int, int]] = set()

    spine = [
        (15, 29), (15, 28), (15, 27), (14, 26), (14, 25),
        (15, 24), (15, 23), (15, 22), (16, 21), (16, 20),
        (15, 19), (15, 18), (14, 17), (14, 16), (15, 15),
        (15, 14), (16, 13), (16, 12), (15, 11), (15, 10),
        (14, 9), (14, 8), (15, 7), (15, 6), (16, 5),
    ]
    cells.update(spine)

    cells.update((x, 7) for x in range(8, 15))
    cells.update((x, 7) for x in range(16, 23))
    cells.update([(14, 15), (13, 15), (12, 15), (11, 15)])
    cells.update([(16, 15), (17, 15), (18, 15), (19, 15)])
    cells.update((x, 23) for x in range(8, 15))
    cells.update((x, 23) for x in range(16, 23))
    cells.update([
        (13, 24), (12, 24),
        (17, 20), (18, 20),
        (13, 12), (12, 12),
        (17, 9), (18, 9),
    ])

    cells.difference_update(PLOTS)

    variants = [MAIN_FIRST_GID + local for local in PATH_LOCAL_IDS]
    for x, y in sorted(cells, key=lambda p: (p[1], p[0])):
        gid = variants[0] if rng.random() < 0.84 else rng.choice(variants[1:])
        grid[y][x] = gid
    return grid


def make_soil(firstgid: int) -> list[list[int]]:
    """
    Four little Sunnyside soil mounds form one 32x24-ish cultivation footprint.
    This matches the 2x2 footprint expected by the current Growstep potager.
    """
    grid = empty_grid()
    for i, (cx, cy) in enumerate(PLOTS):
        # Four source soil sprites, arranged around the runtime contact.
        variant = i % 2
        gids = (
            firstgid + variant,
            firstgid + (1 - variant),
            firstgid + variant,
            firstgid + (1 - variant),
        )
        for (x, y), gid in zip(
            ((cx - 1, cy - 1), (cx, cy - 1), (cx - 1, cy), (cx, cy)),
            gids,
        ):
            if 0 <= x < MAP_W and 0 <= y < MAP_H:
                grid[y][x] = gid
    return grid


def make_preview(firstgid: int) -> list[list[int]]:
    grid = empty_grid()
    # Preview crops sit one tile above the contact so their bottom visually
    # reaches the soil. GardenGame hides this layer at runtime.
    for i, (cx, cy) in enumerate(PLOTS):
        grid[max(0, cy - 1)][cx] = firstgid + i
    return grid


def make_decor(
    gids: dict[str, int],
    enabled: dict[str, bool],
    seed: int,
) -> tuple[list[list[int]], list[list[int]]]:
    """Peripheral landscape masses; centre and front interaction corridor stay open."""
    rng = random.Random(seed ^ 0x51A9)
    back = empty_grid()
    front = empty_grid()

    if enabled.get("broadleaf") and "broadleaf" in gids:
        placements = [
            (1, 2), (5, 1), (21, 1), (26, 3),
            (1, 10), (27, 11), (2, 18), (26, 19),
        ]
        for n, (x, y) in enumerate(placements):
            back[y][x] = gids["broadleaf"] + (n % 4)

    if enabled.get("pine") and "pine" in gids:
        placements = [
            (3, 0), (9, 1), (19, 0), (25, 1),
            (0, 14), (28, 15),
        ]
        for n, (x, y) in enumerate(placements):
            back[y][x] = gids["pine"] + ((n + 1) % 4)

    if enabled.get("mushroom") and "mushroom" in gids:
        for x, y in [(3, 7), (26, 8), (4, 20), (25, 21), (6, 27), (23, 27)]:
            front[y][x] = gids["mushroom"] + rng.randrange(4)

    if enabled.get("bird") and "bird" in gids:
        front[26][18] = gids["bird"] + 1

    return back, front


def add_plots_object_group(root: ET.Element, layer_id: int) -> None:
    group = ET.SubElement(root, "objectgroup", {"id": str(layer_id), "name": "plots"})
    for i, (cx, cy) in enumerate(PLOTS):
        # Map pixels. The runtime contacts are exactly these points + mapOffset.
        obj = ET.SubElement(
            group,
            "object",
            {
                "id": str(i + 1),
                "name": f"plot_{i}",
                "class": "plot",
                "x": str(cx * TILE - 22),
                "y": str(cy * TILE - 22),
                "width": "44",
                "height": "44",
            },
        )
        props = ET.SubElement(obj, "properties")
        ET.SubElement(props, "property", {"name": "slotIndex", "type": "int", "value": str(i)})
        ET.SubElement(props, "property", {"name": "contactX", "type": "int", "value": str(cx * TILE)})
        ET.SubElement(props, "property", {"name": "contactY", "type": "int", "value": str(cy * TILE)})


def pretty_xml(root: ET.Element) -> str:
    ET.indent(root, space=" ", level=0)
    return '<?xml version="1.0" encoding="UTF-8"?>\n' + ET.tostring(
        root, encoding="unicode", short_empty_elements=True
    ) + "\n"


def generate(
    repo_root: Path,
    output: Path,
    *,
    seed: int,
    copy_runtime_assets: bool,
    check: bool,
) -> Path:
    repo_root = repo_root.resolve()
    output = output if output.is_absolute() else repo_root / output

    atlas_tsx = repo_root / "assets/maps/sunnyside_tileset.tsx"
    if check and not atlas_tsx.exists():
        raise SystemExit(f"Missing {atlas_tsx}. Run this from the Growstep repo root.")

    decor_enabled = copy_decor(repo_root, copy_runtime_assets)

    root = ET.Element(
        "map",
        {
            "version": "1.11",
            "tiledversion": "1.11.2",
            "orientation": "orthogonal",
            "renderorder": "right-down",
            "width": str(MAP_W),
            "height": str(MAP_H),
            "tilewidth": str(TILE),
            "tileheight": str(TILE),
            "infinite": "0",
            "backgroundcolor": "#9dc74d",
            "nextlayerid": "9",
            "nextobjectid": "9",
        },
    )

    props = ET.SubElement(root, "properties")
    for name, value in [
        ("growstepView", "orthogonal"),
        ("sourcePack", "Sunnyside World Asset Pack V2.1"),
        ("generatedBy", "tools/generate_sunnyside_potager.py"),
        ("layout", "compact-30x30"),
        ("runtimeCropAnchors", "PotagerSprites.plotAnchors"),
    ]:
        ET.SubElement(props, "property", {"name": name, "value": value})

    # Existing 4096-tile atlas.
    ET.SubElement(
        root,
        "tileset",
        {"firstgid": str(MAIN_FIRST_GID), "source": "sunnyside_tileset.tsx"},
    )

    # Inline image-collection tilesets for soil and authoring-only mature previews.
    next_gid = 4097
    soil_first = next_gid
    next_gid = add_image_collection_tileset(
        root,
        next_gid,
        "sunnyside_soil",
        [Path("assets/sprites/sunnyside/crops") / x for x in SOILS],
        repo_root,
        default_size=(16, 12),
    )

    preview_first = next_gid
    next_gid = add_image_collection_tileset(
        root,
        next_gid,
        "sunnyside_crop_preview",
        [Path("assets/sprites/sunnyside/crops") / x for x in PREVIEW_CROPS],
        repo_root,
        default_size=(16, 16),
    )

    # Optional oversized decor strips copied into an already bundled asset folder.
    decor_first: dict[str, int] = {}
    decor_fallbacks = {
        "broadleaf": (128, 34),
        "pine": (112, 43),
        "mushroom": (64, 16),
        "bird": (64, 16),
    }
    for key in ("broadleaf", "pine", "mushroom", "bird"):
        if not decor_enabled.get(key):
            continue
        next_gid, first = add_strip_tileset(
            root,
            next_gid,
            f"sunnyside_{key}",
            DECOR[key]["target"],
            repo_root,
            DECOR[key]["frames"],
            fallback=decor_fallbacks[key],
        )
        decor_first[key] = first

    # Ground: restrained and readable, not a noisy carpet.
    ground = [[GRASS_GID for _ in range(MAP_W)] for _ in range(MAP_H)]
    add_tile_layer(root, 1, "ground", ground)

    # Back vegetation first so all gameplay contacts remain readable.
    decor_back, decor_front = make_decor(decor_first, decor_enabled, seed)
    add_tile_layer(root, 2, "decor_back", decor_back)

    # Main circulation.
    add_tile_layer(root, 3, "paths", make_path(seed))

    # Cultivation areas. Offset subtly centers the four 16x12 source mounds.
    add_tile_layer(root, 4, "soil", make_soil(soil_first), offsety=4)

    # Only a Tiled authoring preview; GardenGame hides this layer at runtime.
    add_tile_layer(
        root,
        5,
        "plants_preview",
        make_preview(preview_first),
        offsetx=-6,
        offsety=-12,
    )

    # Small accents, kept away from crop touch targets.
    add_tile_layer(root, 6, "decor", decor_front)

    # Kept intentionally empty for the current GardenGame post-plant render pass.
    # It gives us a stable place to add planter fronts later without changing code.
    add_tile_layer(root, 7, "planter_edges_front", empty_grid())

    add_plots_object_group(root, 8)

    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(pretty_xml(root), encoding="utf-8")
    return output


def parse_args() -> argparse.Namespace:
    p = argparse.ArgumentParser()
    p.add_argument("--repo-root", type=Path, default=Path.cwd())
    p.add_argument(
        "--output",
        type=Path,
        default=Path("assets/maps/sunnyside_potager_30x30.tmx"),
    )
    p.add_argument("--seed", type=int, default=20260928)
    p.add_argument(
        "--no-copy-decor",
        action="store_true",
        help="Do not copy the selected decor strips from the purchased pack.",
    )
    p.add_argument(
        "--no-check",
        action="store_true",
        help="Generate XML even if repo assets are not present (useful for CI fixtures).",
    )
    return p.parse_args()


if __name__ == "__main__":
    args = parse_args()
    out = generate(
        args.repo_root,
        args.output,
        seed=args.seed,
        copy_runtime_assets=not args.no_copy_decor,
        check=not args.no_check,
    )
    print(f"Generated {out}")
    print("Open it in Tiled, or test with:")
    print(
        "  flutter run "
        "--dart-define=GROWSTEP_POTAGER_MAP=sunnyside_potager_30x30.tmx "
        "--dart-define=GROWSTEP_SUNNYSIDE=true"
    )

#!/usr/bin/env python3
"""
Build semantic Tiled tilesets for Growstep from the Sunnyside World V2.1 pack.

The pack contains a 1024x1024 world atlas (16px grid, 4096 tiles) that mixes
terrain, water, paths, buildings, crops, props, animals and more.  Because we
cannot see the pixels, every semantic decision is backed by *objective
metadata* only:

  1. GameMaker tileset *.yy  -> auto-tile families (Land, River, Path 01..03,
     Building 01/02, Inner Walls, Clouds) and tile animation groups.
  2. GameMaker sprite *.yy   -> sprite names, frame counts, animation speed,
     bbox, and the semantic folder taxonomy (Crops / Props / In House /
     Plants / Animals / Smoke / UI / Characters...).
  3. Existing Growstep repo  -> tile 193 = dominant grass, path tiles 449/460/463
     (see tools/generate_sunnyside_potager_30x30.py).
  4. Exact pixel template matching of named standalone sprites against the
     atlas (no visual interpretation: an accepted match means every
     non-transparent pixel of the sprite is byte-identical in the atlas).

Everything that cannot be attributed to a category with enough certainty goes
to ``ss_unclassified`` and is listed in ``manifests/classification_report.json``
with the reason and the sources consulted.  No silent guess.

Outputs (under assets/tilesets/sunnyside/):
  ss_terrain.tsx            grid tileset, derived atlas (Land auto-tile family)
  ss_water.tsx              grid tileset, derived atlas (River + water tile)
  ss_paths_fences.tsx       grid tileset, derived atlas (Path 01/02/03)
  ss_buildings.tsx          image-collection (Building 01/02 + Inner Walls
                            + beam + chimneys)
  ss_roofs.tsx              image-collection (visual_regions.json aliases, roof_color)
  ss_farm.tsx               image-collection
  ss_crops.tsx              image-collection (crops + farmland + seeds)
  ss_vegetation.tsx         image-collection
  ss_animals.tsx            image-collection (animated)
  ss_resources.tsx          image-collection
  ss_outdoor_decor.tsx      image-collection
  ss_furniture.tsx          image-collection
  ss_vfx.tsx                image-collection (animated)
  ss_forest.tsx             grid tileset, derived 32px forest atlas
  ss_unclassified.tsx       grid tileset, derived atlas of leftover tiles
  generated/                derived PNGs
  manifests/                classification.json, classification_report.json,
                            excluded_assets.json

Run from the repo root:
    python3 scripts/build_sunnyside_tilesets.py
"""

from __future__ import annotations

import argparse
import json
import os
import re
import shutil
import xml.etree.ElementTree as ET
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]

PACK_INNER = Path(
    "Sunnyside_World_ASSET_PACK_V2.1"
) / "Sunnyside_World_ASSET_PACK_V2.1"
ASSETS_DIR = PACK_INNER / "Sunnyside_World_Assets"
GM_DIR = PACK_INNER / "Sunnyside_World_Gamemaker"

OUT_DIR = Path("assets/tilesets/sunnyside")
GENERATED = OUT_DIR / "generated"
MANIFESTS = OUT_DIR / "manifests"

TILE16 = 16
TILE32 = 32
FALLBACK_MS = 150  # documented fallback if no reliable speed in the .yy files

# ---------------------------------------------------------------------------
# GameMaker .yy parsing (GM writes JSON with trailing commas -> tolerated here)
# ---------------------------------------------------------------------------


def load_yy(path: Path) -> dict:
    txt = path.read_text(encoding="utf-8")
    txt = re.sub(r",\s*([}\]])", r"\1", txt)
    return json.loads(txt)


# ---------------------------------------------------------------------------
# Objective atlas metadata extracted from tilesets/tileset_sunnysideworld.yy
# ---------------------------------------------------------------------------
AUTOTILES = {
    "Land": {
        "ids": [193, 194, 195, 196, 197, 198, 199, 200,
                257, 258, 259, 260, 261, 262, 263, 264],
        "category": "terrain",
        "subcategory": "land",
    },
    "River": {
        "ids": [470, 471, 472, 473, 474, 475, 476, 477,
                534, 535, 536, 537, 538, 539, 540, 0],
        "category": "water",
        "subcategory": "river",
    },
    "Path 01": {
        "ids": [449, 450, 451, 452, 453, 454, 455, 456,
                513, 514, 515, 516, 517, 518, 519, 0],
        "category": "paths_fences",
        "subcategory": "path_01",
    },
    "Path 02": {
        "ids": [460, 461, 462, 463, 464, 465, 466, 467,
                524, 525, 526, 527, 528, 529, 530, 0],
        "category": "paths_fences",
        "subcategory": "path_02",
    },
    "Path 03": {
        "ids": [482, 483, 484, 485, 486, 487, 488, 489,
                546, 547, 548, 549, 550, 551, 552, 0],
        "category": "paths_fences",
        "subcategory": "path_03",
    },
    "Building 01": {
        "ids": [577, 578, 579, 580, 581, 582, 583, 584,
                641, 642, 643, 644, 645, 646, 647, 648],
        "category": "buildings",
        "subcategory": "building_01",
        "building_part": "building_01",
    },
    "Building 02": {
        "ids": [961, 962, 963, 964, 965, 966, 967, 968,
                1025, 1026, 1027, 1028, 1029, 1030, 1031, 0],
        "category": "buildings",
        "subcategory": "building_02",
        "building_part": "building_02",
    },
    "Inner Walls": {
        "ids": [769, 770, 771, 772, 773, 774, 775, 776,
                833, 834, 835, 836, 837, 838, 839, 840],
        "category": "buildings",
        "subcategory": "inner_wall",
        "building_part": "inner_wall",
    },
    "Clouds 01": {
        "ids": [1153, 1154, 1155, 1156, 1157, 1158, 1159, 1160,
                1217, 1218, 1219, 1220, 1221, 1222, 1223, 0],
        "category": "unclassified",
        "subcategory": "clouds_01",
        "known_identity": "clouds",
    },
    "Clouds 02": {
        "ids": [1345, 1346, 1347, 1348, 1349, 1350, 1351, 1352,
                1409, 1410, 1411, 1412, 1413, 1414, 1415, 0],
        "category": "unclassified",
        "subcategory": "clouds_02",
        "known_identity": "clouds",
    },
    "Cloud Shadow": {
        "ids": [1537, 1538, 1539, 1540, 1541, 1542, 1543, 1544,
                1601, 1602, 1603, 1604, 1605, 1606, 1607, 0],
        "category": "unclassified",
        "subcategory": "cloud_shadow",
        "known_identity": "clouds",
    },
}

# grass tile confirmed by the existing Growstep generator (dominant land tile)
GRASS_ATLAS_TILE = 193

# water standalone sprite (13x13) located in the atlas by exact pixel match
WATER_ATLAS_TILE = 2858

# glint atlas tiles 1419..1422 == GM tileAnimationFrames animation_25 AND the
# exact pixel matches of spr_deco_glint_01/02 at (11..14, 22)
GLINT_ATLAS_TILES = [1419, 1420, 1421, 1422]

# ---------------------------------------------------------------------------
# Standalone (non-atlas) assets, classified from names / GM folders / user spec
# ---------------------------------------------------------------------------
CROP_NAMES = [
    "beetroot", "cabbage", "carrot", "cauliflower", "kale", "parsnip",
    "potato", "pumpkin", "radish", "sunflower", "wheat",
]

FARMLAND = ["soil_00", "soil_01", "soil_03", "soil_04"]

# Elements/Crops -> resources (NOT crops, per spec)
RESOURCE_FROM_CROPS = ["rock", "wood", "egg", "milk", "fish"]

# GM props -> resources
RESOURCE_GM = [
    "spr_deco_ore_stone", "spr_deco_ore_coal", "spr_deco_ore_gold",
    "spr_deco_ore_silver", "spr_deco_ore_bluestone",
    "spr_deco_wool", "spr_deco_truffle", "spr_deco_acron",
]

VEGETATION_GM = [
    "spr_deco_tree_01", "spr_deco_tree_02",
    "spr_deco_mushroom_blue_01", "spr_deco_mushroom_blue_02",
    "spr_deco_mushroom_blue_03", "spr_deco_mushroom_red_01",
    "spr_deco_flowers_house_01", "spr_deco_flowers_house_02",
    "leaves_hit",
]

FARM_GM = [
    "spr_deco_well", "spr_deco_well_covered",
    "spr_deco_trough", "spr_deco_waterbowl",
    "spr_deco_crate_01", "spr_deco_crate_02",
    "crate_base", "crate_top",
    "spr_deco_barrel_closed", "spr_deco_barrel_open", "spr_deco_barrel_water",
    "spr_deco_bucket", "spr_deco_buckect_rope",
]

OUTDOOR_DECOR_GM = [
    "spr_deco_campfire", "spr_deco_firepit",
    "spr_deco_chest_01_closed", "spr_deco_chest_01_open",
    "spr_deco_chest_02_closed", "spr_deco_chest_02_open",
    "spr_deco_coin", "spr_deco_coins", "spr_deco_minecart",
    "spr_deco_oar", "spr_deco_anvil", "spr_deco_barrel_swords",
    "spr_deco_sword_floor",
]

FURNITURE_GM = [
    "spr_deco_chair_01", "spr_deco_sidetable_01", "spr_deco_rug_01",
    "spr_deco_book_01", "spr_deco_book_02",
    "spr_deco_jar_01", "spr_deco_jar_02",
    "spr_deco_mug_01", "spr_deco_mug_02",
    "spr_deco_plate", "spr_deco_plate_food", "spr_deco_plate_knifeandfork",
    "spr_deco_knifeandfork",
    "spr_deco_picture_01", "spr_deco_picture_01_1",
]

BUILDING_PROPS_GM = [
    "spr_deco_beam",
    "spr_deco_chinmney",
    "spr_deco_cook_chinmney",
]


# ---------------------------------------------------------------------------
# GM sprite metadata
# ---------------------------------------------------------------------------
def gm_sprite_meta() -> dict:
    meta = {}
    sprites_dir = ROOT / GM_DIR / "sprites"
    for yy in sorted(sprites_dir.glob("*/" + "*" + ".yy")):
        if "/layers/" in str(yy):
            continue
        try:
            d = load_yy(yy)
        except Exception:
            continue
        name = d.get("name")
        if not name:
            continue
        frames = [f["name"] for f in d.get("frames", [])]
        seq = d.get("sequence") or {}
        speed = seq.get("playbackSpeed")
        parent = (d.get("parent") or {}).get("path", "")
        meta[name] = {
            "name": name,
            "width": d.get("width"),
            "height": d.get("height"),
            "frames": frames,
            "speed": speed,
            "parent": parent,
            "dir": yy.parent,
        }
    return meta


# ---------------------------------------------------------------------------
# Image helpers (no interpolation: only exact copies and transparent padding)
# ---------------------------------------------------------------------------
def pad_to_cell(img: Image.Image, cell: int = TILE16) -> Image.Image:
    """Centre horizontally, bottom-align vertically on a transparent cell."""
    w, h = img.size
    if w > cell or h > cell:
        raise ValueError(f"pad_to_cell: {w}x{h} does not fit {cell}")
    out = Image.new("RGBA", (cell, cell), (0, 0, 0, 0))
    out.paste(img, ((cell - w) // 2, cell - h), img)
    return out


def tile_is_empty(tile_img: Image.Image, threshold: int = 8) -> bool:
    a = tile_img.getchannel("A")
    return sum(1 for v in a.getdata() if v > threshold) == 0


def atlas_tile(atlas: Image.Image, tile_id: int, cols: int, cell: int) -> Image.Image:
    tx = tile_id % cols
    ty = tile_id // cols
    return atlas.crop((tx * cell, ty * cell, tx * cell + cell, ty * cell + cell))


def make_derived_atlas(tiles: list[dict], cell: int, cols: int) -> Image.Image:
    """Pack tiles (each {id, image}) into a compact deterministic grid."""
    rows = (len(tiles) + cols - 1) // cols
    out = Image.new("RGBA", (cols * cell, rows * cell), (0, 0, 0, 0))
    for i, t in enumerate(tiles):
        out.paste(t["image"], ((i % cols) * cell, (i // cols) * cell), t["image"])
    return out


# ---------------------------------------------------------------------------
# Exact template matching (objective, pixel-level) using a color index
# ---------------------------------------------------------------------------
def build_color_index(atlas: Image.Image) -> dict:
    idx: dict = {}
    px = atlas.load()
    w, h = atlas.size
    for y in range(h):
        for x in range(w):
            idx.setdefault(px[x, y], []).append((x, y))
    return idx


def find_exact_matches(atlas: Image.Image, color_index: dict,
                       template: Image.Image,
                       max_origins: int = 12) -> list[tuple[int, int]]:
    aw, ah = atlas.size
    tw, th = template.size
    if tw > aw or th > ah:
        return []
    ta = template.getchannel("A")
    tpx = template.load()
    opaque = [(x, y) for y in range(th) for x in range(tw)
              if ta.getpixel((x, y)) > 8]
    if not opaque:
        return []
    anchors = [opaque[0], opaque[len(opaque) // 2], opaque[-1]]
    candidates = None
    for (ax, ay) in anchors:
        ac = tpx[ax, ay]
        origins = set()
        for (px, py) in color_index.get(ac, ()):
            ox, oy = px - ax, py - ay
            if 0 <= ox and ox + tw <= aw and 0 <= oy and oy + th <= ah:
                origins.add((ox, oy))
        candidates = origins if candidates is None else (candidates & origins)
        if not candidates:
            return []
    matches = []
    for (x, y) in sorted(candidates):
        ok = True
        for (ox, oy) in opaque:
            if atlas.getpixel((x + ox, y + oy)) != tpx[ox, oy]:
                ok = False
                break
        if ok:
            matches.append((x, y))
    return matches


def tiles_covered(x: int, y: int, w: int, h: int, cell: int,
                  cols: int, max_row: int) -> set[int]:
    covered = set()
    for ty in range(y // cell, (y + h - 1) // cell + 1):
        for tx in range(x // cell, (x + w - 1) // cell + 1):
            if 0 <= ty <= max_row:
                covered.add(ty * cols + tx)
    return covered


# ---------------------------------------------------------------------------
# TSX helpers
# ---------------------------------------------------------------------------
def prop(tile_el: ET.Element, name: str, value) -> None:
    if value is None:
        return
    props = tile_el.find("properties")
    if props is None:
        props = ET.SubElement(tile_el, "properties")
    if isinstance(value, bool):
        ET.SubElement(props, "property", {"name": name, "type": "bool",
                                          "value": "true" if value else "false"})
    elif isinstance(value, int):
        ET.SubElement(props, "property", {"name": name, "type": "int",
                                          "value": str(value)})
    else:
        ET.SubElement(props, "property", {"name": name, "value": str(value)})



def save_img(img: Image.Image, path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    img.save(path)


def write_tsx(root: ET.Element, path: Path) -> None:
    ET.indent(root, space="  ")
    tree = ET.ElementTree(root)
    path.parent.mkdir(parents=True, exist_ok=True)
    tree.write(path, encoding="utf-8", xml_declaration=True)


def tileset_root(name: str, tilewidth: int, tileheight: int, tilecount: int,
                 columns: int = 0, objectalignment: str = "bottom") -> ET.Element:
    return ET.Element(
        "tileset",
        {
            "version": "1.10",
            "tiledversion": "1.11.2",
            "name": name.removesuffix(".tsx"),
            "tilewidth": str(tilewidth),
            "tileheight": str(tileheight),
            "tilecount": str(tilecount),
            "columns": str(columns),
            "objectalignment": objectalignment,
        },
    )


def rel_source(p: Path, out_dir: Path) -> str:
    """Path of a generated PNG relative to the TSX directory (sibling of ./generated)."""
    return p.relative_to(out_dir).as_posix()


# ---------------------------------------------------------------------------
# Build
# ---------------------------------------------------------------------------
def build(args) -> dict:
    out_dir = ROOT / args.output
    generated = out_dir / "generated"
    manifests = out_dir / "manifests"
    if out_dir.exists():
        shutil.rmtree(out_dir)
    generated.mkdir(parents=True)
    manifests.mkdir(parents=True)

    assets_dir = ROOT / ASSETS_DIR
    gm_dir = ROOT / GM_DIR
    atlas16_path = assets_dir / "Tileset/spr_tileset_sunnysideworld_16px.png"
    atlas32_path = assets_dir / "Tileset/spr_tileset_sunnysideworld_forest_32px.png"

    atlas16 = Image.open(atlas16_path).convert("RGBA")
    atlas32 = Image.open(atlas32_path).convert("RGBA")
    assert atlas16.size == (1024, 1024), atlas16.size
    assert atlas32.size == (320, 576), atlas32.size
    color_index = build_color_index(atlas16)

    meta = gm_sprite_meta()

    classification: dict = {"version": "2.1", "pack": "Sunnyside World V2.1",
                            "generated_by": "scripts/build_sunnyside_tilesets.py",
                            "categories": {}}
    report: dict = {
        "classified_by_gamemaker": [],
        "classified_by_visual_manifest": [],
        "aliases_created": [],
        "excluded": [],
        "unclassified": [],
    }
    excluded: dict = {"reason": "Assets deliberately not part of the map tilesets.",
                      "items": []}
    stats: dict = {}
    anim_fallbacks_used: list[str] = []

    def sprite_png(name: str, frame: int = 0) -> Path:
        m = meta[name]
        return m["dir"] / (m["frames"][frame] + ".png")

    def sprite_speed_ms(name: str) -> int:
        m = meta.get(name)
        speed = m.get("speed") if m else None
        if speed and speed > 0:
            return max(1, round(1000.0 / speed))
        anim_fallbacks_used.append(name)
        return FALLBACK_MS

    def record(tile_name: str, category: str, subcategory: str | None,
               source: str, props: dict | None = None,
               animated: bool | None = None, frame_count: int | None = None) -> None:
        classification.setdefault("categories", {}).setdefault(category, []).append({
            "name": tile_name,
            "subcategory": subcategory,
            "source": source,
            "props": props or {},
            "animated": animated if animated is not None else (frame_count or 0) > 1,
            "frame_count": frame_count or 1,
        })

    # ---------------- shared image-collection writers ----------------
    def frame_images(sname: str, n_frames: int) -> list[Path]:
        """Per-frame PNGs: GM sprite frames (same pixels as the Elements strips)."""
        if sname in meta and len(meta[sname]["frames"]) == n_frames:
            return [sprite_png(sname, i) for i in range(n_frames)]
        return []

    def prop_item(sname: str, category: str, subcategory: str,
                  tile_name: str, **extra) -> dict:
        m = meta[sname]
        frames = len(m["frames"])
        pngs = frame_images(sname, frames)
        if pngs:
            size = Image.open(pngs[0]).convert("RGBA").size
        else:
            size = (m["width"] or 16, m["height"] or 16)
        return {
            "name": tile_name,
            "category": category,
            "subcategory": subcategory,
            "png": pngs[0] if pngs else sprite_png(sname, 0),
            "size": size,
            "frame_srcs": pngs,
            "animated": frames > 1,
            "frame_count": frames,
            "animation": None,
            "gm": sname,
            "source": f"sprites/{sname}/{sname}.yy",
            **extra,
        }

    def write_image_collection(tsx_name: str, items: list[dict]) -> None:
        """Emit an image-collection tileset.

        Non-animated items produce one tile.  Animated items produce one tile
        per frame (each tile carrying its own frame image); the first frame
        tile carries the <animation> referencing the sibling frame tiles.
        """
        root = tileset_root(tsx_name, TILE16, TILE16, 0)
        tile_id = 0
        for it in items:
            base = tile_id
            n_frames = len(it["animation"]) if it.get("animated") else 1
            stem = it["png"].with_name(it["png"].stem.removesuffix("_frame0"))
            for fi in range(n_frames):
                el = ET.SubElement(root, "tile", {"id": str(base + fi)})
                prop(el, "name", it["name"])
                prop(el, "category", it["category"])
                prop(el, "subcategory", it.get("subcategory"))
                if it.get("source"):
                    prop(el, "source", it["source"])
                if fi == 0:
                    prop(el, "animated", it.get("animated", False))
                    prop(el, "frame_count", it.get("frame_count", 1))
                for k in ("crop", "stage", "animal", "building_part",
                          "building_palette", "terrain_type", "original_tile_id",
                          "known_identity", "roof_color"):
                    if it.get(k) is not None:
                        prop(el, k, it[k])
                if it.get("animated") and fi == 0:
                    anim = ET.SubElement(el, "animation")
                    for (fid, dur) in it["animation"]:
                        ET.SubElement(anim, "frame", {"tileid": str(base + fid),
                                                      "duration": str(dur)})
                fpath = (stem.with_name(f"{stem.name}_frame{fi}.png")
                         if it.get("animated") else it["png"])
                ET.SubElement(el, "image", {
                    "source": rel_source(fpath, out_dir),
                    "width": str(it["size"][0]),
                    "height": str(it["size"][1]),
                })
                tile_id += 1
        root.set("tilecount", str(tile_id))
        write_tsx(root, out_dir / tsx_name)

    def write_grid_tileset(tsx_name: str, tiles: list[dict], png_name: str,
                           cell: int, cols: int, extra_props_fn=None,
                           add_animations: bool = False) -> None:
        atlas_img = make_derived_atlas(tiles, cell, cols)
        png_rel = generated / png_name
        save_img(atlas_img, png_rel)
        n = len(tiles)
        root = tileset_root(tsx_name, cell, cell, n, cols)
        ET.SubElement(root, "image", {
            "source": rel_source(png_rel, out_dir),
            "width": str(atlas_img.width),
            "height": str(atlas_img.height),
        })
        for i, t in enumerate(tiles):
            el = ET.SubElement(root, "tile", {"id": str(i)})
            prop(el, "name", t["name"])
            prop(el, "category", t["category"])
            prop(el, "subcategory", t["subcategory"])
            prop(el, "original_tile_id", t["id"])
            prop(el, "source", "spr_tileset_sunnysideworld_16px.png")
            if t.get("known_identity"):
                prop(el, "known_identity", t["known_identity"])
            if add_animations and t.get("animation"):
                prop(el, "animated", True)
                prop(el, "frame_count", len(t["animation"]))
            else:
                prop(el, "animated", False)
                prop(el, "frame_count", 1)
            if extra_props_fn:
                extra_props_fn(el, t, i)
            if add_animations and t.get("animation"):
                anim = ET.SubElement(el, "animation")
                for fid, dur in t["animation"]:
                    ET.SubElement(anim, "frame", {"tileid": str(fid),
                                                  "duration": str(dur)})
        write_tsx(root, out_dir / tsx_name)

    # ------------------------------------------------------------------
    # 1. Atlas-derived category tiles
    # ------------------------------------------------------------------
    atlas_16_cols = 64
    terrain_tiles, water_tiles, path_tiles, building_tiles, cloud_tiles = [], [], [], [], []
    atlas_classified: dict[int, dict] = {}

    for fam_name, fam in AUTOTILES.items():
        for tid in fam["ids"]:
            if tid == 0:
                continue
            img = atlas_tile(atlas16, tid, atlas_16_cols, TILE16)
            entry = {
                "id": tid,
                "image": img,
                "name": f"{fam['subcategory']}_{tid}",
                "category": fam["category"],
                "subcategory": fam["subcategory"],
            }
            if fam.get("known_identity"):
                entry["known_identity"] = fam["known_identity"]
            if fam["category"] == "terrain":
                terrain_tiles.append(entry)
            elif fam["category"] == "water":
                water_tiles.append(entry)
            elif fam["category"] == "paths_fences":
                path_tiles.append(entry)
            elif fam["category"] == "buildings":
                building_tiles.append(entry)
            elif fam["category"] == "unclassified":
                cloud_tiles.append(entry)
            atlas_classified[tid] = entry

    # water standalone sprite located by exact match
    water_tiles.append({
        "id": WATER_ATLAS_TILE,
        "image": pad_to_cell(Image.open(sprite_png("water")).convert("RGBA")),
        "name": f"water_{WATER_ATLAS_TILE}",
        "category": "water",
        "subcategory": "water",
    })
    atlas_classified[WATER_ATLAS_TILE] = water_tiles[-1]

    # ------------------------------------------------------------------
    # 2. Exact template matching of named sprites against the atlas
    #    -> mark those atlas tiles as classified (they duplicate the
    #       standalone art used in the image-collection tilesets)
    # ------------------------------------------------------------------
    matched_tiles: dict[int, dict] = {}
    sprites_to_match = []
    for sub in ("Crops", "Plants", "Animals", "Other", "VFX"):
        base = assets_dir / "Elements" / sub
        if base.is_dir():
            for f in sorted(base.rglob("*.png")):
                sprites_to_match.append((f, "props"))
    for sname in (RESOURCE_GM + VEGETATION_GM + FARM_GM + OUTDOOR_DECOR_GM
                  + FURNITURE_GM + BUILDING_PROPS_GM):
        if sname in meta and len(meta[sname]["frames"]) == 1:
            sprites_to_match.append((sprite_png(sname), "props"))

    for png, _cat in sprites_to_match:
        try:
            tpl = Image.open(png).convert("RGBA")
        except Exception:
            continue
        tw, th = tpl.size
        n_opaque = sum(1 for v in tpl.getchannel("A").getdata() if v > 8)
        if n_opaque < 12 or tw > 80 or th > 80:
            continue
        origins = find_exact_matches(atlas16, color_index, tpl)
        if not origins or len(origins) > 12:
            continue  # not distinctive enough -> do not claim atlas tiles
        for (x, y) in origins:
            for tid in tiles_covered(x, y, tw, th, TILE16, atlas_16_cols, 63):
                if tid in atlas_classified or tid in matched_tiles:
                    continue
                matched_tiles[tid] = {"category": "props",
                                      "source_png": os.path.relpath(png, ROOT)}

    # glints (GM animation_25 + template match) -> vfx
    for tid in GLINT_ATLAS_TILES:
        if tid not in atlas_classified and tid not in matched_tiles:
            matched_tiles[tid] = {"category": "vfx",
                                  "source_png": "gm animation_25 + spr_deco_glint_*"}

    # ------------------------------------------------------------------
    # 2b. Visual regions manifest (supplements GM metadata for atlas
    #      tiles that cannot be identified without vision)
    # ------------------------------------------------------------------
    vr_path = ROOT / "visual_regions.json"
    vr_data = json.loads(vr_path.read_text(encoding="utf-8"))

    # Build visual cell map: tile_id -> {category, subcategory, priority, properties}
    # Rule 3: higher priority wins on overlap
    visual_cells: dict[int, dict] = {}
    for region in vr_data.get("regions", []):
        for ry in range(region["y"], region["y"] + region["height"]):
            for rx in range(region["x"], region["x"] + region["width"]):
                tid = ry * atlas_16_cols + rx
                entry = {
                    "category": region["category"],
                    "subcategory": region["name"],
                    "priority": region.get("priority", 0),
                    "properties": region.get("properties", {}),
                }
                if tid not in visual_cells or entry["priority"] > visual_cells[tid]["priority"]:
                    visual_cells[tid] = entry

    # Rule 4: exclusion cells
    excluded_cells: set[int] = set()
    for exc in vr_data.get("exclusions", []):
        for r in exc.get("regions", []):
            for ry in range(r["y"], r["y"] + r["height"]):
                for rx in range(r["x"], r["x"] + r["width"]):
                    excluded_cells.add(ry * atlas_16_cols + rx)

    # Rule 5: alias cells (roofs) — copy cells into additional tilesets
    roof_alias_cells: list[dict] = []
    for alias in vr_data.get("aliases", []):
        color = alias.get("properties", {}).get("roof_color")
        for cell in alias.get("cells", []):
            tid = cell["y"] * atlas_16_cols + cell["x"]
            roof_alias_cells.append({"tile_id": tid, "roof_color": color,
                                     "alias_name": alias["name"]})

    # Rule 1: GM metadata wins over visual classification
    classified_ids = set(atlas_classified.keys()) | set(matched_tiles.keys())
    visual_classified: dict[int, dict] = {}
    conflicts: list[dict] = []

    # Category -> list mapping for grid tilesets (tiles have PIL images)
    grid_cats: dict[str, list] = {
        "terrain": terrain_tiles, "water": water_tiles, "paths_fences": path_tiles,
    }
    # Category -> list mapping for image-collection tilesets
    ic_visual_cats: dict[str, list[dict]] = {
        "buildings": [], "crops": [], "farm": [], "furniture": [],
        "outdoor_decor": [], "resources": [], "vegetation": [], "vfx": [],
    }

    for tid in sorted(visual_cells.keys()):
        if tid in classified_ids:
            conflicts.append({
                "tile_id": tid,
                "atlas_coords": {"col": tid % 64, "row": tid // 64},
                "gamemaker_category": (atlas_classified.get(tid, {}).get("category")
                                       or matched_tiles.get(tid, {}).get("category")),
                "visual_category": visual_cells[tid]["category"],
                "resolution": "gamemaker wins",
            })
            continue
        if tid in excluded_cells:
            continue
        img = atlas_tile(atlas16, tid, atlas_16_cols, TILE16)
        if tile_is_empty(img):
            continue
        vc = visual_cells[tid]
        cat = vc["category"]
        entry = {
            "id": tid, "image": img, "name": f"{vc['subcategory']}_{tid}",
            "category": cat, "subcategory": vc["subcategory"],
            "classification_source": "visual_manifest",
        }
        for pk, pv in vc["properties"].items():
            entry[pk] = pv
        visual_classified[tid] = entry
        if cat in grid_cats:
            grid_cats[cat].append(entry)
        elif cat in ic_visual_cats:
            ic_visual_cats[cat].append(entry)

    # ------------------------------------------------------------------
    # 3. Derived atlas PNGs + grid TSX: terrain, water, paths
    # ------------------------------------------------------------------
    write_grid_tileset("ss_terrain.tsx", terrain_tiles, "ss_terrain.png",
                       TILE16, 8,
                       extra_props_fn=lambda el, t, i:
                       prop(el, "terrain_type", "grass")
                       if t["id"] == GRASS_ATLAS_TILE else None)
    write_grid_tileset("ss_water.tsx", water_tiles, "ss_water.png", TILE16, 8)
    write_grid_tileset("ss_paths_fences.tsx", path_tiles, "ss_paths_fences.png",
                       TILE16, 8)

    stats.update({"Terrain": len(terrain_tiles), "Water": len(water_tiles),
                  "Paths/Fences": len(path_tiles)})

    # ------------------------------------------------------------------
    # 4. ss_buildings (image collection: walls + beam + chimneys)
    # ------------------------------------------------------------------
    building_items = []
    for t in building_tiles:
        rel = generated / "props/buildings" / f"{t['name']}.png"
        save_img(t["image"], rel)
        building_items.append({
            "name": t["name"], "png": rel, "category": "buildings",
            "subcategory": t["subcategory"], "original_tile_id": t["id"],
            "source": "spr_tileset_sunnysideworld_16px.png",
            "building_part": t["subcategory"], "size": (16, 16),
        })
    for sname in BUILDING_PROPS_GM:
        part = {"spr_deco_beam": "beam",
                "spr_deco_chinmney": "chimney",
                "spr_deco_cook_chinmney": "chimney"}[sname]
        img = Image.open(sprite_png(sname)).convert("RGBA")
        rel = generated / "props/buildings" / f"{sname}.png"
        save_img(img, rel)
        building_items.append({"name": sname, "png": rel, "category": "buildings",
                               "subcategory": part, "building_part": part,
                               "source": f"sprites/{sname}/{sname}.yy",
                               "size": img.size})
        record(sname, "buildings", part, f"sprites/{sname}/{sname}.yy")
    for ve in ic_visual_cats.get("buildings", []):
        rel = generated / "props/buildings" / f"{ve['name']}.png"
        save_img(ve["image"], rel)
        building_items.append({"name": ve["name"], "png": rel, "category": "buildings",
                               "subcategory": ve["subcategory"],
                               "original_tile_id": ve["id"],
                               "source": "spr_tileset_sunnysideworld_16px.png",
                               "building_part": ve["subcategory"],
                               "size": (TILE16, TILE16),
                               "classification_source": "visual_manifest",
                               **{k: v for k, v in ve.items()
                                  if k in ("building_palette",)}})
        record(ve["name"], "buildings", ve["subcategory"],
               "spr_tileset_sunnysideworld_16px.png (visual_manifest)",
               props={"building_part": ve.get("building_palette", ve["subcategory"])})
    write_image_collection("ss_buildings.tsx", building_items)
    stats["Buildings"] = len(building_items)

    # ------------------------------------------------------------------
    # 5. ss_roofs (from visual_regions.json aliases — roof_color preserved)
    # ------------------------------------------------------------------
    roof_items = []
    for ac in roof_alias_cells:
        tid = ac["tile_id"]
        img = atlas_tile(atlas16, tid, atlas_16_cols, TILE16)
        if tile_is_empty(img):
            continue
        color = ac["roof_color"]
        name = f"roof_{color}_{tid}"
        rel = generated / "props/roofs" / f"{name}.png"
        save_img(img, rel)
        roof_items.append({"name": name, "category": "roofs",
                           "subcategory": f"roof_{color}", "png": rel,
                           "size": (TILE16, TILE16),
                           "source": "spr_tileset_sunnysideworld_16px.png",
                           "original_tile_id": tid,
                           "roof_color": color,
                           "animated": False, "frame_count": 1})
    write_image_collection("ss_roofs.tsx", roof_items)
    stats["Roofs"] = len(roof_items)

    # ------------------------------------------------------------------
    # 6. ss_forest (derived 32px atlas)
    # ------------------------------------------------------------------
    forest_autotile = {11, 12, 13, 14, 15, 16, 17, 18,
                       21, 22, 23, 24, 25, 26, 27}
    forest_cols = atlas32.width // TILE32
    forest_tiles = []
    for tid in range(atlas32.width * atlas32.height // (TILE32 * TILE32)):
        img = atlas_tile(atlas32, tid, forest_cols, TILE32)
        if tile_is_empty(img):
            continue
        forest_tiles.append({
            "id": tid, "image": img, "name": f"forest_{tid}",
            "category": "forest",
            "subcategory": ("forest_01" if tid in forest_autotile else "forest_detail"),
        })
    write_grid_tileset("ss_forest.tsx", forest_tiles, "ss_forest.png", TILE32, 8)
    stats["Forest"] = len(forest_tiles)

    # ------------------------------------------------------------------
    # 7. ss_crops
    # ------------------------------------------------------------------
    crop_items = []
    for crop in CROP_NAMES:
        for stage in range(6):
            src = assets_dir / "Elements/Crops" / f"{crop}_{stage:02d}.png"
            raw = Image.open(src).convert("RGBA")
            # <=16x16 -> padded 16x16 cell (bottom aligned); taller stages
            # (e.g. sunflower_04 13x19) keep native resolution, never resized.
            if raw.size[0] <= TILE16 and raw.size[1] <= TILE16:
                img = pad_to_cell(raw)
                size = (TILE16, TILE16)
            else:
                img = raw
                size = raw.size
            rel = generated / "props/crops" / f"crop_{crop}_stage_{stage}.png"
            save_img(img, rel)
            crop_items.append({
                "name": f"crop_{crop}_stage_{stage}", "category": "crop",
                "subcategory": crop, "crop": crop, "stage": stage,
                "png": rel, "size": size,
                "source": f"Elements/Crops/{crop}_{stage:02d}.png", "animated": False,
            })
            record(f"crop_{crop}_stage_{stage}", "crop", crop,
                   f"Elements/Crops/{crop}_{stage:02d}.png",
                   props={"crop": crop, "stage": stage})
    for soil in FARMLAND:
        img = pad_to_cell(Image.open(assets_dir / "Elements/Crops" / f"{soil}.png").convert("RGBA"))
        rel = generated / "props/crops" / f"farmland_{soil}.png"
        save_img(img, rel)
        crop_items.append({"name": f"farmland_{soil}", "category": "farmland",
                           "subcategory": "soil", "png": rel,
                           "size": (TILE16, TILE16),
                           "source": f"Elements/Crops/{soil}.png", "animated": False})
        record(f"farmland_{soil}", "farmland", "soil", f"Elements/Crops/{soil}.png")
    img = pad_to_cell(Image.open(assets_dir / "Elements/Crops/seeds_generic.png").convert("RGBA"))
    rel = generated / "props/crops" / "seed_generic.png"
    save_img(img, rel)
    crop_items.append({"name": "seed_generic", "category": "seed",
                       "subcategory": "seeds_generic", "png": rel,
                       "size": (TILE16, TILE16),
                       "source": "Elements/Crops/seeds_generic.png", "animated": False})
    record("seed_generic", "seed", "seeds_generic", "Elements/Crops/seeds_generic.png")
    for ve in ic_visual_cats.get("crops", []):
        rel = generated / "props/crops" / f"{ve['name']}.png"
        save_img(ve["image"], rel)
        crop_items.append({"name": ve["name"], "category": "crops",
                           "subcategory": ve["subcategory"],
                           "original_tile_id": ve["id"], "png": rel,
                           "size": (TILE16, TILE16),
                           "source": "spr_tileset_sunnysideworld_16px.png",
                           "animated": False, "frame_count": 1,
                           "classification_source": "visual_manifest"})
        record(ve["name"], "crops", ve["subcategory"],
               "spr_tileset_sunnysideworld_16px.png (visual_manifest)")
    write_image_collection("ss_crops.tsx", crop_items)
    stats["Crops"] = len(crop_items)

    # ------------------------------------------------------------------
    # 8. ss_resources
    # ------------------------------------------------------------------
    res_items = []
    for rname in RESOURCE_FROM_CROPS:
        img = pad_to_cell(Image.open(assets_dir / "Elements/Crops" / f"{rname}.png").convert("RGBA"))
        rel = generated / "props/resources" / f"resource_{rname}.png"
        save_img(img, rel)
        res_items.append({"name": f"resource_{rname}", "category": "resource",
                          "subcategory": rname, "png": rel,
                          "size": (TILE16, TILE16),
                          "source": f"Elements/Crops/{rname}.png", "animated": False})
        record(f"resource_{rname}", "resource", rname, f"Elements/Crops/{rname}.png")
    for sname in RESOURCE_GM:
        sub = sname.removeprefix("spr_deco_")
        it = prop_item(sname, "resource", sub, f"resource_{sub}")
        if it["animated"]:
            raise RuntimeError(f"animated resource not expected: {sname}")
        img = pad_to_cell(Image.open(it["png"]).convert("RGBA"))
        rel = generated / "props/resources" / f"resource_{sub}.png"
        save_img(img, rel)
        it["png"] = rel
        it["size"] = (TILE16, TILE16)
        res_items.append(it)
        record(f"resource_{sub}", "resource", sub, f"sprites/{sname}/{sname}.yy")
    for ve in ic_visual_cats.get("resources", []):
        rel = generated / "props/resources" / f"{ve['name']}.png"
        save_img(ve["image"], rel)
        res_items.append({"name": ve["name"], "category": "resources",
                          "subcategory": ve["subcategory"],
                          "original_tile_id": ve["id"], "png": rel,
                          "size": (TILE16, TILE16),
                          "source": "spr_tileset_sunnysideworld_16px.png",
                          "animated": False, "frame_count": 1,
                          "classification_source": "visual_manifest"})
        record(ve["name"], "resources", ve["subcategory"],
               "spr_tileset_sunnysideworld_16px.png (visual_manifest)")
    write_image_collection("ss_resources.tsx", res_items)
    stats["Resources"] = len(res_items)

    # ------------------------------------------------------------------
    # 9. ss_vegetation
    # ------------------------------------------------------------------
    veg_items = []
    for sname in VEGETATION_GM:
        sub = sname.removeprefix("spr_deco_")
        if sname == "leaves_hit":
            sub = "leaves_hit"
        it = prop_item(sname, "vegetation", sub, f"vegetation_{sub}")
        if it["animated"]:
            pngs = it["frame_srcs"]
            dur = sprite_speed_ms(sname)
            frames_dir = generated / "props/vegetation"
            anim = []
            for fi in range(it["frame_count"]):
                im = Image.open(pngs[fi]).convert("RGBA")
                rel = frames_dir / f"vegetation_{sub}_frame{fi}.png"
                save_img(im, rel)
                anim.append((fi, dur))
            it["png"] = frames_dir / f"vegetation_{sub}_frame0.png"
            it["animation"] = anim
            it["size"] = Image.open(it["png"]).size
            it["frame_count"] = len(anim)
        else:
            im = Image.open(it["png"]).convert("RGBA")
            if im.size[0] <= TILE16 and im.size[1] <= TILE16:
                im = pad_to_cell(im)
                rel = generated / "props/vegetation" / f"vegetation_{sub}.png"
                save_img(im, rel)
                it["png"] = rel
                it["size"] = (TILE16, TILE16)
            else:
                rel = generated / "props/vegetation" / f"vegetation_{sub}.png"
                save_img(im, rel)
                it["png"] = rel
                it["size"] = im.size
        veg_items.append(it)
        record(f"vegetation_{sub}", "vegetation", sub,
               f"sprites/{sname}/{sname}.yy",
               animated=it["animated"], frame_count=it.get("frame_count"))
    for ve in ic_visual_cats.get("vegetation", []):
        rel = generated / "props/vegetation" / f"{ve['name']}.png"
        save_img(ve["image"], rel)
        veg_items.append({"name": ve["name"], "category": "vegetation",
                          "subcategory": ve["subcategory"],
                          "original_tile_id": ve["id"], "png": rel,
                          "size": (TILE16, TILE16),
                          "source": "spr_tileset_sunnysideworld_16px.png",
                          "animated": False, "frame_count": 1,
                          "classification_source": "visual_manifest"})
        record(ve["name"], "vegetation", ve["subcategory"],
               "spr_tileset_sunnysideworld_16px.png (visual_manifest)")
    write_image_collection("ss_vegetation.tsx", veg_items)
    stats["Vegetation"] = len(veg_items)

    # ------------------------------------------------------------------
    # 10. ss_animals
    # ------------------------------------------------------------------
    ANIMALS = {
        "spr_deco_cow": "cow",
        "spr_deco_sheep_01": "sheep",
        "spr_deco_pig_01": "pig",
        "spr_deco_chicken_01": "chicken",
        "spr_deco_duck_01": "duck",
        "spr_deco_bird_01": "bird",
        "spr_deco_blinking": "unknown",
    }
    animal_items = []
    for sname, animal in ANIMALS.items():
        it = prop_item(sname, "animal", animal, f"animal_{animal}")
        pngs = it["frame_srcs"]
        dur = sprite_speed_ms(sname)
        frames_dir = generated / "props/animals"
        anim = []
        for fi in range(it["frame_count"]):
            im = Image.open(pngs[fi]).convert("RGBA")
            rel = frames_dir / f"animal_{animal}_frame{fi}.png"
            save_img(im, rel)
            anim.append((fi, dur))
        it["png"] = frames_dir / f"animal_{animal}_frame0.png"
        it["animation"] = anim
        it["size"] = Image.open(it["png"]).size
        it["animal"] = animal
        it["frame_count"] = len(anim)
        animal_items.append(it)
        src = ("Elements/Animals/spr_deco_blinking_strip12.png" if animal == "unknown"
               else f"Elements/Animals/spr_deco_{animal}_01_strip4.png"
               if animal in ("sheep", "pig", "chicken", "duck")
               else f"Elements/Animals/spr_deco_{animal}_strip4.png")
        record(f"animal_{animal}", "animal", animal, src,
               props={"animal": animal}, animated=True, frame_count=len(anim))
    write_image_collection("ss_animals.tsx", animal_items)
    stats["Animals"] = len(animal_items)

    # ------------------------------------------------------------------
    # 11. ss_farm
    # ------------------------------------------------------------------
    farm_items = []
    for sname in FARM_GM:
        sub = sname.removeprefix("spr_deco_").removeprefix("crate_")
        it = prop_item(sname, "farm", sub, f"farm_{sub}")
        if it["animated"]:
            pngs = it["frame_srcs"]
            dur = sprite_speed_ms(sname)
            frames_dir = generated / "props/farm"
            anim = []
            for fi in range(it["frame_count"]):
                im = Image.open(pngs[fi]).convert("RGBA")
                rel = frames_dir / f"farm_{sub}_frame{fi}.png"
                save_img(im, rel)
                anim.append((fi, dur))
            it["png"] = frames_dir / f"farm_{sub}_frame0.png"
            it["animation"] = anim
            it["size"] = Image.open(it["png"]).size
            it["frame_count"] = len(anim)
        else:
            im = Image.open(it["png"]).convert("RGBA")
            if im.size[0] <= TILE16 and im.size[1] <= TILE16:
                im = pad_to_cell(im)
                rel = generated / "props/farm" / f"farm_{sub}.png"
                save_img(im, rel)
                it["png"] = rel
                it["size"] = (TILE16, TILE16)
            else:
                rel = generated / "props/farm" / f"farm_{sub}.png"
                save_img(im, rel)
                it["png"] = rel
                it["size"] = im.size
        farm_items.append(it)
        record(f"farm_{sub}", "farm", sub, f"sprites/{sname}/{sname}.yy",
               animated=it["animated"], frame_count=it.get("frame_count"))
    for sname, sub in [("spr_deco_windmill", "windmill"),
                       ("spr_deco_windmill_withshadow", "windmill_withshadow"),
                       ("spr_deco_windmillshadow", "windmillshadow")]:
        strip = assets_dir / "Elements/Other" / f"{sname}_strip9.png"
        im = Image.open(strip).convert("RGBA")
        fw = im.width // 9
        assert fw * 9 == im.width, f"{strip} not 9 frames"
        dur = sprite_speed_ms(sname)
        frames_dir = generated / "props/farm"
        anim = []
        for fi in range(9):
            fr = im.crop((fi * fw, 0, fi * fw + fw, im.height))
            rel = frames_dir / f"farm_{sub}_frame{fi}.png"
            save_img(fr, rel)
            anim.append((fi, dur))
        farm_items.append({"name": f"farm_{sub}", "category": "farm",
                           "subcategory": sub,
                           "png": frames_dir / f"farm_{sub}_frame0.png",
                           "size": (fw, im.height), "animated": True,
                           "frame_count": 9, "animation": anim,
                           "source": f"Elements/Other/{sname}_strip9.png"})
        record(f"farm_{sub}", "farm", sub, f"Elements/Other/{sname}_strip9.png",
               animated=True, frame_count=9)
    for ve in ic_visual_cats.get("farm", []):
        rel = generated / "props/farm" / f"{ve['name']}.png"
        save_img(ve["image"], rel)
        farm_items.append({"name": ve["name"], "category": "farm",
                           "subcategory": ve["subcategory"],
                           "original_tile_id": ve["id"], "png": rel,
                           "size": (TILE16, TILE16),
                           "source": "spr_tileset_sunnysideworld_16px.png",
                           "animated": False, "frame_count": 1,
                           "classification_source": "visual_manifest"})
        record(ve["name"], "farm", ve["subcategory"],
               "spr_tileset_sunnysideworld_16px.png (visual_manifest)")
    write_image_collection("ss_farm.tsx", farm_items)
    stats["Farm"] = len(farm_items)

    # ------------------------------------------------------------------
    # 12. ss_outdoor_decor
    # ------------------------------------------------------------------
    decor_items = []
    for sname in OUTDOOR_DECOR_GM:
        sub = sname.removeprefix("spr_deco_")
        it = prop_item(sname, "outdoor_decor", sub, f"decor_{sub}")
        if it["animated"]:
            pngs = it["frame_srcs"]
            dur = sprite_speed_ms(sname)
            frames_dir = generated / "props/outdoor_decor"
            anim = []
            for fi in range(it["frame_count"]):
                im = Image.open(pngs[fi]).convert("RGBA")
                rel = frames_dir / f"decor_{sub}_frame{fi}.png"
                save_img(im, rel)
                anim.append((fi, dur))
            it["png"] = frames_dir / f"decor_{sub}_frame0.png"
            it["animation"] = anim
            it["size"] = Image.open(it["png"]).size
            it["frame_count"] = len(anim)
        else:
            im = Image.open(it["png"]).convert("RGBA")
            if im.size[0] <= TILE16 and im.size[1] <= TILE16:
                im = pad_to_cell(im)
                rel = generated / "props/outdoor_decor" / f"decor_{sub}.png"
                save_img(im, rel)
                it["png"] = rel
                it["size"] = (TILE16, TILE16)
            else:
                rel = generated / "props/outdoor_decor" / f"decor_{sub}.png"
                save_img(im, rel)
                it["png"] = rel
                it["size"] = im.size
        decor_items.append(it)
        record(f"decor_{sub}", "outdoor_decor", sub,
               f"sprites/{sname}/{sname}.yy",
               animated=it["animated"], frame_count=it.get("frame_count"))
    for sname, sub, n in [("spr_deco_coracle_strip4", "coracle", 4),
                          ("spr_deco_coracle_land", "coracle_land", 1)]:
        strip = assets_dir / "Elements/Other" / f"{sname}.png"
        im = Image.open(strip).convert("RGBA")
        fw = im.width // n
        assert fw * n == im.width, f"{strip} not {n} frames"
        if n > 1:
            dur = sprite_speed_ms("spr_deco_coracle")
            frames_dir = generated / "props/outdoor_decor"
            anim = []
            for fi in range(n):
                fr = im.crop((fi * fw, 0, fi * fw + fw, im.height))
                rel = frames_dir / f"decor_{sub}_frame{fi}.png"
                save_img(fr, rel)
                anim.append((fi, dur))
            it = {"name": f"decor_{sub}", "category": "outdoor_decor",
                  "subcategory": sub, "png": frames_dir / f"decor_{sub}_frame0.png",
                  "size": (fw, im.height), "animated": True, "frame_count": n,
                  "animation": anim, "source": f"Elements/Other/{sname}.png"}
        else:
            rel = generated / "props/outdoor_decor" / f"decor_{sub}.png"
            save_img(im, rel)
            it = {"name": f"decor_{sub}", "category": "outdoor_decor",
                  "subcategory": sub, "png": rel, "size": im.size,
                  "animated": False, "frame_count": 1,
                  "source": f"Elements/Other/{sname}.png"}
        decor_items.append(it)
        record(f"decor_{sub}", "outdoor_decor", sub,
               f"Elements/Other/{sname}.png",
               animated=it["animated"], frame_count=it.get("frame_count"))
    for ve in ic_visual_cats.get("outdoor_decor", []):
        rel = generated / "props/outdoor_decor" / f"{ve['name']}.png"
        save_img(ve["image"], rel)
        decor_items.append({"name": ve["name"], "category": "outdoor_decor",
                           "subcategory": ve["subcategory"],
                           "original_tile_id": ve["id"], "png": rel,
                           "size": (TILE16, TILE16),
                           "source": "spr_tileset_sunnysideworld_16px.png",
                           "animated": False, "frame_count": 1,
                           "classification_source": "visual_manifest"})
        record(ve["name"], "outdoor_decor", ve["subcategory"],
               "spr_tileset_sunnysideworld_16px.png (visual_manifest)")
    write_image_collection("ss_outdoor_decor.tsx", decor_items)
    stats["Outdoor decor"] = len(decor_items)

    # ------------------------------------------------------------------
    # 13. ss_furniture
    # ------------------------------------------------------------------
    furn_items = []
    for sname in FURNITURE_GM:
        sub = sname.removeprefix("spr_deco_")
        it = prop_item(sname, "furniture", sub, f"furniture_{sub}")
        im = Image.open(it["png"]).convert("RGBA")
        if im.size[0] <= TILE16 and im.size[1] <= TILE16:
            im = pad_to_cell(im)
            rel = generated / "props/furniture" / f"furniture_{sub}.png"
            save_img(im, rel)
            it["png"] = rel
            it["size"] = (TILE16, TILE16)
        else:
            rel = generated / "props/furniture" / f"furniture_{sub}.png"
            save_img(im, rel)
            it["png"] = rel
            it["size"] = im.size
        furn_items.append(it)
        record(f"furniture_{sub}", "furniture", sub, f"sprites/{sname}/{sname}.yy")
    for ve in ic_visual_cats.get("furniture", []):
        rel = generated / "props/furniture" / f"{ve['name']}.png"
        save_img(ve["image"], rel)
        furn_items.append({"name": ve["name"], "category": "furniture",
                           "subcategory": ve["subcategory"],
                           "original_tile_id": ve["id"], "png": rel,
                           "size": (TILE16, TILE16),
                           "source": "spr_tileset_sunnysideworld_16px.png",
                           "animated": False, "frame_count": 1,
                           "classification_source": "visual_manifest"})
        record(ve["name"], "furniture", ve["subcategory"],
               "spr_tileset_sunnysideworld_16px.png (visual_manifest)")
    write_image_collection("ss_furniture.tsx", furn_items)
    stats["Furniture"] = len(furn_items)

    # ------------------------------------------------------------------
    # 14. ss_vfx
    # ------------------------------------------------------------------
    vfx_items = []
    vfx_srcs = [
        ("chimneysmoke_01", "chimney_smoke_01", 30),
        ("chimneysmoke_02", "chimney_smoke_02", 30),
        ("chimneysmoke_03", "chimney_smoke_03", 30),
        ("chimneysmoke_04", "chimney_smoke_04", 30),
        ("chimneysmoke_05", "chimney_smoke_05", 30),
        ("spr_deco_fire_01", "fire_01", 4),
        ("spr_deco_fire_02", "fire_02", 4),
        ("spr_deco_glint_01", "glint_01", 6),
        ("spr_deco_glint_02", "glint_02", 4),
    ]
    smoke_dir = assets_dir / "Elements/VFX"
    for sname, sub, n in vfx_srcs:
        if sname.startswith("chimneysmoke"):
            strip = smoke_dir / "Chimney Smoke" / f"{sname}_strip30.png"
        elif sname.startswith("spr_deco_fire"):
            strip = smoke_dir / "Fire" / f"{sname}_strip4.png"
        else:
            strip = smoke_dir / "Glint" / f"{sname}_strip{n}.png"
        im = Image.open(strip).convert("RGBA")
        fw = im.width // n
        assert fw * n == im.width, f"{strip} not {n} frames"
        dur = sprite_speed_ms(sname)
        frames_dir = generated / "props/vfx"
        anim = []
        for fi in range(n):
            fr = im.crop((fi * fw, 0, fi * fw + fw, im.height))
            rel = frames_dir / f"vfx_{sub}_frame{fi}.png"
            save_img(fr, rel)
            anim.append((fi, dur))
        vfx_items.append({"name": f"vfx_{sub}", "category": "vfx",
                          "subcategory": sub,
                          "png": frames_dir / f"vfx_{sub}_frame0.png",
                          "size": (fw, im.height), "animated": True,
                          "frame_count": n, "animation": anim,
                          "source": os.path.relpath(strip, ROOT)})
        record(f"vfx_{sub}", "vfx", sub, os.path.relpath(strip, ROOT),
               animated=True, frame_count=n)
    for ve in ic_visual_cats.get("vfx", []):
        rel = generated / "props/vfx" / f"{ve['name']}.png"
        save_img(ve["image"], rel)
        vfx_items.append({"name": ve["name"], "category": "vfx",
                          "subcategory": ve["subcategory"],
                          "original_tile_id": ve["id"], "png": rel,
                          "size": (TILE16, TILE16),
                          "source": "spr_tileset_sunnysideworld_16px.png",
                          "animated": False, "frame_count": 1,
                          "classification_source": "visual_manifest"})
        record(ve["name"], "vfx", ve["subcategory"],
               "spr_tileset_sunnysideworld_16px.png (visual_manifest)")
    write_image_collection("ss_vfx.tsx", vfx_items)
    stats["VFX"] = len(vfx_items)

    # ------------------------------------------------------------------
    # 15. ss_unclassified (derived grid atlas + report entries)
    # ------------------------------------------------------------------
    ts = load_yy(ROOT / GM_DIR / "tilesets/tileset_sunnysideworld/tileset_sunnysideworld.yy")
    gm_anim_groups = [a["frames"] for a in ts.get("tileAnimationFrames", [])]
    gm_anim_ms = max(1, round(1000.0 / ts.get("tileAnimationSpeed", 5.0)))

    # All tiles that have been classified or excluded
    all_classified_ids = classified_ids | set(visual_classified.keys()) | excluded_cells
    unclassified_tiles = []
    for tid in range(64 * 64):
        if tid in all_classified_ids:
            continue
        img = atlas_tile(atlas16, tid, atlas_16_cols, TILE16)
        if tile_is_empty(img):
            continue
        unclassified_tiles.append({"id": tid, "image": img,
                                   "name": f"unclassified_{tid}",
                                   "category": "unclassified",
                                   "subcategory": "unclassified"})
    # Clouds remain unclassified (no ss_clouds tileset in target categories)
    for c in cloud_tiles:
        if c["id"] in excluded_cells:
            continue
        c["category"] = "unclassified"
        unclassified_tiles.append(c)
    unclassified_tiles.sort(key=lambda t: t["id"])
    new_id_of = {t["id"]: i for i, t in enumerate(unclassified_tiles)}

    for i, t in enumerate(unclassified_tiles):
        if t.get("known_identity"):
            continue
        for group in gm_anim_groups:
            if t["id"] in group and all(f in new_id_of for f in group):
                t["animation"] = [(new_id_of[f], gm_anim_ms) for f in group]
                t["gm_animation"] = "tileAnimationFrames"
                break

    write_grid_tileset("ss_unclassified.tsx", unclassified_tiles,
                       "ss_unclassified.png", TILE16, 64,
                       add_animations=True,
                       extra_props_fn=lambda el, t, i: (
                           prop(el, "reason", (
                               "identified as clouds via GameMaker auto-tile "
                               "family; no ss_clouds tileset exists in the "
                               "target categories") if t.get("known_identity")
                               else "no metadata identifies this atlas cell without vision"))
                       )
    stats["Unclassified"] = len(unclassified_tiles)

    # ------------------------------------------------------------------
    # 16. classification_report.json (5 separate sections)
    # ------------------------------------------------------------------
    # classified_by_gamemaker: tiles from GM autotiles + template matching
    for tid in sorted(classified_ids):
        gm_cat = (atlas_classified.get(tid, {}).get("category")
                  or matched_tiles.get(tid, {}).get("category"))
        if tid in excluded_cells:
            continue
        if gm_cat == "unclassified":
            continue  # clouds go to unclassified section
        report["classified_by_gamemaker"].append({
            "atlas_tile_id": tid,
            "atlas_coords": {"col": tid % 64, "row": tid // 64},
            "category": gm_cat,
            "source": ("GameMaker auto-tile family" if tid in atlas_classified
                       else "exact pixel template matching"),
        })

    # classified_by_visual_manifest: tiles from visual_regions.json
    for tid in sorted(visual_classified.keys()):
        vc = visual_classified[tid]
        report["classified_by_visual_manifest"].append({
            "atlas_tile_id": tid,
            "atlas_coords": {"col": tid % 64, "row": tid // 64},
            "category": vc["category"],
            "subcategory": vc["subcategory"],
            "region_properties": vc.get("properties", {}),
        })

    # aliases_created: roof alias cells
    for ac in roof_alias_cells:
        tid = ac["tile_id"]
        report["aliases_created"].append({
            "atlas_tile_id": tid,
            "atlas_coords": {"col": tid % 64, "row": tid // 64},
            "alias_category": "roofs",
            "roof_color": ac["roof_color"],
            "alias_name": ac["alias_name"],
            "note": "primary category unchanged; cell duplicated into ss_roofs",
        })

    # excluded: non-empty tiles in exclusion regions
    for tid in sorted(excluded_cells):
        img = atlas_tile(atlas16, tid, atlas_16_cols, TILE16)
        if tile_is_empty(img):
            continue
        report["excluded"].append({
            "atlas_tile_id": tid,
            "atlas_coords": {"col": tid % 64, "row": tid // 64},
            "reason": "visual_regions.json exclusion: UI/editor/game-control icons",
        })

    # unclassified: remaining non-transparent tiles
    for t in sorted(unclassified_tiles, key=lambda t: t["id"]):
        report["unclassified"].append({
            "atlas_tile_id": t["id"],
            "atlas_coords": {"col": t["id"] % 64, "row": t["id"] // 64},
            "known_identity": t.get("known_identity"),
            "gm_animation": t.get("gm_animation"),
            "reason": ("identified as clouds via GameMaker auto-tile family; "
                       "no ss_clouds tileset exists in the target categories"
                       if t.get("known_identity") else
                       "no metadata identifies this atlas cell without vision"),
            "sources_consulted": [
                "Sunnyside_World_Gamemaker/tilesets/tileset_sunnysideworld/tileset_sunnysideworld.yy",
                "Sunnyside_World_Gamemaker/sprites/**/*.yy",
                "exact pixel template matching of named standalone sprites",
                "visual_regions.json",
            ],
        })

    # Log conflicts (GM vs visual)
    if conflicts:
        report["conflicts"] = conflicts

    # ------------------------------------------------------------------
    # 17. Excluded assets manifest
    # ------------------------------------------------------------------
    excluded_sets = {
        "UI (bars, cursors, labels, 9-slice, icons)": set(),
        "Human characters (body + hair + held tools)": set(),
        "Goblins": set(),
        "Skeletons": set(),
        "Character VFX (dust) + character shadows": set(),
        "Source files (.aseprite, example scene)": set(),
    }
    for name, m in meta.items():
        parent = m["parent"]
        if parent.startswith("folders/Sprites/UI"):
            excluded_sets["UI (bars, cursors, labels, 9-slice, icons)"].add(name)
        elif parent.startswith("folders/Sprites/Decoration/Characters"):
            if "Goblins" in parent:
                excluded_sets["Goblins"].add(name)
            elif "Skeletons" in parent:
                excluded_sets["Skeletons"].add(name)
            elif "Dust Vfx" in parent:
                excluded_sets["Character VFX (dust) + character shadows"].add(name)
            else:
                excluded_sets["Human characters (body + hair + held tools)"].add(name)
    for it in excluded_sets["Human characters (body + hair + held tools)"].copy():
        if it.endswith("shadow") or "shadow" in it:
            excluded_sets["Character VFX (dust) + character shadows"].add(it)
            excluded_sets["Human characters (body + hair + held tools)"].discard(it)
    excluded_sets["Source files (.aseprite, example scene)"].update(
        ["Sunnyside_World_ExampleScene.png",
         "Characters/_Source/sunnyside_world_chatacter_anim_GOBLIN.aseprite"])
    for reason, items in excluded_sets.items():
        for it in sorted(items):
            excluded["items"].append({"reason": reason, "asset": it})
    for f in sorted((assets_dir / "UI").rglob("*.png")):
        excluded["items"].append({
            "reason": "UI (bars, cursors, labels, 9-slice, icons)",
            "asset": os.path.relpath(f, ROOT),
        })

    # ------------------------------------------------------------------
    # 18. Write manifests + classification summary
    # ------------------------------------------------------------------
    classification.setdefault("categories", {}).setdefault("terrain", []).extend(
        [{"name": t["name"], "subcategory": t["subcategory"],
          "source": "spr_tileset_sunnysideworld_16px.png (auto-tile Land)",
          "original_tile_id": t["id"],
          "props": ({"terrain_type": "grass"} if t["id"] == GRASS_ATLAS_TILE else {})}
         for t in terrain_tiles])
    classification.setdefault("categories", {}).setdefault("water", []).extend(
        [{"name": t["name"], "subcategory": t["subcategory"],
          "source": ("spr_tileset_sunnysideworld_16px.png (auto-tile River)"
                     if t["id"] != WATER_ATLAS_TILE else
                     "standalone water sprite, exact atlas match"),
          "original_tile_id": t["id"]} for t in water_tiles])
    classification.setdefault("categories", {}).setdefault("paths_fences", []).extend(
        [{"name": t["name"], "subcategory": t["subcategory"],
          "source": "spr_tileset_sunnysideworld_16px.png (auto-tile Path)",
          "original_tile_id": t["id"]} for t in path_tiles])
    classification.setdefault("categories", {}).setdefault("buildings", []).extend(
        [{"name": it["name"], "subcategory": it["subcategory"],
          "source": it["source"], "original_tile_id": it.get("original_tile_id"),
          "props": {"building_part": it["building_part"]}} for it in building_items])
    classification.setdefault("categories", {}).setdefault("forest", []).extend(
        [{"name": t["name"], "subcategory": t["subcategory"],
          "source": "spr_tileset_sunnysideworld_forest_32px.png",
          "original_tile_id": t["id"]} for t in forest_tiles])
    classification["roofs"] = {
        "status": ("populated" if roof_items else "empty"),
        "source": "visual_regions.json aliases",
        "tile_count": len(roof_items),
        "roof_colors": sorted(set(ac["roof_color"] for ac in roof_alias_cells
                                  if ac["roof_color"])),
        "note": ("Roof tiles identified via visual_regions.json aliases. "
                 "Cells are duplicated from building regions into ss_roofs "
                 "with roof_color property. Primary category unchanged."),
    }
    classification["animation"] = {
        "fallback_ms": FALLBACK_MS,
        "fallback_used_for": sorted(set(anim_fallbacks_used)),
    }
    classification["atlas_derived"] = {
        "terrain": "generated/ss_terrain.png",
        "water": "generated/ss_water.png",
        "paths_fences": "generated/ss_paths_fences.png",
        "forest": "generated/ss_forest.png",
        "unclassified": "generated/ss_unclassified.png",
        "note": ("ss_buildings and ss_roofs use image-collection tilesets. "
                 "Building atlas tiles are exported 1:1 as 16x16 PNGs. "
                 "Roof tiles are aliased from building system regions via "
                 "visual_regions.json."),
    }
    classification["visual_manifest"] = {
        "source": "visual_regions.json",
        "classified_cells": len(visual_classified),
        "excluded_cells": len([t for t in excluded_cells
                               if not tile_is_empty(atlas_tile(atlas16, t, atlas_16_cols, TILE16))]),
        "aliases_created": len(roof_alias_cells),
        "conflicts_logged": len(conflicts),
    }

    (manifests / "classification.json").write_text(
        json.dumps(classification, indent=2, ensure_ascii=False), encoding="utf-8")
    (manifests / "classification_report.json").write_text(
        json.dumps(report, indent=2, ensure_ascii=False), encoding="utf-8")
    (manifests / "excluded_assets.json").write_text(
        json.dumps(excluded, indent=2, ensure_ascii=False), encoding="utf-8")
    stats["classified_by_gamemaker"] = len(report["classified_by_gamemaker"])
    stats["classified_by_visual"] = len(report["classified_by_visual_manifest"])
    stats["aliases_created"] = len(report["aliases_created"])
    stats["excluded"] = len(report["excluded"])
    stats["conflicts"] = len(conflicts)
    return stats


# ---------------------------------------------------------------------------
# Validation
# ---------------------------------------------------------------------------
def validate(args, stats) -> None:
    problems: list[str] = []
    out_dir = ROOT / args.output
    tsx_files = sorted(out_dir.glob("ss_*.tsx"))

    for tsx in tsx_files:
        try:
            tree = ET.parse(tsx)
        except ET.ParseError as e:
            problems.append(f"invalid XML {tsx}: {e}")
            continue
        root = tree.getroot()
        seen = set()
        for tile in root.findall("tile"):
            tid = int(tile.get("id"))
            if tid in seen:
                problems.append(f"{tsx.name}: duplicate tile id {tid}")
            seen.add(tid)
        for ref in root.iter("image"):
            src = ref.get("source")
            p = (out_dir / src).resolve()
            if not p.exists():
                problems.append(f"{tsx.name}: missing image {src}")
        for tile in root.findall("tile"):
            anim = tile.find("animation")
            if anim is None:
                continue
            for fr in anim.findall("frame"):
                if int(fr.get("tileid")) not in seen:
                    problems.append(f"{tsx.name}: animation frame tileid out of range")

    # crops completeness
    crop_dir = out_dir / "generated/props/crops"
    crop_names = ["beetroot", "cabbage", "carrot", "cauliflower", "kale", "parsnip",
                  "potato", "pumpkin", "radish", "sunflower", "wheat"]
    for crop in crop_names:
        for stage in range(6):
            if not (crop_dir / f"crop_{crop}_stage_{stage}.png").exists():
                problems.append(f"crops: missing {crop} stage {stage}")

    # stripN == N frames
    elements = ROOT / ASSETS_DIR / "Elements"
    for f in sorted(elements.rglob("*_strip*.png")):
        m = re.search(r"_strip(\d+)\.png$", f.name)
        if not m:
            continue
        n = int(m.group(1))
        try:
            im = Image.open(f)
        except Exception as e:
            problems.append(f"strip unreadable {f}: {e}")
            continue
        if im.width % n != 0:
            problems.append(f"strip {f.name}: width {im.width} not divisible by {n}")

    # per-tile image dimensions in image-collection tilesets must match file
    for tsx in tsx_files:
        tree = ET.parse(tsx)
        for tile in tree.getroot().findall("tile"):
            img = tile.find("image")
            if img is None:
                continue
            src = (out_dir / img.get("source")).resolve()
            if not src.exists():
                continue
            iw, ih = Image.open(src).size
            if int(img.get("width")) != iw or int(img.get("height")) != ih:
                problems.append(f"{tsx.name} tile {tile.get('id')}: declared "
                                f"{img.get('width')}x{img.get('height')} != "
                                f"actual {iw}x{ih}")

    if problems:
        print("VALIDATION PROBLEMS:")
        for p in problems:
            print("  -", p)
        raise SystemExit(1)
    print("Validation OK: XML valid, images exist, no duplicate ids, "
          "crops 0..5 complete, strip widths divisible by frame count, "
          "declared dimensions match files.")


def print_report(stats) -> None:
    order = ["Terrain", "Water", "Forest", "Paths/Fences", "Buildings", "Roofs",
             "Farm", "Crops", "Vegetation", "Animals", "Resources",
             "Outdoor decor", "Furniture", "VFX", "Unclassified"]
    print()
    print("Sunnyside World V2.1")
    print("--------------------")
    for key in order:
        print(f"{key}: {stats.get(key, 0)}")
    print()
    print("Classification breakdown:")
    print(f"  classified_by_gamemaker:   {stats.get('classified_by_gamemaker', 0)}")
    print(f"  classified_by_visual:      {stats.get('classified_by_visual', 0)}")
    print(f"  aliases_created:           {stats.get('aliases_created', 0)}")
    print(f"  excluded:                  {stats.get('excluded', 0)}")
    print(f"  unclassified:              {stats.get('Unclassified', 0)}")
    if stats.get("conflicts", 0):
        print(f"  conflicts_logged:          {stats['conflicts']}")
    un = stats.get("Unclassified", 0)
    if un > 0:
        print(f"\nUnclassified ({un}) tiles are listed individually in "
              "assets/tilesets/sunnyside/manifests/classification_report.json")


def parse_args() -> argparse.Namespace:
    p = argparse.ArgumentParser()
    p.add_argument("--output", type=Path, default=OUT_DIR)
    p.add_argument("--skip-validation", action="store_true")
    return p.parse_args()


if __name__ == "__main__":
    args = parse_args()
    stats = build(args)
    if not args.skip_validation:
        validate(args, stats)
    print_report(stats)

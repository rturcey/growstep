"""Validate production-ready modular sprites against Growstep's shared contract.

Run from the repository root: python3 scripts/validate_sprites.py.
Requires Pillow and PyYAML. Every YAML sheet in assets/sprite_sources is checked.
"""

import argparse
import json
import re
import sys
import xml.etree.ElementTree as ET
from pathlib import Path
from zipfile import BadZipFile, ZipFile

import yaml
from PIL import Image

from build_tiled_stone_tiles import STONE_COUNT, build_tile, tile_name
from build_surface_tiles import build as check_surface_tiles
from build_tiled_tilesets import build as check_tiled_tilesets


ROOT = Path(__file__).resolve().parents[1]
NAME = re.compile(r"^(commun|potager|fleurs|verger)_[a-z0-9]+_[a-z0-9_]+$")
VARIANTS = {"ordinaire", "brillante"}
SIZE_LIMITS = {
    "small_plant": (80, 100),
    "tree": (160, 150),
    "bed": (80, 70),
    "small_decor": (80, 80),
    "terrain_cell": (80, 68),
    "large_decor": (160, 100),
    "long_edge": (240, 75),
    "wide_cultivation_surround": (210, 90),
    "deep_cultivation_surround": (160, 145),
}
PALETTE_ROLES = {
    "fond_hors_jardin": "#E4EBD5",
    "herbe_eclairee": "#B5CE85",
    "herbe_principale": "#9DBF72",
    "herbe_ombree": "#79995B",
    "feuillage_sauge": "#829E70",
    "feuillage_profond": "#52764F",
    "terre_culture": "#6C503C",
    "terre_tranche": "#8A674A",
    "bois_chaud": "#B98A5A",
    "pierre_creme": "#D9D0B8",
    "rose": "#D98FA3",
    "jaune": "#E5C75F",
    "rouge_fruit": "#C96955",
    "bleu_doux": "#83A9B7",
    "violet": "#9C8BB5",
    "blanc_floral": "#F5EDDA",
}


def _metadata(sheet: Path) -> dict:
    data = yaml.safe_load(sheet.read_text(encoding="utf-8"))
    if not isinstance(data, dict):
        raise ValueError("metadata must be a YAML mapping")
    return data


def _image(path: Path, expected_size: tuple[int, int]) -> Image.Image:
    with Image.open(path) as source:
        if source.format != "PNG" or source.mode != "RGBA":
            raise ValueError("expected RGBA PNG")
        image = source.copy()
    if image.size != expected_size:
        raise ValueError(f"expected {expected_size[0]}×{expected_size[1]} pixels, got {image.size}")
    return image


def validate_sheet(sheet: Path, root: Path, manifest: dict) -> list[str]:
    errors = []

    def fail(message: str) -> None:
        errors.append(f"{sheet.name}: {message}")

    try:
        data = _metadata(sheet)
    except (OSError, yaml.YAMLError, ValueError) as error:
        return [f"{sheet.name}: {error}"]

    sprite_id = data.get("id")
    if not isinstance(sprite_id, str) or sheet.stem != sprite_id or not NAME.fullmatch(sprite_id):
        fail("id/name must match the YAML filename and use lowercase ASCII zone_family_object_state_variant_frame")
        return errors
    state = data.get("state")
    variant = data.get("variant")
    frames = data.get("frames")
    if not isinstance(variant, str) or variant not in VARIANTS or not isinstance(state, str) or not re.fullmatch(r"[a-z]+(?:_[a-z]+)*", state):
        fail("state and variant must be named in lowercase ASCII; variant is ordinaire or brillante")
    elif not sprite_id.endswith(f"_{state}_{variant}_00"):
        fail("id must end with the declared state, variant and frame 00")
    if frames != 1:
        fail("this fixed-sprite contract requires frames: 1; animated sheets need a shared-frame contract")

    canvas = data.get("canvas_1x")
    if not isinstance(canvas, list) or len(canvas) != 2 or any(type(n) is not int or n <= 0 for n in canvas):
        fail("canvas_1x must be two positive integer logical dimensions")
        return errors
    anchor = data.get("anchor_4x")
    if not isinstance(anchor, list) or len(anchor) != 2 or any(type(n) is not int for n in anchor):
        fail("anchor_4x must be two integer master-pixel coordinates")
        return errors
    if not (0 <= anchor[0] < canvas[0] * 4 and 0 <= anchor[1] < canvas[1] * 4):
        fail("anchor_4x lies outside the master canvas")

    footprint = data.get("footprint_grid")
    if not isinstance(footprint, list) or len(footprint) != 2 or any(
        not isinstance(n, (int, float)) or n <= 0 or n * 2 != int(n * 2)
        for n in footprint
    ):
        fail("footprint_grid must use positive whole or half 80×40 grid cells")
    if data.get("projection") != "isometric_80x40":
        fail("projection must be isometric_80x40")
    if data.get("light") != "upper_left":
        fail("light must be upper_left")
    if data.get("shadow") != "separate_contact":
        fail("shadow must be separate_contact")
    roles = data.get("palette_roles")
    if not isinstance(roles, list) or not roles or any(not isinstance(role, str) for role in roles):
        fail("palette_roles must list at least one palette role")
    else:
        unknown_roles = set(roles) - PALETTE_ROLES.keys()
        if unknown_roles:
            fail(f"unknown palette role: {', '.join(sorted(unknown_roles))}")
    size_class = data.get("size_class")
    if not isinstance(size_class, str) or size_class not in SIZE_LIMITS:
        fail(f"size_class must be one of {', '.join(SIZE_LIMITS)}")

    source_path = sheet.with_suffix(".ora")
    master_path = root / "assets" / "sprites" / f"{sprite_id}.png"
    try:
        master = _image(master_path, (canvas[0] * 4, canvas[1] * 4))
        alpha = master.getchannel("A")
        bbox = alpha.getbbox()
        if bbox is None or alpha.getextrema() == (255, 255):
            fail("master must contain visible pixels and transparent background")
        else:
            margin = min(bbox[0], bbox[1], master.width - bbox[2], master.height - bbox[3])
            if margin < 4:
                fail(f"transparent master margin is {margin}px; minimum is 4px")
            if not (bbox[0] <= anchor[0] <= bbox[2] and bbox[1] <= anchor[1] <= bbox[3] + 4):
                fail("anchor_4x must touch the sprite's visible ground-contact area")
            if isinstance(size_class, str) and size_class in SIZE_LIMITS:
                max_width, max_height = SIZE_LIMITS[size_class]
                if (bbox[2] - bbox[0]) / 4 > max_width or (bbox[3] - bbox[1]) / 4 > max_height:
                    fail(f"visible silhouette exceeds size_class {size_class}: {max_width}×{max_height} logical px")
            entry = manifest.get(f"{sprite_id}.png")
            if entry is None:
                fail("sprite is missing from the runtime manifest")
            else:
                expected_bounds = alpha.point(lambda value: 255 if value > 32 else 0).getbbox()
                if entry.get("width") != master.width or entry.get("height") != master.height:
                    fail("runtime manifest dimensions do not match the master")
                if expected_bounds is None:
                    fail("master has no visible alpha above the runtime threshold")
                elif entry.get("bbox") != list(expected_bounds):
                    fail("runtime manifest bounds do not match visible pixels")
                if entry.get("anchor") != anchor or entry.get("shadow") != data.get("shadow"):
                    fail("runtime manifest ground anchor or shadow do not match the YAML sheet")
    except (OSError, ValueError) as error:
        fail(f"master PNG: {error}")
        master = None

    try:
        with ZipFile(source_path) as archive:
            if archive.read("mimetype") != b"image/openraster":
                fail("source ORA has an invalid mimetype")
            stack = ET.fromstring(archive.read("stack.xml"))
            if (int(stack.attrib["w"]), int(stack.attrib["h"])) != (canvas[0] * 4, canvas[1] * 4):
                fail("source ORA dimensions differ from canvas_1x × 4")
            if not stack.findall(".//layer"):
                fail("source ORA has no editable layer")
            with archive.open("mergedimage.png") as merged:
                source = Image.open(merged).convert("RGBA")
                source.load()
            if master is not None and (source.size != master.size or source.tobytes() != master.tobytes()):
                fail("master PNG differs from the editable source ORA")
    except (OSError, BadZipFile, KeyError, ValueError, ET.ParseError) as error:
        fail(f"source ORA: {error}")

    if master is not None:
        for scale in (2, 3):
            path = root / "assets" / "sprite_exports" / f"{scale}.0x" / f"{sprite_id}.png"
            try:
                exported = _image(path, (canvas[0] * scale, canvas[1] * scale))
                expected = master.resize(exported.size, Image.Resampling.LANCZOS)
                if exported.tobytes() != expected.tobytes():
                    fail(f"{scale}x export differs from the master-derived export")
            except (OSError, ValueError) as error:
                fail(f"{scale}x export: {error}")
    return errors


def validate(root: Path) -> tuple[int, list[str]]:
    source_dir = root / "assets" / "sprite_sources"
    sheets = sorted(source_dir.glob("*.yaml"))
    if not sheets:
        return 0, ["no sprite metadata sheets found"]
    try:
        manifest = json.loads((root / "assets" / "sprites" / "manifest.json").read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as error:
        return len(sheets), [f"runtime manifest: {error}"]
    errors = []
    for sheet in sheets:
        errors.extend(validate_sheet(sheet, root, manifest))
    allowlist_path = source_dir / "legacy_allowlist.json"
    if allowlist_path.exists():
        try:
            allowlist = set(json.loads(allowlist_path.read_text(encoding="utf-8"))["legacy_pngs"])
        except (OSError, json.JSONDecodeError, KeyError, TypeError) as error:
            errors.append(f"legacy allowlist: {error}")
            allowlist = set()
    else:
        allowlist = set()
    named = {f"{sheet.stem}.png" for sheet in sheets}
    if (root / "assets" / "maps" / "growstep.tsx").exists():
        for index in range(STONE_COUNT):
            name = tile_name(index)
            named.add(name)
            try:
                actual = _image(root / "assets" / "sprites" / name, (80, 40))
                expected = build_tile(root, manifest, index)
                if actual.tobytes() != expected.tobytes():
                    errors.append(f"{name}: differs from its master-derived Tiled tile")
            except (OSError, ValueError, KeyError) as error:
                errors.append(f"{name}: {error}")
    inventory_path = root / "assets" / "surface_sources" / "inventory.json"
    if inventory_path.exists():
        try:
            inventory = json.loads(inventory_path.read_text(encoding="utf-8"))["families"]
            for family in inventory.values():
                for index in range(family["count"]):
                    named.add(f'{family["prefix"]}{index:02}.png')
            errors.extend(check_surface_tiles(root, check=True))
            errors.extend(check_tiled_tilesets(root, check=True))
        except (OSError, ValueError, KeyError, BadZipFile, ET.ParseError) as error:
            errors.append(f"Tiled asset contract: {error}")
    for image in sorted((root / "assets" / "sprites").glob("*.png")):
        if image.name not in named and image.name not in allowlist:
            errors.append(f"{image.name}: missing metadata sheet")
    return len(sheets), errors


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, default=ROOT, help="repository root for validation")
    args = parser.parse_args()
    count, problems = validate(args.root)
    if problems:
        for problem in problems:
            print(problem, file=sys.stderr)
        sys.exit(1)
    print(f"validated {count} sprite{'s' if count != 1 else ''}")

"""Normalize inherited plant PNGs into the 4x sprite contract.

The original raster files are archived outside the Flutter bundle. Their ORA
sources contain a single flattened layer because the original working layers
were never available. Re-running this script uses the archived originals.
"""

from __future__ import annotations

import io
import json
import shutil
from pathlib import Path
from zipfile import ZIP_STORED, ZipFile

import yaml
from PIL import Image

from export_sprite import export


ROOT = Path(__file__).resolve().parents[1]
SPRITES = ROOT / "assets" / "sprites"
SOURCES = ROOT / "assets" / "sprite_sources"
ORIGINALS = ROOT / "assets" / "sprite_archive" / "original_plants"

# Maximum displayed silhouette at the mature stage, in logical points.
BOXES = {
    "tomate": (72, 58),
    "carotte": (72, 40),
    "courgette": (72, 60),
    "tournesol": (72, 83),
    "tulipe": (67, 72),
    "lavande": (67, 73),
    "pommier": (137, 127),
    "poirier": (139, 131),
}
ACCENTS = {
    "tomate": "rouge_fruit",
    "carotte": "jaune",
    "courgette": "jaune",
    "tournesol": "jaune",
    "tulipe": "rose",
    "lavande": "violet",
    "pommier": "rouge_fruit",
    "poirier": "jaune",
}


def png_bytes(image: Image.Image) -> bytes:
    stream = io.BytesIO()
    image.save(stream, format="PNG")
    return stream.getvalue()


def make_ora(path: Path, image: Image.Image, sprite_id: str) -> None:
    stack = (
        f'<image w="{image.width}" h="{image.height}" name="{sprite_id}">'
        '<stack><layer name="PNG hérité aplati — provisoire" '
        'src="data/layer0.png" opacity="1.0" visibility="visible" '
        'composite-op="svg:src-over" x="0" y="0"/></stack></image>'
    )
    content = png_bytes(image)
    with ZipFile(path, "w") as archive:
        archive.writestr("mimetype", "image/openraster", compress_type=ZIP_STORED)
        archive.writestr("stack.xml", stack)
        archive.writestr("data/layer0.png", content)
        archive.writestr("mergedimage.png", content)


def migrate(name: str) -> None:
    sprite_id = name.removesuffix(".png")
    parts = sprite_id.split("_")
    species = parts[2]
    state = sprite_id.removeprefix("_".join(parts[:3]) + "_").removesuffix("_ordinaire_00")
    is_tree = parts[1] == "arbre"
    original = ORIGINALS / name
    if not original.exists():
        shutil.copy2(SPRITES / name, original)

    with Image.open(original) as source:
        image = source.convert("RGBA")
    alpha = image.getchannel("A")
    bounds = alpha.point(lambda value: 255 if value > 32 else 0).getbbox()
    if bounds is None:
        raise ValueError(f"{name}: no visible alpha")
    # Keep soft fringe pixels beside the visible silhouette.
    bounds = (
        max(0, bounds[0] - 3),
        max(0, bounds[1] - 3),
        min(image.width, bounds[2] + 3),
        min(image.height, bounds[3] + 3),
    )
    crop = image.crop(bounds)
    factor = (0.64 if is_tree else 0.63) if state == "jeune" else 1.0
    box_w, box_h = BOXES[species]
    max_w, max_h = box_w * factor, box_h * factor
    ratio = crop.width / crop.height
    width = max(1, round(min(max_w, max_h * ratio)))
    height = max(1, round(min(max_h, max_w / ratio)))
    scaled = crop.resize((width * 4, height * 4), Image.Resampling.LANCZOS)

    # Eight master pixels on every side exceed the four-pixel contract margin.
    canvas = Image.new("RGBA", ((width + 4) * 4, (height + 4) * 4))
    canvas.paste(scaled, (8, 8))
    visible = canvas.getchannel("A").getbbox()
    if visible is None:
        raise ValueError(f"{name}: empty normalized image")
    anchor = [(visible[0] + visible[2]) // 2, visible[3] - 2]
    sheet = {
        "id": sprite_id,
        "canvas_1x": [width + 4, height + 4],
        "anchor_4x": anchor,
        "footprint_grid": [2, 2] if is_tree else ([0.5, 0.5] if state == "jeune" else [1, 1]),
        "size_class": "tree" if is_tree else "small_plant",
        "projection": "isometric_80x40",
        "light": "upper_left",
        "shadow": "separate_contact",
        "palette_roles": ["feuillage_sauge", "feuillage_profond", ACCENTS[species]],
        "state": state,
        "variant": "ordinaire",
        "frames": 1,
    }
    (SOURCES / f"{sprite_id}.yaml").write_text(
        yaml.safe_dump(sheet, sort_keys=False, allow_unicode=True), encoding="utf-8"
    )
    make_ora(SOURCES / f"{sprite_id}.ora", canvas, sprite_id)
    export(sprite_id)


def main() -> None:
    ORIGINALS.mkdir(parents=True, exist_ok=True)
    allowlist = SOURCES / "legacy_allowlist.json"
    data = json.loads(allowlist.read_text(encoding="utf-8"))
    remaining = []
    migrated = 0
    for name in data["legacy_pngs"]:
        if "_plante_" in name or name.startswith(("verger_arbre_pommier_", "verger_arbre_poirier_")):
            migrate(name)
            migrated += 1
        else:
            remaining.append(name)
    allowlist.write_text(
        json.dumps({"legacy_pngs": remaining}, indent=2, ensure_ascii=False) + "\n",
        encoding="utf-8",
    )
    print(f"Normalized {migrated} inherited plant/tree sprites")


if __name__ == "__main__":
    main()

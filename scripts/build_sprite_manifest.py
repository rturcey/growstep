"""Rebuild the runtime alpha bounds for modular garden sprites.

Requires Pillow. Run from the repository root with
`python3 scripts/build_sprite_manifest.py` after adding a sprite.
"""

import json
from pathlib import Path

from PIL import Image
import yaml


SPRITES = Path(__file__).resolve().parents[1] / "assets" / "sprites"
manifest = {}

for sheet in sorted((SPRITES.parent / "sprite_sources").glob("*.yaml")):
    path = SPRITES / f"{sheet.stem}.png"
    with Image.open(path) as image:
        if image.mode != "RGBA":
            raise ValueError(f"{path.name}: expected transparent RGBA PNG")
        alpha = image.getchannel("A")
        bounds = alpha.point(lambda value: 255 if value > 32 else 0).getbbox()
        if bounds is None:
            raise ValueError(f"{path.name}: no visible pixels")
        manifest[path.name] = {
            "width": image.width,
            "height": image.height,
            "bbox": list(bounds),
        }
        sheet = SPRITES.parent / "sprite_sources" / f"{path.stem}.yaml"
        if sheet.exists():
            metadata = yaml.safe_load(sheet.read_text(encoding="utf-8"))
            manifest[path.name]["anchor"] = metadata["anchor_4x"]
            manifest[path.name]["shadow"] = metadata["shadow"]

(SPRITES / "manifest.json").write_text(
    json.dumps(manifest, indent=2, ensure_ascii=False) + "\n"
)
print(f"Indexed {len(manifest)} sprites")

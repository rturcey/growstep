"""Rebuild the runtime alpha bounds for modular garden sprites.

Requires Pillow. Run from the repository root with
`python3 scripts/build_sprite_manifest.py` after adding a sprite.
"""

import json
from pathlib import Path

from PIL import Image
import yaml


SPRITES = Path(__file__).resolve().parents[1] / "assets" / "sprites"

PRESERVE_MANIFEST_PREFIXES = (
    "commun_sol_pas_pierre_statique_ordinaire_",
)

manifest_path = SPRITES / "manifest.json"
previous_manifest = (
    json.loads(manifest_path.read_text(encoding="utf-8"))
    if manifest_path.exists()
    else {}
)

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
        if (
            path.name in previous_manifest
            and path.name.startswith(PRESERVE_MANIFEST_PREFIXES)
        ):
            # These six historical stepping-stone entries are an approved
            # runtime geometry contract. Their alpha-derived bbox is
            # intentionally not regenerated.
            manifest[path.name] = dict(previous_manifest[path.name])
        else:
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

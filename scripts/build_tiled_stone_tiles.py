"""Build 80×40 Tiled tiles from the existing stepping-stone masters.

The manifest anchor lands at the center of the isometric tile. The smaller
scale leaves every visible source pixel inside the transparent tile canvas.
"""

import json
from pathlib import Path

from PIL import Image


ROOT = Path(__file__).resolve().parents[1]
STONE_COUNT = 6
TILE_SCALE = 0.18


def tile_name(index: int) -> str:
    return f"commun_sol_pas_pierre_tile_{index:02}.png"


def build_tile(root: Path, manifest: dict, index: int) -> Image.Image:
    source_name = f"commun_sol_pas_pierre_statique_ordinaire_{index:02}.png"
    with Image.open(root / "assets" / "sprites" / source_name) as source:
        master = source.convert("RGBA")
    anchor_x, anchor_y = manifest[source_name]["anchor"]
    scaled = master.resize(
        (round(master.width * TILE_SCALE), round(master.height * TILE_SCALE)),
        Image.Resampling.LANCZOS,
    )
    x = 40 - round(anchor_x * TILE_SCALE)
    y = 20 - round(anchor_y * TILE_SCALE)
    bounds = scaled.getbbox()
    if bounds is None or not (
        0 < x + bounds[0]
        and 0 < y + bounds[1]
        and x + bounds[2] < 80
        and y + bounds[3] < 40
    ):
        raise ValueError(f"{source_name}: visible stone does not fit inside its tile")
    tile = Image.new("RGBA", (80, 40))
    tile.alpha_composite(scaled, (x, y))
    return tile


def main() -> None:
    manifest = json.loads((ROOT / "assets" / "sprites" / "manifest.json").read_text())
    for index in range(STONE_COUNT):
        build_tile(ROOT, manifest, index).save(
            ROOT / "assets" / "sprites" / tile_name(index), optimize=True
        )


if __name__ == "__main__":
    main()

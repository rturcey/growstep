"""Export a layered OpenRaster sprite as 4x master and 3x/2x game variants.

Run from the repository root: python3 scripts/export_sprite.py SPRITE_ID.
Requires Pillow. The source ORA stays authoritative; exports are disposable.
"""

import argparse
from pathlib import Path
from zipfile import ZipFile

from PIL import Image


ROOT = Path(__file__).resolve().parents[1]


def export(sprite_id: str, root: Path = ROOT) -> None:
    source = root / "assets" / "sprite_sources" / f"{sprite_id}.ora"
    with ZipFile(source) as archive:
        with archive.open("mergedimage.png") as merged:
            image = Image.open(merged)
            image.load()
    if image.mode != "RGBA":
        raise ValueError(f"{sprite_id}: OpenRaster merged image must be RGBA")
    for scale, directory in (
        (4, root / "assets" / "sprites"),
        (3, root / "assets" / "sprite_exports" / "3.0x"),
        (2, root / "assets" / "sprite_exports" / "2.0x"),
    ):
        directory.mkdir(parents=True, exist_ok=True)
        size = (image.width * scale // 4, image.height * scale // 4)
        exported = image if scale == 4 else image.resize(size, Image.Resampling.LANCZOS)
        exported.save(directory / f"{sprite_id}.png")
    print(f"Exported {sprite_id} at 4x, 3x and 2x")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("sprite_id")
    args = parser.parse_args()
    export(args.sprite_id)

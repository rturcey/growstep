"""Export the 1x surface tiles deterministically from editable 4x family ORAs."""

import argparse
import io
import json
import xml.etree.ElementTree as ET
from pathlib import Path
from zipfile import ZipFile

from PIL import Image, ImageChops, ImageDraw


ROOT = Path(__file__).resolve().parents[1]


def _seal_diamond(tile: Image.Image, family: str) -> Image.Image:
    """Make adjacent Tiled cells opaque at their shared raster seam."""
    mask = Image.new("L", (80, 40))
    ImageDraw.Draw(mask).polygon([(40, -2), (82, 20), (40, 42), (-2, 20)], fill=255)
    alpha = ImageChops.lighter(tile.getchannel("A"), mask)
    tile.putalpha(alpha)
    base = (138, 103, 74) if family == "ground_skirt" else (108, 80, 60) if family == "ground_earth" else (157, 191, 114)
    pixels = tile.load()
    for y in range(40):
        for x in range(80):
            distance = abs((x - 40) / 40) + abs((y - 20) / 20)
            if 0.94 <= distance <= 1.0 and alpha.getpixel((x, y)) == 255:
                pixels[x, y] = (*base, 255)
    return tile


def expected_tiles(root: Path):
    sources = root / "assets" / "surface_sources"
    families = json.loads((sources / "inventory.json").read_text())["families"]
    for family, info in families.items():
        if info.get("derived_from"):
            continue
        with ZipFile(sources / f"{family}_master.ora") as archive:
            stack = ET.fromstring(archive.read("stack.xml"))
            if (int(stack.attrib["w"]), int(stack.attrib["h"])) != (320, 160):
                raise ValueError(f"{family}: expected 320x160 master")
            named = {layer.attrib["name"]: layer.attrib["src"] for layer in stack.findall(".//layer")}
            for index in range(info["count"]):
                name = f'{info["prefix"]}{index:02}.png'
                if name not in named:
                    raise ValueError(f"{family}: missing layer {name}")
                with Image.open(io.BytesIO(archive.read(named[name]))) as source:
                    if source.size != (320, 160) or source.mode != "RGBA":
                        raise ValueError(f"{family}/{name}: expected 320x160 RGBA layer")
                    tile = _seal_diamond(source.resize((80, 40), Image.Resampling.LANCZOS), family)
                yield name, tile


def build(root: Path, check: bool = False) -> list[str]:
    problems = []
    destination = root / "assets" / "sprites"
    for name, tile in expected_tiles(root):
        path = destination / name
        if check:
            try:
                with Image.open(path) as actual:
                    if actual.size != (80, 40) or actual.mode != "RGBA" or actual.tobytes() != tile.tobytes():
                        problems.append(f"{name}: stale surface tile export")
            except OSError as error:
                problems.append(f"{name}: {error}")
        else:
            tile.save(path, optimize=True)
    return problems


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, default=ROOT)
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()
    errors = build(args.root, args.check)
    if errors:
        parser.exit(1, "\n".join(errors) + "\n")
    print("surface tile exports are current" if args.check else "surface tiles exported")

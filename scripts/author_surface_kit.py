"""Seed editable family ORAs from the approved painted material references.

This is an authoring aid, not the export pipeline. Running it replaces the
family ORAs, so make manual paint edits in those ORAs after the initial seed.
"""

import io
import json
import random
import xml.etree.ElementTree as ET
from pathlib import Path
from zipfile import ZIP_DEFLATED, ZIP_STORED, ZipFile

from PIL import Image, ImageChops, ImageDraw


ROOT = Path(__file__).resolve().parents[1]
SOURCES = ROOT / "assets" / "surface_sources"
SIZE = (320, 160)


def _png_bytes(image: Image.Image) -> bytes:
    output = io.BytesIO()
    image.save(output, format="PNG", optimize=True)
    return output.getvalue()


def _material(reference: Image.Image, index: int, color: str, strength: float) -> Image.Image:
    # Stable, separated patches keep variants distinct; normalization keeps
    # their average value close enough to avoid an obvious checkerboard.
    offsets = [(44, 46), (388, 112), (722, 286), (166, 542), (782, 688)]
    x, y = offsets[index % len(offsets)]
    patch = reference.crop((x, y, x + SIZE[0], y + SIZE[1])).convert("RGB")
    pixels = patch.load()
    means = tuple(sum(pixel[channel] for pixel in patch.getdata()) / (SIZE[0] * SIZE[1]) for channel in range(3))
    target = tuple(bytes.fromhex(color[1:]))
    adjusted = Image.new("RGB", SIZE)
    output = adjusted.load()
    for row in range(SIZE[1]):
        for col in range(SIZE[0]):
            diamond_distance = abs((col - 160) / 160) + abs((row - 80) / 80)
            # Every tile reaches the same base colour at its four seams.
            # The painted detail remains in the interior, where it cannot
            # reveal the grid as repeated bright/dark edges.
            edge_fade = max(0.0, min(1.0, (1.0 - diamond_distance) / 0.23))
            output[col, row] = tuple(max(0, min(255, round(target[channel] + (pixels[col, row][channel] - means[channel]) * strength * edge_fade))) for channel in range(3))
    return adjusted.convert("RGBA")


def _diamond_mask() -> Image.Image:
    mask = Image.new("L", SIZE)
    draw = ImageDraw.Draw(mask)
    # A tiny overlap survives downsampling and hides transparent hairlines
    # between adjacent diamonds in Tiled.
    draw.polygon([(160, -16), (336, 80), (160, 176), (-16, 80)], fill=255)
    return mask


def _grass_edge(image: Image.Image, index: int, mask: Image.Image) -> Image.Image:
    rng = random.Random(6400 + index)
    draw = ImageDraw.Draw(image)
    directions = {
        0: [0], 1: [1], 2: [2], 3: [3],
        4: [0, 1], 5: [1, 2], 6: [2, 3], 7: [3, 0],
        8: [0], 9: [1], 10: [2], 11: [3],
    }[index]
    corners = [(160, 0), (320, 80), (160, 160), (0, 80)]
    for side in directions:
        start, end = corners[side], corners[(side + 1) % 4]
        for n in range(23 if index < 8 else 12):
            t = (n + rng.uniform(-0.3, 0.3)) / 23
            x = start[0] * (1 - t) + end[0] * t
            y = start[1] * (1 - t) + end[1] * t
            # Outward normal of the diamond edge; protrusions remain within
            # the 80x40 image canvas and never change logical occupancy.
            dx = end[1] - start[1]
            dy = -(end[0] - start[0])
            length = (dx * dx + dy * dy) ** 0.5
            blade = rng.uniform(6, 17) if index < 8 else rng.uniform(3, 9)
            tip = (x + dx / length * blade + rng.uniform(-2, 2), y + dy / length * blade + rng.uniform(-2, 2))
            color = rng.choice(["#719455", "#85A965", "#A7C77D", "#91AD68"])
            draw.line((x, y, *tip), fill=color, width=rng.choice((3, 4, 5)))
    image.putalpha(ImageChops.lighter(mask, image.getchannel("A")))
    return image


def _skirt(reference: Image.Image, index: int) -> Image.Image:
    image = _material(reference, index, "#8A674A", 0.35)
    mask = _diamond_mask()
    rng = random.Random(6700 + index)
    # The full diamond closes gaps between neighbouring skirt cells. It is
    # only painted in empty front neighbours, beneath the grassy surface.
    image.putalpha(mask)
    shading = Image.new("RGBA", SIZE)
    gradient = shading.load()
    for y in range(80, 160):
        alpha = round((y - 80) / 80 * 28)
        for x in range(320):
            gradient[x, y] = (52, 34, 24, alpha)
    image.alpha_composite(shading)
    shade = Image.new("RGBA", SIZE, (58, 39, 29, 0))
    shade_draw = ImageDraw.Draw(shade)
    for n in range(45):
        x = rng.randrange(0, 320)
        y = rng.randrange(100, 160)
        shade_draw.line((x, y, x + rng.randrange(-5, 6), y + rng.randrange(3, 11)), fill=(58, 39, 29, rng.randrange(20, 65)), width=rng.randrange(1, 4))
    image.alpha_composite(shade)
    image.putalpha(mask)
    return image


def _write_ora(path: Path, layers: list[tuple[str, Image.Image]]) -> None:
    stack = ET.Element("image", {"w": "320", "h": "160", "name": path.stem, "version": "0.0.1"})
    layer_stack = ET.SubElement(stack, "stack")
    with ZipFile(path, "w") as archive:
        archive.writestr("mimetype", "image/openraster", compress_type=ZIP_STORED)
        for index, (name, image) in enumerate(layers):
            source = f"data/layer{index:02}.png"
            ET.SubElement(layer_stack, "layer", {"name": name, "src": source, "x": "0", "y": "0", "opacity": "1.0", "visibility": "visible" if index == 0 else "hidden", "composite-op": "svg:src-over"})
            archive.writestr(source, _png_bytes(image), compress_type=ZIP_DEFLATED)
        archive.writestr("stack.xml", ET.tostring(stack, encoding="utf-8", xml_declaration=True))
        archive.writestr("mergedimage.png", _png_bytes(layers[0][1]))


def main() -> None:
    inventory = json.loads((SOURCES / "inventory.json").read_text())["families"]
    with Image.open(SOURCES / "grass_reference.png") as grass_source, Image.open(SOURCES / "earth_reference.png") as earth_source:
        grass, earth = grass_source.convert("RGBA"), earth_source.convert("RGBA")
        diamond = _diamond_mask()
        for family, info in inventory.items():
            if family == "paths":
                continue
            layers = []
            for index in range(info["count"]):
                name = f'{info["prefix"]}{index:02}.png'
                if family == "ground_skirt":
                    image = _skirt(earth, index)
                else:
                    reference, color, strength = (earth, "#6C503C", 0.28) if family == "ground_earth" else (grass, "#9DBF72", 0.28)
                    image = _material(reference, index, color, strength)
                    image.putalpha(diamond)
                    if family == "ground_edges":
                        image = _grass_edge(image, index, diamond)
                layers.append((name, image))
            _write_ora(SOURCES / f"{family}_master.ora", layers)
            print(f"authored {family}: {len(layers)} layers")


if __name__ == "__main__":
    main()

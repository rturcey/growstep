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

from PIL import Image, ImageDraw


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
            # Normalize every crop to the same mean and keep variation very
            # low. A special flat edge band would trace the isometric grid.
            output[col, row] = tuple(max(0, min(255, round(target[channel] + (pixels[col, row][channel] - means[channel]) * strength))) for channel in range(3))
    return adjusted.convert("RGBA")


def _exposure_mask(directions: list[int]) -> Image.Image:
    mask = Image.new("L", SIZE, 255)
    clear = ImageDraw.Draw(mask)
    outside = [
        [(160, -16), (336, -16), (336, 80)],
        [(336, 80), (336, 176), (160, 176)],
        [(160, 176), (-16, 176), (-16, 80)],
        [(-16, 80), (-16, -16), (160, -16)],
    ]
    for side in directions:
        clear.polygon(outside[side], fill=0)
    return mask


def _grass_edge(image: Image.Image, index: int) -> Image.Image:
    rng = random.Random(6400 + index)
    directions = {
        0: [0], 1: [1], 2: [2], 3: [3],
        4: [0, 1], 5: [1, 2], 6: [2, 3], 7: [3, 0],
        8: [0], 9: [1], 10: [2], 11: [3],
    }[index]
    # Fill through the sides that touch occupied cells. Only the exposed
    # outside triangles are transparent, so adjacent ground tiles have no
    # alpha seam. Blades painted next cross those exposed boundaries.
    image.putalpha(_exposure_mask(directions))
    draw = ImageDraw.Draw(image)
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
    return image


def _earth_edge(image: Image.Image, index: int) -> Image.Image:
    rng = random.Random(6800 + index)
    directions = {
        3: [0], 4: [1], 5: [2], 6: [3],
        7: [0, 1], 8: [1, 2], 9: [2, 3], 10: [3, 0],
    }[index]
    image.putalpha(_exposure_mask(directions))
    draw = ImageDraw.Draw(image)
    corners = [(160, 0), (320, 80), (160, 160), (0, 80)]
    for side in directions:
        start, end = corners[side], corners[(side + 1) % 4]
        for _ in range(14):
            t = rng.uniform(0.08, 0.92)
            x = start[0] * (1 - t) + end[0] * t
            y = start[1] * (1 - t) + end[1] * t
            # Short, muted overhangs break the geometric edge without
            # creating isolated green dots at the soil boundary.
            reach = rng.uniform(3, 8)
            draw.line((x, y, x + (end[1] - start[1]) / 360 * reach,
                       y - (end[0] - start[0]) / 360 * reach),
                      fill=rng.choice(("#6F533D", "#795B42", "#866449")), width=rng.choice((2, 3)))
    return image


def _skirt(reference: Image.Image, index: int) -> Image.Image:
    # Keep the long exterior face at a stable value across cell boundaries;
    # the sparse brush marks provide variation without regular color joins.
    image = _material(reference, 0, "#76543B", 0.03)
    mask = Image.new("L", SIZE)
    rng = random.Random(6700 + index)
    draw = ImageDraw.Draw(mask)
    # An exposed front-right edge occupies the back-left half of the empty
    # neighbouring cell; front-left uses the mirrored half. The two slanted
    # top edges coincide with the occupied grass cell's exposed edges, while
    # their lower edges sit 20 logical pixels below to form a vertical face.
    left_face = [(160, -8), (-8, 80), (-8, 168), (160, 80)]
    right_face = [(160, -8), (328, 80), (328, 168), (160, 80)]
    if index // 2 in (0, 2):
        draw.polygon(left_face, fill=255)
    if index // 2 in (1, 2):
        draw.polygon(right_face, fill=255)
    shade = Image.new("RGBA", SIZE)
    shade_draw = ImageDraw.Draw(shade)
    for _ in range(50):
        x = rng.randrange(0, 320)
        y = rng.randrange(70, 160)
        shade_draw.line((x, y, x + rng.randrange(-2, 3), y + rng.randrange(5, 18)), fill=(58, 39, 29, rng.randrange(10, 45)), width=rng.randrange(1, 3))
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
        for family, info in inventory.items():
            if family == "paths":
                continue
            layers = []
            for index in range(info["count"]):
                name = f'{info["prefix"]}{index:02}.png'
                if family == "ground_skirt":
                    image = _skirt(earth, index)
                else:
                    reference, color, strength = (earth, "#6C503C", 0.16) if family == "ground_earth" else (grass, "#9DBF72", 0.12)
                    image = _material(reference, index, color, strength)
                    if family == "ground_edges":
                        image = _grass_edge(image, index)
                    if family == "ground_earth" and index >= 3:
                        image = _earth_edge(image, index)
                layers.append((name, image))
            _write_ora(SOURCES / f"{family}_master.ora", layers)
            print(f"authored {family}: {len(layers)} layers")


if __name__ == "__main__":
    main()

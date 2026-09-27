#!/usr/bin/env python3

from __future__ import annotations

import json
from collections import deque
from pathlib import Path

from PIL import Image


ROOT = Path(__file__).resolve().parents[1]

SOURCE = ROOT / "assets/reference/new_da_atlas.png"
OUTPUT = ROOT / "assets/sprites/new_da"
INDEX = OUTPUT / "index.json"

# Ignore almost-transparent antialiasing noise.
ALPHA_THRESHOLD = 10

# Reject microscopic isolated pixels.
MIN_COMPONENT_PIXELS = 100

# Transparent padding around each exported sprite.
PADDING = 8


def connected_components(alpha: Image.Image):
    width, height = alpha.size
    px = alpha.load()

    visited = bytearray(width * height)

    def idx(x: int, y: int) -> int:
        return y * width + x

    components = []

    for y0 in range(height):
        for x0 in range(width):
            key = idx(x0, y0)

            if visited[key]:
                continue

            visited[key] = 1

            if px[x0, y0] <= ALPHA_THRESHOLD:
                continue

            queue = deque([(x0, y0)])

            min_x = max_x = x0
            min_y = max_y = y0
            count = 0

            while queue:
                x, y = queue.popleft()
                count += 1

                min_x = min(min_x, x)
                max_x = max(max_x, x)
                min_y = min(min_y, y)
                max_y = max(max_y, y)

                for nx, ny in (
                    (x - 1, y),
                    (x + 1, y),
                    (x, y - 1),
                    (x, y + 1),
                ):
                    if nx < 0 or ny < 0 or nx >= width or ny >= height:
                        continue

                    nkey = idx(nx, ny)

                    if visited[nkey]:
                        continue

                    visited[nkey] = 1

                    if px[nx, ny] > ALPHA_THRESHOLD:
                        queue.append((nx, ny))

            if count < MIN_COMPONENT_PIXELS:
                continue

            components.append(
                {
                    "pixels": count,
                    "bbox": [
                        min_x,
                        min_y,
                        max_x + 1,
                        max_y + 1,
                    ],
                }
            )

    # Human-friendly ordering: top to bottom, then left to right.
    components.sort(
        key=lambda c: (
            c["bbox"][1] // 100,
            c["bbox"][0],
            c["bbox"][1],
        )
    )

    return components


def padded_crop(
    source: Image.Image,
    bbox: list[int],
) -> Image.Image:
    left, top, right, bottom = bbox

    crop = source.crop((left, top, right, bottom))

    result = Image.new(
        "RGBA",
        (
            crop.width + PADDING * 2,
            crop.height + PADDING * 2,
        ),
        (0, 0, 0, 0),
    )

    result.alpha_composite(
        crop,
        (PADDING, PADDING),
    )

    return result


def main():
    if not SOURCE.exists():
        raise SystemExit(
            f"Atlas introuvable:\n{SOURCE}\n\n"
            "Place l'image générée à cet emplacement."
        )

    OUTPUT.mkdir(parents=True, exist_ok=True)

    source = Image.open(SOURCE).convert("RGBA")
    alpha = source.getchannel("A")

    components = connected_components(alpha)

    print(f"Atlas: {source.width}x{source.height}")
    print(f"Composants détectés: {len(components)}")

    if len(components) != 35:
        print(
            "⚠️ Je m'attends à 35 éléments sur l'atlas actuel. "
            "Le script continue, mais vérifie le résultat."
        )

    index = []

    # Remove only our previous generic exports.
    for old in OUTPUT.glob("atlas_sprite_*.png"):
        old.unlink()

    for number, component in enumerate(components):
        bbox = component["bbox"]

        sprite = padded_crop(
            source,
            bbox,
        )

        filename = f"atlas_sprite_{number:02}.png"
        path = OUTPUT / filename

        sprite.save(
            path,
            "PNG",
            optimize=True,
        )

        entry = {
            "index": number,
            "file": filename,
            "source_bbox": bbox,
            "width": sprite.width,
            "height": sprite.height,
            "opaque_pixels": component["pixels"],
        }

        index.append(entry)

        print(
            f"✓ {number:02}: "
            f"{sprite.width:>3}x{sprite.height:<3} "
            f"source={bbox}"
        )

    INDEX.write_text(
        json.dumps(
            {
                "source": str(SOURCE.relative_to(ROOT)),
                "count": len(index),
                "sprites": index,
            },
            indent=2,
            ensure_ascii=False,
        )
        + "\n",
        encoding="utf-8",
    )

    print()
    print(f"✅ {len(index)} sprites exportés dans:")
    print(OUTPUT)
    print()
    print("Aucun fichier Growstep existant n'a été modifié.")


if __name__ == "__main__":
    main()

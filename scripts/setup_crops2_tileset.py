#!/usr/bin/env python3
"""Slice crops2.png (8 crops x growth stages) into a Tiled collection-of-images tileset.

crops2.png is an irregular sheet: each of the 8 rows holds one crop's growth
stages — a few seedling variants (~28-35px), a young plant (~80-150px), an
almost-mature sprite (~157-190px) and a mature sprite (~168-197px).

Outputs:
  assets/sprites/fantasy_farm_free/crops2/*.png   (tight-cropped stage sprites)
  assets/maps/fantasy_farm/crops2.tsx             (collection-of-images tileset)
"""

from __future__ import annotations

import shutil
import xml.etree.ElementTree as ET
from collections import deque
from pathlib import Path

try:
    from PIL import Image
except ImportError as e:
    raise SystemExit("Pillow est requis") from e

ROOT = Path(__file__).resolve().parents[1]
SRC = ROOT / "crops2.png"
SPR = ROOT / "assets/sprites/fantasy_farm_free"
SPR_SUB = SPR / "crops2"
TSX = ROOT / "assets/maps/fantasy_farm/crops2.tsx"
PAD = 4
TARGET_MAX = 32  # largest dimension of the mature stage, in source pixels (1 tile)


def components(im):
    w, h = im.size
    px = im.load()
    mask = [[px[x, y][3] > 40 for x in range(w)] for y in range(h)]
    seen = [[False] * w for _ in range(h)]
    comps = []
    for y in range(h):
        for x in range(w):
            if mask[y][x] and not seen[y][x]:
                q = deque([(x, y)])
                seen[y][x] = True
                xs, ys = [], []
                while q:
                    cx, cy = q.popleft()
                    xs.append(cx)
                    ys.append(cy)
                    for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                        nx, ny = cx + dx, cy + dy
                        if 0 <= nx < w and 0 <= ny < h and mask[ny][nx] and not seen[ny][nx]:
                            seen[ny][nx] = True
                            q.append((nx, ny))
                comps.append((min(xs), min(ys), max(xs), max(ys)))
    return comps


def group_rows(comps):
    rows = []
    for b in comps:
        y0 = b[1]
        for r in rows:
            if abs(r["y"] - y0) < 160:
                r["comps"].append(b)
                break
        else:
            rows.append({"y": y0, "comps": [b]})
    for r in rows:
        r["comps"].sort(key=lambda b: (b[0], b[1]))
    rows.sort(key=lambda r: r["y"])
    return rows


def classify(bbox):
    x0, _y0, _x1, _y1 = bbox
    if x0 < 200:
        return 0
    if x0 < 400:
        return 1
    if x0 < 600:
        return 2
    return 3


def main():
    if not SRC.exists():
        raise SystemExit(f"Missing {SRC}")

    with Image.open(SRC) as raw:
        im = raw.convert("RGBA")
        comps = components(im)
        rows = group_rows(comps)

    if SPR_SUB.exists():
        shutil.rmtree(SPR_SUB)
    SPR_SUB.mkdir(parents=True)

    # Uniform downscale so the largest sprite (mature stage) fits one 32px tile.
    largest = max(max(x1 - x0 + 1, y1 - y0 + 1) for x0, y0, x1, y1 in comps)
    scale = TARGET_MAX / largest

    tiles = []  # (id, filename)
    tid = 0
    for row_idx, row in enumerate(rows):
        for comp in row["comps"]:
            stage = classify(comp)
            x0, y0, x1, y1 = comp
            name = f"crops2_r{row_idx}_s{stage}.png"
            out = SPR_SUB / name
            x0 = max(0, x0 - PAD)
            y0 = max(0, y0 - PAD)
            x1 = min(im.width, x1 + 1 + PAD)
            y1 = min(im.height, y1 + 1 + PAD)
            crop = im.crop((x0, y0, x1, y1))
            crop = crop.resize(
                (max(1, round(crop.width * scale)), max(1, round(crop.height * scale))),
                Image.Resampling.LANCZOS,
            )
            crop.save(out)
            tiles.append((tid, name, crop.width, crop.height))
            tid += 1

    root = ET.Element(
        "tileset",
        {
            "version": "1.10",
            "tiledversion": "1.11.2",
            "name": "crops2",
            "tilewidth": "32",
            "tileheight": "32",
            "tilecount": str(len(tiles)),
            "columns": "0",
            "objectalignment": "bottom",
        },
    )
    for tid, name, w, h in tiles:
        tile = ET.SubElement(root, "tile", {"id": str(tid)})
        ET.SubElement(
            tile,
            "image",
            {
                "source": f"../../sprites/fantasy_farm_free/crops2/{name}",
                "width": str(w),
                "height": str(h),
            },
        )
    ET.indent(root, space="  ")
    ET.ElementTree(root).write(TSX, encoding="utf-8", xml_declaration=True)

    print(f"Rows   : {len(rows)}")
    print(f"Tiles  : {len(tiles)}")
    print(f"Scale  : {scale:.3f} (largest {largest}px -> {TARGET_MAX}px)")
    for row_idx, row in enumerate(rows):
        stages = sorted({classify(b) for b in row["comps"]})
        print(f"  row {row_idx}: {len(row['comps'])} sprites, stages {stages}")
    print(f"TSX   : {TSX.relative_to(ROOT)}")
    print(f"PNG   : {SPR_SUB.relative_to(ROOT)}/")


if __name__ == "__main__":
    main()

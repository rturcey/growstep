#!/usr/bin/env python3
"""Slice trees4.png (6 tree varieties x 4 growth stages) into ONE grid tileset.

trees4.png is a regular 6x4 grid (varieties = rows, stages = columns), detected
by opaque-pixel bands.

Kept at NATIVE resolution: downscaling the ink-outlined drawings smears a thick
black fringe around each silhouette ("détourage noir"). No resize is done.

Each tree becomes a block of 32x32 tiles (a tree is NOT one tile), exactly like
the pack's own trees__tree1/2/3 tilesets: the tree spans several tiles and every
tile can be stamped / moved independently in Tiled. All trees are laid out in a
regular grid in one sheet (one tileset): one row per variety, one column per
stage, every cell the same size, bottom-aligned. Tree at (row r, col c) =
variety r, stage c.

Outputs:
  assets/sprites/fantasy_farm_free/trees4_grid/trees4_grid.png   (one sheet)
  assets/maps/fantasy_farm/trees4.tsx                            (one grid tileset)
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
SRC = ROOT / "trees4.png"
SPR_SUB = ROOT / "assets/sprites/fantasy_farm_free/trees4_grid"
TSX = ROOT / "assets/maps/fantasy_farm/trees4.tsx"
PAD = 4
TILE = 32
MIN_SIZE = 10     # drop stray anti-aliasing/noise specks


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


def row_bands(im):
    """Detect horizontal bands of tree rows via opaque-pixel projection."""
    w, h = im.size
    px = im.load()
    counts = [sum(1 for x in range(w) if px[x, y][3] > 40) for y in range(h)]
    bands = []
    start = None
    for y, c in enumerate(counts):
        if c > 50 and start is None:
            start = y
        elif c <= 50 and start is not None:
            bands.append((start, y))
            start = None
    if start is not None:
        bands.append((start, h))
    return bands


def to_block(im, comp):
    """Crop a tree at native res, pad to whole 32px tiles, bottom-anchored."""
    x0, y0, x1, y1 = comp
    x0 = max(0, x0 - PAD)
    y0 = max(0, y0 - PAD)
    x1 = min(im.width, x1 + 1 + PAD)
    y1 = min(im.height, y1 + 1 + PAD)
    sprite = im.crop((x0, y0, x1, y1))
    cols = (sprite.width + TILE - 1) // TILE
    rows_t = (sprite.height + TILE - 1) // TILE
    canvas = Image.new("RGBA", (cols * TILE, rows_t * TILE), (0, 0, 0, 0))
    ox = (canvas.width - sprite.width) // 2
    oy = canvas.height - sprite.height  # bottom-anchored
    canvas.alpha_composite(sprite, (ox, oy))
    return canvas, cols, rows_t


def write_tsx(path, name, cols, rows, image_rel, w, h):
    count = cols * rows
    root = ET.Element(
        "tileset",
        {
            "version": "1.10",
            "tiledversion": "1.11.2",
            "name": name,
            "tilewidth": str(TILE),
            "tileheight": str(TILE),
            "tilecount": str(count),
            "columns": str(cols),
            "objectalignment": "bottom",
        },
    )
    ET.SubElement(
        root,
        "image",
        {"source": image_rel, "width": str(w), "height": str(h)},
    )
    ET.indent(root, space="  ")
    ET.ElementTree(root).write(path, encoding="utf-8", xml_declaration=True)
    return count


def main():
    if not SRC.exists():
        raise SystemExit(f"Missing {SRC}")

    with Image.open(SRC) as raw:
        im = raw.convert("RGBA")
        comps = components(im)
        bands = row_bands(im)

    # assign each tree to a row by its vertical centre, then sort by x (stage col)
    def centre_y(comp):
        return (comp[1] + comp[3]) // 2

    def band_of(y):
        for b in bands:
            if b[0] <= y <= b[1]:
                return b
        return None

    grid = {}  # band -> list of (stage_col, block, cols, rows_t)
    for comp in comps:
        if comp[2] - comp[0] + 1 < MIN_SIZE or comp[3] - comp[1] + 1 < MIN_SIZE:
            print(f"  skip {comp} (noise)")
            continue
        b = band_of(centre_y(comp))
        if b is None:
            print(f"  skip {comp} (no row band)")
            continue
        block, cols, rows_t = to_block(im, comp)
        grid.setdefault(b, []).append((comp[0], block, cols, rows_t))

    # order rows top->bottom, stages left->right
    rows_ordered = sorted(grid, key=lambda b: b[0])
    per_row = []
    for b in rows_ordered:
        items = sorted(grid[b], key=lambda it: it[0])
        per_row.append([(i, blk, c, r) for i, (_, blk, c, r) in enumerate(items)])

    n_cols = max(len(row) for row in per_row)
    # uniform cell size across the whole sheet -> regular, easy-to-select grid
    cell_w = max(c for row in per_row for _, _, c, _ in row)
    cell_h = max(r for row in per_row for _, _, _, r in row)

    sheet = Image.new(
        "RGBA", (cell_w * TILE * n_cols, cell_h * TILE * len(per_row)), (0, 0, 0, 0)
    )
    for r_idx, row in enumerate(per_row):
        for c_idx, (_, block, _, _) in enumerate(row):
            paste_x = c_idx * cell_w * TILE
            paste_y = (r_idx + 1) * cell_h * TILE - block.height  # bottom-anchored
            sheet.alpha_composite(block, (paste_x, paste_y))

    if SPR_SUB.exists():
        shutil.rmtree(SPR_SUB)
    SPR_SUB.mkdir(parents=True)
    png = SPR_SUB / "trees4_grid.png"
    sheet.save(png)
    count = write_tsx(
        TSX,
        "trees4",
        cell_w * n_cols,
        cell_h * len(per_row),
        "../../sprites/fantasy_farm_free/trees4_grid/trees4_grid.png",
        sheet.width,
        sheet.height,
    )

    print(f"Rows   : {len(per_row)} (varieties)")
    print(f"Cols   : {n_cols} (stages per variety)")
    print(f"Trees  : {sum(len(r) for r in per_row)}")
    print(f"Cell   : {cell_w}x{cell_h} tiles")
    print(f"Sheet  : {sheet.width}x{sheet.height}px ({sheet.width//TILE}x{sheet.height//TILE} tiles, {count} tiles)")
    for r_idx, row in enumerate(per_row):
        sizes = [f"s{i}:{c}x{r}" for i, _, c, r in row]
        print(f"  row {r_idx}: {sizes}")
    print(f"TSX   : {TSX.relative_to(ROOT)}")
    print(f"PNG   : {png.relative_to(ROOT)}")


if __name__ == "__main__":
    main()

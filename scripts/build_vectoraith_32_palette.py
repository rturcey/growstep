#!/usr/bin/env python3

from __future__ import annotations

import json
import math
import shutil
from pathlib import Path
from xml.sax.saxutils import escape

try:
    from PIL import Image
except ImportError as exc:
    raise SystemExit(
        "Pillow est requis.\n"
        "Lance avec :\n"
        "  uv run --with pillow scripts/build_vectoraith_32_palette.py"
    ) from exc


ROOT = Path(__file__).resolve().parents[1]
PACK_NAME = "vectoraith_tileset_farming_sim_essentials"


def find_source() -> Path:
    candidates = [
        ROOT / PACK_NAME,
        ROOT.parent / "refactor_potager" / PACK_NAME,
    ]

    # Cherche aussi automatiquement dans les worktrees/repos voisins.
    candidates.extend(
        path
        for path in ROOT.parent.glob(f"*/{PACK_NAME}")
        if path.is_dir()
    )

    seen = set()

    for candidate in candidates:
        candidate = candidate.resolve()

        if candidate in seen:
            continue

        seen.add(candidate)

        expected = (
            candidate
            / "Original"
            / "32x32"
        )

        if expected.is_dir():
            print(f"✓ Pack VectoRaith trouvé : {candidate}")
            return candidate

    searched = "\n".join(
        f"  - {candidate}"
        for candidate in seen
    )

    raise RuntimeError(
        "Pack VectoRaith introuvable. Chemins testés :\n"
        + searched
    )


SOURCE = find_source()
OUT = ROOT / "tools/vectoraith_palette_32"

BASE_TILE = 32
MAX_ATLAS_SIZE = 4096
EXPECTED_SHEETS = 135

VARIANTS = (
    "Original",
    "ReColor",
    "ReShade",
)

FAMILY_ORDER = {
    "RPG Maker autotiles": 0,
    "Sprites": 1,
    "Tilesets (Compact)": 2,
    "Tilesets (Modular)": 3,
}


def relative_of(path: Path) -> Path:
    return path.relative_to(SOURCE)


def variant_of(path: Path) -> str:
    return relative_of(path).parts[0]


def family_of(path: Path) -> str:
    return relative_of(path).parts[2]


def collect_sheets() -> list[Path]:
    sheets: list[Path] = []

    for variant in VARIANTS:
        root = SOURCE / variant / "32x32"
        if not root.exists():
            raise RuntimeError(f"Dossier VectoRaith absent : {root}")

        sheets.extend(
            p
            for p in root.rglob("*.png")
            if p.is_file()
        )

    sheets.sort(
        key=lambda p: (
            VARIANTS.index(variant_of(p)),
            FAMILY_ORDER.get(family_of(p), 999),
            p.name.lower(),
        )
    )

    if len(sheets) != EXPECTED_SHEETS:
        raise RuntimeError(
            f"Attendu {EXPECTED_SHEETS} sheets 32×32, "
            f"trouvé {len(sheets)}.\n"
            "Le contenu du pack a changé."
        )

    return sheets


def xml_properties(values: dict[str, object]) -> str:
    lines = []
    for key, value in values.items():
        lines.append(
            f'      <property '
            f'name="{escape(str(key))}" '
            f'value="{escape(str(value))}"/>'
        )
    return "\n".join(lines)


def write_atlas_tsx(
    path: Path,
    *,
    name: str,
    image_name: str,
    tile_width: int,
    tile_height: int,
    columns: int,
    rows: int,
    records: list[dict],
):
    image_width = columns * tile_width
    image_height = rows * tile_height
    tile_nodes = []

    for record in records:
        tile_id = record["catalogTileId"]
        props = {
            "sourceFile": record["sourceFile"],
            "variant": record["variant"],
            "family": record["family"],
            "sheet": record["sheet"],
        }

        if "sourceTileId" in record:
            props["sourceTileId"] = record["sourceTileId"]

        if "sourceFrameId" in record:
            props["sourceFrameId"] = record["sourceFrameId"]
            props["frameColumn"] = record["frameColumn"]
            props["frameRow"] = record["frameRow"]
            props["sourceFrameWidth"] = record["sourceFrameWidth"]
            props["sourceFrameHeight"] = record["sourceFrameHeight"]

        tile_nodes.append(
            f'''  <tile id="{tile_id}">
    <properties>
{xml_properties(props)}
    </properties>
  </tile>'''
        )

    xml = f'''<?xml version="1.0" encoding="UTF-8"?>
<tileset
  version="1.10"
  tiledversion="1.11.2"
  name="{escape(name)}"
  tilewidth="{tile_width}"
  tileheight="{tile_height}"
  tilecount="{len(records)}"
  columns="{columns}"
  objectalignment="bottom">
  <image
    source="{escape(image_name)}"
    width="{image_width}"
    height="{image_height}"/>
{chr(10).join(tile_nodes)}
</tileset>
'''

    path.write_text(xml, encoding="utf-8")


def regular_tiles(sheet: Path):
    with Image.open(sheet) as raw:
        image = raw.convert("RGBA")
        width, height = image.size

        if width % BASE_TILE != 0:
            raise RuntimeError(
                f"{relative_of(sheet)} : largeur {width} non divisible par 32"
            )
        if height % BASE_TILE != 0:
            raise RuntimeError(
                f"{relative_of(sheet)} : hauteur {height} non divisible par 32"
            )

        columns = width // BASE_TILE
        rows = height // BASE_TILE

        for tile_id in range(columns * rows):
            x = (tile_id % columns) * BASE_TILE
            y = (tile_id // columns) * BASE_TILE
            yield (
                tile_id,
                image.crop((x, y, x + BASE_TILE, y + BASE_TILE)),
            )


def sprite_frames(sheet: Path):
    """Découpe les sprites RPG Maker en 3 colonnes × 4 lignes."""
    with Image.open(sheet) as raw:
        image = raw.convert("RGBA")
        width, height = image.size

        if width % 3 != 0:
            raise RuntimeError(
                f"{relative_of(sheet)} : largeur {width} incompatible avec 3 colonnes"
            )
        if height % 4 != 0:
            raise RuntimeError(
                f"{relative_of(sheet)} : hauteur {height} incompatible avec 4 lignes"
            )

        frame_width = width // 3
        frame_height = height // 4

        for frame_id in range(12):
            column = frame_id % 3
            row = frame_id // 3
            x = column * frame_width
            y = row * frame_height
            yield (
                frame_id,
                column,
                row,
                frame_width,
                frame_height,
                image.crop((x, y, x + frame_width, y + frame_height)),
            )


def flush_page(
    *,
    variant: str,
    kind: str,
    page_number: int,
    pending: list[dict],
    tile_width: int,
    tile_height: int,
    columns: int,
    all_records: list[dict],
) -> dict:
    rows = math.ceil(len(pending) / columns)
    atlas = Image.new(
        "RGBA",
        (columns * tile_width, rows * tile_height),
        (0, 0, 0, 0),
    )
    records: list[dict] = []
    page_slug = f"{variant.lower()}_{kind}_{page_number:02}"

    for catalog_tile_id, item in enumerate(pending):
        column = catalog_tile_id % columns
        row = catalog_tile_id // columns
        cell_x = column * tile_width
        cell_y = row * tile_height
        image = item["image"]

        draw_x = cell_x + (tile_width - image.width) // 2
        draw_y = cell_y + tile_height - image.height
        atlas.alpha_composite(image, (draw_x, draw_y))

        record = {k: v for k, v in item.items() if k != "image"}
        record["catalogTileId"] = catalog_tile_id
        record["palettePage"] = page_slug
        records.append(record)
        all_records.append(record)

    png_name = f"{page_slug}.png"
    tsx_name = f"{page_slug}.tsx"
    atlas.save(OUT / png_name)

    write_atlas_tsx(
        OUT / tsx_name,
        name=f"VectoRaith 32 {variant} {kind} {page_number}",
        image_name=png_name,
        tile_width=tile_width,
        tile_height=tile_height,
        columns=columns,
        rows=rows,
        records=records,
    )

    print(f"  ✓ {tsx_name}: {len(records)} entrées")

    return {
        "name": page_slug,
        "png": png_name,
        "tsx": tsx_name,
        "tileCount": len(records),
        "tileWidth": tile_width,
        "tileHeight": tile_height,
    }


def build_regular_variant(
    variant: str,
    sheets: list[Path],
    all_records: list[dict],
) -> list[dict]:
    selected = [
        p
        for p in sheets
        if variant_of(p) == variant and family_of(p) != "Sprites"
    ]

    columns = MAX_ATLAS_SIZE // BASE_TILE
    capacity = columns * columns
    pages = []
    pending = []
    page_number = 1

    for sheet in selected:
        relative = relative_of(sheet)
        count = 0

        for tile_id, image in regular_tiles(sheet):
            if len(pending) >= capacity:
                pages.append(
                    flush_page(
                        variant=variant,
                        kind="tiles",
                        page_number=page_number,
                        pending=pending,
                        tile_width=BASE_TILE,
                        tile_height=BASE_TILE,
                        columns=columns,
                        all_records=all_records,
                    )
                )
                pending = []
                page_number += 1

            pending.append(
                {
                    "image": image,
                    "sourceFile": relative.as_posix(),
                    "sourceTileId": tile_id,
                    "variant": variant,
                    "family": family_of(sheet),
                    "sheet": sheet.name,
                }
            )
            count += 1

        print(f"    {relative}: {count} tiles")

    if pending:
        pages.append(
            flush_page(
                variant=variant,
                kind="tiles",
                page_number=page_number,
                pending=pending,
                tile_width=BASE_TILE,
                tile_height=BASE_TILE,
                columns=columns,
                all_records=all_records,
            )
        )

    return pages


def build_sprite_variant(
    variant: str,
    sheets: list[Path],
    all_records: list[dict],
) -> list[dict]:
    selected = [
        p
        for p in sheets
        if variant_of(p) == variant and family_of(p) == "Sprites"
    ]

    extracted = []
    max_width = 1
    max_height = 1

    for sheet in selected:
        relative = relative_of(sheet)
        count = 0

        for (
            frame_id,
            frame_column,
            frame_row,
            frame_width,
            frame_height,
            image,
        ) in sprite_frames(sheet):
            max_width = max(max_width, frame_width)
            max_height = max(max_height, frame_height)
            extracted.append(
                {
                    "image": image,
                    "sourceFile": relative.as_posix(),
                    "sourceFrameId": frame_id,
                    "frameColumn": frame_column,
                    "frameRow": frame_row,
                    "sourceFrameWidth": frame_width,
                    "sourceFrameHeight": frame_height,
                    "variant": variant,
                    "family": "Sprites",
                    "sheet": sheet.name,
                }
            )
            count += 1

        print(f"    {relative}: {count} frames")

    if not extracted:
        return []

    columns = max(1, MAX_ATLAS_SIZE // max_width)
    rows_capacity = max(1, MAX_ATLAS_SIZE // max_height)
    capacity = columns * rows_capacity
    pages = []
    page_number = 1

    for start in range(0, len(extracted), capacity):
        pending = extracted[start:start + capacity]
        pages.append(
            flush_page(
                variant=variant,
                kind="sprites",
                page_number=page_number,
                pending=pending,
                tile_width=max_width,
                tile_height=max_height,
                columns=columns,
                all_records=all_records,
            )
        )
        page_number += 1

    return pages


def build_palette_map(pages_by_variant: dict[str, list[dict]]):
    first_gid = 1
    refs = []

    for variant in VARIANTS:
        for page in pages_by_variant[variant]:
            refs.append(
                f'''  <tileset firstgid="{first_gid}" source="{escape(page["tsx"])}"/>'''
            )
            first_gid += page["tileCount"]

    xml = f'''<?xml version="1.0" encoding="UTF-8"?>
<map
  version="1.10"
  tiledversion="1.11.2"
  orientation="orthogonal"
  renderorder="right-down"
  width="1"
  height="1"
  tilewidth="32"
  tileheight="32"
  infinite="0"
  nextlayerid="2"
  nextobjectid="1">
{chr(10).join(refs)}
  <layer id="1" name="catalogue" width="1" height="1">
    <data encoding="csv">
0
</data>
  </layer>
</map>
'''

    (OUT / "vectoraith_32_palette.tmx").write_text(xml, encoding="utf-8")


def write_readme(
    sheets: list[Path],
    pages_by_variant: dict,
    records: list[dict],
):
    page_count = sum(len(v) for v in pages_by_variant.values())
    sprite_frames_count = sum(
        1 for item in records if item["family"] == "Sprites"
    )
    regular_tiles_count = len(records) - sprite_frames_count

    text = f"""# VectoRaith 32×32 — Full Palette

Catalogue généré automatiquement.

- Sheets source : {len(sheets)}
- Variantes : Original / ReColor / ReShade
- Pages Tiled : {page_count}
- Tiles réguliers : {regular_tiles_count}
- Frames de sprites : {sprite_frames_count}
- Entrées totales : {len(records)}

## Ouvrir

```bash
tiled tools/vectoraith_palette_32/vectoraith_32_palette.tmx
```

Chaque entrée expose dans Tiled :

- `sourceFile`
- `variant`
- `family`
- `sheet`
- `sourceTileId` pour les tilesets
- `sourceFrameId` pour les sprites
- `frameColumn`
- `frameRow`

Les sprites RPG Maker sont découpés en 3 colonnes × 4 lignes,
sans supposer que leurs frames font 32×32.

Ce dossier est un catalogue d'authoring.
Il ne remplace pas les assets runtime Growstep.
"""

    (OUT / "README.md").write_text(text, encoding="utf-8")


def main():
    sheets = collect_sheets()

    print("VectoRaith 32×32 full palette")
    print("============================")
    print(f"Sheets détectées : {len(sheets)}")

    if OUT.exists():
        shutil.rmtree(OUT)

    OUT.mkdir(parents=True, exist_ok=True)

    pages_by_variant = {}
    all_records = []

    for variant in VARIANTS:
        print()
        print(f"=== {variant} ===")

        pages = []
        pages.extend(
            build_regular_variant(
                variant,
                sheets,
                all_records,
            )
        )
        pages.extend(
            build_sprite_variant(
                variant,
                sheets,
                all_records,
            )
        )
        pages_by_variant[variant] = pages

    build_palette_map(pages_by_variant)

    index = {
        "sheetCount": len(sheets),
        "tileCount": len(all_records),
        "variants": pages_by_variant,
        "tiles": all_records,
    }

    (OUT / "index.json").write_text(
        json.dumps(index, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )

    write_readme(
        sheets,
        pages_by_variant,
        all_records,
    )

    print()
    print("============================")
    print("✓ CATALOGUE TERMINÉ")
    print("============================")
    print(f"Sheets : {len(sheets)}/{EXPECTED_SHEETS}")
    print(f"Entrées : {len(all_records)}")
    print("Map Tiled :")
    print("  tools/vectoraith_palette_32/vectoraith_32_palette.tmx")


if __name__ == "__main__":
    main()

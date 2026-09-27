#!/usr/bin/env python3

from __future__ import annotations

import argparse
import json
import shutil
from collections import Counter, defaultdict
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont, ImageOps


ROOT = Path(__file__).resolve().parents[1]

RAW_DEST = ROOT / "assets" / "vendor" / "vectoraith_farming_raw"
AUDIT_DIR = ROOT / "docs" / "vectoraith-audit"

THUMB_W = 220
THUMB_H = 180
LABEL_H = 54

SHEET_COLS = 4
SHEET_W = SHEET_COLS * THUMB_W


def safe_name(value: str) -> str:
    result = []

    for char in value.lower():
        if char.isalnum():
            result.append(char)
        else:
            result.append("_")

    return "_".join(
        part
        for part in "".join(result).split("_")
        if part
    )


def copy_pack(source: Path):
    if not source.exists():
        raise SystemExit(
            f"Pack introuvable : {source}"
        )

    if RAW_DEST.exists():
        print(
            f"⚠ {RAW_DEST.relative_to(ROOT)} existe déjà."
        )
        print(
            "  Je le supprime pour réimporter le pack proprement."
        )

        shutil.rmtree(
            RAW_DEST
        )

    RAW_DEST.parent.mkdir(
        parents=True,
        exist_ok=True,
    )

    shutil.copytree(
        source,
        RAW_DEST,
    )

    print(
        f"✓ Pack brut copié dans {RAW_DEST.relative_to(ROOT)}"
    )


def inspect_png(path: Path) -> dict:
    with Image.open(path) as image:
        image.load()

        mode = image.mode
        width, height = image.size

        has_alpha = (
            "A" in mode
            or "transparency" in image.info
        )

        alpha_bbox = None

        if has_alpha:
            rgba = image.convert("RGBA")
            alpha_bbox = rgba.getchannel("A").getbbox()

        return {
            "path": str(
                path.relative_to(RAW_DEST)
            ),
            "width": width,
            "height": height,
            "mode": mode,
            "has_alpha": has_alpha,
            "alpha_bbox": list(alpha_bbox)
            if alpha_bbox
            else None,
            "likely_tilesheet": (
                width >= 128
                and height >= 128
            ),
        }


def make_checkerboard(
    width: int,
    height: int,
    size: int = 12,
):
    image = Image.new(
        "RGB",
        (width, height),
        (230, 230, 230),
    )

    draw = ImageDraw.Draw(
        image
    )

    for y in range(
        0,
        height,
        size,
    ):
        for x in range(
            0,
            width,
            size,
        ):
            if (
                x // size
                + y // size
            ) % 2:
                draw.rectangle(
                    (
                        x,
                        y,
                        x + size - 1,
                        y + size - 1,
                    ),
                    fill=(
                        205,
                        205,
                        205,
                    ),
                )

    return image


def make_card(
    path: Path,
    info: dict,
) -> Image.Image:

    card = Image.new(
        "RGB",
        (
            THUMB_W,
            THUMB_H + LABEL_H,
        ),
        "white",
    )

    checker = make_checkerboard(
        THUMB_W,
        THUMB_H,
    )

    card.paste(
        checker,
        (0, 0),
    )

    source = Image.open(
        path
    ).convert("RGBA")

    preview = ImageOps.contain(
        source,
        (
            THUMB_W - 16,
            THUMB_H - 16,
        ),
        Image.Resampling.NEAREST,
    )

    px = (
        THUMB_W
        - preview.width
    ) // 2

    py = (
        THUMB_H
        - preview.height
    ) // 2

    card.paste(
        preview,
        (
            px,
            py,
        ),
        preview,
    )

    draw = ImageDraw.Draw(
        card
    )

    rel = str(
        path.relative_to(
            RAW_DEST
        )
    )

    filename = path.name

    if len(filename) > 31:
        filename = (
            filename[:28]
            + "..."
        )

    draw.text(
        (
            6,
            THUMB_H + 5,
        ),
        filename,
        fill="black",
    )

    draw.text(
        (
            6,
            THUMB_H + 23,
        ),
        (
            f"{info['width']}×{info['height']} "
            f"{info['mode']}"
        ),
        fill="black",
    )

    parent = str(
        Path(rel).parent
    )

    if len(parent) > 34:
        parent = (
            "..."
            + parent[-31:]
        )

    draw.text(
        (
            6,
            THUMB_H + 39,
        ),
        parent,
        fill=(
            80,
            80,
            80,
        ),
    )

    return card


def build_contact_sheet(
    title: str,
    entries: list[tuple[Path, dict]],
    output: Path,
):

    if not entries:
        return

    rows = (
        len(entries)
        + SHEET_COLS
        - 1
    ) // SHEET_COLS

    header_h = 42

    sheet = Image.new(
        "RGB",
        (
            SHEET_W,
            header_h
            + rows
            * (
                THUMB_H
                + LABEL_H
            ),
        ),
        "white",
    )

    draw = ImageDraw.Draw(
        sheet
    )

    draw.text(
        (
            10,
            12,
        ),
        title,
        fill="black",
    )

    for index, (
        path,
        info,
    ) in enumerate(entries):

        col = (
            index
            % SHEET_COLS
        )

        row = (
            index
            // SHEET_COLS
        )

        card = make_card(
            path,
            info,
        )

        sheet.paste(
            card,
            (
                col
                * THUMB_W,

                header_h
                + row
                * (
                    THUMB_H
                    + LABEL_H
                ),
            ),
        )

    output.parent.mkdir(
        parents=True,
        exist_ok=True,
    )

    sheet.save(
        output,
        "PNG",
        optimize=True,
    )


def audit():
    AUDIT_DIR.mkdir(
        parents=True,
        exist_ok=True,
    )

    pngs = sorted(
        RAW_DEST.rglob(
            "*.png"
        )
    )

    if not pngs:
        raise SystemExit(
            "Aucun PNG trouvé dans le pack."
        )

    records = []

    grouped = defaultdict(
        list
    )

    dimensions = Counter()

    print()
    print(
        f"Analyse de {len(pngs)} PNG..."
    )

    for path in pngs:
        info = inspect_png(
            path
        )

        records.append(
            info
        )

        dimensions[
            (
                info["width"],
                info["height"],
            )
        ] += 1

        rel = path.relative_to(
            RAW_DEST
        )

        # Group contact sheets by first useful directory.
        parts = rel.parts

        group = (
            parts[0]
            if len(parts) > 1
            else "root"
        )

        grouped[
            group
        ].append(
            (
                path,
                info,
            )
        )

    inventory = {
        "pack_root": str(
            RAW_DEST.relative_to(
                ROOT
            )
        ),
        "png_count": len(
            records
        ),
        "most_common_dimensions": [
            {
                "size":
                    [
                        w,
                        h,
                    ],
                "count":
                    count,
            }
            for (
                (
                    w,
                    h,
                ),
                count,
            )
            in dimensions.most_common(
                30
            )
        ],
        "files": records,
    }

    inventory_path = (
        AUDIT_DIR
        / "inventory.json"
    )

    inventory_path.write_text(
        json.dumps(
            inventory,
            indent=2,
            ensure_ascii=False,
        )
        + "\n",
        encoding="utf-8",
    )

    # Markdown summary.
    markdown = []

    markdown.append(
        "# VectoRaith Farming Sim Asset Pack — audit"
    )

    markdown.append(
        ""
    )

    markdown.append(
        f"- PNG : **{len(records)}**"
    )

    markdown.append(
        f"- Dossiers principaux : **{len(grouped)}**"
    )

    markdown.append(
        ""
    )

    markdown.append(
        "## Tailles les plus courantes"
    )

    markdown.append(
        ""
    )

    markdown.append(
        "| Taille | Fichiers |"
    )

    markdown.append(
        "|---:|---:|"
    )

    for (
        width,
        height,
    ), count in dimensions.most_common(
        20
    ):
        markdown.append(
            f"| {width}×{height} | {count} |"
        )

    markdown.append(
        ""
    )

    markdown.append(
        "## Dossiers"
    )

    markdown.append(
        ""
    )

    for group in sorted(
        grouped
    ):
        markdown.append(
            f"- `{group}` : {len(grouped[group])} PNG"
        )

    summary_path = (
        AUDIT_DIR
        / "README.md"
    )

    summary_path.write_text(
        "\n".join(
            markdown
        )
        + "\n",
        encoding="utf-8",
    )

    # Contact sheets.
    sheets = []

    for index, (
        group,
        entries,
    ) in enumerate(
        sorted(
            grouped.items()
        ),
        start=1,
    ):
        name = (
            f"{index:02}_"
            f"{safe_name(group)}.png"
        )

        output = (
            AUDIT_DIR
            / name
        )

        build_contact_sheet(
            group,
            entries,
            output,
        )

        sheets.append(
            output
        )

    print()
    print(
        f"✓ inventory : {inventory_path.relative_to(ROOT)}"
    )

    print(
        f"✓ summary   : {summary_path.relative_to(ROOT)}"
    )

    print(
        f"✓ contact sheets : {len(sheets)}"
    )

    for sheet in sheets:
        print(
            f"    {sheet.relative_to(ROOT)}"
        )

    return sheets


def main():
    parser = argparse.ArgumentParser()

    parser.add_argument(
        "source",
        type=Path,
        help=(
            "Dossier décompressé du "
            "VectoRaith Farming Sim Asset Pack"
        ),
    )

    args = parser.parse_args()

    print(
        "GROWSTEP — IMPORT VECTORAITH"
    )
    print(
        "============================"
    )

    copy_pack(
        args.source.expanduser().resolve()
    )

    sheets = audit()

    print()
    print(
        "✅ Import brut terminé."
    )

    print()
    print(
        "Aucun sprite Growstep existant "
        "n'a été remplacé."
    )

    print(
        "Aucune map isométrique n'a été modifiée."
    )


if __name__ == "__main__":
    main()

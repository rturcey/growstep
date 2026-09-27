#!/usr/bin/env python3
from __future__ import annotations

import io
import zipfile
from collections import deque
from pathlib import Path
from xml.etree.ElementTree import Element, SubElement, tostring

from PIL import Image

# ============================================================
# CONFIG
# ============================================================

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "chou.png"

SPECIES = "lavande"  # <- change ici pour carotte, courgette, fraisier, etc.
STATES = [
    "graine_germee",
    "jeune",
    "presque_mature",
    "recoltable",
]
VARIANT = "ordinaire"
FRAME = "00"

# Taille de sortie standard
OUT_SIZE = 320

# Dossiers de sortie
SPRITE_SOURCES_DIR = ROOT / "assets" / "sprite_sources"
SPRITES_DIR = ROOT / "assets" / "sprites"
EXPORT_2X_DIR = ROOT / "assets" / "sprite_exports" / "2.0x"
EXPORT_3X_DIR = ROOT / "assets" / "sprite_exports" / "3.0x"

# seuil alpha pour considérer un pixel "présent"
ALPHA_THRESHOLD = 8

# padding autour du crop final
CROP_PAD = 10

# taille minimale d’un blob utile
MIN_COMPONENT_PIXELS = 80

# marge intérieure du sprite dans le canvas 320x320
INNER_PAD = 14


# ============================================================
# HELPERS
# ============================================================

def sprite_id(species: str, state: str) -> str:
    return f"potager_plante_{species}_{state}_{VARIANT}_{FRAME}"


def ensure_dirs() -> None:
    for path in [
        SPRITE_SOURCES_DIR,
        SPRITES_DIR,
        EXPORT_2X_DIR,
        EXPORT_3X_DIR,
    ]:
        path.mkdir(parents=True, exist_ok=True)


def load_rgba(path: Path) -> Image.Image:
    if not path.exists():
        raise FileNotFoundError(f"Image source introuvable: {path}")
    return Image.open(path).convert("RGBA")


def alpha_mask(img: Image.Image):
    alpha = img.getchannel("A")
    return alpha


def find_connected_components(img: Image.Image):
    """
    Détecte les composants connexes sur alpha > threshold.
    Retourne une liste de bbox: (left, top, right, bottom)
    """
    w, h = img.size
    alpha = alpha_mask(img)
    px = alpha.load()

    visited = [[False] * w for _ in range(h)]
    boxes = []

    for y in range(h):
        for x in range(w):
            if visited[y][x]:
                continue
            visited[y][x] = True
            if px[x, y] <= ALPHA_THRESHOLD:
                continue

            q = deque([(x, y)])
            min_x = max_x = x
            min_y = max_y = y
            count = 0

            while q:
                cx, cy = q.popleft()
                count += 1
                min_x = min(min_x, cx)
                max_x = max(max_x, cx)
                min_y = min(min_y, cy)
                max_y = max(max_y, cy)

                for nx, ny in (
                    (cx - 1, cy),
                    (cx + 1, cy),
                    (cx, cy - 1),
                    (cx, cy + 1),
                ):
                    if 0 <= nx < w and 0 <= ny < h and not visited[ny][nx]:
                        visited[ny][nx] = True
                        if px[nx, ny] > ALPHA_THRESHOLD:
                            q.append((nx, ny))

            if count >= MIN_COMPONENT_PIXELS:
                boxes.append((min_x, min_y, max_x + 1, max_y + 1))

    return boxes


def pad_box(box, img_size, pad=CROP_PAD):
    l, t, r, b = box
    w, h = img_size
    return (
        max(0, l - pad),
        max(0, t - pad),
        min(w, r + pad),
        min(h, b + pad),
    )


def sort_boxes_left_to_right(boxes):
    return sorted(boxes, key=lambda b: ((b[0] + b[2]) / 2.0))


def fit_to_canvas_bottom_center(crop: Image.Image, size=OUT_SIZE, inner_pad=INNER_PAD) -> Image.Image:
    """
    Place le crop sur un canvas transparent 320x320.
    Alignement: centré horizontalement, posé vers le bas.
    """
    cw, ch = crop.size
    max_w = size - inner_pad * 2
    max_h = size - inner_pad * 2

    scale = min(max_w / cw, max_h / ch)
    nw = max(1, round(cw * scale))
    nh = max(1, round(ch * scale))

    resized = crop.resize((nw, nh), Image.LANCZOS)

    canvas = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    x = (size - nw) // 2
    y = size - inner_pad - nh
    canvas.alpha_composite(resized, (x, y))
    return canvas


def save_pngs(base_name: str, img: Image.Image):
    png_path = SPRITES_DIR / f"{base_name}.png"
    img.save(png_path)

    img.resize((img.width * 2, img.height * 2), Image.LANCZOS).save(
        EXPORT_2X_DIR / f"{base_name}.png"
    )
    img.resize((img.width * 3, img.height * 3), Image.LANCZOS).save(
        EXPORT_3X_DIR / f"{base_name}.png"
    )

    return png_path


def build_stack_xml(w: int, h: int) -> bytes:
    image = Element("image", {
        "version": "0.0.3",
        "w": str(w),
        "h": str(h),
    })
    stack = SubElement(image, "stack", {"name": "root"})
    SubElement(
        stack,
        "layer",
        {
            "name": "sprite",
            "src": "data/layer0.png",
            "x": "0",
            "y": "0",
            "opacity": "1",
            "visibility": "visible",
        },
    )
    return tostring(image, encoding="utf-8", xml_declaration=True)


def save_ora(base_name: str, img: Image.Image):
    ora_path = SPRITE_SOURCES_DIR / f"{base_name}.ora"

    png_buf = io.BytesIO()
    img.save(png_buf, format="PNG")
    layer_bytes = png_buf.getvalue()

    merged_buf = io.BytesIO()
    img.save(merged_buf, format="PNG")
    merged_bytes = merged_buf.getvalue()

    thumbnail = img.copy()
    thumbnail.thumbnail((256, 256), Image.LANCZOS)
    thumb_buf = io.BytesIO()
    thumbnail.save(thumb_buf, format="PNG")
    thumb_bytes = thumb_buf.getvalue()

    stack_xml = build_stack_xml(img.width, img.height)

    with zipfile.ZipFile(ora_path, "w", compression=zipfile.ZIP_DEFLATED) as zf:
        zf.writestr("mimetype", "image/openraster", compress_type=zipfile.ZIP_STORED)
        zf.writestr("stack.xml", stack_xml)
        zf.writestr("mergedimage.png", merged_bytes)
        zf.writestr("data/layer0.png", layer_bytes)
        zf.writestr("Thumbnails/thumbnail.png", thumb_bytes)

    return ora_path


def save_yaml(base_name: str, state: str, png_path: Path, ora_path: Path, img: Image.Image):
    """
    YAML minimaliste. Si ton validateur attend d'autres clés obligatoires,
    garde surtout la logique d'ID ici, qui corrige ton erreur actuelle.
    """
    yaml_path = SPRITE_SOURCES_DIR / f"{base_name}.yaml"

    content = f"""id: {base_name}
kind: plant
species: {SPECIES}
state: {state}
variant: {VARIANT}
frame: {FRAME}
source_ora: {ora_path.relative_to(ROOT).as_posix()}
source_png: {png_path.relative_to(ROOT).as_posix()}
size:
  width: {img.width}
  height: {img.height}
"""

    yaml_path.write_text(content, encoding="utf-8")
    return yaml_path


# ============================================================
# MAIN
# ============================================================

def main():
    ensure_dirs()

    sheet = load_rgba(SOURCE)
    boxes = find_connected_components(sheet)
    boxes = sort_boxes_left_to_right(boxes)

    if len(boxes) != 4:
        raise RuntimeError(
            f"Je m'attendais à 4 stades dans {SOURCE.name}, mais j'ai trouvé {len(boxes)} composants utiles."
        )

    print(f"Source: {SOURCE}")
    print(f"{len(boxes)} stades détectés")

    for i, (state, box) in enumerate(zip(STATES, boxes), start=1):
        padded = pad_box(box, sheet.size, pad=CROP_PAD)
        crop = sheet.crop(padded)
        final_img = fit_to_canvas_bottom_center(crop, size=OUT_SIZE, inner_pad=INNER_PAD)

        base_name = sprite_id(SPECIES, state)
        png_path = save_pngs(base_name, final_img)
        ora_path = save_ora(base_name, final_img)
        yaml_path = save_yaml(base_name, state, png_path, ora_path, final_img)

        print(f"✓ {i}. {state}")
        print(f"  png : {png_path.relative_to(ROOT)}")
        print(f"  ora : {ora_path.relative_to(ROOT)}")
        print(f"  yaml: {yaml_path.relative_to(ROOT)}")

    print("\nTerminé.")
    print("Important : ce script suppose que plantes.png contient UNE seule plante sur 4 stades, avec fond transparent.")


if __name__ == "__main__":
    main()

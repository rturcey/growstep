#!/usr/bin/env python3

from __future__ import annotations

import json
import sys
from collections import deque

from PIL import Image

from import_new_da_batch_01 import (
    ROOT,
    SOURCES,
    SPRITES,
    EXPORT_3X,
    EXPORT_2X,
    MANIFEST,
    AUDIT,
    fit_to_master,
    write_ora,
    write_yaml,
    write_exports,
)


SOURCE = ROOT / "assets/reference/portail_fleuri_en_bois_peint.png"

SPRITE_ID = "potager_decor_portail_bois_statique_ordinaire_00"

CONFIG = {
    "id": SPRITE_ID,

    # Taille logique Growstep.
    "canvas_1x": (76, 68),
    "max_visible_1x": (68, 60),

    # Le portail suit un côté de la grille isométrique.
    "footprint_grid": [1.0, 0.5],

    "size_class": "small_decor",

    "palette_roles": [
        "bois_chaud",
        "feuillage_sauge",
        "feuillage_profond",
        "blanc_floral",
        "jaune",
    ],
}


def connected_background_mask(rgb: Image.Image) -> Image.Image:
    """
    Retire uniquement le fond sombre connecté aux bords.

    Important :
    - les trous entre les planches deviennent transparents ;
    - les vis / ombres sombres enfermées dans le portail restent présentes ;
    - on ne fait PAS un simple "supprimer tous les pixels noirs".
    """

    image = rgb.convert("RGB")
    width, height = image.size
    pixels = image.load()

    # 0 = inconnu / objet
    # 1 = fond connecté
    background = bytearray(width * height)

    def index(x: int, y: int) -> int:
        return y * width + x

    def looks_like_background(x: int, y: int) -> bool:
        r, g, b = pixels[x, y]

        maximum = max(r, g, b)
        minimum = min(r, g, b)
        spread = maximum - minimum

        # Le fond généré est un gris très sombre, légèrement bleuté.
        # Une valeur assez permissive permet aussi d'absorber son vignettage.
        return maximum <= 125 and spread <= 32

    queue: deque[tuple[int, int]] = deque()

    def seed(x: int, y: int):
        key = index(x, y)

        if background[key]:
            return

        if not looks_like_background(x, y):
            return

        background[key] = 1
        queue.append((x, y))

    # Le fond doit obligatoirement être relié à un bord de l'image.
    for x in range(width):
        seed(x, 0)
        seed(x, height - 1)

    for y in range(height):
        seed(0, y)
        seed(width - 1, y)

    while queue:
        x, y = queue.popleft()

        for nx, ny in (
            (x - 1, y),
            (x + 1, y),
            (x, y - 1),
            (x, y + 1),
        ):
            if not (0 <= nx < width and 0 <= ny < height):
                continue

            key = index(nx, ny)

            if background[key]:
                continue

            if not looks_like_background(nx, ny):
                continue

            background[key] = 1
            queue.append((nx, ny))

    mask = Image.new("L", (width, height), 255)
    alpha = mask.load()

    for y in range(height):
        for x in range(width):
            if background[index(x, y)]:
                alpha[x, y] = 0

    return mask


def clean_background(source: Image.Image) -> Image.Image:
    rgb = source.convert("RGB")
    alpha = connected_background_mask(rgb)

    result = rgb.convert("RGBA")
    result.putalpha(alpha)

    bbox = result.getchannel("A").getbbox()

    if bbox is None:
        raise RuntimeError("Le détourage a supprimé toute l'image.")

    # Coupe le grand canvas généré mais garde 12 px de sécurité.
    left, top, right, bottom = bbox
    margin = 12

    left = max(0, left - margin)
    top = max(0, top - margin)
    right = min(result.width, right + margin)
    bottom = min(result.height, bottom + margin)

    return result.crop((left, top, right, bottom))


def main():
    if not SOURCE.exists():
        raise SystemExit(
            "Image absente :\n"
            f"  {SOURCE}\n\n"
            "Place portail_fleuri_en_bois_peint.png dans assets/reference/."
        )

    for directory in (
        SOURCES,
        SPRITES,
        EXPORT_3X,
        EXPORT_2X,
    ):
        directory.mkdir(parents=True, exist_ok=True)

    source = Image.open(SOURCE)

    print("NEW DA — REPLACE PORTAIL")
    print("========================")
    print(f"source : {source.width}x{source.height}")

    # Protection contre le mauvais fichier.
    if source.size != (1312, 1199):
        print(
            "⚠️ Dimensions différentes de l'image générée attendue "
            "(1312x1199). Le script continue."
        )

    transparent = clean_background(source)

    bbox = transparent.getchannel("A").getbbox()

    if bbox is None:
        raise RuntimeError("Sprite transparent vide.")

    print(
        f"détourage : {transparent.width}x{transparent.height}"
    )

    # Normalise dans le contrat Growstep 4x.
    master, anchor = fit_to_master(
        transparent,
        CONFIG,
    )

    print(
        f"master : {master.width}x{master.height}"
    )
    print(
        f"anchor : {anchor}"
    )

    # ------------------------------------------------------------------
    # Source ORA + métadonnées + exports
    # ------------------------------------------------------------------

    write_ora(
        SPRITE_ID,
        master,
    )

    write_yaml(
        CONFIG,
        anchor,
    )

    write_exports(
        SPRITE_ID,
        master,
    )

    # ------------------------------------------------------------------
    # Manifest
    # ------------------------------------------------------------------

    manifest = json.loads(
        MANIFEST.read_text(
            encoding="utf-8",
        )
    )

    runtime_bbox = (
        master
        .getchannel("A")
        .point(
            lambda value: 255 if value > 32 else 0
        )
        .getbbox()
    )

    if runtime_bbox is None:
        raise RuntimeError(
            "Le master exporté ne contient aucun pixel visible."
        )

    manifest[f"{SPRITE_ID}.png"] = {
        "width": master.width,
        "height": master.height,
        "bbox": list(runtime_bbox),
        "anchor": anchor,
        "shadow": "separate_contact",
    }

    MANIFEST.write_text(
        json.dumps(
            manifest,
            indent=2,
            ensure_ascii=False,
        )
        + "\n",
        encoding="utf-8",
    )

    # ------------------------------------------------------------------
    # Palette audit
    # ------------------------------------------------------------------

    audit = json.loads(
        AUDIT.read_text(
            encoding="utf-8",
        )
    )

    # Toujours pas branché automatiquement à Tiled :
    # on valide d'abord le sprite final.
    audit[f"{SPRITE_ID}.png"] = {
        "status": "excluded",
    }

    AUDIT.write_text(
        json.dumps(
            audit,
            indent=2,
            ensure_ascii=False,
        )
        + "\n",
        encoding="utf-8",
    )

    # ------------------------------------------------------------------
    # Validation ciblée
    # ------------------------------------------------------------------

    sys.path.insert(
        0,
        str(ROOT / "scripts"),
    )

    from validate_sprites import validate_sheet

    fresh_manifest = json.loads(
        MANIFEST.read_text(
            encoding="utf-8",
        )
    )

    errors = validate_sheet(
        SOURCES / f"{SPRITE_ID}.yaml",
        ROOT,
        fresh_manifest,
    )

    if errors:
        print()
        print("❌ VALIDATION FAILED")

        for error in errors:
            print(error)

        raise SystemExit(1)

    print()
    print("✅ Portail remplacé.")
    print()
    print("Source authoritative :")
    print(
        f"  assets/sprite_sources/{SPRITE_ID}.ora"
    )
    print()
    print("Sprite runtime :")
    print(
        f"  assets/sprites/{SPRITE_ID}.png"
    )


if __name__ == "__main__":
    main()

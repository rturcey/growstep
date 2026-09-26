# scripts/add_potager_small_decor.py
from __future__ import annotations

import json
from pathlib import Path
from zipfile import ZipFile, ZIP_DEFLATED, ZIP_STORED
import xml.etree.ElementTree as ET

import yaml
from PIL import Image, ImageOps


ROOT = Path(__file__).resolve().parents[1]

SPRITES = ROOT / "assets" / "sprites"
SOURCES = ROOT / "assets" / "sprite_sources"
EXPORT2 = ROOT / "assets" / "sprite_exports" / "2.0x"
EXPORT3 = ROOT / "assets" / "sprite_exports" / "3.0x"
ARCHIVE = ROOT / "assets" / "sprite_archive"
AUDIT = ROOT / "assets" / "maps" / "palette_audit.json"


def ensure_dirs() -> None:
    SPRITES.mkdir(parents=True, exist_ok=True)
    SOURCES.mkdir(parents=True, exist_ok=True)
    EXPORT2.mkdir(parents=True, exist_ok=True)
    EXPORT3.mkdir(parents=True, exist_ok=True)


def load_rgba(path: Path) -> Image.Image:
    with Image.open(path) as src:
        return src.convert("RGBA")


def visible_bbox(image: Image.Image):
    alpha = image.getchannel("A")
    bbox = alpha.getbbox()
    if bbox is None:
        raise ValueError(f"{image}: no visible pixels")
    return bbox


def fit_on_canvas(
    source: Image.Image,
    canvas_1x: tuple[int, int],
    bottom_anchor_delta: int = 13,
    margin_px: int = 8,
) -> Image.Image:
    """
    Normalize any source sprite into a 4x master canvas.
    Anchor convention for Tiled preview families stays near (0, -13).
    """
    canvas_w = canvas_1x[0] * 4
    canvas_h = canvas_1x[1] * 4

    bbox = visible_bbox(source)
    cropped = source.crop(bbox)

    max_w = canvas_w - margin_px * 2
    max_h = canvas_h - margin_px * 2 - bottom_anchor_delta

    scale = min(max_w / cropped.width, max_h / cropped.height, 1.0)
    resized = cropped.resize(
        (max(1, round(cropped.width * scale)), max(1, round(cropped.height * scale))),
        Image.Resampling.LANCZOS,
    )

    out = Image.new("RGBA", (canvas_w, canvas_h), (0, 0, 0, 0))
    x = (canvas_w - resized.width) // 2
    y = canvas_h - bottom_anchor_delta - resized.height
    out.alpha_composite(resized, (x, y))
    return out


def write_ora(path: Path, merged: Image.Image) -> None:
    stack = ET.Element(
        "image",
        {
            "w": str(merged.width),
            "h": str(merged.height),
            "name": path.stem,
            "version": "0.0.1",
        },
    )
    root_stack = ET.SubElement(stack, "stack")
    ET.SubElement(
        root_stack,
        "layer",
        {
            "name": "base",
            "src": "data/layer00.png",
            "x": "0",
            "y": "0",
            "opacity": "1.0",
            "visibility": "visible",
            "composite-op": "svg:src-over",
        },
    )

    ET.indent(stack, space="  ")

    import io

    layer_bytes = io.BytesIO()
    merged.save(layer_bytes, format="PNG")
    layer_data = layer_bytes.getvalue()

    xml_data = ET.tostring(stack, encoding="utf-8", xml_declaration=True)

    with ZipFile(path, "w") as zf:
        zf.writestr("mimetype", "image/openraster", compress_type=ZIP_STORED)
        zf.writestr("stack.xml", xml_data, compress_type=ZIP_DEFLATED)
        zf.writestr("mergedimage.png", layer_data, compress_type=ZIP_DEFLATED)
        zf.writestr("data/layer00.png", layer_data, compress_type=ZIP_DEFLATED)


def export_scaled(sprite_id: str, merged: Image.Image) -> None:
    merged.save(SPRITES / f"{sprite_id}.png")
    merged.resize(
        (merged.width * 3 // 4, merged.height * 3 // 4),
        Image.Resampling.LANCZOS,
    ).save(EXPORT3 / f"{sprite_id}.png")
    merged.resize(
        (merged.width // 2, merged.height // 2),
        Image.Resampling.LANCZOS,
    ).save(EXPORT2 / f"{sprite_id}.png")


def write_yaml(
    sprite_id: str,
    canvas_1x: tuple[int, int],
    footprint_grid: tuple[float, float],
    size_class: str,
    palette_roles: list[str],
    anchor_4x: tuple[int, int] | None = None,
) -> None:
    if anchor_4x is None:
        anchor_4x = (canvas_1x[0] * 2, canvas_1x[1] * 4 - 13)

    data = {
        "id": sprite_id,
        "canvas_1x": [canvas_1x[0], canvas_1x[1]],
        "anchor_4x": [anchor_4x[0], anchor_4x[1]],
        "footprint_grid": [footprint_grid[0], footprint_grid[1]],
        "size_class": size_class,
        "projection": "isometric_80x40",
        "light": "upper_left",
        "shadow": "separate_contact",
        "palette_roles": palette_roles,
        "state": "statique",
        "variant": "ordinaire",
        "frames": 1,
    }
    (SOURCES / f"{sprite_id}.yaml").write_text(
        yaml.safe_dump(data, sort_keys=False, allow_unicode=True),
        encoding="utf-8",
    )


def register_in_audit(sprite_id: str, group: str) -> None:
    audit = json.loads(AUDIT.read_text(encoding="utf-8"))
    audit[f"{sprite_id}.png"] = {"status": "included", "group": group}
    AUDIT.write_text(
        json.dumps(audit, indent=2, ensure_ascii=False, sort_keys=True) + "\n",
        encoding="utf-8",
    )


def make_new_sprite_from_archive(
    *,
    source_png: Path,
    sprite_id: str,
    canvas_1x: tuple[int, int],
    footprint_grid: tuple[float, float],
    size_class: str,
    palette_roles: list[str],
    group: str,
) -> None:
    source = load_rgba(source_png)
    merged = fit_on_canvas(source, canvas_1x)

    write_ora(SOURCES / f"{sprite_id}.ora", merged)
    export_scaled(sprite_id, merged)
    write_yaml(
        sprite_id=sprite_id,
        canvas_1x=canvas_1x,
        footprint_grid=footprint_grid,
        size_class=size_class,
        palette_roles=palette_roles,
    )
    register_in_audit(sprite_id, group)


def clone_existing_sprite(
    *,
    source_id: str,
    target_id: str,
    group: str,
    mirror: bool = False,
) -> None:
    source_yaml = yaml.safe_load((SOURCES / f"{source_id}.yaml").read_text(encoding="utf-8"))
    merged = load_rgba(SPRITES / f"{source_id}.png")
    if mirror:
        merged = ImageOps.mirror(merged)

    write_ora(SOURCES / f"{target_id}.ora", merged)
    export_scaled(target_id, merged)

    source_yaml["id"] = target_id
    (SOURCES / f"{target_id}.yaml").write_text(
        yaml.safe_dump(source_yaml, sort_keys=False, allow_unicode=True),
        encoding="utf-8",
    )
    register_in_audit(target_id, group)


def main() -> None:
    ensure_dirs()

    # 1) Nouveau banc
    make_new_sprite_from_archive(
        source_png=ARCHIVE / "verger_banc_bois_ordinaire_00.png",
        sprite_id="potager_decor_banc_bois_statique_ordinaire_00",
        canvas_1x=(56, 34),
        footprint_grid=(1.0, 0.5),
        size_class="small_decor",
        palette_roles=["bois_chaud"],
        group="props",
    )

    # 2) Petite fontaine (ici on promeut le bain d’oiseaux comme petite fontaine)
    make_new_sprite_from_archive(
        source_png=ARCHIVE / "fleurs_bain_oiseaux_pierre_ordinaire_00.png",
        sprite_id="potager_decor_fontaine_pierre_statique_ordinaire_00",
        canvas_1x=(40, 48),
        footprint_grid=(0.5, 0.5),
        size_class="small_decor",
        palette_roles=["pierre_creme", "bleu_doux"],
        group="props",
    )

    # 3) Cagette/panier de légumes
    #    Pour l’instant: alias propre de la caisse de semis existante.
    #    Tu pourras remplacer l’ORA plus tard sans changer l’ID.
    clone_existing_sprite(
        source_id="potager_decor_caisse_semis_statique_ordinaire_00",
        target_id="potager_decor_cagette_legumes_statique_ordinaire_00",
        group="props",
        mirror=False,
    )

    # 4) Variantes d’arche explicites
    #    On ne casse pas les anciennes arches ; on ajoute des IDs dédiés.
    clone_existing_sprite(
        source_id="commun_decor_treillis_bois_fleuri_statique_ordinaire_00",
        target_id="potager_decor_arche_grille_statique_ordinaire_00",
        group="structures",
        mirror=False,
    )

    clone_existing_sprite(
        source_id="commun_decor_treillis_bois_fleuri_statique_ordinaire_01",
        target_id="potager_decor_arche_diagonale_statique_ordinaire_00",
        group="structures",
        mirror=True,
    )

    print("✔ Sprites décor ajoutés.")
    print("✔ Palette audit mis à jour.")
    print("➡ Rebuild manifest + TSX...")

    import subprocess
    import sys

    subprocess.run([sys.executable, "scripts/build_sprite_manifest.py"], cwd=ROOT, check=True)
    subprocess.run([sys.executable, "scripts/build_tiled_tilesets.py"], cwd=ROOT, check=True)
    subprocess.run([sys.executable, "scripts/validate_sprites.py"], cwd=ROOT, check=True)

    print()
    print("Nouveaux IDs disponibles dans Tiled :")
    print(" - potager_decor_banc_bois_statique_ordinaire_00")
    print(" - potager_decor_fontaine_pierre_statique_ordinaire_00")
    print(" - potager_decor_cagette_legumes_statique_ordinaire_00")
    print(" - potager_decor_arche_grille_statique_ordinaire_00")
    print(" - potager_decor_arche_diagonale_statique_ordinaire_00")


if __name__ == "__main__":
    main()

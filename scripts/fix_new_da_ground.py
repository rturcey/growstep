#!/usr/bin/env python3

from __future__ import annotations

from pathlib import Path

from PIL import Image, ImageChops, ImageEnhance, ImageFilter, ImageStat


ROOT = Path(__file__).resolve().parents[1]

SPRITES = ROOT / "assets" / "sprites"
SURFACE = ROOT / "assets" / "surface_sources"

GRASS_TEXTURE = SURFACE / "potager_texture_herbe_source.png"
EARTH_TEXTURE = SURFACE / "potager_texture_terre_cultivee_source.png"
SKIRT_TEXTURE = SURFACE / "potager_texture_bordure_terre_source.png"


def require(path: Path):
    if not path.exists():
        raise SystemExit(f"Fichier manquant : {path}")


def normalized_material(
    source: Image.Image,
    target_rgb: tuple[int, int, int],
    detail_strength: float,
) -> Image.Image:
    """
    Produit UNE matière 80x40 commune à toute la famille.

    On conserve un peu de détail de la texture source, mais toutes les tiles
    partagent exactement la même luminosité moyenne.
    """

    source = source.convert("RGB")

    # Grande zone de la texture pour éviter de capturer un motif local fort.
    w, h = source.size

    crop_w = min(w, 400)
    crop_h = min(h, 200)

    left = (w - crop_w) // 2
    top = (h - crop_h) // 2

    crop = source.crop(
        (
            left,
            top,
            left + crop_w,
            top + crop_h,
        )
    )

    # Le downsampling adoucit fortement le bruit.
    crop = crop.resize(
        (80, 40),
        Image.Resampling.LANCZOS,
    )

    stat = ImageStat.Stat(crop)
    means = stat.mean

    out = Image.new("RGBA", (80, 40), (0, 0, 0, 255))

    src = crop.load()
    dst = out.load()

    for y in range(40):
        for x in range(80):
            r, g, b = src[x, y]

            values = (r, g, b)

            rgb = []

            for channel in range(3):
                deviation = values[channel] - means[channel]

                value = (
                    target_rgb[channel]
                    + deviation * detail_strength
                )

                rgb.append(
                    max(
                        0,
                        min(
                            255,
                            round(value),
                        ),
                    )
                )

            dst[x, y] = (
                rgb[0],
                rgb[1],
                rgb[2],
                255,
            )

    return out


def recolor_from_mask(
    production_tile: Path,
    candidate_tile: Path,
    material: Image.Image,
):
    """
    La production reste notre référence géométrique.

    On reprend EXACTEMENT son alpha.
    """

    source = Image.open(
        production_tile
    ).convert("RGBA")

    if source.size != (80, 40):
        raise RuntimeError(
            f"{production_tile.name}: "
            f"taille {source.size}, attendu 80x40"
        )

    result = material.copy()

    result.putalpha(
        source.getchannel("A")
    )

    result.save(
        candidate_tile,
        "PNG",
        optimize=True,
    )


def add_clipped_skirt_depth(
    image: Image.Image,
) -> Image.Image:
    """
    Assombrit progressivement la tranche vers le bas.

    CRITIQUE :
    le shading est multiplié par l'alpha original.
    Il est donc IMPOSSIBLE de créer les rectangles visibles auparavant.
    """

    result = image.copy()

    original_alpha = result.getchannel("A")

    shade = Image.new(
        "RGBA",
        (80, 40),
        (0, 0, 0, 0),
    )

    shade_pixels = shade.load()

    for y in range(40):
        t = y / 39

        # Très léger en haut, plus profond en bas.
        a = round(
            6 + 58 * (t ** 1.5)
        )

        for x in range(80):
            shade_pixels[x, y] = (
                55,
                31,
                18,
                a,
            )

    # CLIP sur la silhouette.
    shade_alpha = shade.getchannel("A")

    clipped_alpha = ImageChops.multiply(
        shade_alpha,
        original_alpha,
    )

    shade.putalpha(
        clipped_alpha
    )

    result.alpha_composite(
        shade
    )

    # Restaurer exactement l'alpha source.
    result.putalpha(
        original_alpha
    )

    return result


def add_subtle_soil_depth(
    image: Image.Image,
) -> Image.Image:
    """
    Un peu plus de volume pour la terre cultivée,
    toujours sans toucher à l'alpha.
    """

    result = image.copy()

    alpha = result.getchannel("A")

    # Contraste très léger seulement.
    rgb = ImageEnhance.Contrast(
        result.convert("RGB")
    ).enhance(1.04)

    result = rgb.convert("RGBA")

    result.putalpha(alpha)

    return result


def main():
    require(GRASS_TEXTURE)
    require(EARTH_TEXTURE)
    require(SKIRT_TEXTURE)

    grass_source = Image.open(
        GRASS_TEXTURE
    ).convert("RGBA")

    earth_source = Image.open(
        EARTH_TEXTURE
    ).convert("RGBA")

    skirt_source = Image.open(
        SKIRT_TEXTURE
    ).convert("RGBA")

    # ------------------------------------------------------------
    # Palette cible inspirée directement de la nouvelle DA.
    #
    # Important :
    # on veut surtout éviter que des tiles voisines aient des
    # moyennes différentes.
    # ------------------------------------------------------------

    grass_material = normalized_material(
        grass_source,
        target_rgb=(166, 205, 96),
        detail_strength=0.24,
    )

    earth_material = normalized_material(
        earth_source,
        target_rgb=(132, 88, 52),
        detail_strength=0.28,
    )

    skirt_material = normalized_material(
        skirt_source,
        target_rgb=(119, 75, 44),
        detail_strength=0.30,
    )

    print("NEW DA — FIX GROUND")
    print("===================")

    # ------------------------------------------------------------
    # 1. GRASS EDGES
    # ------------------------------------------------------------

    for i in range(12):
        production = (
            SPRITES
            / f"commun_sol_bordure_herbe_tile_{i:02}.png"
        )

        candidate = (
            SPRITES
            / f"potager_newda_sol_bordure_herbe_tile_{i:02}.png"
        )

        require(production)

        recolor_from_mask(
            production,
            candidate,
            grass_material,
        )

        print(
            f"✓ grass edge {i:02}"
        )

    # ------------------------------------------------------------
    # 2. FULL GRASS
    # ------------------------------------------------------------

    for i in range(5):
        production = (
            SPRITES
            / f"commun_sol_herbe_tile_{i:02}.png"
        )

        candidate = (
            SPRITES
            / f"potager_newda_sol_herbe_tile_{i:02}.png"
        )

        require(production)

        recolor_from_mask(
            production,
            candidate,
            grass_material,
        )

        print(
            f"✓ grass {i:02}"
        )

    # ------------------------------------------------------------
    # 3. CULTIVATED EARTH
    # ------------------------------------------------------------

    for i in range(11):
        production = (
            SPRITES
            / f"commun_sol_terre_tile_{i:02}.png"
        )

        candidate = (
            SPRITES
            / f"potager_newda_sol_terre_tile_{i:02}.png"
        )

        require(production)

        recolor_from_mask(
            production,
            candidate,
            earth_material,
        )

        current = Image.open(
            candidate
        ).convert("RGBA")

        current = add_subtle_soil_depth(
            current
        )

        current.save(
            candidate,
            "PNG",
            optimize=True,
        )

        print(
            f"✓ earth {i:02}"
        )

    # ------------------------------------------------------------
    # 4. EARTH SKIRT
    # ------------------------------------------------------------

    for i in range(6):
        production = (
            SPRITES
            / f"commun_sol_tranche_terre_tile_{i:02}.png"
        )

        candidate = (
            SPRITES
            / f"potager_newda_sol_tranche_terre_tile_{i:02}.png"
        )

        require(production)

        recolor_from_mask(
            production,
            candidate,
            skirt_material,
        )

        current = Image.open(
            candidate
        ).convert("RGBA")

        current = add_clipped_skirt_depth(
            current
        )

        current.save(
            candidate,
            "PNG",
            optimize=True,
        )

        print(
            f"✓ skirt {i:02}"
        )

    # ------------------------------------------------------------
    # Absolute alpha validation
    # ------------------------------------------------------------

    print()
    print("Validation alpha...")

    groups = [
        (
            "commun_sol_bordure_herbe_tile_",
            "potager_newda_sol_bordure_herbe_tile_",
            12,
        ),
        (
            "commun_sol_herbe_tile_",
            "potager_newda_sol_herbe_tile_",
            5,
        ),
        (
            "commun_sol_terre_tile_",
            "potager_newda_sol_terre_tile_",
            11,
        ),
        (
            "commun_sol_tranche_terre_tile_",
            "potager_newda_sol_tranche_terre_tile_",
            6,
        ),
    ]

    for old_prefix, new_prefix, count in groups:
        for i in range(count):
            old = Image.open(
                SPRITES
                / f"{old_prefix}{i:02}.png"
            ).convert("RGBA")

            new = Image.open(
                SPRITES
                / f"{new_prefix}{i:02}.png"
            ).convert("RGBA")

            diff = ImageChops.difference(
                old.getchannel("A"),
                new.getchannel("A"),
            )

            if diff.getbbox() is not None:
                raise RuntimeError(
                    f"Alpha changé sur "
                    f"{new_prefix}{i:02}.png"
                )

    print("✅ Alpha identique à la géométrie production.")
    print()
    print("✅ Plus aucun rectangle semi-transparent possible.")
    print("✅ Toutes les tiles d'herbe partagent la même matière.")
    print("✅ Toutes les tiles de terre partagent la même matière.")
    print()
    print("Recharge potager_diorama_v1.tmx dans Tiled.")


if __name__ == "__main__":
    main()

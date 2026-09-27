#!/usr/bin/env python3

from __future__ import annotations

import argparse
import shutil
import subprocess
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


# ============================================================
# SAFE CLEANUP
#
# Can be removed now without breaking the current Flutter runtime.
# ============================================================

SAFE_DIRS = [
    "assets/sprite_sources",
    "assets/sprite_exports",

    # Historical screenshots / old visual iteration artefacts.
    "docs/visual-review",
    "docs/art",
]


SAFE_FILES = [
    # Old art / isometric documentation.
    "docs/MAP_COMPOSITION_SPEC.md",
    "docs/analyse-maquettes-art.md",
    "docs/art-gabarit.md",
    "docs/geometrie-ilots.md",
    "docs/sprite-pipeline.md",
    "docs/terrain-kit.md",
    "docs/tiled-isometric-study.md",

    # Art/render ADRs superseded by the orthogonal direction.
    "docs/adr/0006-rendu-hybride-canvas-sprites.md",
    "docs/adr/0007-sources-provisoires-des-sprites-herites.md",
    "docs/adr/0008-tiled-composition-visuelle.md",
    "docs/adr/0009-surface-tile-classe-asset.md",
    "docs/adr/0010-modele-autoring-tiled.md",

    # Obvious backup file.
    "lib/garden/garden_game.dart.before_square_map",
]


OLD_ART_SCRIPTS = [
    "scripts/add_potager_small_decor.py",
    "scripts/apply_new_da_ground.py",
    "scripts/author_surface_kit.py",
    "scripts/build_all_sprites_palette.py",
    "scripts/build_potager_diorama_v2.py",
    "scripts/build_potager_texture_sources.py",
    "scripts/build_premium_island_edges.py",
    "scripts/build_sprite_manifest.py",
    "scripts/build_sprite_palettes.py",
    "scripts/build_surface_tiles.py",
    "scripts/build_tiled_review_map.py",
    "scripts/build_tiled_stone_tiles.py",
    "scripts/build_tiled_tilesets.py",
    "scripts/capture_linux_visuals.py",
    "scripts/capture_potager_visuals.py",
    "scripts/capture_tiled_review.py",
    "scripts/export_sprite.py",
    "scripts/extract_new_da_atlas.py",
    "scripts/extract_plants.py",
    "scripts/fix_new_da_ground.py",
    "scripts/import_growth_tomate.py",
    "scripts/import_new_da_batch_01.py",
    "scripts/import_new_da_batch_02.py",
    "scripts/import_new_da_batch_03.py",
    "scripts/import_new_da_batch_04.py",
    "scripts/import_new_da_batch_05.py",
    "scripts/migrate_legacy_plants.py",
    "scripts/rebuild_potager_square.py",
    "scripts/rebuild_potager_square_island.py",
    "scripts/rebuild_potager_square_premium.py",
    "scripts/replace_new_da_portail.py",
    "scripts/validate_sprites.py",
]


# ============================================================
# RUNTIME PURGE
#
# DO NOT use until GardenGame renders potager_2d_poc.tmx.
# ============================================================

KEEP_MAPS = {
    "potager_2d_poc.tmx",

    "vectoraith_terrain.tsx",
    "vectoraith_crops.tsx",
    "vectoraith_crops_dense.tsx",
    "vectoraith_details.tsx",
    "vectoraith_orchard.tsx",
    "vectoraith_buildings.tsx",
    "vectoraith_soil_growstep.tsx",
}


KEEP_SPRITE_DIRS = {
    "vectoraith_2d",
}


KEEP_DOC_DIRS = {
    "vectoraith-audit",
    "agents",
    "research",
}


KEEP_NEW_SCRIPTS = {
    "import_vectoraith_pack.py",
    "setup_vectoraith_2d_poc.py",
    "build_vectoraith_potager_scene.py",
    "cleanup_old_art_direction.py",
}


# ============================================================
# NEW CANONICAL DOC
# ============================================================

ART_DIRECTION_DOC = """\
# Direction artistique

> Document canonique pour la direction visuelle de Growstep.

## Direction

Growstep utilise désormais une vue **2D orthogonale top-down**.

L'ancienne direction isométrique 80×40, ses assets peints spécifiques,
ses bordures de diorama et son pipeline ORA/exports ne constituent plus
la direction artistique du produit.

## Kit graphique de référence

Le kit actuellement retenu est :

`vectoraith_tileset_farming_sim_essentials`

Pour le premier environnement Growstep, la variante canonique est :

`Original/32x32/Tilesets (Compact)`

Les variantes `ReColor` et `ReShade` restent disponibles pour étude mais
ne doivent pas être mélangées avec `Original` dans une même scène.

## Grille

- orientation Tiled : `orthogonal`
- taille source : `32×32`
- une cellule logique = une cellule Tiled
- pas de projection isométrique
- pas de coordonnées en demi-case nécessaires
- les objets plus grands que 32×32 sont ancrés par leur contact au sol

La taille d'affichage dans Flutter/Flame pourra être supérieure à 32 px.
Le pixel art doit être agrandi avec un filtrage nearest-neighbour.

## Assets Growstep

Les assets VectoRaith effectivement utilisés par Growstep sont copiés sous :

`assets/sprites/vectoraith_2d/`

Le pack source complet reste temporairement à la racine sous :

`vectoraith_tileset_farming_sim_essentials/`

Une fois la sélection stabilisée, le runtime ne devra dépendre que des
assets réellement nécessaires.

## Tiled

Map de travail actuelle :

`assets/maps/potager_2d_poc.tmx`

Tilesets :

- `vectoraith_terrain`
- `vectoraith_crops`
- `vectoraith_crops_dense`
- `vectoraith_details`
- `vectoraith_orchard`
- `vectoraith_buildings`

Organisation cible des layers :

1. `ground`
2. `paths`
3. `soil`
4. `bed_edges`
5. `decor_back`
6. `crops_preview`
7. `decor`
8. `decor_front`
9. `plots`

`plots` contient les positions logiques utilisées par le gameplay.

Les cultures visibles dans Tiled servent de preview. En jeu, leur stade est
déterminé dynamiquement à partir de l'état Growstep.

## Cultures

Le catalogue associe chaque espèce à plusieurs tile IDs correspondant aux
stades de croissance.

Le runtime doit choisir le sprite à partir de :

`espèce + stade`

et non encoder directement la culture dans la map.

## Principes visuels

Le jardin doit être :

- cosy ;
- dense mais lisible ;
- coloré ;
- végétalisé ;
- progressivement personnalisable ;
- moins géométrique qu'une simple grille de farming.

Les chemins servent la circulation visuelle mais ne doivent pas transformer
le jardin en quadrillage.

Les bords doivent être enrichis par des arbres, buissons, fleurs, clôtures,
rochers et petits objets afin de donner l'impression d'un vrai espace clos.

## Ancienne DA

L'ancienne DA isométrique est considérée comme legacy.

Ses sources, exports, documents de recherche et scripts de génération peuvent
être supprimés.

Les anciens sprites/maps runtime seront supprimés uniquement après le passage
effectif de `GardenGame` au renderer orthogonal.
"""


# ============================================================
# HELPERS
# ============================================================

def git_branch() -> str:
    try:
        return subprocess.check_output(
            ["git", "branch", "--show-current"],
            cwd=ROOT,
            text=True,
        ).strip()
    except Exception:
        return ""


def remove_file(path: Path, *, apply: bool) -> None:
    if not path.exists():
        return

    print(f"  FILE  {path.relative_to(ROOT)}")

    if apply:
        path.unlink()


def remove_dir(path: Path, *, apply: bool) -> None:
    if not path.exists():
        return

    count = sum(
        1
        for item in path.rglob("*")
        if item.is_file()
    )

    print(
        f"  DIR   {path.relative_to(ROOT)} "
        f"({count} fichiers)"
    )

    if apply:
        shutil.rmtree(path)


def write_new_doc(*, apply: bool) -> None:
    target = ROOT / "docs" / "art-direction.md"

    print(
        f"  WRITE {target.relative_to(ROOT)}"
    )

    if apply:
        target.write_text(
            ART_DIRECTION_DOC,
            encoding="utf-8",
        )


# ============================================================
# SAFE CLEAN
# ============================================================

def safe_cleanup(*, apply: bool) -> None:
    print()
    print("Ancienne chaîne de production graphique")
    print("---------------------------------------")

    for item in SAFE_DIRS:
        remove_dir(
            ROOT / item,
            apply=apply,
        )

    for item in SAFE_FILES:
        remove_file(
            ROOT / item,
            apply=apply,
        )

    print()
    print("Scripts legacy")
    print("--------------")

    for item in OLD_ART_SCRIPTS:
        remove_file(
            ROOT / item,
            apply=apply,
        )

    print()
    print("Nouvelle documentation")
    print("----------------------")

    write_new_doc(
        apply=apply,
    )


# ============================================================
# RUNTIME PURGE
# ============================================================

def purge_maps(*, apply: bool) -> None:
    maps = ROOT / "assets" / "maps"

    if not maps.exists():
        return

    print()
    print("Anciennes maps / palettes runtime")
    print("--------------------------------")

    for path in sorted(
        maps.iterdir()
    ):
        if not path.is_file():
            continue

        if path.name in KEEP_MAPS:
            continue

        # Preserve any newly-created Vectoraith file even if this script
        # predates it.
        if path.name.startswith("vectoraith_"):
            continue

        remove_file(
            path,
            apply=apply,
        )


def purge_sprites(*, apply: bool) -> None:
    sprites = ROOT / "assets" / "sprites"

    if not sprites.exists():
        return

    print()
    print("Ancienne bibliothèque de sprites runtime")
    print("----------------------------------------")

    for path in sorted(
        sprites.iterdir()
    ):
        if (
            path.is_dir()
            and path.name in KEEP_SPRITE_DIRS
        ):
            continue

        # Future Vectoraith additions remain protected.
        if path.name.startswith("vectoraith_"):
            continue

        if path.is_dir():
            remove_dir(
                path,
                apply=apply,
            )
        else:
            remove_file(
                path,
                apply=apply,
            )


def purge_runtime(*, apply: bool) -> None:
    purge_maps(
        apply=apply,
    )

    purge_sprites(
        apply=apply,
    )


# ============================================================
# STALE REFERENCES
# ============================================================

def scan_stale_references() -> None:
    print()
    print("Références legacy restant dans le code")
    print("--------------------------------------")

    needles = (
        "potager.tmx",
        "potager_diorama",
        "potager_square",
        "PotagerGridAdapter",
        "IsoGrid",
        "manifest.json",
        "sprite_sources",
        "sprite_exports",
    )

    roots = [
        ROOT / "lib",
        ROOT / "test",
        ROOT / "pubspec.yaml",
    ]

    found = []

    for root in roots:
        if not root.exists():
            continue

        paths = (
            [root]
            if root.is_file()
            else [
                p
                for p in root.rglob("*")
                if p.is_file()
            ]
        )

        for path in paths:
            try:
                content = path.read_text(
                    encoding="utf-8"
                )
            except Exception:
                continue

            for needle in needles:
                if needle in content:
                    found.append(
                        (
                            path.relative_to(ROOT),
                            needle,
                        )
                    )

    if not found:
        print("  ✓ aucune")
        return

    for path, needle in found:
        print(
            f"  ⚠ {path}: {needle}"
        )

    print()
    print(
        "Ces références sont normales tant que le renderer "
        "orthogonal n'est pas encore branché."
    )


# ============================================================
# MAIN
# ============================================================

def main() -> None:
    parser = argparse.ArgumentParser(
        description=(
            "Remove Growstep's legacy isometric art direction."
        )
    )

    parser.add_argument(
        "--apply",
        action="store_true",
        help="Actually delete/write files.",
    )

    parser.add_argument(
        "--purge-runtime",
        action="store_true",
        help=(
            "Also delete old maps and runtime sprites. "
            "Use only after GardenGame has migrated to 2D."
        ),
    )

    args = parser.parse_args()

    branch = git_branch()

    if branch and branch != "refactor_potager":
        raise SystemExit(
            f"Refus : branche actuelle = {branch!r}\n"
            "Attendu : refactor_potager"
        )

    print()
    print("GROWSTEP — CLEANUP ANCIENNE DA")
    print("==============================")

    if not args.apply:
        print()
        print("MODE DRY-RUN — aucun fichier ne sera modifié.")

    safe_cleanup(
        apply=args.apply,
    )

    if args.purge_runtime:
        print()
        print("!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!")
        print("PURGE RUNTIME DEMANDÉE")
        print("!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!")

        purge_runtime(
            apply=args.apply,
        )

    scan_stale_references()

    print()
    print("==============================")

    if args.apply:
        print("✅ nettoyage appliqué")
    else:
        print("✅ dry-run terminé")

    print()
    print("Vérifie ensuite :")
    print("  git status --short")
    print("  git diff --stat")


if __name__ == "__main__":
    main()

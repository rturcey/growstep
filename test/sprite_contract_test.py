"""Public CLI checks for the modular sprite production contract."""

import subprocess
import sys
import json
import shutil
import tempfile
import unittest
import xml.etree.ElementTree as ET
from pathlib import Path

from PIL import Image


REPO = Path(__file__).resolve().parents[1]
VALIDATOR = REPO / "scripts" / "validate_sprites.py"
SURFACE_BUILDER = REPO / "scripts" / "build_surface_tiles.py"
TILESET_BUILDER = REPO / "scripts" / "build_tiled_tilesets.py"
SPRITE = "potager_plante_tomate_jeune_ordinaire_00"


def contract_fixture(root):
    for directory, suffix in (
        ("sprite_sources", ".yaml"),
        ("sprite_sources", ".ora"),
        ("sprites", ".png"),
        ("sprite_exports/2.0x", ".png"),
        ("sprite_exports/3.0x", ".png"),
    ):
        destination = root / "assets" / directory
        destination.mkdir(parents=True, exist_ok=True)
        shutil.copy2(REPO / "assets" / directory / f"{SPRITE}{suffix}", destination)
    manifest = json.loads((REPO / "assets/sprites/manifest.json").read_text())
    (root / "assets/sprites/manifest.json").write_text(
        json.dumps({f"{SPRITE}.png": manifest[f"{SPRITE}.png"]})
    )


class SpriteContractTest(unittest.TestCase):
    def test_surface_tile_export_detects_a_stale_pixel(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            source_dir = root / "assets/surface_sources"
            sprite_dir = root / "assets/sprites"
            source_dir.mkdir(parents=True)
            sprite_dir.mkdir(parents=True)
            inventory = json.loads((REPO / "assets/surface_sources/inventory.json").read_text())
            inventory["families"] = {"ground_grass": inventory["families"]["ground_grass"]}
            (source_dir / "inventory.json").write_text(json.dumps(inventory))
            shutil.copy2(REPO / "assets/surface_sources/ground_grass_master.ora", source_dir)
            for index in range(5):
                shutil.copy2(REPO / f"assets/sprites/commun_sol_herbe_tile_{index:02}.png", sprite_dir)
            self.assertEqual(subprocess.run([sys.executable, str(SURFACE_BUILDER), "--root", str(root), "--check"], capture_output=True).returncode, 0)
            tile_path = sprite_dir / "commun_sol_herbe_tile_00.png"
            with Image.open(tile_path) as source:
                tile = source.copy()
            tile.putpixel((40, 20), (255, 0, 0, 255))
            tile.save(tile_path)
            result = subprocess.run([sys.executable, str(SURFACE_BUILDER), "--root", str(root), "--check"], capture_output=True, text=True)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("stale surface tile export", result.stderr)

    def test_generated_tsx_and_palette_classification_are_checked(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / "assets/surface_sources").mkdir(parents=True)
            (root / "assets/sprites").mkdir(parents=True)
            (root / "assets/maps").mkdir(parents=True)
            for source, target in (
                ("assets/surface_sources/inventory.json", "assets/surface_sources/inventory.json"),
                ("assets/sprites/manifest.json", "assets/sprites/manifest.json"),
                ("assets/maps/palette_audit.json", "assets/maps/palette_audit.json"),
            ):
                shutil.copy2(REPO / source, root / target)
            result = subprocess.run([sys.executable, str(TILESET_BUILDER), "--root", str(root)], capture_output=True, text=True)
            self.assertEqual(result.returncode, 0, result.stderr)
            check = subprocess.run([sys.executable, str(TILESET_BUILDER), "--root", str(root), "--check"], capture_output=True, text=True)
            self.assertEqual(check.returncode, 0, check.stderr)
            (root / "assets/maps/rocks.tsx").write_text("stale")
            stale = subprocess.run([sys.executable, str(TILESET_BUILDER), "--root", str(root), "--check"], capture_output=True, text=True)
            self.assertIn("generated TSX is stale", stale.stderr)
            audit_path = root / "assets/maps/palette_audit.json"
            audit = json.loads(audit_path.read_text())
            audit.pop(next(iter(audit)))
            audit_path.write_text(json.dumps(audit))
            missing = subprocess.run([sys.executable, str(TILESET_BUILDER), "--root", str(root), "--check"], capture_output=True, text=True)
        self.assertNotEqual(missing.returncode, 0)
        self.assertIn("palette audit must classify every manifest entry", missing.stderr)

    def test_review_map_keeps_skirt_outside_ground_and_palette_excludes_runtime_art(self):
        map_path = REPO / "tools/tiled/review/potager-kit-review.tmx"
        root = ET.parse(map_path).getroot()
        layers = {layer.attrib["name"]: layer for layer in root.findall("layer")}
        def occupied(layer):
            values = [int(value) for value in layers[layer].find("data").text.replace("\n", ",").split(",") if value.strip()]
            return {index for index, value in enumerate(values) if value}
        self.assertTrue(occupied("ground"))
        self.assertTrue(occupied("skirt"))
        self.assertFalse(occupied("ground") & occupied("skirt"))
        names = {group.attrib["name"] for group in root.findall("objectgroup")}
        self.assertTrue({"floor_decor", "vegetation", "rocks", "structures", "props", "edge_overlays", "path_sources"} <= names)
        palette = "\n".join(path.read_text() for path in (REPO / "assets/maps").glob("*.tsx") if path.name != "growstep.tsx")
        self.assertNotIn("potager_decor_bac_potager", palette)
        self.assertNotIn("commun_ombre_contact", palette)
        self.assertNotIn("potager_plante_", palette)

    def test_surface_tiles_have_no_sprite_manifest_or_high_density_exports(self):
        inventory = json.loads((REPO / "assets/surface_sources/inventory.json").read_text())["families"]
        manifest = json.loads((REPO / "assets/sprites/manifest.json").read_text())
        for family in inventory.values():
            for index in range(family["count"]):
                name = f'{family["prefix"]}{index:02}.png'
                self.assertNotIn(name, manifest)
                self.assertFalse((REPO / "assets/sprite_exports/2.0x" / name).exists())
                self.assertFalse((REPO / "assets/sprite_exports/3.0x" / name).exists())

    def test_repository_contract_assets_validate(self):
        result = subprocess.run(
            [sys.executable, str(VALIDATOR)],
            cwd=REPO,
            capture_output=True,
            text=True,
        )
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertRegex(result.stdout, r"validated [1-9][0-9]* sprites?")

    def test_new_png_without_metadata_is_rejected(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            contract_fixture(root)
            shutil.copy2(
                root / "assets/sprites" / f"{SPRITE}.png",
                root / "assets/sprites/potager_plante_tomate_adulte_ordinaire_00.png",
            )
            result = subprocess.run(
                [sys.executable, str(VALIDATOR), "--root", str(root)],
                capture_output=True,
                text=True,
            )
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("missing metadata sheet", result.stderr)

    def test_stale_runtime_bounds_are_rejected(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            contract_fixture(root)
            manifest_path = root / "assets/sprites/manifest.json"
            manifest = json.loads(manifest_path.read_text())
            manifest[f"{SPRITE}.png"]["bbox"] = [0, 0, 10, 10]
            manifest_path.write_text(json.dumps(manifest))
            result = subprocess.run(
                [sys.executable, str(VALIDATOR), "--root", str(root)],
                capture_output=True,
                text=True,
            )
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("runtime manifest bounds", result.stderr)

    def test_unknown_palette_role_is_rejected(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            contract_fixture(root)
            sheet = root / "assets/sprite_sources" / f"{SPRITE}.yaml"
            sheet.write_text(sheet.read_text().replace("feuillage_sauge", "vert_neon"))
            result = subprocess.run(
                [sys.executable, str(VALIDATOR), "--root", str(root)],
                capture_output=True,
                text=True,
            )
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("unknown palette role", result.stderr)

    def test_invisible_alpha_reports_a_rule_instead_of_crashing(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            contract_fixture(root)
            master_path = root / "assets/sprites" / f"{SPRITE}.png"
            with Image.open(master_path) as source:
                image = source.copy()
            image.putalpha(image.getchannel("A").point(lambda value: min(value, 16)))
            image.save(master_path)
            result = subprocess.run(
                [sys.executable, str(VALIDATOR), "--root", str(root)],
                capture_output=True,
                text=True,
            )
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("visible alpha", result.stderr)
        self.assertNotIn("Traceback", result.stderr)


if __name__ == "__main__":
    unittest.main()

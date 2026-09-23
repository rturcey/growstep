"""Public CLI checks for the modular sprite production contract."""

import subprocess
import sys
import json
import shutil
import tempfile
import unittest
from pathlib import Path

from PIL import Image


REPO = Path(__file__).resolve().parents[1]
VALIDATOR = REPO / "scripts" / "validate_sprites.py"
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
    def test_repository_contract_assets_validate(self):
        result = subprocess.run(
            [sys.executable, str(VALIDATOR)],
            cwd=REPO,
            capture_output=True,
            text=True,
        )
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn("validated 1 sprite", result.stdout)

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

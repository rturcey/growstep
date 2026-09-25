"""Rasterize the editor-only review map on Growstep's neutral background."""

import os
import subprocess
import tempfile
from pathlib import Path

from PIL import Image


ROOT = Path(__file__).resolve().parents[1]
MAP = ROOT / "tools" / "tiled" / "review" / "potager-kit-review.tmx"
OUTPUT = MAP.with_suffix(".png")


def main() -> None:
    with tempfile.TemporaryDirectory() as directory:
        transparent = Path(directory) / "review.png"
        subprocess.run(
            ["tmxrasterizer", "-s", "2", str(MAP), str(transparent)],
            check=True,
            env={**os.environ, "QT_QPA_PLATFORM": "offscreen"},
        )
        with Image.open(transparent) as source:
            image = source.convert("RGBA")
        background = Image.new("RGBA", image.size, "#E4EBD5")
        background.alpha_composite(image)
        background.convert("RGB").save(OUTPUT, optimize=True)
    print(f"wrote {OUTPUT.relative_to(ROOT)}")


if __name__ == "__main__":
    main()

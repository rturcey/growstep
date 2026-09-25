"""Generate Tiled TSX collections from the surface inventory and sprite audit.

Run with --check in CI; generated TSX files are never edited in Tiled.
"""

import argparse
import json
import xml.etree.ElementTree as ET
from collections import defaultdict
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
GROUPS = ("ground", "paths", "paths_anchored", "floor_decor", "vegetation", "rocks", "structures", "props")
CANDIDATE_GROUP = "diorama"
STATUSES = {"included", "excluded", "other_island", "runtime_only", "outside_tiled", "deprecated"}


def _xml(name: str, images: list[tuple[str, int, int]], offset: tuple[int, int] | None = None,
         tile_size: tuple[int, int] | None = None) -> bytes:
    tileset = ET.Element("tileset", {
        "version": "1.10", "tiledversion": "1.11.2", "name": name,
        "tilewidth": str(tile_size[0] if tile_size else max(width for _, width, _ in images)),
        "tileheight": str(tile_size[1] if tile_size else max(height for _, _, height in images)),
        "tilecount": str(len(images)), "columns": "0", "objectalignment": "bottom",
    })
    if offset is not None:
        ET.SubElement(tileset, "tileoffset", {"x": str(offset[0]), "y": str(offset[1])})
    for index, (image, width, height) in enumerate(images):
        tile = ET.SubElement(tileset, "tile", {"id": str(index)})
        ET.SubElement(tile, "image", {"source": f"../sprites/{image}", "width": str(width), "height": str(height)})
    ET.indent(tileset, space="  ")
    return ET.tostring(tileset, encoding="utf-8", xml_declaration=True) + b"\n"


def expected_tilesets(root: Path) -> dict[str, bytes]:
    source = root / "assets" / "surface_sources" / "inventory.json"
    families = json.loads(source.read_text(encoding="utf-8"))["families"]
    manifest = json.loads((root / "assets" / "sprites" / "manifest.json").read_text(encoding="utf-8"))
    audit = json.loads((root / "assets" / "maps" / "palette_audit.json").read_text(encoding="utf-8"))
    if set(audit) != set(manifest):
        raise ValueError(f"palette audit must classify every manifest entry (missing={sorted(set(manifest) - set(audit))}, extra={sorted(set(audit) - set(manifest))})")
    for name, entry in audit.items():
        if entry.get("status") not in STATUSES:
            raise ValueError(f"{name}: invalid palette classification")
    grouped: dict[str, list[tuple[str, int, int]]] = defaultdict(list)
    for family in families.values():
        for index in range(family["count"]):
            name = f'{family["prefix"]}{index:02}.png'
            grouped[family["tileset"]].append((name, 80, 40))
    for name, entry in sorted(audit.items()):
        if entry["status"] != "included":
            continue
        category = entry["group"]
        if category not in (*GROUPS, CANDIDATE_GROUP) or category == "ground":
            raise ValueError(f"{name}: invalid anchored sprite group {category}")
        metadata = manifest[name]
        if "anchor" not in metadata:
            raise ValueError(f"{name}: missing manifest anchor")
        delta = (metadata["anchor"][0] - metadata["width"] / 2, metadata["anchor"][1] - metadata["height"])
        # The existing source pack has one shared family: rock (0,-13),
        # barrel (-1,-13), trellis (0,-13), and later sprites (0,-12).
        if abs(delta[0]) > 1 or abs(delta[1] + 13) > 1:
            raise ValueError(f"{name}: anchor delta {delta} has no preview family")
        grouped[category].append((name, metadata["width"], metadata["height"]))
    result = {}
    for group in GROUPS:
        images = sorted(grouped[group])
        if not images:
            raise ValueError(f"empty Tiled palette group: {group}")
        offset = None if group in ("ground", "paths") else (0, -13)
        result[f"{group}.tsx"] = _xml(group, images, offset)
    candidate_images = sorted(grouped[CANDIDATE_GROUP])
    if candidate_images:
        result[f"{CANDIDATE_GROUP}.tsx"] = _xml(
            CANDIDATE_GROUP, candidate_images, (0, -13)
        )
    # Archived PoC maps still reference growstep.tsx with rock at gid 7.
    # Keep that compatibility collection generated as well.
    rock = "commun_decor_rochers_herbe_statique_ordinaire_00.png"
    rock_data = manifest[rock]
    result["growstep.tsx"] = _xml("growstep", sorted(grouped["paths"]) +
                                  [(rock, rock_data["width"], rock_data["height"])], tile_size=(80, 40))
    return result


def build(root: Path, check: bool = False) -> list[str]:
    generated = expected_tilesets(root)
    maps = root / "assets" / "maps"
    problems = []
    for name, contents in generated.items():
        path = maps / name
        if check:
            if not path.exists() or path.read_bytes() != contents:
                problems.append(f"{name}: generated TSX is stale")
        else:
            path.write_bytes(contents)
    return problems


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, default=ROOT)
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()
    try:
        errors = build(args.root, args.check)
    except (OSError, ValueError, KeyError) as error:
        parser.exit(1, f"{error}\n")
    if errors:
        parser.exit(1, "\n".join(errors) + "\n")
    print("Tiled TSX files are current" if args.check else "Tiled TSX files generated")

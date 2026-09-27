#!/usr/bin/env python3
from __future__ import annotations

import shutil
import xml.etree.ElementTree as ET
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

AUTHORING_MAP = ROOT / "assets/maps/potager_2d_authoring.tmx"
RUNTIME_MAP = ROOT / "assets/maps/potager_2d_v1.tmx"
AUTHORING_FIRST_GID = 100_000


def decode_gid(raw_gid: int) -> int:
    # Tiled stores flip flags in the high bits.
    FLIP_MASK = 0xE0000000
    return raw_gid & ~FLIP_MASK


def layer_gids(root: ET.Element) -> set[int]:
    used: set[int] = set()

    for layer in root.findall("layer"):
        data = layer.find("data")
        if data is None:
            continue

        encoding = data.attrib.get("encoding")

        if encoding != "csv":
            raise SystemExit(
                f"Layer {layer.attrib.get('name')} uses encoding={encoding!r}. "
                "This publisher currently expects CSV."
            )

        raw = data.text or ""

        for token in raw.replace("\n", ",").split(","):
            token = token.strip()
            if not token:
                continue

            gid = decode_gid(int(token))
            if gid:
                used.add(gid)

    return used


def tile_count_from_tsx(map_dir: Path, source: str) -> int:
    tsx = (map_dir / source).resolve()

    if not tsx.exists():
        raise RuntimeError(
            f"Tileset file missing: {tsx}"
        )

    root = ET.parse(tsx).getroot()
    count = root.attrib.get("tilecount")

    if count is not None:
        return int(count)

    # Collection-of-images fallback.
    tile_ids = [
        int(tile.attrib["id"])
        for tile in root.findall("tile")
        if "id" in tile.attrib
    ]

    if tile_ids:
        return max(tile_ids) + 1

    raise RuntimeError(
        f"Could not determine tilecount for {tsx}"
    )


def required_tilesets(
    root: ET.Element,
    used_gids: set[int],
) -> set[ET.Element]:
    nodes = list(root.findall("tileset"))

    ranges = []

    for index, node in enumerate(nodes):
        firstgid = int(node.attrib["firstgid"])

        if index + 1 < len(nodes):
            next_firstgid = int(nodes[index + 1].attrib["firstgid"])
            lastgid = next_firstgid - 1
        else:
            source = node.attrib.get("source")
            if source:
                count = tile_count_from_tsx(
                    AUTHORING_MAP.parent,
                    source,
                )
                lastgid = firstgid + count - 1
            else:
                count = int(node.attrib.get("tilecount", "1"))
                lastgid = firstgid + count - 1

        ranges.append(
            (node, firstgid, lastgid)
        )

    required: set[ET.Element] = set()

    for node, firstgid, lastgid in ranges:
        # Always retain the original Growstep runtime tilesets.
        if firstgid < AUTHORING_FIRST_GID:
            required.add(node)
            continue

        if any(firstgid <= gid <= lastgid for gid in used_gids):
            required.add(node)

    return required


def remove_authoring_property(root: ET.Element) -> None:
    properties = root.find("properties")
    if properties is None:
        return

    for prop in list(properties.findall("property")):
        if prop.attrib.get("name") == "growstepAuthoring":
            properties.remove(prop)


def main() -> None:
    if not AUTHORING_MAP.exists():
        raise SystemExit(
            "Authoring map missing:\n"
            f"  {AUTHORING_MAP}\n\n"
            "Run:\n"
            "  python3 scripts/setup_tiled_full_workspace.py"
        )

    tree = ET.parse(AUTHORING_MAP)
    root = tree.getroot()

    used = layer_gids(root)
    keep = required_tilesets(root, used)

    all_tilesets = list(root.findall("tileset"))
    before = len(all_tilesets)

    for node in all_tilesets:
        if node not in keep:
            root.remove(node)

    after = len(root.findall("tileset"))
    remove_authoring_property(root)

    # Back up the current runtime map before replacing it.
    if RUNTIME_MAP.exists():
        backup = RUNTIME_MAP.with_suffix(".before_publish.tmx")
        shutil.copy2(RUNTIME_MAP, backup)

    ET.indent(tree, space="  ")
    tree.write(
        RUNTIME_MAP,
        encoding="utf-8",
        xml_declaration=True,
    )

    print("======================================")
    print("✓ POTAGER PUBLISHED")
    print("======================================")
    print(f"Used GIDs             : {len(used)}")
    print(f"Tilesets before prune : {before}")
    print(f"Tilesets after prune  : {after}")
    print(f"Runtime map           : {RUNTIME_MAP.relative_to(ROOT)}")
    print()
    print("Next:")
    print("  flutter analyze")
    print("  flutter test")


if __name__ == "__main__":
    main()

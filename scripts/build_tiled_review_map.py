"""Build the representative editor-only Potager kit review map.

The surface occupancy drives the optional skirt: a skirt tile is emitted only
in an empty front neighbour of an occupied cell. The edge_overlays object
layer is decorative and can be hidden or deleted without changing this map.
"""

import json
import random
import xml.etree.ElementTree as ET
from pathlib import Path

from build_tiled_tilesets import GROUPS


ROOT = Path(__file__).resolve().parents[1]
MAPS = ROOT / "assets" / "maps"
WIDTH = HEIGHT = 16


def _tilesets(map_root: ET.Element):
    gid = 1
    names = {}
    sizes = {}
    for group in GROUPS:
        source = f"{group}.tsx"
        tileset = ET.parse(MAPS / source).getroot()
        ET.SubElement(map_root, "tileset", {"firstgid": str(gid), "source": f"../../../assets/maps/{source}"})
        for tile in tileset.findall("tile"):
            image = tile.find("image")
            name = Path(image.attrib["source"]).name
            names[name] = gid + int(tile.attrib["id"])
            sizes[name] = (int(image.attrib["width"]), int(image.attrib["height"]))
        gid += int(tileset.attrib["tilecount"])
    return names, sizes


def _layer(root: ET.Element, id: int, name: str, cells: dict[tuple[int, int], int]) -> None:
    layer = ET.SubElement(root, "layer", {"id": str(id), "name": name, "width": str(WIDTH), "height": str(HEIGHT)})
    data = ET.SubElement(layer, "data", {"encoding": "csv"})
    data.text = "\n" + ",\n".join(",".join(str(cells.get((col, row), 0)) for col in range(WIDTH)) for row in range(HEIGHT)) + "\n"


def _object(group: ET.Element, id: int, name: str, asset: str, col: float, row: float, gids: dict, sizes: dict, shadow: str | None = None) -> None:
    width, height = sizes[asset]
    object_ = ET.SubElement(group, "object", {
        "id": str(id), "name": name, "class": group.attrib["name"], "gid": str(gids[asset]),
        "x": str((col + 0.5) * 40), "y": str((row + 0.5) * 40),
        "width": str(round(width / 4, 2)), "height": str(round(height / 4, 2)),
    })
    properties = ET.SubElement(object_, "properties")
    for key, value in (("gridCol", col - 7), ("gridRow", row - 7)):
        ET.SubElement(properties, "property", {"name": key, "type": "float", "value": str(value)})
    if shadow is not None:
        ET.SubElement(properties, "property", {"name": "shadow", "value": shadow})


def build() -> None:
    root = ET.Element("map", {
        "version": "1.10", "tiledversion": "1.11.2", "orientation": "isometric", "renderorder": "right-down",
        "width": str(WIDTH), "height": str(HEIGHT), "tilewidth": "80", "tileheight": "40", "infinite": "0",
        "nextlayerid": "12", "nextobjectid": "100", "backgroundcolor": "#E4EBD5",
    })
    gids, sizes = _tilesets(root)
    occupied = {(col, row) for row in range(2, 13) for col in range(2, 13)
                if 3 <= col + row <= 22 and not ((col < 4 or col > 10) and (row < 4 or row > 10))}
    rng = random.Random(6400)
    surface = {}
    earth = {}
    skirt_faces = {}
    path = {}
    soil_cells = {(col, row) for col, row in occupied if 5 <= col <= 7 and 5 <= row <= 7}
    corners = {frozenset((0, 1)): 0, frozenset((1, 2)): 1,
               frozenset((2, 3)): 2, frozenset((0, 3)): 3}
    for col, row in sorted(occupied):
        exposed = [(col - 1, row) not in occupied, (col, row - 1) not in occupied,
                   (col + 1, row) not in occupied, (col, row + 1) not in occupied]
        sides = {side for missing, side in zip(exposed, (3, 0, 1, 2)) if missing}
        if sides:
            # 00–03 are single sides, 04–07 their adjacent-side corners,
            # 08–11 subtle alternatives to the single sides.
            matched = next((index for pair, index in corners.items() if pair <= sides), None)
            index = 4 + matched if matched is not None else min(sides) + (8 if (col + row) % 3 == 0 else 0)
            surface[(col, row)] = gids[f"commun_sol_bordure_herbe_tile_{index:02}.png"]
        else:
            surface[(col, row)] = gids[f"commun_sol_herbe_tile_{rng.randrange(5):02}.png"]
        if (col, row) in soil_cells:
            soil_exposed = [(col - 1, row) not in soil_cells, (col, row - 1) not in soil_cells,
                            (col + 1, row) not in soil_cells, (col, row + 1) not in soil_cells]
            soil_sides = {side for missing, side in zip(soil_exposed, (3, 0, 1, 2)) if missing}
            corner = next((index for pair, index in corners.items() if pair <= soil_sides), None)
            earth_index = 7 + corner if corner is not None else 3 + min(soil_sides) if soil_sides else (col + row) % 3
            earth[(col, row)] = gids[f"commun_sol_terre_tile_{earth_index:02}.png"]
        for front, face in (((col + 1, row), 1), ((col, row + 1), 2)):
            if front not in occupied and all(0 <= n < WIDTH for n in front):
                skirt_faces[front] = skirt_faces.get(front, 0) | face
    skirt = {
        cell: gids[f"commun_sol_tranche_terre_tile_{({1: 0, 2: 2, 3: 4}[faces] + (cell[0] + cell[1]) % 2):02}.png"]
        for cell, faces in skirt_faces.items()
    }
    for index, cell in enumerate(((5, 7), (6, 8), (7, 9), (8, 10), (9, 11), (10, 12))):
        if cell in occupied:
            path[cell] = gids[f"commun_sol_pas_pierre_tile_{index:02}.png"]
    _layer(root, 1, "skirt", skirt)
    _layer(root, 2, "ground", surface)
    _layer(root, 3, "earth", earth)
    _layer(root, 4, "path", path)

    audit = json.loads((MAPS / "palette_audit.json").read_text())
    by_group = {group: [name for name, entry in audit.items() if entry.get("group") == group and entry["status"] == "included"] for group in GROUPS}
    source_group = ET.SubElement(root, "objectgroup", {"id": "5", "name": "path_sources"})
    source_asset = by_group["paths_anchored"][0]
    _object(source_group, 1, "stone_master_sample", source_asset, 10, 10, gids, sizes, "none")
    placements = {
        "floor_decor": [(4, 5), (5, 4), (9, 5), (4, 9), (10, 8), (8, 4)],
        "vegetation": [(3, 6), (4, 3), (7, 3), (10, 4), (11, 7), (8, 11)],
        "rocks": [(3, 9), (8, 3), (11, 8), (9, 10), (6, 11), (4, 10)],
        "structures": [(5, 3), (7, 4), (8, 8)],
        "props": [(6, 4), (9, 6), (5, 9), (10, 9), (7, 10), (4, 7)],
    }
    object_id = 2
    layer_id = 6
    for group_name, positions in placements.items():
        group = ET.SubElement(root, "objectgroup", {"id": str(layer_id), "name": group_name})
        layer_id += 1
        for index, asset in enumerate(by_group[group_name]):
            col, row = positions[index % len(positions)]
            _object(group, object_id, Path(asset).stem, asset, col, row, gids, sizes, "none" if object_id == 1 else None)
            object_id += 1
    overlay = ET.SubElement(root, "objectgroup", {"id": str(layer_id), "name": "edge_overlays"})
    for asset, col, row in (("commun_bordure_herbe_debordante_statique_ordinaire_00.png", 3, 10),
                            ("commun_bordure_mixte_statique_ordinaire_00.png", 9, 11),
                            ("commun_bordure_rochers_statique_ordinaire_00.png", 11, 9)):
        _object(overlay, object_id, Path(asset).stem, asset, col, row, gids, sizes)
        object_id += 1
    ET.indent(root, space="  ")
    destination = ROOT / "tools" / "tiled" / "review" / "potager-kit-review.tmx"
    destination.write_bytes(ET.tostring(root, encoding="utf-8", xml_declaration=True) + b"\n")
    print(f"wrote {destination.relative_to(ROOT)} with {len(occupied)} ground cells and {len(skirt)} exposed skirt cells")


if __name__ == "__main__":
    build()

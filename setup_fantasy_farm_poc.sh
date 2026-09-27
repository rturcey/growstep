#!/usr/bin/env bash
set -Eeuo pipefail

# Growstep — Fantasy Farm POC setup, de A à Z.
# Usage:
#   ./setup_fantasy_farm_poc.sh [chemin/vers/Fantasy\ Farm\ Asset\ Pack\ Free\ version\ v1.0.zip]
#
# Lance ce script depuis n'importe où dans le dépôt Growstep : il retrouve la
# racine Git, vérifie pubspec.yaml, installe Pillow dans un environnement isolé,
# génère les assets/TSX/audits/POC, puis affiche le git diff.

log()  { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
ok()   { printf '\033[1;32m✓\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m!\033[0m %s\n' "$*" >&2; }
die()  { printf '\033[1;31mERROR:\033[0m %s\n' "$*" >&2; exit 1; }

command -v git >/dev/null 2>&1 || die "git est requis."

if ROOT="$(git rev-parse --show-toplevel 2>/dev/null)"; then
  :
elif [[ -f ./pubspec.yaml ]]; then
  ROOT="$(pwd)"
else
  die "Lance ce script depuis le dépôt Growstep (ou un sous-dossier)."
fi

cd "$ROOT"
[[ -f pubspec.yaml ]] || die "pubspec.yaml introuvable dans $ROOT"

DEFAULT_ZIP="$ROOT/Fantasy Farm Asset Pack Free version v1.0.zip"
ZIP_INPUT="${1:-$DEFAULT_ZIP}"
[[ "$ZIP_INPUT" = /* ]] || ZIP_INPUT="$PWD/$ZIP_INPUT"
[[ -f "$ZIP_INPUT" ]] || die "Pack introuvable : $ZIP_INPUT"
ZIP_INPUT="$(realpath "$ZIP_INPUT")"

log "Racine projet : $ROOT"
log "Pack source    : $ZIP_INPUT"

mkdir -p scripts
PY_SCRIPT="$ROOT/scripts/setup_fantasy_farm_poc.py"

log "Création de scripts/setup_fantasy_farm_poc.py"
cat > "$PY_SCRIPT" <<'PY'
#!/usr/bin/env python3
from __future__ import annotations

import json
import os
import shutil
import statistics
import zipfile
import xml.etree.ElementTree as ET
from pathlib import Path
from xml.dom import minidom
from xml.sax.saxutils import escape

try:
    from PIL import Image, ImageDraw, ImageFont
except ImportError as e:
    raise SystemExit("Pillow est requis") from e

ROOT = Path(__file__).resolve().parents[1]
ZIP = Path(os.environ.get("FANTASY_FARM_ZIP", ROOT / "Fantasy Farm Asset Pack Free version v1.0.zip"))
THIRD = ROOT / "third_party/fantasy_farm_free_v1"
SPR = ROOT / "assets/sprites/fantasy_farm_free"
TSX = ROOT / "assets/maps/fantasy_farm"
AUDIT = ROOT / "docs/fantasy-farm-audit"
CATALOG = ROOT / "assets/maps/fantasy_farm_catalog.tmx"
POC = ROOT / "assets/maps/potager_fantasy_poc.tmx"
PUBSPEC = ROOT / "pubspec.yaml"
TILE = 32
W = H = 20
DYNAMIC = {"Animals", "Player"}


def slug(s):
    out = "".join(c.lower() if c.isalnum() else "_" for c in s)
    while "__" in out:
        out = out.replace("__", "_")
    return out.strip("_")


def extract():
    if not ZIP.exists():
        raise SystemExit(f"Missing {ZIP}")
    if THIRD.exists():
        shutil.rmtree(THIRD)
    THIRD.mkdir(parents=True)
    with zipfile.ZipFile(ZIP) as z:
        z.extractall(THIRD)
    dirs = [p for p in THIRD.iterdir() if p.is_dir()]
    root = dirs[0] if len(dirs) == 1 else THIRD
    if not list(root.rglob("*.png")):
        raise RuntimeError("No PNG in pack")
    return root


def fam(p, root):
    return p.relative_to(root).parts[0]


def size(p):
    with Image.open(p) as im:
        return im.size


def regular(p, root):
    w, h = size(p)
    return fam(p, root) not in DYNAMIC and w % TILE == 0 and h % TILE == 0


def copy_assets(files, root):
    if SPR.exists():
        shutil.rmtree(SPR)
    SPR.mkdir(parents=True)
    copied = {}
    for src in files:
        rel = src.relative_to(root)
        dst = SPR / f"{slug(rel.parent.as_posix())}__{src.name}"
        shutil.copy2(src, dst)
        copied[src] = dst
    return copied


def write_tsx(png, out):
    w, h = size(png)
    cols, rows = w // TILE, h // TILE
    count = cols * rows
    xml = f'''<?xml version="1.0" encoding="UTF-8"?>
<tileset version="1.10" tiledversion="1.11.2" name="{escape(png.stem)}" tilewidth="32" tileheight="32" tilecount="{count}" columns="{cols}" objectalignment="bottom">
  <image source="../../sprites/fantasy_farm_free/{escape(png.name)}" width="{w}" height="{h}"/>
</tileset>
'''
    out.write_text(xml, encoding="utf-8")
    return cols, rows, count


def build_records(files, root, copied):
    if TSX.exists():
        shutil.rmtree(TSX)
    TSX.mkdir(parents=True)
    records = []
    for src in files:
        rel = src.relative_to(root)
        w, h = size(src)
        r = {
            "source": rel.as_posix(),
            "family": fam(src, root),
            "width": w,
            "height": h,
            "copied": copied[src].relative_to(ROOT).as_posix(),
            "regular32": False,
            "tsx": None,
            "columns": None,
            "rows": None,
            "tileCount": None,
        }
        if regular(src, root):
            out = TSX / f"{copied[src].stem}.tsx"
            c, rr, n = write_tsx(copied[src], out)
            r.update({
                "regular32": True,
                "tsx": out.relative_to(ROOT).as_posix(),
                "columns": c,
                "rows": rr,
                "tileCount": n,
            })
        records.append(r)
    return records


def crop(im, tid):
    cols = im.width // TILE
    x = (tid % cols) * TILE
    y = (tid // cols) * TILE
    return im.crop((x, y, x + TILE, y + TILE))


def stats(tile):
    px = [(r, g, b) for r, g, b, a in tile.convert("RGBA").getdata() if a >= 128]
    if not px:
        return 0, 0, 0, 0
    return (
        len(px) / (TILE * TILE),
        statistics.fmean(x[0] for x in px),
        statistics.fmean(x[1] for x in px),
        statistics.fmean(x[2] for x in px),
    )


def choose(path, target):
    with Image.open(path) as raw:
        im = raw.convert("RGBA")
        n = (im.width // TILE) * (im.height // TILE)
        best = (10**18, 0)
        for tid in range(n):
            cov, r, g, b = stats(crop(im, tid))
            if cov < 0.8:
                continue
            d = (
                (r - target[0]) ** 2
                + (g - target[1]) ** 2
                + (b - target[2]) ** 2
                + (1 - cov) * 10000
            )
            if d < best[0]:
                best = (d, tid)
        return best[1]


def nonempty(path):
    with Image.open(path) as raw:
        im = raw.convert("RGBA")
        n = (im.width // TILE) * (im.height // TILE)
        return [i for i in range(n) if stats(crop(im, i))[0] >= 0.08]


def audit(src, out, title):
    with Image.open(src) as raw:
        im = raw.convert("RGBA")
        cols, rows = im.width // TILE, im.height // TILE
        cell, lh, margin, title_h = 64, 14, 8, 22
        canvas = Image.new(
            "RGBA",
            (margin * 2 + cols * cell, margin * 2 + title_h + rows * (cell + lh)),
            (28, 30, 34, 255),
        )
        draw = ImageDraw.Draw(canvas)
        font = ImageFont.load_default()
        draw.text((margin, margin), title, fill="white", font=font)
        for tid in range(cols * rows):
            t = crop(im, tid).resize((cell, cell), Image.Resampling.NEAREST)
            x = margin + (tid % cols) * cell
            y = margin + title_h + (tid // cols) * (cell + lh)
            draw.rectangle((x, y, x + cell - 1, y + cell - 1), fill=(70, 72, 78, 255))
            canvas.alpha_composite(t, (x, y))
            draw.text((x + 2, y + cell), str(tid), fill="white", font=font)
        canvas.save(out)


def build_audit(records, byrel):
    if AUDIT.exists():
        shutil.rmtree(AUDIT)
    AUDIT.mkdir(parents=True)
    for r in records:
        if not r["regular32"]:
            continue
        out = AUDIT / f"{slug(r['source'])}_ids.png"
        audit(byrel[r["source"]], out, r["source"])
        r["audit"] = out.relative_to(ROOT).as_posix()
    (AUDIT / "index.json").write_text(
        json.dumps({"files": records}, indent=2), encoding="utf-8"
    )


def patch_pubspec():
    s = PUBSPEC.read_text(encoding="utf-8")
    line = "    - assets/sprites/fantasy_farm_free/\n"
    if line in s:
        return
    marker = "  assets:\n"
    if marker not in s:
        raise RuntimeError("No flutter assets block in pubspec.yaml")
    i = s.index(marker) + len(marker)
    PUBSPEC.write_text(s[:i] + line + s[i:], encoding="utf-8")


def tsx_source(r):
    return Path(r["tsx"]).relative_to("assets/maps").as_posix()


def catalog(records):
    root = ET.Element("map", {
        "version": "1.10", "tiledversion": "1.11.2", "orientation": "orthogonal",
        "renderorder": "right-down", "width": "1", "height": "1",
        "tilewidth": "32", "tileheight": "32", "infinite": "0",
        "nextlayerid": "2", "nextobjectid": "1",
    })
    gid = 1
    for r in records:
        if not r["regular32"]:
            continue
        ET.SubElement(root, "tileset", {"firstgid": str(gid), "source": tsx_source(r)})
        gid += r["tileCount"]
    layer = ET.SubElement(root, "layer", {"id": "1", "name": "catalogue", "width": "1", "height": "1"})
    ET.SubElement(layer, "data", {"encoding": "csv"}).text = "\n0\n"
    ET.indent(root, space="  ")
    ET.ElementTree(root).write(CATALOG, encoding="utf-8", xml_declaration=True)


def find(records, name):
    name = name.lower()
    return next(
        (r for r in records if r["regular32"] and Path(r["source"]).name.lower() == name),
        None,
    )


def blank():
    return [[0] * W for _ in range(H)]


def csv(a):
    return "\n".join(
        ",".join(map(str, row)) + ("," if y < H - 1 else "")
        for y, row in enumerate(a)
    )


def add_layer(root, i, name, a):
    layer = ET.SubElement(root, "layer", {
        "id": str(i), "name": name, "width": str(W), "height": str(H)
    })
    ET.SubElement(layer, "data", {"encoding": "csv"}).text = "\n" + csv(a) + "\n"


def make_poc(records, byrel):
    regs = [r for r in records if r["regular32"]]
    root = ET.Element("map", {
        "version": "1.10", "tiledversion": "1.11.2", "orientation": "orthogonal",
        "renderorder": "right-down", "width": "20", "height": "20",
        "tilewidth": "32", "tileheight": "32", "infinite": "0",
        "backgroundcolor": "#b9d89b", "nextlayerid": "8", "nextobjectid": "9",
    })
    props = ET.SubElement(root, "properties")
    ET.SubElement(props, "property", {
        "name": "sourcePack", "value": "Fantasy Farm Asset Pack Free v1.0"
    })

    gids = {}
    gid = 1
    for r in regs:
        gids[r["source"]] = gid
        ET.SubElement(root, "tileset", {"firstgid": str(gid), "source": tsx_source(r)})
        gid += r["tileCount"]

    grass, farm, crops = [find(records, n) for n in ("grass.png", "farm_tile.png", "crops.png")]
    if not grass:
        raise RuntimeError("grass.png is not a 32x32 grid")

    gg = gids[grass["source"]] + choose(byrel[grass["source"]], (95, 155, 75))
    if farm:
        pg = gids[farm["source"]] + choose(byrel[farm["source"]], (190, 155, 105))
        sg = gids[farm["source"]] + choose(byrel[farm["source"]], (125, 85, 55))
    else:
        pg = sg = gg

    ground = [[gg] * W for _ in range(H)]
    paths, soil, orchard, plants, decor = blank(), blank(), blank(), blank(), blank()
    plots = [(4, 4), (9, 4), (14, 4), (4, 9), (14, 9), (4, 14), (9, 14), (14, 14)]
    used = set()
    for x, y in plots:
        for yy in (y, y + 1):
            for xx in (x, x + 1):
                used.add((xx, yy))
                soil[yy][xx] = sg

    pcs = {
        (9,6),(10,6),(11,6),(6,7),(7,7),(8,7),(12,7),(13,7),(14,7),(7,8),
        (12,8),(7,9),(8,9),(9,9),(10,9),(11,9),(12,9),(7,10),(8,10),(9,10),
        (10,10),(11,10),(12,10),(7,11),(12,11),(6,12),(7,12),(8,12),(12,12),
        (13,12),(14,12),(8,13),(9,13),(10,13),(11,13),(8,16),(9,16),(10,16),
        (11,16),(9,17),(10,17),(9,18),(10,18),(9,19),(10,19),
    }
    for x, y in pcs - used:
        paths[y][x] = pg

    if crops:
        ids = nonempty(byrel[crops["source"]])
        if ids:
            step = max(1, len(ids) // 8)
            selected = [ids[min(i * step, len(ids) - 1)] for i in range(8)]
            for (x, y), tid in zip(plots, selected):
                cg = gids[crops["source"]] + tid
                for yy in (y, y + 1):
                    for xx in (x, x + 1):
                        plants[yy][xx] = cg

    dec_recs = [find(records, n) for n in ("bushes.png", "flowers.png", "stones.png", "decor_plants.png", "fence.png")]
    cands = []
    for r in [x for x in dec_recs if x]:
        cands += [gids[r["source"]] + i for i in nonempty(byrel[r["source"]])[:8]]
    pos = [(3,2),(6,2),(9,2),(12,2),(16,2),(2,5),(17,5),(2,8),(17,8),(2,11),(17,11),(2,14),(17,14),(3,17),(6,18),(13,18),(16,17)]
    if cands:
        for i, (x, y) in enumerate(pos):
            decor[y][x] = cands[i % len(cands)]

    tree = find(records, "tree1.png")
    if tree:
        ids = nonempty(byrel[tree["source"]])
        for i, (x, y) in enumerate(((0,0),(18,0),(0,18),(18,18))):
            if ids:
                orchard[y][x] = gids[tree["source"]] + ids[i % len(ids)]

    for i, (name, a) in enumerate((
        ("ground", ground), ("paths", paths), ("soil", soil),
        ("orchard_preview", orchard), ("plants_preview", plants), ("decor", decor),
    ), 1):
        add_layer(root, i, name, a)

    og = ET.SubElement(root, "objectgroup", {"id": "7", "name": "plots"})
    species = ["corn", "cabbage", "strawberry", "carrot", "tomato", "pepper", "eggplant", "pumpkin"]
    for i, ((x, y), sp) in enumerate(zip(plots, species), 1):
        obj = ET.SubElement(og, "object", {
            "id": str(i), "name": f"plot_{i-1}", "class": "plot",
            "x": str((x + 1) * TILE), "y": str((y + 1) * TILE),
        })
        ET.SubElement(obj, "point")
        pp = ET.SubElement(obj, "properties")
        ET.SubElement(pp, "property", {"name": "gridX", "value": str(x), "type": "int"})
        ET.SubElement(pp, "property", {"name": "gridY", "value": str(y), "type": "int"})
        ET.SubElement(pp, "property", {"name": "species", "value": sp})

    POC.parent.mkdir(parents=True, exist_ok=True)
    POC.write_bytes(
        minidom.parseString(ET.tostring(root, encoding="utf-8"))
        .toprettyxml(indent="  ", encoding="utf-8")
    )


def main():
    root = extract()
    files = sorted(p for p in root.rglob("*.png") if p.is_file())
    print(f"PNG: {len(files)}")
    for p in files:
        w, h = size(p)
        kind = "32-grid" if regular(p, root) else "sprite/raw"
        print(f"{p.relative_to(root)} -> {w}x{h} {kind}")

    copied = copy_assets(files, root)
    records = build_records(files, root, copied)
    byrel = {s.relative_to(root).as_posix(): d for s, d in copied.items()}
    build_audit(records, byrel)
    patch_pubspec()
    catalog(records)
    make_poc(records, byrel)

    print("\nREADY")
    print(f"Catalog: {CATALOG.relative_to(ROOT)}")
    print(f"POC:     {POC.relative_to(ROOT)}")
    print(f"Audit:   {AUDIT.relative_to(ROOT)}")


if __name__ == "__main__":
    main()
PY
chmod +x "$PY_SCRIPT"

log "Validation syntaxique Python"
if command -v python3 >/dev/null 2>&1; then
  python3 -m py_compile "$PY_SCRIPT"
else
  die "python3 est requis."
fi
ok "Script Python valide"

export FANTASY_FARM_ZIP="$ZIP_INPUT"

if command -v uv >/dev/null 2>&1; then
  log "Exécution avec uv + Pillow isolé"
  uv run --with pillow python "$PY_SCRIPT"
else
  warn "uv absent : utilisation d'un venv local temporaire (.tmp/fantasy-farm-venv)."
  VENV="$ROOT/.tmp/fantasy-farm-venv"
  python3 -m venv "$VENV"
  "$VENV/bin/python" -m pip -q install --upgrade pip
  "$VENV/bin/python" -m pip -q install pillow
  "$VENV/bin/python" "$PY_SCRIPT"
fi

log "Vérification des sorties"
required=(
  "assets/maps/fantasy_farm_catalog.tmx"
  "assets/maps/potager_fantasy_poc.tmx"
  "docs/fantasy-farm-audit/index.json"
  "assets/sprites/fantasy_farm_free"
  "assets/maps/fantasy_farm"
)
for path in "${required[@]}"; do
  [[ -e "$path" ]] || die "Sortie attendue absente : $path"
  ok "$path"
done

grep -Fq 'assets/sprites/fantasy_farm_free/' pubspec.yaml \
  || die "pubspec.yaml n'a pas été patché correctement."
ok "pubspec.yaml référence les nouveaux sprites"

if command -v flutter >/dev/null 2>&1; then
  log "flutter pub get"
  flutter pub get
else
  warn "flutter non trouvé : flutter pub get ignoré."
fi

printf '\n'
log "Résumé Git"
git status --short -- \
  pubspec.yaml \
  scripts/setup_fantasy_farm_poc.py \
  third_party/fantasy_farm_free_v1 \
  assets/sprites/fantasy_farm_free \
  assets/maps/fantasy_farm \
  assets/maps/fantasy_farm_catalog.tmx \
  assets/maps/potager_fantasy_poc.tmx \
  docs/fantasy-farm-audit || true

printf '\n'
ok "Fantasy Farm POC prêt."
printf 'Ouvre dans Tiled : %s\n' "$ROOT/assets/maps/potager_fantasy_poc.tmx"
printf 'Catalogue       : %s\n' "$ROOT/assets/maps/fantasy_farm_catalog.tmx"
printf 'Audit           : %s\n' "$ROOT/docs/fantasy-farm-audit/index.json"

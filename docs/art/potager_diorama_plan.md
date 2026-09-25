# Potager diorama: saturated-first art and candidate plan

Status: design only. No map, sprite, pipeline, runtime, or gameplay implementation is authorized by this document.

## Visual target and decision rule

The primary reference is [`test.png`](../../test.png), as confirmed by the user. The saturated Potager should feel immediately close to it in **density, hierarchy, scale, overlap, and diorama richness** when viewed at phone size. Copying its dog, UI, exact crops, benches, or beds is not the goal. A candidate fails the art test if it still reads as broad lawn with independent one-cell objects, even when every technical test passes.

Compose the saturated state first, with all eight dynamic plants visible. The cultivated center, rear canopies, path, and edges should together occupy most of the island's readable surface. Then check that the initial and intermediate states remain coherent without moving contacts or hiding unpurchased gameplay positions. A prepared garden may be visually rich before every position is bought.

The Growstep art bible still governs 2:1 projection, material and lighting, 4× editable masters, deterministic exports, ground anchors, contact shadows, fixed phone scale, clear interactions, and visible earth skirt. Its older one-cell bed size class is not suitable for the proposed **multi-cell cultivation surround**. That class and its validator limit must be explicitly added during asset production; do not shrink the new beds to pass an old limit.

## Current audit and technical boundary

The current working-tree `assets/maps/potager.tmx` is a 14×14 isometric map with 71 painted ground cells, 16 skirt cells, 8 small stone-path cells, 8 stable plot markers, and 23 environmental objects. A fresh static Tiled raster shows separated shrubs, an isolated barrel/can cluster, a small arch, extensive lawn, and a stair-stepped outline. The checked-in issue-64 phone captures predate the uncommitted map changes and cannot establish the current phone crop. The map is a technical baseline, not the composition to preserve.

The eight contacts and their save order remain immutable:

| Visual row | Fixed plot identities |
| --- | --- |
| Rear | `0` at (75,150), `4` at (195,150), `7` at (315,150) |
| Middle | `5` at (115,230), `1` at (275,230) |
| Front | `2` at (75,310), `6` at (195,310), `3` at (315,310) |

Saved order stays `0,1,2,3,4,5,6,7`; visual grouping never renumbers it. Soil footprints, plants, stages, progress, selection, and hit testing keep their current gameplay behavior during the **first visual proof**. Static environment placement belongs in Tiled and uses whole/half-cell logical coordinates, manifest-derived ground anchors, and existing depth sorting.

The runtime currently also stores these plot contacts in Dart and requires a named `east_upper_rock` object while parsing the map. Both are valid technical debt. They are **after visual acceptance**, not prerequisites for the candidate. For the first proof, retain the rock under that name as an intentional member of a cluster and verify that Tiled plot markers exactly match the existing runtime contacts. A capture-only map selection can load `potager_diorama_v1.tmx` without switching the production map.

## Audit of the available art vocabulary

| Judgment | Assets and reason |
| --- | --- |
| Strong enough to retain | Existing grass, earth, border and skirt surface tiles; the six small cream stone tiles as accents; one flowering trellis; the barrel and watering can. They supply consistent material and garden identity. |
| Useful inside larger compositions | Existing high/low bosquets, mixed rock/grass overlays, and two low grass tufts. They can connect hero masses but do not supply the massing on their own. |
| Redundant | Several near-identical rock variants, alternate trellises, barrel/can/seed-box composites, and scattered small ground stamps. Repeating these would reproduce the current stamp-like look. |
| Misleading | Tulip, sunflower and lavender environmental stamps, seedling crates, and the old tiny raised plot boxes resemble growable or purchased content. Dynamic tomato, carrot and courgette must remain the only crop-like protagonists. The old boxes are excluded **as assets**, not as a cultivation design idea. |
| Missing | Two substantial canopy silhouettes, multi-contact low cultivation frames, a compact gardening utility cluster, a dense side-corner composition, a long foreground overhang, and larger path pieces. Each has a specific location and role below. |

All reviewed Potager palette sprites have ORA/YAML sources and entries in the runtime manifest. Surface tiles follow their separate family-ORA inventory and generated TSX pipeline. None of the generated PNG derivatives or TSX files should be edited by hand.

### Exact existing assets retained

- **Surface families:** `commun_sol_herbe_tile_00.png`…`04.png`; `commun_sol_bordure_herbe_tile_00.png`…`11.png`; `commun_sol_tranche_terre_tile_00.png`…`05.png`; `commun_sol_terre_tile_00.png`…`10.png`; `commun_sol_pas_pierre_tile_00.png`…`05.png`. Earth tiles now provide broad permanent soil fields under the new low frames; the current dynamic footprint remains drawn at each purchased contact.
- **Rear and side vegetation:** `commun_decor_bosquet_haut_statique_ordinaire_00.png`, `commun_decor_bosquet_haut_statique_ordinaire_02.png`, `commun_decor_bosquet_bas_statique_ordinaire_00.png`, `commun_decor_bosquet_bas_statique_ordinaire_01.png`, `commun_bordure_herbe_debordante_statique_ordinaire_00.png`, `commun_bordure_mixte_statique_ordinaire_00.png`.
- **Rocks:** `commun_decor_rochers_herbe_statique_ordinaire_00.png`, `commun_decor_rochers_statique_ordinaire_03.png`, `commun_bordure_rochers_statique_ordinaire_00.png`.
- **Structure and tools:** `commun_decor_treillis_bois_fleuri_statique_ordinaire_00.png`, `commun_decor_tonneau_bois_statique_ordinaire_00.png`, `potager_decor_arrosoir_metal_statique_ordinaire_00.png`.
- **Cluster-only low detail:** `commun_decor_touffe_herbe_statique_ordinaire_00.png`, `commun_decor_touffe_herbe_statique_ordinaire_01.png`.

The existing trellis is the lightweight structural focal point. There is **no new work shelter**: a shed-like mass would fill space but would not bring the scene closer to the reference's canopy, cultivated beds, and open-air garden utility.

### Exact Potager-relevant assets intentionally excluded from candidate placement

- **Old one-cell beds and seedling look:** `potager_decor_bac_potager_statique_ordinaire_00.png`, `potager_decor_bac_potager_statique_ordinaire_01.png`, `potager_decor_bac_potager_statique_ordinaire_02.png`, `potager_decor_bac_potager_statique_ordinaire_03.png`, `potager_decor_caisse_semis_statique_ordinaire_00.png`, `potager_decor_outils_jardin_statique_ordinaire_00.png`, `potager_decor_stockage_jardin_statique_ordinaire_00.png`.
- **Crop-like floral stamps:** `commun_decor_fleurs_blanches_statique_ordinaire_00.png` (reads as tulips), `commun_decor_fleurs_jaunes_statique_ordinaire_00.png` (sunflowers), `commun_decor_trefle_statique_ordinaire_00.png` (lavender), `commun_decor_herbes_folles_statique_ordinaire_00.png` (seedling-like).
- **Duplicate clusters or shapes:** `potager_decor_coin_jardinage_statique_ordinaire_00.png`, `commun_decor_treillis_bois_fleuri_statique_ordinaire_01.png`, `commun_decor_treillis_bois_statique_ordinaire_00.png`, `commun_decor_rochers_statique_ordinaire_00.png`, `commun_decor_rochers_statique_ordinaire_01.png`, `commun_decor_rochers_statique_ordinaire_02.png`, `commun_decor_bosquet_haut_statique_ordinaire_01.png`, `commun_decor_bosquet_bas_statique_ordinaire_02.png`.
- **Superseded path alternatives:** `commun_sol_pas_pierre_statique_ordinaire_00.png`…`05.png` as placed objects, and `commun_sol_chemin_pierres_droit_statique_ordinaire_00.png`, `commun_sol_chemin_pierres_courbe_gauche_statique_ordinaire_00.png`, `commun_sol_chemin_pierres_courbe_droite_statique_ordinaire_00.png`. The retained surface stones can still accent the new main path.

Exclusion means no placement in this candidate, not deletion from the shared asset library.

## Final macro composition and saturated hierarchy

| Area | Authored composition | Reference relationship |
| --- | --- | --- |
| Rear-left | A substantial non-fruiting tree/canopy overlaps the existing high bosquets and flowering trellis. A low mixed vegetation corner binds it to the island's left edge. | Emulates the tall leafy mass, layered side garden and lightweight timber visible at the upper-left of `test.png`, without copying its tree contents. |
| Rear-right | A second, differently shaped non-fruiting canopy and existing rocks/shrubs form the opposite high mass. Leave a narrow visual opening above the center. | Emulates the large right-hand canopy and rich rear frame, not a shed silhouette. |
| Center | Four broad, low, **two-contact cultivation surrounds** sit around a shared path. They use continuous Tiled earth areas and low irregular rims; eight dynamic crop contacts remain fixed. | Emulates the large proportion of the reference occupied by cultivated beds and soil. The four surrounds read together as one vegetable garden, not four isolated boxes. |
| Utility side | One authored rack/low timber/foliage sprite groups the existing barrel and watering can in a compact open-air work cluster beside the path. | Emulates the watering tools, pots, barrel and lived-in working edge without adding a building. |
| Foreground and flanks | One long, asymmetric front overhang joins existing rocks, grass and mixed edge assets. The opposite side uses existing overlays; the entrance stays clear. | Emulates the deep, vegetated front lip and irregular island edge while keeping the earth skirt visible. |

At saturated phone size the intended read is: **(1)** whole island silhouette; **(2)** one broad cultivated center with eight clearly legible crop crowns; **(3)** unequal canopy and trellis/utility masses; **(4)** a connected pale path; **(5)** low edge details. The bed field should take a large fraction of the readable island. Rear and side volumes overlap one another and the boundary; front planting and low overhang fill the foreground without forming a wall. The grid remains a placement system and should be nearly impossible to reconstruct from the screenshot.

The only deliberate calm areas are the entrance landing and small circulation pockets immediately beside the path. Do not reserve a broad lawn behind or between the beds to make the initial state symmetrical.

## Cultivation treatment

The old `potager_decor_bac_potager_*` sprites were one-cell boxes; do not scale or repeat them. Author four different low multi-cell surrounds, each serving **two fixed contacts**:

| Surround | Contacts | Plan shape and crop clearance |
| --- | --- | --- |
| Rear band | `0 + 4` | Wide, shallow soil/rim shape that joins two rear planting positions. |
| Right diagonal band | `7 + 1` | Longer staggered shape, a different silhouette from the rear band. |
| Left diagonal band | `5 + 2` | Companion staggered shape; enough space for foliage to spill over the low edge. |
| Front band | `6 + 3` | Wide low shape that helps carry the cultivation field toward the viewer. |

The four forms and the earth tiles between them should read as one designed cultivation area around a path, while maintaining visible gaps for walking. Approximate envelopes are 205×65 for the two horizontal bands and 145×130 for the two diagonal bands; these are multi-cell silhouettes, not new logical hit regions. The soil base comes from Tiled earth tiles under the plants. The anchored frames carry low irregular timber/earth rims, generally 6–10 logical pixels above the local surface, and render behind dynamic crops so no rim cuts across a plant. Their open interior and contact spacing must allow mature tomato, carrot and courgette foliage to overflow naturally.

The permanent prepared soil and frame do not grant or display ownership. Purchased positions still receive their existing dynamic soil footprint and plant; unpurchased positions remain non-interactive beyond the existing purchase flow and must be distinguishable through the existing selection/purchase UI. Review the initial state specifically for false ownership cues, while judging composition primarily in the saturated state.

## Exact new anchored sprites

The **nine** proposed anchored sprites are all high-value multi-cell forms. Approximate envelopes are visible 1× bounds, not logical cell limits. The reference column names the part of `test.png` each asset helps emulate.

| Proposed canonical ID, before `.png` | Envelope | Reference area and exact compositional job |
| --- | --- | --- |
| `potager_decor_arbre_canopee_ouest_statique_ordinaire_00` | 160×145 | Upper-left tree/canopy: makes one high rear-left silhouette and binds trellis plus small shrubs into one mass; no fruit or crop cues. |
| `potager_decor_arbre_canopee_est_statique_ordinaire_00` | 155×140 | Upper-right canopy: supplies a different, broader counterweight and rear depth without a building; non-fruiting and asymmetric to the west tree. |
| `potager_decor_coin_vegetal_ouest_statique_ordinaire_00` | 150×85 | Dense left garden margin below the tree: joins foliage, one substantial rock, low grass and non-crop blossom texture to the edge; bridges high canopy to low foreground. This is a mixed corner, not another generic shrub. |
| `potager_decor_station_jardinage_statique_ordinaire_00` | 145×85 | Reference's tools/pots/utility pocket: a lightweight timber rack or short fence with foliage and tool storage, placed beside the existing barrel and can; one compact work cluster, no shed or seedlings. |
| `potager_decor_cadre_culture_arriere_statique_ordinaire_00` | 205×65 | Rear cultivated beds: one open low surround for contacts `0+4`, making soil and two mature crops read as a substantial shared bed. |
| `potager_decor_cadre_culture_droite_statique_ordinaire_00` | 145×130 | Right cultivated beds: staggered open surround for `7+1`, filling the upper-right middle without masking either crop. |
| `potager_decor_cadre_culture_gauche_statique_ordinaire_00` | 145×130 | Left middle/front beds: staggered open surround for `5+2`, giving the cultivated area depth and a different edge rhythm. |
| `potager_decor_cadre_culture_avant_statique_ordinaire_00` | 205×65 | Front cultivated beds: open surround for `6+3`, carrying the reference's broad bed motif toward the entrance while keeping crops dominant. |
| `potager_bordure_frange_avant_statique_ordinaire_00` | 230×65 | Reference's thick vegetated front lip: one irregular rock/grass/low-foliage overhang crossing several cells, leaving the entrance opening and ≥40% of the front earth skirt visible. |

The two canopies are the only new tall masses. The four cultivation assets have different horizontal/diagonal silhouettes and jobs; they are not four interchangeable copies. Existing small shrubs and rocks fill joints between these nine forms. No additional tiny flowers, pebbles, tools, or standalone bushes are proposed.

Production contract: 4× editable ORA and YAML per anchored sprite, deterministic 1×/2×/3× exports, manifest ground anchor and contact-shadow metadata, generated TSX, and in-scene review. The tree assets use the existing `tree` size class. Add explicit size classes for low multi-cell cultivation surrounds and long edge overlays, with limits matching their justified envelopes; update the art bible and validator together. Do not reduce their scale to the old 80-pixel `bed` limit. New candidate sprites belong in a separate generated `diorama.tsx` palette to keep existing GIDs stable; Tiled object-layer placement, not the palette name, supplies scene role.

## Path: route first, tiles second

The route enters at the front lip **between plots 6 and 3**, bends behind the front band, passes through the open pocket between plots 5 and 1, and aims toward the rear trellis. A shorter branch indicates access to the right-hand utility cluster. It must remain one perceptual network, with a broad near entrance, irregular slab spacing, and vegetation partially overlapping outer stone edges. It never crosses a 44×44 hit square or the visible planted contact.

For Tiled blockout, the main control sequence on the existing logical grid is approximately `(4,4) → (4,3) → (3,2) → (2,1) → (1,1) → (0,0)`; these are route controls, not a mandate to center one stone in each cell. Tiled artwork should combine adjacent controls into wider slab groups, stagger apparent centers within the tile artwork, and allow some green gaps. The rear and utility branches terminate before plot-contact exclusion zones. The exact painted cells are settled in Tiled against the saturated crops, not converted into Dart coordinates.

That route needs **six** new transparent 80×40 surface tiles in one 4× ORA family:

| Proposed file | Route purpose | Reference area |
| --- | --- | --- |
| `potager_sol_dalles_chemin_tile_00.png` | Uneven broad entrance threshold, used once | Wide near-edge entrance stones |
| `potager_sol_dalles_chemin_tile_01.png` | Main large slab group, with an off-center silhouette | Broad central pavers |
| `potager_sol_dalles_chemin_tile_02.png` | Different broken/slipped slab group, alternating with `01` | Irregular paver cadence |
| `potager_sol_dalles_chemin_tile_03.png` | Leftward inside bend | Curving left side of the path |
| `potager_sol_dalles_chemin_tile_04.png` | Rightward outside bend | Curving right side of the path |
| `potager_sol_dalles_chemin_tile_05.png` | Tapered branch/end piece | Short destinations by beds and utility |

The six existing small stone tiles may add a few transitions; they must not form a visible chain. New path tiles share edge-compatible stone shapes across adjacent cells and stay transparent outside the stones. The surface exporter currently seals non-skirt tiles as opaque diamonds, so this new path family needs an explicit transparency exception. Generate a separate `paths_diorama.tsx` palette and reference it after the legacy GID ranges in the candidate. Do not hand-patch exports or shift the known-good map's TSX IDs.

## Island-edge strategy

Keep a connected logical ground footprint but redraw its occupied outline in Tiled to create **unequal lobes**, not a symmetric diamond or repeated staircase. The rear canopies and mixed side corner overhang the top/side border; existing rocks and grass bridge exposed seams. The new long front fringe plus existing edge overlays break the foreground sequence at a larger scale than one cell. Vary where the earth skirt is exposed, but leave at least 40% of the projected front skirt visible and leave a clear opening at the path entrance. No ring of repeated flower/rock stamps should trace the boundary.

## Candidate boundaries, checks, and visual-pass sequence

1. Make `assets/maps/potager_diorama_v1.tmx` as a separate candidate. Keep the current working-tree map untouched. Preserve 14×14 origin/projection, required layer semantics, all eight named plot markers and exact half-cell values, existing gameplay/save order, dynamic plant rendering, and the temporary `east_upper_rock` parser sentinel. No new static Dart coordinates.
2. Load the candidate only through a reversible capture/test selector until it passes review. The first proof may keep the current Dart plot-contact source and rock parser. Runtime authority cleanup follows **after** visual acceptance.
3. Add only the nine justified anchored sprites and six path surface tiles through their canonical pipelines. Paint the static ground, soil, path, structures, vegetation, rocks, props and edge overlays in Tiled. Protect mature crop silhouettes and tap squares in the saturated state.
4. At every meaningful pass, capture saturated and initial views at 390×844 and 375×667; add intermediate views for the cultivation pass. Compare saturated first with `test.png` for density, hierarchy, scale, overlap and edge richness. Run Tiled generation checks, sprite validation, map parsing, contact and hit tests, analyzer and Flutter tests before a production switch. The current Snap Flutter launcher cannot run here, so those gates require an accessible Flutter SDK.

Stop after each pass for **external visual review**. Do not infer approval from code checks or from our own visual judgment:

`silhouette + hero masses`
→ external review
→ `cultivation + path`
→ external review
→ `edges + overlaps`
→ external review
→ `micro-decoration`
→ final review

The final pass may add only small details that strengthen the already accepted composition. It is not a way to repair an unresolved sparse macro layout.

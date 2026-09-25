# Issue #68 — Potager diorama, Pass 1.5 review

**Decision: Pass 1 approved by external visual review.** Pass 1 was returned
for a stronger rear-right tree and a more continuous island edge. The revised
captures and five hero sprites were accepted as the basis for Pass 2. This
approval does not extend to later passes or production promotion.

## Requested captures

| State | 390 × 844 | 375 × 667 |
| --- | --- | --- |
| Saturated | [color](potager_sature_390x844.png) · [grayscale](potager_sature_390x844_gris.png) | [color](potager_sature_375x667.png) · [grayscale](potager_sature_375x667_gris.png) |
| Initial | [color](potager_initial_390x844.png) · [grayscale](potager_initial_390x844_gris.png) | [color](potager_initial_375x667.png) · [grayscale](potager_initial_375x667_gris.png) |

Inspect the [five assets at actual 1× scale](hero_assets_1x.png) as well as
their overlap in both phone layouts. [`test.png`](../../../test.png) remains
the visual reference. The central cultivation area is deliberately open.

## Pass 1.5 changes

| Element | Current treatment |
| --- | --- |
| West rear canopy | Original Pass 1 painting and placement retained. |
| East rear canopy | Repainted from the approved west-tree style and reference image as a taller tree with a visible trunk. Its visible alpha bounds are approximately 155 × 120 logical pixels. |
| West vegetation corner | Original Pass 1 painting and placement retained. |
| Gardening station | Original painting retained, scaled down and moved forward of the east tree so that their silhouettes separate. |
| Front-edge fringe | Repainted with a deeper, unequal vegetation and earth silhouette; the entrance remains open. The candidate scales the painted source across the front border. |
| Ground and skirt | Recomputed border tiles for the revised connected ground outline, removed the front ground spur, and kept a connected stretch of the existing earth-skirt tiles visible below the front fringe. Detached brown side teeth were removed. |

The east canopy and front fringe were produced with the built-in imagegen tool
using their prior sprites and `test.png` as references. Their transparent
paintings were stored in one-layer ORA sources with YAML contacts, then exported
through the deterministic 4×/3×/2× sprite pipeline. The other three hero
paintings were not regenerated. No new central decoration, cultivation
surround, or path work was added.

## Reproduction and technical status

From the repository root:

```sh
flutter test test/visual_capture_test.dart \
  --dart-define=GROWSTEP_POTAGER_MAP=potager_diorama_v1.tmx \
  --dart-define=GROWSTEP_CAPTURE_DIR=/tmp/issue-68-captures \
  --dart-define=GROWSTEP_CAPTURE_FULL_SCREEN=true
```

The eight linked PNGs were selected from this final run. The candidate loads
through the real `GardenGame`; normal play still defaults to `potager.tmx`.
That production map and all production TSX files remain unchanged. Existing
production GID ranges are fixed, and the candidate-only `diorama.tsx` starts
at GID 76. All eight saved plot identities and contacts remain unchanged.

`flutter analyze`, the full `flutter test` suite, deterministic capture test,
candidate palette check, surface export check, and targeted validation of all
five hero sheets pass. The repository-wide sprite validator still reports the
pre-existing legacy production-sheet/manifest errors; those files were not
changed as part of #68.

## Review points

- Judge the east tree's crown, trunk and separation from the station at both
  sizes. Its ORA/YAML validity alone is insufficient.
- The front edge and visible earth were accepted as a sufficient frame for
  Pass 2. The geometric right-flank turn near the rock remains a known visual
  debt for Pass 3 (#70), not additional Pass 1 decoration.
- Judge all five paintings and their relative scale against `test.png`. No
  asset is self-approved; request external art production for any painting
  whose quality or silhouette remains insufficient.

Do not infer Pass 2 approval from these captures. Production promotion and
micro-decoration remain outside this review.

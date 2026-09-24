# Growstep environment sprite pack v3 (clean)

This pack replaces the previous generated-atlas extraction approach.

## Guarantees
- Existing canonical sprites are copied unchanged.
- No tomato/carrot/zucchini variations were added.
- New sprites are built from the original transparent canonical ORA assets or, for stepping stones/shadows only, drawn directly on transparent canvases.
- No sprite is cropped from a preview sheet.
- ORA files use the same flattened one-layer convention as the provided canonical ORA files.
- 4x ORA source + 3x/2x PNG exports are included.
- Minimum transparent safety margins are enforced.

## Scope
New families: raised-bed variants, spaced stepping stones with grass, intermediate greenery/flowers, bush variants, rock variants, island-edge overlays, garden hero clusters, flowering trellises, contact shadows.

The bench/wheelbarrow/compost/bin/birdhouse/pots from v2 were intentionally removed because they were not derivable from canonical source art at acceptable quality without creating new standalone illustrations.


## Structure corrigée v3.1
Le dossier `sprites/` contient les PNG 4x/runtime et `manifest.json`, comme dans le ZIP source.

# Growstep — Tiled workspace

Authoring library intentionally limited to:

- Variant: Original
- Resolution: 32×32
- Tilesets attached: 45

ReColor and ReShade remain imported in the repository but are NOT attached
to `potager_2d_authoring.tmx`.

Families:
- RPG Maker autotiles: 2
- Sprites: 14
- Tilesets (Compact): 11
- Tilesets (Modular): 18

## Workflow

Open:

    tiled growstep.tiled-project

Then:

    assets/maps/potager_2d_authoring.tmx

Publish to the runtime map with:

    python3 scripts/publish_potager_map.py

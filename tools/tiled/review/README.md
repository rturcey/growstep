# Revue du kit Tiled Potager (#64)

Ouvrir `potager-kit-review.tmx` dans Tiled. Cette scène de démonstration est hors du bundle Flutter et ne fixe pas la composition finale du Potager. Elle exerce les surface tiles, les six pas japonais et les palettes d'anchored sprites ; `path_sources` montre un master de pas uniquement pour comparaison. La couche `edge_overlays` peut être masquée ou supprimée sans modifier le sol ou sa tranche.

La capture `potager-kit-review.png` vient de `tmxrasterizer` à 2×, puis d'un fond uni `#E4EBD5` appliqué à la transparence de la capture. Elle sert à la revue visuelle externe : vérifier l'absence de damier et de joints, la cohérence des échelles, les points de contact, la lisibilité des gros objets et la continuité de la tranche. La validation artistique finale appartient au relecteur humain.

Pour régénérer la map et la capture depuis la racine du dépôt :

```sh
python3 scripts/build_tiled_review_map.py
python3 scripts/capture_tiled_review.py
```

`tmxrasterizer` exporte de la transparence autour de l'îlot ; la capture commitée est composée sur la couleur de fond de Growstep pour faciliter la lecture.

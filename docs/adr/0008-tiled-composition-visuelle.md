# Tiled isométrique natif comme source de vérité de la composition visuelle

> Décision issue de l'évaluation Tiled. Inverse la décision #1 de `MAP_COMPOSITION_SPEC.md` (« aucun moteur de niveaux ni DSL externe ») et l'aspect « définition Dart immuable » de l'ADR-0006.

La composition visuelle du Potager est aujourd'hui rédigée en constantes Dart (`PotagerComposition`, `PotagerPath`, `PotagerPilotScene`). Chaque itération visuelle passe par une modification de code : lent, difficile à calibrer, et les résultats déclinent souvent. Tiled Map Editor devient l'outil de composition visuelle humaine. Une carte Tiled isométrique native 80×40 stocke les positions des tuiles et des objets. La grille logique `(gridCol, gridRow)` est la source de vérité spatiale, pas les coordonnées pixel libres. Le paquet `flame_tiled` rend les tile layers via `RenderableTiledMap`, tenu comme membre de `GardenGame` et rendu manuellement entre le terrain Canvas et la scène dynamique. Les object layers sont parsés par Growstep et rendus via le pipeline `_SceneObject` existant. Le renderer Flame, le transform d'artboard, le tri en profondeur, les ombres de contact et tout le gameplay restent inchangés.

Tiled possède le placement visuel statique (où sont les rochers, le treillis, les pas de pierre, les bosquets). Growstep possède l'état du jeu (emplacements achetés, espèces, étapes, florins, progression). Les IDs stables sont des noms humainement lisibles (`plot_0`, `east_barrel`) dans le champ `name` de l'objet Tiled, jamais l'ID numérique interne de Tiled. Le manifeste des sprites reste la source canonique des ground anchors.

## Options écartées

- **`TiledComponent` comme enfant Flame** : `priority` contrôle l'ordre entre composants enfants d'un même parent ; `FlameGame.render()` n'est pas un sibling de `TiledComponent`. Le rendu de Tiled ne peut pas être garanti avant le contenu de `GardenGame.render()` via `priority`. Refusé pour le PoC ; `RenderableTiledMap` est rendu manuellement. Direction long terme : extraire le rendu en composants frères si justifié.
- **Carte Tiled orthogonale** : évaluée en première intention car les coordonnées d'objets sont en pixels de l'artboard sans conversion. Refusée car la grille isométrique native 80×40 correspond exactement à la projection `IsoGrid` existante et permet le pinceau Stamp Brush sur une grille isométrique visible, qui est le workflow cible.
- **Éditeur visuel personnalisé in-app** : évalué comme Option A. Refusé car Tiled est mature, gère le placement sur grille et le pinceau de tuiles, et ne nécessite pas de construire un éditeur.
- **Placement libre au pixel** : refusé. La cellule de grille définit le contact logique ; les objets peuvent dépasser visuellement mais le placement n'est jamais libre au pixel.

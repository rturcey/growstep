# Direction artistique

> Document canonique pour la direction visuelle de Growstep.

## Direction

Growstep utilise désormais une vue **2D orthogonale top-down**.

L'ancienne direction isométrique 80×40, ses assets peints spécifiques,
ses bordures de diorama et son pipeline ORA/exports ne constituent plus
la direction artistique du produit.

## Kit graphique de référence

Le kit actuellement retenu est :

`vectoraith_tileset_farming_sim_essentials`

Pour le premier environnement Growstep, la variante canonique est :

`Original/32x32/Tilesets (Compact)`

Les variantes `ReColor` et `ReShade` restent disponibles pour étude mais
ne doivent pas être mélangées avec `Original` dans une même scène.

## Grille

- orientation Tiled : `orthogonal`
- taille source : `32×32`
- une cellule logique = une cellule Tiled
- pas de projection isométrique
- pas de coordonnées en demi-case nécessaires
- les objets plus grands que 32×32 sont ancrés par leur contact au sol

La taille d'affichage dans Flutter/Flame pourra être supérieure à 32 px.
Le pixel art doit être agrandi avec un filtrage nearest-neighbour.

## Assets Growstep

Les assets VectoRaith effectivement utilisés par Growstep sont copiés sous :

`assets/sprites/vectoraith_2d/`

Le pack source complet reste temporairement à la racine sous :

`vectoraith_tileset_farming_sim_essentials/`

Une fois la sélection stabilisée, le runtime ne devra dépendre que des
assets réellement nécessaires.

## Tiled

Map de travail actuelle :

`assets/maps/potager_2d_poc.tmx`

Tilesets :

- `vectoraith_terrain`
- `vectoraith_crops`
- `vectoraith_crops_dense`
- `vectoraith_details`
- `vectoraith_orchard`
- `vectoraith_buildings`

Organisation cible des layers :

1. `ground`
2. `paths`
3. `soil`
4. `bed_edges`
5. `decor_back`
6. `crops_preview`
7. `decor`
8. `decor_front`
9. `plots`

`plots` contient les positions logiques utilisées par le gameplay.

Les cultures visibles dans Tiled servent de preview. En jeu, leur stade est
déterminé dynamiquement à partir de l'état Growstep.

## Cultures

Le catalogue associe chaque espèce à plusieurs tile IDs correspondant aux
stades de croissance.

Le runtime doit choisir le sprite à partir de :

`espèce + stade`

et non encoder directement la culture dans la map.

## Principes visuels

Le jardin doit être :

- cosy ;
- dense mais lisible ;
- coloré ;
- végétalisé ;
- progressivement personnalisable ;
- moins géométrique qu'une simple grille de farming.

Les chemins servent la circulation visuelle mais ne doivent pas transformer
le jardin en quadrillage.

Les bords doivent être enrichis par des arbres, buissons, fleurs, clôtures,
rochers et petits objets afin de donner l'impression d'un vrai espace clos.

## Ancienne DA

L'ancienne DA isométrique est considérée comme legacy.

Ses sources, exports, documents de recherche et scripts de génération peuvent
être supprimés.

Les anciens sprites/maps runtime seront supprimés uniquement après le passage
effectif de `GardenGame` au renderer orthogonal.

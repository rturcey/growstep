# Tiled isométrique natif comme source de vérité spatiale de Growstep

> Statut : étude technique pour spécification. S'appuie sur le dépôt Growstep actuel, la documentation officielle Tiled (TMX Map Format, Working with Objects, Editing Tilesets, Working with Layers), le code source de `flame_tiled` 3.1.2 et `tiled` 0.12.0 sur pub.dev, et les contraintes de `pubspec.yaml`.

## 1. Objectif

Remplacer l'autoring de composition visuelle en code Dart par une carte Tiled isométrique native 80×40. La grille isométrique `(gridCol, gridRow)` devient la source de vérité du placement. Un humain compose le jardin dans Tiled — peint le sol, place les objets, trace le chemin — et le runtime consomme cette carte. Le gameplay, les plantes dynamiques, les sauvegardes et l'UI Flutter restent propriété de Growstep.

## 2. Constats du dépôt

### 2.1 La math grille est déjà isométrique 2:1

`IsoGrid.toScreen()` (`garden_scene.dart:12`) :

```dart
Offset toScreen(double i, double j) => Offset(
  origin.dx + (i - j) * cellWidth / 2,
  origin.dy + (i + j) * cellHeight / 2,
);
```

`IsometricTileLayer.cacheTiles()` dans `flame_tiled` (`isometric_tile_layer.dart:33`) :

```dart
offsetX = halfDestinationTile.x * (tx - ty) + isometricXShift;
offsetY = halfDestinationTile.y * (tx + ty) + isometricYShift;
```

**(tx - ty)** et **(tx + ty)** — strictement la même formule de projection. Une carte Tiled isométrique avec `tilewidth=80, tileheight=40` produit des positions de tuiles sur la même grille que `IsoGrid`.

### 2.2 Le terrain actuel est 100% Canvas procédural

`GardenGame._drawTerrain()` (`garden_game.dart:322-484`) : 163 lignes de strates de terre, 120 patches d'herbe aléatoires (`math.Random(42 + zone.index)`), 115 lames d'herbe, 25 highlights, contour polygone, lèvre herbeuse. Ce rendu donne au Potager son aspect peint.

`PotagerComposition.drawGround()` (`potager_composition.dart:48-143`) : masses paysagères Canvas, touffes d'herbe aléatoires (`math.Random(4106)`), lames d'herbe, contacts au sol des objets de soin.

Aucun asset de tuile de sol 80×40 n'existe dans `assets/sprites/`. Les sprites existants sont des silhouettes d'objets, pas des tuiles de terrain.

### 2.3 Les objets sont déjà déclaratifs

`PotagerPilotScene` (`potager_scene.dart:7-29`) : `east_upper_rock` et `east_barrel` comme `GardenSpriteObject(id, asset, contact, size, layer)`.

`PotagerPath.stones` (`potager_path.dart:55-140`) : 12 pas japonais comme `GardenSpriteObject`.

`PotagerPlots` (`potager_scene.dart:44-61`) : 8 emplacements sur grille demi-entière.

`PotagerComposition` (`potager_composition.dart:10-46`) : treillis, tonneau, arrosoir, caisse, masses, bordures — coordonnées hardcoded.

### 2.4 `flame_tiled` ne rend pas les object layers

`ObjectLayer.render()` (`object_layer.dart:20`) :

```dart
void render(Canvas canvas, CameraComponent? camera) {
  // nothing to do
}
```

Seuls `FlameTileLayer` (tile layers) et `FlameImageLayer` (image layers) sont rendus par `flame_tiled`. Les object layers sont parsés mais ignorés au rendu. Growstep doit lire les objets depuis le `TiledMap` parsé et les rendre via son pipeline `_SceneObject` / `GardenSpriteObject` existant.

### 2.5 Le tri en profondeur est par contact au sol

`GardenSceneRenderer.depthOrder()` (`garden_scene_renderer.dart:33`) : `layer.index → contact.dy + zBias → id`. Les tuiles de sol sont toujours en dessous (phase `ground` / `path`), les objets verticaux au-dessus (phase `depth`). Acceptable : le sol n'a pas besoin d'intercaler avec les objets.

### 2.6 Les contours sont des polygones irréguliers

`GardenGame._islandContour()` (`garden_game.dart:271-320`) : polygones à 9-13 points. Le user a accepté des contours rectangles : l'îlot devient un rectangle de tuiles dans la carte Tiled, avec des tuiles vides (gid=0) à l'extérieur du contour.

### 2.7 Les demi-positions existent

Les 8 plots sont à des coordonnées demi-entières (`potager_scene.dart:52-61`) : `(-3.5, -0.5)`, `(1, -1)`, `(0.5, 3.5)`, etc. Les tuiles Tiled sont à coordonnées entières uniquement. Les plots deviennent des point objects sur une object layer avec `gridCol/gridRow` explicites en custom properties.

### 2.8 Compatibilité des paquets

| Paquet | Version | Dépendances | Compatible ? |
|---|---|---|---|
| `flame_tiled` | 3.1.2 | `flame ^1.38.0`, `tiled ^0.11.0` | Oui (`flame: ^1.38.2` dans pubspec) |
| `tiled` | 0.12.0 | `xml ^7.0.0`, `archive ^4.0.2` | Oui (aucun conflit) |

`flame_tiled` résout les images depuis `assets/images/` par défaut (`tile_atlas.dart:130`, `renderable_tile_map.dart:175`). Les sprites Growstep sont dans `assets/sprites/`. Solution la plus simple : passer `imagesDirectory: 'assets/sprites/'` au chargement, et déclarer `assets/maps/` dans `pubspec.yaml`.

## 3. Architecture — PoC

### 3.1 Vue d'ensemble

```
Tiled editor (desktop)
  ↓ .tmx + .tsx committed
GardenGame.onLoad()
  ↓ RenderableTiledMap.fromFile("assets/maps/potager_diorama_v1.tmx", ...)
  ↓ RenderableTiledMap held as GardenGame member (NOT a Flame child)
  ↓ TiledMap parsed → objects extracted → GardenSpriteObject list
  ↓
_drawIsland(Canvas)
  ├── _drawTerrain()         → Canvas terrain (existant, inchangé)
  ├── _tileMap?.render()     → Tiled tile layers (path uniquement)
  ├── _drawEnvironmentObjects() → objets existants + objets Tiled
  ├── _drawPlants()          → plantes dynamiques (inchangé)
  ├── _drawSelection()
  └── _drawDebug()
```

Le tout sous le même `GardenArtboardTransform`. Pas de `TiledComponent` enfant. Le `RenderableTiledMap` est rendu manuellement entre le terrain Canvas et la scène dynamique.

### 3.2 Carte Tiled

- **Orientation** : `isometric`
- **tilewidth** : 80, **tileheight** : 40
- **Dimensions** : 14×14 tuiles (voir §4)
- **Format** : TMX (XML), diffable en git
- **Fichier** : `assets/maps/potager_diorama_v1.tmx`
- **Tileset externe** : `assets/maps/growstep.tsx`, type collection-of-images, `objectalignment: bottom`

### 3.3 Couches du PoC

| Couche | Type | Contenu du PoC | Rendu par |
|---|---|---|---|
| `path` | Tile layer | Tuiles de pas japonais 80×40 transparentes | `flame_tiled` via `RenderableTiledMap.render()` |
| `plots` | Object layer | 8 point objects `plot_0`…`plot_7`, `class=plot`, couleur distinctive | Non rendu (Growstep lit `gridCol/gridRow`) |
| `props` | Object layer | 1 objet vertical (rocher existant), `class=prop` | Growstep via `_SceneObject` |

Les tile layers sont rendues par `RenderableTiledMap.render()`. Les object layers sont parsées par Growstep ; chaque objet devient un `GardenSpriteObject` ou un `_SceneObject`. Les object layers techniques (`plots`) ne sont jamais rendues.

### 3.4 Couches futures (post-PoC)

Ces couches n'existent pas dans le PoC. Elles sont listées ici pour documenter la direction long terme.

| Couche | Type | Contenu futur | Rendu par |
|---|---|---|---|
| `ground` | Tile layer | Tuiles d'herbe 80×40 (variantes) | `flame_tiled` |
| `soil` | Tile layer | Tuiles de terre plate (emplacements achetés) | `flame_tiled` ou Canvas runtime |
| `edges` | Tile layer | Tuiles de bordure / tranche de terre | `flame_tiled` |
| `vegetation` | Object layer | Touffes, herbes folles, trèfles, fleurs | Growstep |

### 3.5 Tuiles de pas japonais

Les 6 sprites `commun_sol_pas_pierre_*.png` existants sont placés sur un canvas transparent 80×40, correctement ancrés dans la cellule. Les pierres ne sont pas redessinées. La pierre visuelle reste plus petite que la cellule, laissant l'herbe visible entre les pierres. Noms : `commun_sol_pas_pierre_tile_00.png`…`_05.png` dans `assets/sprites/`. Le tileset les référence comme tuiles individuelles (collection-of-images). Cela permet le pinceau Stamp Brush de Tiled pour peindre rapidement des pierres alignées à la grille.

### 3.6 Plot markers

Les 8 plots sont des Point Objects Tiled natifs avec `name=plot_0`…`plot_7`, `class=plot`, et `gridCol`/`gridRow` en custom properties (int). Couche `plots` avec couleur distinctive. Pas de PNG marker artificiel. Le runtime lit uniquement `stable plot id + gridCol/gridRow` et ignore la représentation editor-only.

### 3.7 Schéma d'objet Tiled

| Champ Tiled | Usage Growstep |
|---|---|
| `name` | ID stable (`plot_0`, `east_barrel`) |
| `type` (class) | Catégorie : `plot`, `prop`, `vegetation`, `ambient` |
| `x`, `y` | Position dans l'espace projeté isométrique (convertie via adapter) |
| `gid` | Référence de tuile → asset sprite (pour les props) |
| `width`, `height` | Taille d'affichage |
| `opacity` | Opacité |
| `gridCol`, `gridRow` (custom properties) | Coordonnées de grille explicites (autoritaires si la conversion native échoue) |

Les IDs numériques internes de Tiled (`id`) ne sont jamais utilisés.

### 3.8 Conversion de coordonnées — adapter grille → artboard

La grille logique `(gridCol, gridRow)` reste la source de vérité, pas les coordonnées pixel libres de Tiled. La conversion est isolée dans un adapter unique et testée.

`IsoGrid.toScreen()` existant (`garden_scene.dart:12`) :

```dart
Offset toScreen(double i, double j) => Offset(
  origin.dx + (i - j) * cellWidth / 2,
  origin.dy + (i + j) * cellHeight / 2,
);
```

Le PoC doit prouver la conversion avec les coordonnées natives des Object Layers Tiled (espace projeté isométrique). Si ces coordonnées ne retrouvent pas exactement les contacts historiques, le fallback utilise les propriétés `gridCol/gridRow` explicites de la carte, jamais des coordonnées d'objets conservées en Dart.

Le PoC #59 encode les coordonnées demi-entières historiques en propriétés entières : `gridCol = 2 × i`, `gridRow = 2 × j`. `PotagerGridAdapter.fromTiledProperties()` divise ces valeurs par deux avant d'appeler `IsoGrid.toScreen()`. La cellule Tiled `(7,9)` correspond au centre logique `(0,0)`. Les coordonnées natives des objets sont stockées dans l'espace projeté de Tiled, en carrés de 40 px ; le centre `(7,9)` vaut `(x=300,y=380)`. `fromTiledObject()` calcule donc `(i,j) = (x/40 - 7.5, y/40 - 9.5)` avant la même projection. Les huit plots retrouvent exactement les contacts historiques par les deux voies. Les propriétés `gridCol/gridRow` restent autoritaires pour la composition ; les coordonnées natives servent à vérifier leur cohérence.

### 3.9 Ancres sprites

Le manifeste Growstep reste la source canonique des ground anchors. Les PNG ne sont pas corrigés. Tiled utilise `objectalignment: bottom` (bas-centre, défaut pour les maps isométriques). Le runtime mesure le delta entre `Tiled bottom-center` et `manifest ground anchor` sur plusieurs sprites représentatifs. Si le delta n'est pas nul, le runtime applique un offset déterministe dérivé du manifeste, pas une correction manuelle par objet. `tileoffset` n'est utilisé que pour un décalage commun à tout un tileset.

Pour le rocher pilote du #62, le PNG source mesure 216 × 148 px. Tiled place son ancre bas-centre en `(108, 148)` ; le manifeste place le contact au sol en `(108, 135)`. Le delta source est donc `(0, -13)` px. L'objet TMX mesure 48,6 × 33,3 px, soit une échelle de 0,225 : le delta artboard est `(0, -2,925)` px. Son contact de grille reste `(355, 150)` et le contact transmis au renderer devient `(355, 147,075)`. Le rectangle visible du manifeste `(16, 24, 200, 136)` donne une taille rendue de 41,4 × 25,2 px. Le calcul est centralisé dans `PotagerTiledObjects` et suit les dimensions du TMX et du manifeste si elles changent.

### 3.10 Plantes dynamiques

Les plantes ne sont **jamais** des objets Tiled. Le flow reste :

```
plot marker Tiled → grid/contact → purchased state Growstep → soil Canvas si acheté → plant dynamique
```

`GardenGame._drawPlant()` est inchangé.

### 3.11 État d'achat des emplacements

L'empreinte de terre plate reste rendue par Canvas runtime selon l'état d'achat (`purchased[slot] != null`). La couche `soil` n'existe pas dans Tiled pour le PoC.

### 3.12 Rendu runtime

`RenderableTiledMap` est un membre de `GardenGame`, pas un enfant Flame. Rendu manuel dans `_drawIsland()` :

```dart
_drawTerrain(canvas, zone);
_tileMap?.render(canvas);      // ← tile layers Tiled (path uniquement)
_drawEnvironmentObjects(...);   // objets existants + objets Tiled extraits
_drawPlants(...);               // plantes dynamiques (inchangé)
```

Le tout sous le même `GardenArtboardTransform`. Vérifications : transform appliqué une seule fois, map rendue une seule fois, object layers techniques non rendues, rendu Tiled entre terrain et scène dynamique.

### 3.13 Dépendances

Ajouter `flame_tiled: ^3.1.2` au `pubspec.yaml`. Déclarer `assets/maps/` dans les assets Flutter. `flame_tiled` résout les images depuis `assets/sprites/` via `imagesDirectory: 'assets/sprites/'`.

## 4. Dimensions de la carte

### 4.1 Analyse de l'emprise actuelle

Le contour du Potager (`garden_game.dart:272-287`) s'étend de `(24, 68)` à `(378, 416)` dans l'artboard 390×450.

En coordonnées de grille (i, j) autour de l'origine `O = (195, 230)` :

| Point artboard | i-j | i+j |
|---|---|---|
| `(24, 118)` (haut-gauche) | -4.275 | -5.6 |
| `(200, 68)` (haut-centre) | 0.125 | -8.1 |
| `(358, 118)` (haut-droit) | 4.075 | -5.6 |
| `(376, 205)` (droite) | 4.525 | -1.25 |
| `(330, 374)` (bas-droit) | 3.375 | 7.2 |
| `(195, 410)` (entrée chemin) | 0 | 9 |
| `(60, 374)` (bas-gauche) | -3.375 | 7.2 |
| `(24, 205)` (gauche) | -4.275 | -1.25 |

Plage : i ∈ [-5, 5], j ∈ [-5, 6], i+j ∈ [-9, 10].

### 4.2 Carte proposée

Pour couvrir cette emprise avec de la marge :

- **Map size** : 14 × 14 tuiles
- **Grid offset** : `(7, 9)` — Growstep (0, 0) → Tiled (7, 9)
- Les coordonnées Tiled vont de (0, 0) à (13, 13)
- La tuile (7, 9) correspond au centre du Potager

Taille du composant Tiled : (14+14)×40 = 1120 px large, (14+14)×20 = 560 px haut. Le `GardenArtboardTransform` et un offset positionnent la zone utile pour que seule la partie relevante (390×450) soit visible.

### 4.3 Contour rectangle

L'îlot devient un rectangle de tuiles dans la carte. Les tuiles en dehors du rectangle sont vides (gid=0).

**Pour le PoC :** contour rectangle simple. La silhouette organique actuelle peut être affinée plus tard avec des tuiles de bordure spécifiques.

## 5. Assets du PoC

| Asset | Dimensions | Quantité | Rôle |
|---|---|---|---|
| Tuile de pas japonais | 80×40 transparente | 6 (sprites existants placés sur canvas 80×40) | Couche `path` |

Les pierres ne sont pas redessinées. Les sprites `commun_sol_pas_pierre_*.png` existants sont placés sur un canvas transparent 80×40, correctement ancrés dans la cellule.

Les sprites d'objets existants (`commun_decor_*.png`, `potager_decor_*.png`) sont utilisés tels quels dans le tileset collection-of-images.

## 6. Architecture runtime

### 6.1 Chargement

```dart
// GardenGame.onLoad()
_tileMap = await RenderableTiledMap.fromFile(
  'assets/maps/potager_diorama_v1.tmx',
  Vector2(80.0, 40.0),  // destTileSize = tile size
  bundle: rootBundle,
  imagesDirectory: 'assets/sprites/',
);
// Parse objects from the TiledMap
final potagerObjects = _loadObjectsFromTiled(_tileMap!.map);
```

`RenderableTiledMap` est tenu comme membre de `GardenGame`. Pas de `TiledComponent`. Pas de `add()`.

### 6.2 Rendu

```dart
// GardenGame._drawIsland()
void _drawIsland(Canvas canvas, ZoneType zone) {
  _drawTerrain(canvas, zone);
  _tileMap?.render(canvas);      // tile layers Tiled (path uniquement)
  // Environment objects (existing + Tiled-extracted)
  for (final entry in _environmentObjects(zone)) { ... }
  // Plants, selection, debug...
}
```

Le tout sous le même `GardenArtboardTransform`. Le `RenderableTiledMap` est rendu manuellement après le terrain Canvas et avant les objets dynamiques.

### 6.3 Lecture des objets

```dart
List<GardenSpriteObject> _loadObjectsFromTiled(TiledMap map) {
  final objects = <GardenSpriteObject>[];
  for (final layer in map.layers) {
    if (layer is! ObjectGroup) continue;
    if (layer.name == 'plots') continue;  // technical, not rendered
    for (final obj in layer.objects) {
      final contact = _adapter.toArtboard(obj);  // grid or native conversion
      objects.add(GardenSpriteObject(
        id: obj.name,
        asset: _assetFromGid(obj, map),
        contact: contact,
        size: Size(obj.width, obj.height),
        layer: _layerFromName(layer.name),
        opacity: obj.opacity,
      ));
    }
  }
  return objects;
}
```

### 6.4 Plot contacts depuis Tiled

```dart
List<Offset> _loadPlotContacts(TiledMap map) {
  final plotsLayer = map.layerByName('plots') as ObjectGroup;
  final contacts = List<Offset>.filled(8, Offset.zero);
  for (final obj in plotsLayer.objects) {
    if (obj.name.startsWith('plot_')) {
      final index = int.parse(obj.name.substring(5));
      final gridCol = obj.properties.getValueByName('gridCol') as int;
      final gridRow = obj.properties.getValueByName('gridRow') as int;
      contacts[index] = _adapter.fromTiledProperties(gridCol, gridRow);
    }
  }
  return contacts;
}
```

Les `gridCol/gridRow` sont autoritaires. La conversion native Tiled `(x, y)` est testée contre les mêmes contacts, mais n'est pas la source du placement runtime.

## 7. Preuve de concept (slice minimal)

### 7.1 Objectif

Prouver que Tiled + grille isométrique 80×40 peut devenir proprement la source de vérité spatiale de Growstep.

### 7.2 Périmètre du PoC

1. Créer `assets/maps/potager_diorama_v1.tmx` : carte isométrique 14×14, `tilewidth=80, tileheight=40`
2. Créer `assets/maps/growstep.tsx` : tileset collection-of-images avec les 6 tuiles de pas japonais 80×40 et 1 sprite d'objet (rocher)
3. Peindre quelques tuiles de pas japonais dans la couche `path`
4. Placer le rocher comme tile object dans la couche `props`
5. Placer 8 point objects `plot_0`…`plot_7` avec `class=plot` et `gridCol/gridRow` dans la couche `plots`
6. Ajouter `flame_tiled: ^3.1.2` au `pubspec.yaml`
7. Déclarer `assets/maps/` dans les assets Flutter
8. Charger `RenderableTiledMap` dans `GardenGame.onLoad()` (membre, pas enfant Flame)
9. Rendre `_tileMap.render(canvas)` manuellement entre `_drawTerrain()` et `_environmentObjects()`
10. Extraire le rocher depuis le TMX et le rendre via le pipeline existant
11. Vérifier : déplacer le rocher dans Tiled → il bouge dans Growstep

### 7.3 Critères de réussite du PoC (9 points)

1. Map Tiled isométrique 80×40 ouverte et éditable
2. Correspondance exacte grille Tiled → contacts Growstep (8 plots historiques)
3. Tile layer `path` rendue correctement dans Growstep
4. Tile de pas japonais 80×40 transparente (sprite existant, non redessiné)
5. Un objet vertical ancré à une cellule (rocher)
6. Anchor manifest correctement compensé (delta mesuré, offset déterministe appliqué)
7. Plot avec marker editor-only natif Tiled (Point Object, `class=plot`), invisible dans Growstep
8. Rendu Tiled entre terrain Canvas et scène dynamique
9. Modification dans Tiled → résultat visible dans Growstep sans modifier une coordonnée Dart

### 7.4 Hors périmètre du PoC

- Tuiles d'herbe ou de terre (terrain Canvas conservé)
- Tuiles de bordure / tranche de terre
- Migration des 12 pierres existantes vers Tiled
- Migration des masses paysagères, treillis, arrosoir, caisse
- Migration des 8 plot contacts vers le runtime (le PoC lit mais ne remplace pas `PotagerPlots`)
- Refactor en composants Flame frères
- Échelles d'embellissement
- Jardin fleuri et verger
- Suppression du code de composition Dart existant
- Nouveaux assets artistiques (les pierres ne sont pas redessinées)

## 8. Direction post-PoC — migration progressive

Ces phases sont post-PoC. Le PoC ne migre aucune famille existante.

| Phase | Contenu | Condition de passage |
|---|---|---|
| 2 | Migrer les 8 plot contacts vers le runtime Tiled | 8 taps intacts, sauvegardes intactes |
| 3 | Migrer les 12 pas de chemin vers tile layer `path` | Chemin lisible, herbe entre pierres |
| 4 | Migrer masses, rochers, treillis vers object layer | Masses cohérentes, profondeur juste |
| 5 | Migrer arrosoir, caisse, bordures | Objets héros en place |
| 6 | Remplacer le terrain Canvas par des tuiles peintes (grass, soil, edges) | Terrain tuilé accepté visuellement |
| 7 | Supprimer le code de composition Dart mort | Captures validées, tests propres |
| 8 | Étendre au jardin fleuri et au verger | Trois îlots cohérents |
| 9 | Refactor en composants Flame frères si justifié | Performance ou lisibilité améliorée |

Chaque phase laisse le jeu fonctionnel. Une seule source de vérité par famille d'objets : dès qu'une famille migre vers Tiled, les coordonnées Dart correspondantes sont supprimées.

## 9. Risques

| # | Risque | Mitigation |
|---|---|---|
| R1 | Les coordonnées natives des Object Layers Tiled (espace projeté) ne reproduisent pas exactement les contacts historiques | Fallback sur `gridCol/gridRow` explicites dans les propriétés Tiled, contact calculé via `IsoGrid.toScreen()`. Le PoC doit trancher. |
| R2 | `flame_tiled` a un bug connu de lignes supplémentaires avec SpriteBatch (issue #1152) | Désactiver `useAtlas` si nécessaire : rendu par `drawImageRect` au lieu de `drawAtlas` |
| R3 | L'ancre Tiled `bottom-center` ≠ ancre manifeste | Offset déterministe dérivé du manifeste, mesuré au PoC |
| R4 | La coexistence Canvas terrain + Tiled tiles produit des artefacts visuels | Le terrain Canvas reste sous les tuiles Tiled, qui sont transparentes sauf aux pierres |
| R5 | La taille du composant Tiled (1120×560 pour 14×14) dépasse l'artboard visible | Normal : le `GardenArtboardTransform` et l'offset positionnent la zone utile ; le reste est clipped |
| R6 | Les chemins d'assets relatifs entre `.tmx`, `.tsx` et PNG ne résolvent pas correctement | Tester dans Tiled éditeur ET au runtime Flutter ; utiliser des chemins relatifs cohérents |
| R7 | La performance dégrade avec le rendu de tuiles + Canvas + sprites | Mesurer au PoC ; le terrain Canvas procédural actuel fait déjà ~400 draw calls, les tuiles batchées devraient être plus rapides |

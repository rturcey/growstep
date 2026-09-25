# Modèle d'autoring Tiled : ancres par famille, demi-cellules, ombres

## Ancres

Le manifeste reste la source canonique de l'ancre au sol pour le rendu runtime. L'`objectalignment="bottom"` de Tiled place le bas-centre de l'image au point de l'objet, mais les ancres du manifeste sont décalées (typiquement ~13px au-dessus à 4×, à cause de la marge transparente). Pour un aperçu WYSIWYG, les TSX sont générés avec un `tileoffset` par famille d'offset : le script lit les dimensions d'image et l'ancre du manifeste, calcule `manifestGroundAnchor - tiledBottomCenter`, assigne le sprite à une famille. Le runtime ignore `tileoffset` ; il lit `gridCol`/`gridRow` + l'ancre du manifeste. Tolérance ±1px ; les sprites aux deltas quasi-identiques partagent une famille (p.ex. rocher, tonneau, treillis → `(0, -13)`). Aucun nudge manuel, aucun recadrage de PNG.

## Demi-cellules

Les contacts historiques du Potager utilisent des demi-cellules (`-3.5`, `-0.5`, `0.5`, `3.5`). Le code Dart utilise déjà `double` pour `gridI`/`gridJ`. Les propriétés Tiled `gridCol`/`gridRow` passent de `int` (hack ×2 divisé à l'exécution) à `double` avec des valeurs `.5` directement lisibles. Validation : `value * 2` doit être entier. Remplace `fromTiledProperties(int, int)` qui divisait par 2.

## Ombres

Le manifeste reste la source par défaut (tous les sprites ont `shadow: separate_contact`). Un objet Tiled peut porter une propriété `shadow` (`none` | `small` | `medium` | `large` | `elongated`) pour surcharger le choix. Absente, le runtime utilise la valeur du manifeste. Une seule ombre rendue, immédiatement avant l'objet. Jamais d'objet ombre placé manuellement dans Tiled.

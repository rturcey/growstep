# Ticket #63 — validation du workflow Tiled

Les fichiers TMX de ce dossier conservent les quatre états de l'expérience. Ils
s'ouvrent dans Tiled avec le tileset du dépôt. La [carte de départ](baseline.tmx)
reprend la carte du commit `5918a5d` ; les trois variantes ont été écrites par
Tiled 1.11.0 avec [tiled-variant.js](tiled-variant.js). Aucun point de contact
Dart n'a été modifié pour produire ces captures.

| Manipulation dans Tiled | Changement mesuré dans Growstep |
| --- | --- |
| [Rocher A → B](rock-one-cell.tmx) : `east_upper_rock` passe de `(300, 220)` à `(300, 260)` dans l'espace objet de Tiled ; `gridRow` passe de `-8` à `-6` (une cellule entière). | Contact de grille `(355, 150)` → `(315, 170)`, avec compensation d'ancre `y = -2,925`. Le rocher apparaît en B et disparaît de A. |
| [Paint](paint.tmx) : une pierre est posée en cellule `(6, 10)` sur la couche `path`. | Nouvelle pierre visible au contact `(115, 230)`. |
| [Depaint](depaint.tmx) : la pierre de la cellule `(8, 10)` est retirée. | Pierre absente au contact `(195, 270)`. |

Les différences entre la carte de départ et chaque variante sont limitées au
Potager : les 24 captures des deux autres îlots restent identiques octet pour
octet. Les régions de pixels modifiés à 390 × 844 sont respectivement
`(294, 319)–(376, 370)`, `(101, 408)–(128, 427)` et
`(180, 448)–(211, 468)`. Les captures ci-dessous montrent la scène Flame à la
taille complète indiquée, en couleur et en niveaux de gris.

| État | 390 × 844 | 375 × 667 |
| --- | --- | --- |
| Départ | [couleur](canonical_390x844.png) · [gris](canonical_390x844_gris.png) | [couleur](canonical_375x667.png) · [gris](canonical_375x667_gris.png) |
| Rocher B | [couleur](rock-one-cell_390x844.png) · [gris](rock-one-cell_390x844_gris.png) | [couleur](rock-one-cell_375x667.png) · [gris](rock-one-cell_375x667_gris.png) |
| Pierre ajoutée | [couleur](paint_390x844.png) · [gris](paint_390x844_gris.png) | [couleur](paint_375x667.png) · [gris](paint_375x667_gris.png) |
| Pierre retirée | [couleur](depaint_390x844.png) · [gris](depaint_390x844_gris.png) | [couleur](depaint_375x667.png) · [gris](depaint_375x667_gris.png) |

## Carte retenue

La [carte finale](../../../assets/maps/potager.tmx) est restaurée à l'octet près
à l'état du commit `5918a5d` : cinq cellules peintes dans `path`, rocher en A et
huit points `plots` sur leurs contacts historiques. Ces points restent des
marqueurs d'éditeur invisibles dans Growstep. Les douze pierres Dart historiques
restent présentes pendant le PoC. Le rendu final peut être inspecté à quatre,
six et huit emplacements de plantation :

| Emplacements de plantation | 390 × 844 | 375 × 667 |
| --- | --- | --- |
| 4 | [couleur](final_initial_390x844.png) · [gris](final_initial_390x844_gris.png) | [couleur](final_initial_375x667.png) · [gris](final_initial_375x667_gris.png) |
| 6 | [couleur](final_intermediaire_390x844.png) · [gris](final_intermediaire_390x844_gris.png) | [couleur](final_intermediaire_375x667.png) · [gris](final_intermediaire_375x667_gris.png) |
| 8 | [couleur](final_sature_390x844.png) · [gris](final_sature_390x844_gris.png) | [couleur](final_sature_375x667.png) · [gris](final_sature_375x667_gris.png) |

## Contrôles techniques du PoC

1. La carte est isométrique 80 × 40, et Tiled a lu, édité et réécrit les variantes.
2. Le test TMX vérifie les huit contacts des emplacements de plantation et leurs positions natives dans Tiled.
3. Les captures montrent la couche `path` rendue dans Growstep.
4. Les six tuiles de pierre réutilisent les sprites existants : PNG 80 × 40 avec transparence autour du dessin.
5. Le déplacement A → B du rocher suit une cellule et modifie son contact rendu.
6. Le test TMX vérifie la compensation déterministe de l'ancre du manifeste.
7. Les marqueurs `plots` restent visibles dans Tiled et absents du rendu Growstep.
8. Le code rend la couche Tiled après le terrain Canvas et avant les objets dynamiques ; la revue humaine a confirmé sa composition visuelle.
9. Les trois changements Tiled apparaissent dans les captures sans changement de coordonnées Dart.

La revue visuelle externe demandée par le ticket a été **validée par
l'utilisateur le 25 septembre 2026** après consultation du dossier de captures
(« Impec ! »). Elle portait sur les pierres aux cellules attendues, le terrain
visible, l'ordre de profondeur avec les objets dynamiques, l'ancre du rocher et
l'absence de décalage d'artboard.

Pour régénérer des variantes, lancer `tiled --evaluate tiled-variant.js
baseline.tmx sortie.tmx rock-one-cell` depuis ce dossier, avec `paint` ou
`depaint` pour les autres manipulations. Pour capturer une carte chargée par
Growstep, utiliser `flutter test test/visual_capture_test.dart
--dart-define=GROWSTEP_CAPTURE_DIR=<dossier>
--dart-define=GROWSTEP_CAPTURE_FULL_SCREEN=true` depuis la racine du dépôt.

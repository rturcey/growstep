# #50 — Chemin du Potager en pas japonais

Le chemin du Potager suit un réseau déclaré dans `PotagerPath.routes`, de l'entrée avant `(195, 410)` jusqu'à l'arrière `(195, 190)`, avec trois branches courtes vers les cultures. `PotagerPath.stones` fixe l'asset, le contact et la taille de chacun des douze pas. Les six variantes du pack sont utilisées, sans tirage au sort. Le renderer dessine ces sprites sur l'herbe avant les empreintes de terre, sans doubler leur ombre peinte ; le tracé et les pierres Canvas continus du Potager ont été retirés.

Les captures sont produites par `test/visual_capture_test.dart` avec `GROWSTEP_CAPTURE_DIR`. Les noms indiquent les formats de téléphone ; le pipeline capture le monde seul en `390 × 450` et `375 × 380` pixels. Les états montrent 4, 6 et 8 emplacements achetés. Les [captures du #49](../issue-49/README.md) servent de référence avant le remplacement du chemin.

| État | 390 × 844 | 375 × 667 |
| --- | --- | --- |
| 4 emplacements | [couleur](potager_initial_390x844.png) · [gris](potager_initial_390x844_gris.png) | [couleur](potager_initial_375x667.png) · [gris](potager_initial_375x667_gris.png) |
| 6 emplacements | [couleur](potager_intermediaire_390x844.png) · [gris](potager_intermediaire_390x844_gris.png) | [couleur](potager_intermediaire_375x667.png) · [gris](potager_intermediaire_375x667_gris.png) |
| 8 emplacements | [couleur](potager_sature_390x844.png) · [gris](potager_sature_390x844_gris.png) | [couleur](potager_sature_375x667.png) · [gris](potager_sature_375x667_gris.png) |

Points à contrôler en revue visuelle : continuité perçue depuis l'entrée, branches lisibles sans effet de grille, herbe visible entre les pierres, contraste du chemin en niveaux de gris, absence de conflit avec les cultures, les sols et les accessoires, et composition satisfaisante aux deux formats. La validation graphique finale reste à confirmer par une revue externe.

## Validation technique

`dart analyze` et la suite complète `flutter test` passent. Les tests du chemin vérifient le réseau, les six assets, le déterminisme, une marge d'herbe entre boîtes visibles, et l'absence de recouvrement des huit surfaces de terre et cibles 44 × 44. Le validateur global `scripts/validate_sprites.py` échoue sur les métadonnées du pack d'environnement préexistant, y compris les fiches des six pas : catégories d'emprise/taille et seuil alpha du calcul de bbox. Le #50 ne modifie ni PNG, ni fiches, ni manifeste ; leurs références runtime et boîtes alpha sont contrôlées séparément par le test du chemin.

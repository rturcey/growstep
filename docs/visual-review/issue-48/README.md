# #48 — Primitive de scène déclarative

Point de départ : `c0ba7fc`. Les captures après proviennent d'une archive propre de ce commit avec les seuls changements du #48, sans le pack de sprites ni les autres essais locaux du dossier de travail. La composition pilote remplace le placement impératif d'un rocher bas `(355,150)` et d'un tonneau vertical `(355,230)`. Les tailles, opacités, assets et contacts historiques sont inchangés. Aucun emplacement, plante ou état métier n'a changé.

## Comparaison visuelle

Les [captures avant du #47](../issue-47/README.md) sont la référence. Les captures après sont ici :

| État | 390 × 844 | 375 × 667 |
| --- | --- | --- |
| 4 emplacements | [couleur](application_potager_initial_390x844.png) · [gris](application_potager_initial_390x844_gris.png) | [couleur](application_potager_initial_375x667.png) · [gris](application_potager_initial_375x667_gris.png) |
| 8 emplacements | [couleur](application_potager_sature_390x844.png) · [gris](application_potager_sature_390x844_gris.png) | [couleur](application_potager_sature_375x667.png) · [gris](application_potager_sature_375x667_gris.png) |

L'[overlay de diagnostic activé](debug_potager_initial_390x844.png) montre limites d'artboard, cibles de sélection et contacts/IDs/couches des deux objets pilotes. Les captures normales ont été construites sans cette option.

Inspection des quatre vues : îlot entier, tranche, entrée, rocher, tonneau et cultures restent cadrés. Les vues initiales sont identiques pixel par pixel à la référence du #47. Les vues saturées diffèrent sur 427 pixels à 390 × 844 et 440 pixels à 375 × 667, localisés près d'une platebande arrière et du rocher pilote : le tri stable départage désormais les contacts à profondeur égale. Le rocher et le tonneau ne bougent pas. Les cibles des huit parcelles restent testées aux deux formats.

## Contrat vérifié

- `GardenArtboardTransform` applique la même translation et la même échelle fixe 1 au dessin et au hit test.
- Les deux objets pilotes sont des données visuelles immuables avec ID, asset, contact au sol, taille, couche et opacité. Ils n'ont ni callback ni cible tactile.
- Le tri utilise la couche, le Y du contact plus le biais, puis l'ID des objets nommés. Les anciens objets sans ID restent stables selon leur index de déclaration. L'ombre issue du manifeste se dessine une seule fois, immédiatement avant son sprite.
- L'overlay de diagnostic s'active seulement en développement par `--dart-define=GROWSTEP_MAP_DEBUG=true` et reste inactif en release.

Reproduction : depuis une archive de `c0ba7fc`, appliquer le diff du #48, créer au besoin le runner Linux avec `flutter create --platforms=linux .`, puis construire `lib/potager_visual_fixture.dart` avec `GROWSTEP_POTAGER_STATE=initial` ou `sature`. Capturer via `scripts/capture_potager_visuals.py` sous Xvfb aux deux tailles ; rogner la capture racine à la largeur et hauteur demandées. Les fichiers de ce dossier sont les sorties rognées, inspectées en couleur et en gris.

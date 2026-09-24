# #49 — Intégrer les variantes de platebande

Les huit emplacements du Potager passent par la composition déclarative introduite au #48. Chaque index référence explicitement une des quatre variantes de platebande (`bac_potager_statique_ordinaire_00..03`) ; le renderer exécute la composition sans choisir la variante. L'ancienne règle calculée `drawBedSeam` (`((dx+dy)/40)%3`) est supprimée.

## Captures après

Commit : `ef44c95`. Captures générées par `test/visual_capture_test.dart` avec `--dart-define=GROWSTEP_CAPTURE_DIR`.

| État | 390 × 844 | 375 × 667 |
| --- | --- | --- |
| 4 emplacements (initial) | [couleur](potager_initial_390x844.png) · [gris](potager_initial_390x844_gris.png) | [couleur](potager_initial_375x667.png) · [gris](potager_initial_375x667_gris.png) |
| 6 emplacements (intermédiaire) | [couleur](potager_intermediaire_390x844.png) · [gris](potager_intermediaire_390x844_gris.png) | [couleur](potager_intermediaire_375x667.png) · [gris](potager_intermediaire_375x667_gris.png) |
| 8 emplacements (saturé) | [couleur](potager_sature_390x844.png) · [gris](potager_sature_390x844_gris.png) | [couleur](potager_sature_375x667.png) · [gris](potager_sature_375x667_gris.png) |

## Référence avant

Les [captures du #48](../issue-48/README.md) servent de référence avant.

## Points d'inspection

- Les huit platebandes utilisent les quatre variantes peintes, choisies à la main par index.
- Le cadre d'un emplacement ne change pas avec la plante, son stade ou son état.
- Les contacts au sol, cibles tactiles 44 × 44 et sauvegardes sont inchangés.
- Le terrain, le chemin et les cultures (tomate, carotte, courgette) ne sont pas modifiés.

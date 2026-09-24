# #49 — Intégrer les variantes de platebande

Les huit emplacements du Potager passent par la composition déclarative introduite au #48. Chaque index référence explicitement la variante de platebande `bac_potager_statique_ordinaire_00` — la seule dont les `palette_roles` (bois_chaud, terre_humide) ne contiennent ni pierre ni feuillage intégrés. Les variantes 01–03 portent `pierre_creme` et `feuillage_sauge` et ont été écartées. Le renderer exécute la composition sans choisir la variante. L'ancienne règle calculée `drawBedSeam` (`((dx+dy)/40)%3`) est supprimée.

## Taille de rendu

Les platebandes sont rendues à 80 × 62 (visible), correspondant au ratio natif de la variante v00 et à la largeur maximale de platebande du gabarit géométrique (`docs/geometrie-ilots.md`). Cette taille restore l'emprise visuelle du Canvas bed d'origine (w=40, largeur 80) et permet au cadre de dépasser légèrement des cultures matures (~72 de large).

## Captures après

Captures générées par `test/visual_capture_test.dart` avec `--dart-define=GROWSTEP_CAPTURE_DIR`.

| État | 390 × 844 | 375 × 667 |
| --- | --- | --- |
| 4 emplacements (initial) | [couleur](potager_initial_390x844.png) · [gris](potager_initial_390x844_gris.png) | [couleur](potager_initial_375x667.png) · [gris](potager_initial_375x667_gris.png) |
| 6 emplacements (intermédiaire) | [couleur](potager_intermediaire_390x844.png) · [gris](potager_intermediaire_390x844_gris.png) | [couleur](potager_intermediaire_375x667.png) · [gris](potager_intermediaire_375x667_gris.png) |
| 8 emplacements (saturé) | [couleur](potager_sature_390x844.png) · [gris](potager_sature_390x844_gris.png) | [couleur](potager_sature_375x667.png) · [gris](potager_sature_375x667_gris.png) |

## Référence avant

Les [captures du #48](../issue-48/README.md) servent de référence avant.

## Points d'inspection

- Les huit platebandes utilisent la variante v00 (bois + terre, sans accessoire intégré).
- Le cadre d'un emplacement ne change pas avec la plante, son stade ou son état.
- Les contacts au sol, cibles tactiles 44 × 44 et sauvegardes sont inchangés.
- Le terrain, le chemin et les cultures (tomate, carotte, courgette) ne sont pas modifiés.

## Conflit documenté — platebande arrière-centre et treillis

L'emplacement 4 (`(195, 150)`) et le treillis (`(155, 150)`) sont distants de 40 px. Le treillis s'étend jusqu'à x ≈ 184 ; la platebande à 80 de large s'étend à partir de x ≈ 154. Le chevauchement existe donc déjà avec l'ancien Canvas bed (w = 40, largeur 80). #49 ne l'aggrave pas : la largeur 80 correspond à l'emprise d'origine.

Ce conflit ne peut pas être résolu dans #49 sans déplacer le treillis ou le contact de l'emplacement, ce qui est hors scope. Il appartient au ticket ultérieur de structure végétale (#46 itération 4).

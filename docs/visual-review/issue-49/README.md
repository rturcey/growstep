# #49 — Empreintes de terre des emplacements du Potager

Objectif : rendre les huit emplacements par la composition déclarative sous forme de surfaces de terre plates, alignées sur la géométrie existante, en conservant exactement contacts, états, cultures et interactions.

## Contrat spatial et graphique

`PotagerPlots.plots` encode les index sauvegardés `0..7` en coordonnées du treillis 80 × 40 autour de `(195,230)`. La projection commune redonne les huit contacts historiques. Une seule empreinte Canvas de `72 × 36` points, inscrite dans une case logique, est peinte pour chaque emplacement acheté dans la phase de sol. Son contour commun est légèrement irrégulier et arrondi ; la terre plus claire et translucide laisse affleurer la pelouse, sans trait de bordure. La plante utilise ensuite le même contact dans la phase à profondeur. La forme de terre ne dépend ni de l'espèce, ni de la taille du sprite, ni du viewport. Les cibles tactiles restent indépendantes du dessin et mesurent 44 × 44 points.

Les bacs en bois et leur essai de rendu en deux passes sont abandonnés : leurs parois créaient des chevauchements artificiels avec le feuillage. Leurs PNG restent dans le dépôt, sans rôle dans la composition actuelle. L'arche, le chemin, les cultures et le reste de l'environnement ne sont pas recomposés par ce ticket.

## Captures pour la revue externe

Captures régénérées par `test/visual_capture_test.dart` avec `GROWSTEP_CAPTURE_DIR`. Les noms indiquent les formats de téléphone ; le pipeline capture le monde seul en `390 × 450` et `375 × 380` pixels. Les états représentent réellement 4, 6 et 8 emplacements achetés. La validation graphique est en attente de revue externe.

| État | 390 × 844 | 375 × 667 |
| --- | --- | --- |
| 4 emplacements | [couleur](potager_initial_390x844.png) · [gris](potager_initial_390x844_gris.png) | [couleur](potager_initial_375x667.png) · [gris](potager_initial_375x667_gris.png) |
| 6 emplacements | [couleur](potager_intermediaire_390x844.png) · [gris](potager_intermediaire_390x844_gris.png) | [couleur](potager_intermediaire_375x667.png) · [gris](potager_intermediaire_375x667_gris.png) |
| 8 emplacements | [couleur](potager_sature_390x844.png) · [gris](potager_sature_390x844_gris.png) | [couleur](potager_sature_375x667.png) · [gris](potager_sature_375x667_gris.png) |

Les [captures du #48](../issue-48/README.md) servent de référence antérieure. La revue doit contrôler la lecture des cultures dans la terre, le débordement naturel des carottes, la lisibilité des surfaces sans domination visuelle, la disposition `3 / 2 / 3` et les éventuels conflits visuels. Le treillis reste à son contact actuel ; sa composition relève du ticket de structure végétale.

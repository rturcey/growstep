# Potager étalon — revue à taille réelle (#41)

Captures de l'application complète, à échelle 1:1 et animation ambiante absente.
Elles proviennent d'un checkout isolé contenant les changements du ticket #41.
Les trois états montrent respectivement 4, 6 et 8 platebandes.

[Maquette cible du potager saturé](potager_ideal_concept.png) ·
[Analyse comparative et contraintes de réalisation](analyse-potager.md).
Cette maquette est une proposition visuelle générée à partir de la capture
390 × 844 ; elle ne représente pas le rendu actuel de l'application.

| État | 390 × 844 | 375 × 667 |
| --- | --- | --- |
| Initial | [Couleur](application_potager_initial_390x844.png) · [Gris](application_potager_initial_390x844_gris.png) | [Couleur](application_potager_initial_375x667.png) · [Gris](application_potager_initial_375x667_gris.png) |
| Intermédiaire | [Couleur](application_potager_intermediaire_390x844.png) · [Gris](application_potager_intermediaire_390x844_gris.png) | [Couleur](application_potager_intermediaire_375x667.png) · [Gris](application_potager_intermediaire_375x667_gris.png) |
| Saturé | [Couleur](application_potager_sature_390x844.png) · [Gris](application_potager_sature_390x844_gris.png) | [Couleur](application_potager_sature_375x667.png) · [Gris](application_potager_sature_375x667_gris.png) |

Points à examiner : la bordure plus dense derrière et sur les côtés, l'arche
derrière les cultures, le tonneau et l'arrosoir sur le côté droit, la caisse
de semis près de la platebande avant gauche, et la zone calme à l'avant droit.
Le chemin et les huit cultures restent identifiables ; la tranche avant de
terre reste largement visible. La validation visuelle explicite de cet étalon
reste le préalable aux compositions du jardin fleuri et du verger.

Pour régénérer une paire couleur/gris sous Linux :

```sh
flutter build linux --debug -t lib/potager_visual_fixture.dart --dart-define=GROWSTEP_POTAGER_STATE=initial
xvfb-run -a -s '-screen 0 390x844x24' python3 scripts/capture_potager_visuals.py initial 390 844
```

Répéter pour `intermediaire` et `sature`, puis pour `375 667` avec la taille
Xvfb correspondante. Le test `test/potager_path_slots_test.dart` vérifie que
les huit emplacements restent sélectionnables aux deux tailles.

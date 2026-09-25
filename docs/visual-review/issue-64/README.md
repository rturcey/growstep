# Issue #64 — kit Tiled et rendu du Potager

Ces captures documentent la revue visuelle du kit et le correctif de rendu de la carte peinte. Les captures de l'application montrent la scène Flame à la taille complète, dans l'état initial avec quatre emplacements achetés.

| Capture | Fichier | Ce qu'elle montre |
| --- | --- | --- |
| Kit Tiled | [kit_tiled_review.png](kit_tiled_review.png) | Carte de démonstration du kit graphique, hors du bundle Flutter. |
| Avant correction, 390 × 844 | [avant_potager_initial_390x844.png](avant_potager_initial_390x844.png) | Ancien terrain Canvas visible sous la TMX ; des anchored sprites ont été peints comme des tuiles et apparaissent trop grands. |
| Après correction, 390 × 844 | [apres_potager_initial_390x844.png](apres_potager_initial_390x844.png) | Terrain Tiled seul et objets ancrés à leur taille logique. |
| Après correction, 375 × 667 | [apres_potager_initial_375x667.png](apres_potager_initial_375x667.png) | Même scène sur le petit écran de référence. |

La composition peinte du Potager est encore partielle : la première culture de départ se situe hors de la zone de sol actuellement peinte. Les emplacements et leurs contacts de grille ont été conservés ; cette capture permet de poursuivre la revue de la composition dans Tiled.

Les captures de scène se régénèrent avec `flutter test test/visual_capture_test.dart --dart-define=GROWSTEP_CAPTURE_DIR=<dossier> --dart-define=GROWSTEP_CAPTURE_FULL_SCREEN=true` depuis la racine du dépôt. La capture du kit vient de `python3 scripts/build_tiled_review_map.py` puis `python3 scripts/capture_tiled_review.py`.

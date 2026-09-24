# Potager paysager — implémentation de l'issue 41

La [bible graphique](../../../../ART_BIBLE.md) fixe désormais la composition par masses perceptives pour tous les îlots. Cette passe applique ses règles au Potager uniquement. Les captures sont celles de l'application Flutter complète, sans retouche ; les suffixes `_gris` sont des conversions en niveaux de gris.

| Emplacements | 390 × 844 | 375 × 667 |
| --- | --- | --- |
| 4 | [Couleur](application_potager_initial_390x844.png) · [Gris](application_potager_initial_390x844_gris.png) | [Couleur](application_potager_initial_375x667.png) · [Gris](application_potager_initial_375x667_gris.png) |
| 6 | [Couleur](application_potager_intermediaire_390x844.png) · [Gris](application_potager_intermediaire_390x844_gris.png) | [Couleur](application_potager_intermediaire_375x667.png) · [Gris](application_potager_intermediaire_375x667_gris.png) |
| 8 | [Couleur](application_potager_sature_390x844.png) · [Gris](application_potager_sature_390x844_gris.png) | [Couleur](application_potager_sature_375x667.png) · [Gris](application_potager_sature_375x667_gris.png) |

Vue du monde saturé sans UI : [couleur](monde_potager_sature_390x844.png) · [niveaux de gris](monde_potager_sature_390x844_gris.png).

## Diagnostic et décisions

| Cause | Observation dans la capture de départ | Correction |
| --- | --- | --- |
| Composition et densité | La haie était une suite de petits buissons et la pelouse une surface uniforme. | Deux grandes masses déclaratives relient les arbustes et quelques rochers ; le bas droit reste calme. Les détails de sol du Potager sont moins uniformément distribués. |
| Placement | Les volumes arrière et latéraux coupaient la lecture de certains plants. | Contacts des hauts feuillages remontés derrière les cultures ; masses latérales rentrées pour rester dans le cadrage 375 × 667. |
| Échelle | La végétation périphérique était trop basse pour encadrer le diorama. | Volumes arrière plus grands et plus hauts, sans changement de caméra ou de contour logique. |
| Asset | Les PNG de cultures existaient déjà et restaient lisibles ; les décors Canvas avaient une matière différente. | Les cultures sont réutilisées. Cinq nouveaux sprites RGBA modulaires couvrent deux arbustes, rochers-herbes, treillis et tonneau ; l'arrosoir et la caisse hérités sont adaptés au pipeline actif. Le terrain, les platebandes et le tracé du chemin restent en Canvas. |
| Contraste | Les bacs et les pas dominaient le sol nu. | Feuillage périphérique plus mat, bois du Potager assourdi et trois platebandes basses bordées d'herbe ; une bande d'herbe usée lie les pas du chemin. Contrôle en gris aux deux tailles. |
| Depth sorting | Les objets se trient par contact au sol ; un grand buisson latéral devant un plant aurait masqué ce dernier. | Chaque élément d'une masse conserve son propre contact dans le tri ; les hauts feuillages ont été placés derrière les contacts interactifs. |

Le tracé du chemin conserve des contacts sur le treillis entier ou demi-entier : une entrée sur la lèvre avant `(195, 410)`, une colonne principale courbe et de courtes approches vers les huit positions. Les masses, les pierres et les accessoires ont des ancrages sur ce même treillis ; les index, ancrages et cibles tactiles 44 × 44 des cultures sont inchangés. Le treillis et le tonneau restent les deux grandes décorations indépendantes ; l'arrosoir et la petite caisse servent leurs coins respectifs. Les rares herbes du bord avant cassent la silhouette visuelle tout en laissant la tranche de terre largement exposée.

## Itération visuelle

La première capture de travail montrait des feuillages trop ronds et un recouvrement de la rangée arrière. Les passes suivantes ont simplifié les arbustes en silhouettes continues, réduit les pierres visibles tout en conservant le tracé complet, remonté les contacts des masses arrière et éclairci le chemin. Le contrôle à 375 × 667 a fait rentrer les feuilles latérales qui touchaient le bord, puis réduit le volume droit qui passait devant une culture. La vue du monde a révélé que les huit bordures de bois répétaient encore la grille : trois platebandes ont reçu un bord bas végétalisé commun, sans changer leurs positions ni leurs surfaces de contact. La revue du premier commit a conduit à recaler tous les contacts environnementaux sur le treillis, à amener le chemin sur la lèvre avant et à assourdir les planches répétées. La dernière passe remplace les silhouettes Canvas de décor par des sprites réutilisables et adoucit le contour avant avec une frange d'herbe basse. Les captures ci-dessus correspondent au code final.

## Sprites de décor

Les cinq nouveaux motifs sont `commun_decor_bosquet_haut`, `commun_decor_bosquet_bas`, `commun_decor_rochers_herbe`, `commun_decor_treillis_bois` et `commun_decor_tonneau_bois`, chacun en état `statique_ordinaire_00`. Les deux sprites `potager_decor_arrosoir_metal` et `potager_decor_caisse_semis` réutilisent les PNG archivés, adaptés au canevas et à l'ancrage 4×. Chaque motif possède un master PNG, des exports 2×/3×, une fiche YAML et une source ORA à une couche ; cette couche aplatie pourra être séparée en couches de peinture lors d'une retouche ultérieure. Les ombres restent dessinées séparément au contact par le renderer. Les arbustes sont réutilisés à plusieurs tailles dans deux masses ; aucun fond d'îlot n'a été généré.

Les prompts des cinq sources générées avec l'outil intégré `image_gen` étaient, dans l'ordre :

1. « Isolated wide compact garden shrub cluster; overlapping foliage forming one irregular silhouette; muted moss, sage and olive; matte hand-painted; upper-left light; restrained detail; transparent RGBA; no terrain, shadow, flowers or scene. »
2. « Two low warm-gray garden rocks with muted sage grass at their bases; asymmetric and simple; matte hand-painted; upper-left light; transparent RGBA; no soil tile, path or scene. »
3. « Modest open wooden garden trellis arch with a few climbing leaves; muted honey wood; quiet matte hand-painted secondary decoration; upper-left light; transparent RGBA; no crops or scene. »
4. « Small rustic oak rain barrel, muted blue-gray metal hoops and a small twig; compact matte hand-painted 3/4 isometric view; upper-left light; transparent RGBA; no scene. »
5. « Low asymmetrical shrub with broad left shoulder and tapering right edge; muted sage and deep olive; broad matte foliage masses; upper-left light; transparent RGBA; no flowers or scene. »

Le modèle et la graine ne sont pas exposés par l'outil intégré. Les PNG générés ont été détourés, redimensionnés dans les limites de la bible et enregistrés comme sources ORA ; aucun asset n'est chargé depuis le répertoire de génération.

Reproduction : construire `lib/potager_visual_fixture.dart` avec `GROWSTEP_POTAGER_STATE=initial`, `intermediaire` ou `sature`, puis utiliser `scripts/capture_potager_visuals.py` sous Xvfb avec `GROWSTEP_CAPTURE_DIR` pointant sur ce dossier.

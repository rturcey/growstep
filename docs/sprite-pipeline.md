# Sprites du jardin

`assets/sprites/` contient 71 PNG RGBA modulaires référencés par le manifeste et chargés par Flame. Le terrain et les empreintes de terre du Potager restent dessinés en Canvas ; son chemin utilise douze pas japonais du pack, choisis parmi six variantes et placés dans `PotagerPath.stones`. Les anciens PNG de décor remplacés sont archivés dans `assets/sprite_archive/`, hors du bundle. Les maquettes complètes de `art-mockups/` et `test.png` sont des références visuelles ; elles ne sont jamais déclarées comme assets de l'application.

## Contrat d'un nouvel asset

Un identifiant stable suit `zone_famille_objet_etat_variante_frame`, en minuscules ASCII. La fiche `assets/sprite_sources/<identifiant>.yaml` et la source modifiable OpenRaster `.ora` portent le même identifiant. L'exemple complet livré est `potager_plante_tomate_jeune_ordinaire_00`.

La fiche fixe le canevas logique 1×, l'ancrage au contact du sol en pixels du master 4×, l'emprise en cases de la grille, la classe de taille, l'état, la variante, le nombre de frames, les rôles de palette, la projection et la lumière. Les valeurs partagées sont : dessus de case **80 × 40** points, pas d'emprise par demi-case, lumière `upper_left`, ombre de contact `separate_contact`. Le manifeste conserve cet ancrage ; le moteur le projette depuis les pixels visibles et dessine l'ombre juste avant chaque objet, dans l'ordre de profondeur. Les limites de silhouette à 1× sont : petite plante 80 × 100, arbre 160 × 150. Les noms de couleur autorisés et leurs hexadécimaux sont fixés dans la [bible graphique](../ART_BIBLE.md), section « Couleur, lumière et matières ».

Le master est un PNG RGBA transparent sRGB à 4× ; le canevas garde au moins quatre pixels masters transparents autour de la silhouette. Les exports 3× et 2× sont dérivés du master, sans retouche indépendante. Un sprite fixe possède une image complète ; une future animation devra partager canevas et ancrage entre ses frames. Aucune capture complète, texture de fond opaque ou ombre noire incorporée au sprite ne passe ce contrat.

## Ajouter ou remplacer un sprite

Depuis la racine du dépôt, avec Pillow et PyYAML installés :

```text
python3 scripts/export_sprite.py <identifiant>
python3 scripts/build_sprite_manifest.py
python3 scripts/validate_sprites.py
```

L'export lit `assets/sprite_sources/<identifiant>.ora` et écrit le master dans `assets/sprites/`, puis les exports 3× et 2× dans `assets/sprite_exports/`. Le constructeur du manifeste mesure les pixels visibles et ajoute l'ancrage de la fiche. La validation vérifie la source modifiable, les trois résolutions, le nom, la transparence et sa marge, les dimensions, la classe de taille, les coordonnées d'ancrage, la grille, la lumière, le rôle de palette et la cohérence du manifeste. Une erreur nomme l'asset et la règle à corriger. Vérifier ensuite le rendu réel à 390 × 844 et 375 × 667 points, dans une scène complète et aux états pertinents.

Les 23 PNG végétaux hérités ont été normalisés en masters 4× avec exports 2× et 3×. Leurs originaux sont conservés dans `assets/sprite_archive/original_plants/` pour comparer les silhouettes. Le script `scripts/migrate_legacy_plants.py` documente cette migration ponctuelle. Chaque source ORA créée à partir d'un ancien PNG ou d'une génération porte une seule couche aplatie identifiée comme provisoire : elle ne recrée pas les couches de travail d'origine. `legacy_allowlist.json` est vide ; tout nouveau PNG sans fiche échoue au validateur. Le manifeste recense les 71 sprites actifs. Les prompts et la provenance des nouveaux décors figurent dans la [revue de l'issue 41](visual-review/issue-41/implementation/README.md).

Les captures déterministes des trois scènes, dans les états initial, intermédiaire et saturé, aux fenêtres logiques de 390 × 450 et 375 × 380 points correspondant aux écrans de 390 × 844 et 375 × 667, sont dans `docs/visual-review/`. Les fichiers `application_*.png` montrent en plus l'application Linux complète après navigation réelle entre les trois îlots, sur les deux écrans. Des variantes en niveaux de gris accompagnent toutes les captures de scène et d'application. La fixture isolée `lib/visual_fixture.dart` fournit les sauvegardes de revue et `scripts/capture_linux_visuals.py` pilote la fenêtre sous Xvfb ; l'entrée de production `lib/main.dart` ne crée pas ces sauvegardes.

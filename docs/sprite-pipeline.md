# Sprites du jardin

Le dépôt contient deux classes d'assets distinctes : les **anchored sprites** (sprites verticaux ancrés au sol, triés en profondeur) et les **surface tiles** (textures de grille alignées sur la cellule 80×40, peintes au pinceau dans Tiled). Voir [ADR-0009](../docs/adr/0009-surface-tile-classe-asset.md) pour la décision architecturale.

`assets/sprites/` contient les PNG RGBA modulaires référencés par le manifeste et chargés par Flame. Le chemin historique du Potager, `PotagerPath.stones`, reste disponible lorsque la carte Tiled ne porte pas encore de sol ; une carte peinte utilise ses surface tiles 80×40. Le terrain Canvas est remplacé dans le Potager dès que la couche `ground` de la TMX est peinte (voir [ADR-0008](../docs/adr/0008-tiled-composition-visuelle.md)). Les anciens PNG de décor remplacés sont archivés dans `assets/sprite_archive/`, hors du bundle. Les maquettes complètes de `art-mockups/` et `test.png` sont des références visuelles ; elles ne sont jamais déclarées comme assets de l'application.

## Anchored sprite — contrat d'un nouvel asset

Un identifiant stable suit `zone_famille_objet_etat_variante_frame`, en minuscules ASCII. La fiche `assets/sprite_sources/<identifiant>.yaml` et la source modifiable OpenRaster `.ora` portent le même identifiant. L'exemple complet livré est `potager_plante_tomate_jeune_ordinaire_00`.

La fiche fixe le canevas logique 1×, l'ancrage au contact du sol en pixels du master 4×, l'emprise en cases de la grille, la classe de taille, l'état, la variante, le nombre de frames, les rôles de palette, la projection et la lumière. Les valeurs partagées sont : dessus de case **80 × 40** points, pas d'emprise par demi-case, lumière `upper_left`, ombre de contact `separate_contact`. Le manifeste conserve cet ancrage ; le moteur le projette depuis les pixels visibles et dessine l'ombre juste avant chaque objet, dans l'ordre de profondeur. Les limites de silhouette à 1× sont : petite plante 80 × 100, arbre 160 × 150. Les noms de couleur autorisés et leurs hexadécimaux sont fixés dans la [bible graphique](../ART_BIBLE.md), section « Couleur, lumière et matières ».

Le master est un PNG RGBA transparent sRGB à 4× ; le canevas garde au moins quatre pixels masters transparents autour de la silhouette. Les exports 3× et 2× sont dérivés du master, sans retouche indépendante. Un sprite fixe possède une image complète ; une future animation devra partager canevas et ancrage entre ses frames. Aucune capture complète, texture de fond opaque ou ombre noire incorporée au sprite ne passe ce contrat.

## Surface tile — contrat d'un nouvel asset de grille

Les surface tiles sont des textures alignées sur la grille Tiled 80×40, pas des sprites verticaux ancrés. Elles peignent le sol, les bordures et les tranches de terre. Le bord d'îlot utilise deux couches distinctes : une couche de surface (herbe + débordements organiques maîtrisés) et une couche de jupe (tranche de terre sur les bords extérieurs uniquement). L'occupation logique reste la cellule ; la silhouette visuelle peut déborder légèrement.

### Authoring

L'art est produit à 4× (320×160 pixels pour une cellule 80×40). Le master n'est jamais peint directement à 80×40. L'export 1× (80×40) est dérivé du master par downsampling déterministe. Le résultat final 80×40 ne doit pas dépendre de détails qui disparaissent après downsampling.

Les sources modifiables sont organisées par famille, pas par tile individuel. Un ORA par famille (`ground_grass_master.ora`, `ground_earth_master.ora`, `ground_edges_master.ora`, `ground_skirt_master.ora`) contient les variantes de cette famille. Les tiles individuels sont exportés depuis le master de leur famille. Le kit Potager contient 5 herbes intérieures, 11 terres (intérieurs, côtés et coins), 12 bordures d'herbe, 6 tranches de terre et les 6 pas de pierre dérivés.

### Naming

Les surface tiles suivent le suffixe `_tile_XX` : `commun_sol_herbe_tile_00`, `commun_sol_terre_tile_00`, `commun_sol_bordure_herbe_tile_00`. Les pas de pierre existants (`commun_sol_pas_pierre_tile_00`…`_05`) suivent déjà cette convention.

### Livrables

Requis : source modifiable 4× par famille (`.ora`) ; export 1× 80×40 PNG RGBA transparent ; nom stable ; référence dans le TSX généré ; métadonnées suffisantes pour régénérer les exports.

Non requis : fiche YAML individuelle par tile ; entrée au manifeste runtime ; ground anchor ; exports 2×/3× ; un ORA par tile individuel.

### Tiles dérivés d'anchored sprites

Les six `commun_sol_pas_pierre_tile_00.png`…`_05.png` sont des surface tiles dérivés des anchored sprites `commun_sol_pas_pierre_statique_ordinaire_*.png`. `python3 scripts/build_tiled_stone_tiles.py` les régénère en 80×40 transparent à partir des PNG et des ancres du manifeste. Le master de référence est l'anchored sprite 4× ; il n'y a pas d'ORA de surface tile séparé pour les pas de pierre.

### TSX générés

Les TSX de Tiled sont générés depuis l'inventaire des surface tiles et le manifeste des anchored sprites. Ils ne sont jamais édités manuellement dans Tiled. Le workflow est : `manifeste / inventaire → générateur → *.tsx → Tiled`. Le CI vérifie que les TSX commités sont à jour. Les `gid` Tiled sont des détails techniques de fichier et ne sont jamais des identifiants persistés ou métier ; les noms d'assets et d'objets restent canoniques.

### Review maps

Les maps de démonstration Tiled vivent dans `tools/tiled/review/`, hors du bundle applicatif. Elles sont des outils de production artistique, pas des assets du jeu.

### Régénération du kit Potager

`assets/surface_sources/inventory.json` énumère les familles et les exports 80×40. Les quatre ORA `*_master.ora` portent chacun des couches 320×160 nommées comme leurs exports. Les références peintes de matière sont dans le même dossier ; `scripts/author_surface_kit.py` a servi à amorcer les ORA et **réécrit ces sources** s'il est relancé. Après une retouche manuelle dans l'ORA, exporter sans réamorcer :

```sh
python3 scripts/build_surface_tiles.py
python3 scripts/build_tiled_stone_tiles.py
python3 scripts/build_tiled_tilesets.py
python3 scripts/build_tiled_review_map.py
python3 scripts/build_surface_tiles.py --check
python3 scripts/build_tiled_tilesets.py --check
```

`assets/maps/palette_audit.json` classe chaque entrée du manifeste et fixe sa palette (`floor_decor`, `vegetation`, `rocks`, `structures`, `props`, `paths_anchored`). Le générateur vérifie que toutes les entrées sont classées et que les deltas d'ancre des sprites inclus restent dans la famille de prévisualisation `(0, -13)` à ±1 pixel master. Les TSX `ground` et `paths` sont des surface tiles sans `tileoffset` ; les palettes d'anchored sprites ont ce décalage de prévisualisation. `growstep.tsx` est maintenu par le générateur pour les anciennes cartes de revue du PoC.

Dans Tiled, `gridCol` et `gridRow` sont des propriétés `float` en cellules entières ou demi-cellules ; `shadow` peut être `none`, `small`, `medium`, `large` ou `elongated`. Le manifeste fournit l'ombre par défaut et l'ancre canonique au runtime. Dans la map applicative, `ground`, `skirt` et `path` ne contiennent que des surface tiles 80×40. Les anchored sprites se placent dans les object layers (`floor_decor`, `vegetation`, `rocks`, `structures`, `props`, `edge_overlays`) avec une taille logique correspondant à un quart de leur master 4×. Lorsque `ground` est peint, Tiled remplace le terrain, le chemin et les décors statiques Canvas du Potager ; les empreintes et plantes liées aux emplacements restent dynamiques dans Growstep. La review map exerce le kit complet hors de l'application.

## Ajouter ou remplacer un anchored sprite

Depuis la racine du dépôt, avec Pillow et PyYAML installés :

```text
python3 scripts/export_sprite.py <identifiant>
python3 scripts/build_sprite_manifest.py
python3 scripts/validate_sprites.py
```

L'export lit `assets/sprite_sources/<identifiant>.ora` et écrit le master dans `assets/sprites/`, puis les exports 3× et 2× dans `assets/sprite_exports/`. Le constructeur du manifeste mesure les pixels visibles et ajoute l'ancrage de la fiche. La validation vérifie la source modifiable, les trois résolutions, le nom, la transparence et sa marge, les dimensions, la classe de taille, les coordonnées d'ancrage, la grille, la lumière, le rôle de palette et la cohérence du manifeste. Une erreur nomme l'asset et la règle à corriger. Vérifier ensuite le rendu réel à 390 × 844 et 375 × 667 points, dans une scène complète et aux états pertinents.

Les 23 PNG végétaux hérités ont été normalisés en masters 4× avec exports 2× et 3×. Leurs originaux sont conservés dans `assets/sprite_archive/original_plants/` pour comparer les silhouettes. Le script `scripts/migrate_legacy_plants.py` documente cette migration ponctuelle. Chaque source ORA créée à partir d'un ancien PNG ou d'une génération porte une seule couche aplatie identifiée comme provisoire : elle ne recrée pas les couches de travail d'origine. `legacy_allowlist.json` est vide ; tout nouveau PNG source sans fiche échoue au validateur. Le manifeste recense les sprites actifs. Les prompts et la provenance des nouveaux décors figurent dans la [revue de l'issue 41](visual-review/issue-41/implementation/README.md).

Les captures déterministes des trois scènes, dans les états initial, intermédiaire et saturé, aux fenêtres logiques de 390 × 450 et 375 × 380 points correspondant aux écrans de 390 × 844 et 375 × 667, sont dans `docs/visual-review/`. Les fichiers `application_*.png` montrent en plus l'application Linux complète après navigation réelle entre les trois îlots, sur les deux écrans. Des variantes en niveaux de gris accompagnent toutes les captures de scène et d'application. La fixture isolée `lib/visual_fixture.dart` fournit les sauvegardes de revue et `scripts/capture_linux_visuals.py` pilote la fenêtre sous Xvfb ; l'entrée de production `lib/main.dart` ne crée pas ces sauvegardes.

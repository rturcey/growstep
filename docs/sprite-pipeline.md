# Sprites du jardin

`assets/sprites/` contient uniquement les PNG RGBA modulaires chargés par Flame : terrain, platebandes, végétaux, arbres, accessoires et animal. Les maquettes complètes de `art-mockups/` et `test.png` sont des références visuelles ; elles ne sont jamais déclarées comme assets de l'application.

Pour le Potager, sept végétaux et objets de décor sont maintenant des sprites RGBA modulaires : deux bosquets, un ensemble de rochers et d'herbes, un treillis, un tonneau, un arrosoir et une caisse. Le terrain, les platebandes et le tracé des chemins restent en Canvas. Les sources ORA, fiches YAML, masters 4× et exports 2×/3× suivent le même contrat que les plantes ; les prompts et la provenance sont documentés dans [la revue de l'issue 41](visual-review/issue-41/implementation/README.md).

## Contrat d'un nouvel asset

Un identifiant stable suit `zone_famille_objet_etat_variante_frame`, en minuscules ASCII. La fiche `assets/sprite_sources/<identifiant>.yaml` et la source modifiable OpenRaster `.ora` portent le même identifiant. L'exemple complet livré est `potager_plante_tomate_jeune_ordinaire_00`.

La fiche fixe le canevas logique 1×, l'ancrage au contact du sol en pixels du master 4×, l'emprise en cases de la grille, la classe de taille, l'état, la variante, le nombre de frames, les rôles de palette, la projection et la lumière. Les valeurs partagées sont : dessus de case **80 × 40** points, pas d'emprise par demi-case, lumière `upper_left`, ombre de contact `separate_contact`. Le manifeste conserve cet ancrage ; le moteur le projette depuis les pixels visibles et dessine l'ombre dans une passe séparée. Les limites de silhouette à 1× sont : petite plante 80 × 100, arbre 160 × 150, platebande 80 × 70, petit décor 80 × 80, case de terrain 80 × 68 points. Les noms de couleur autorisés et leurs hexadécimaux sont fixés dans la [bible graphique](../ART_BIBLE.md), section « Couleur, lumière et matières ».

Le master est un PNG RGBA transparent sRGB à 4× ; le canevas garde au moins quatre pixels masters transparents autour de la silhouette. Les exports 3× et 2× sont dérivés du master, sans retouche indépendante. Un sprite fixe possède une image complète ; une future animation devra partager canevas et ancrage entre ses frames. Aucune capture complète, texture de fond opaque ou ombre noire incorporée au sprite ne passe ce contrat.

## Ajouter ou remplacer un sprite

Depuis la racine du dépôt, avec Pillow et PyYAML installés :

```text
python3 scripts/export_sprite.py <identifiant>
python3 scripts/build_sprite_manifest.py
python3 scripts/validate_sprites.py
```

L'export lit `assets/sprite_sources/<identifiant>.ora` et écrit le master dans `assets/sprites/`, puis les exports 3× et 2× dans `assets/sprite_exports/`. Le constructeur du manifeste mesure les pixels visibles et ajoute l'ancrage de la fiche. La validation vérifie la source modifiable, les trois résolutions, le nom, la transparence et sa marge, les dimensions, la classe de taille, les coordonnées d'ancrage, la grille, la lumière, le rôle de palette et la cohérence du manifeste. Une erreur nomme l'asset et la règle à corriger. Vérifier ensuite le rendu réel à 390 × 844 et 375 × 667 points, dans une scène complète et aux états pertinents.

Les PNG antérieurs sans source ni fiche sont recensés explicitement dans `legacy_allowlist.json`. Cette liste ferme uniquement la migration des assets déjà présents : un nouveau PNG sans fiche échoue. Lorsqu'un ancien asset est reconstruit selon le contrat, retirer son nom de cette liste.

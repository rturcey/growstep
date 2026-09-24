# PNG hérités archivés

Les 16 PNG de décor placés à la racine de ce dossier ont été retirés de `assets/sprites/` et du manifeste : la scène les remplace par du Canvas. `original_plants/` conserve les 23 PNG végétaux avant leur normalisation en masters 4×. Ces fichiers servent de référence visuelle et ne sont pas déclarés dans `pubspec.yaml` ; ils ne sont donc pas chargés par l'application.

Le script ponctuel `scripts/migrate_legacy_plants.py` consigne la méthode de normalisation. Les fiches des sprites actifs sont dans `assets/sprite_sources/`. Les ORA hérités y sont provisoirement aplatis.

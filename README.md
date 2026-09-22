# Growstep

Application iPhone locale où la marche fait évoluer un jardin isométrique. Le [game design](docs/game-design.md) décrit les règles retenues ; cette tranche implémente les issues [#11](https://github.com/rturcey/growstep/issues/11), [#12](https://github.com/rturcey/growstep/issues/12), [#13](https://github.com/rturcey/growstep/issues/13) et [#15](https://github.com/rturcey/growstep/issues/15).

Le joueur choisit une graine commune offerte dans chaque zone, plante dans le potager, le jardin fleuri ou le verger, puis voit les mêmes nouveaux pas faire progresser toutes ses plantes. Une plante mûre attend la récolte, donne des graines et relance un cycle de production. Les pas sont encore simulés dans cette tranche ; la lecture iPhone appartient à [#14](https://github.com/rturcey/growstep/issues/14). Les florins de récolte, lots et achats seront ajoutés dans les issues suivantes.

Les sauvegardes de l'ancienne démonstration à eau sont reprises automatiquement : le tournesol reste dans le jardin, ses doses déjà versées deviennent une progression de croissance, et chaque dose d'eau inutilisée devient un florin. Les anciennes valeurs sont aussi conservées dans l'archive de migration de la sauvegarde.

## Démarrer

Avec Flutter stable installé :

```sh
flutter pub get
flutter run
```

## Vérifier

```sh
flutter analyze
flutter test
```

La génération iOS et l'exécution sur iPhone nécessitent macOS avec Xcode. Le dépôt peut être analysé et testé sur Linux.

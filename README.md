# Growstep

Application iPhone locale où la marche fait évoluer un jardin isométrique.

Le premier parcours jouable correspond au [ticket #3](https://github.com/rturcey/growstep/issues/3) : semer un tournesol, ajouter des pas simulés, gagner une dose d'eau tous les 300 pas, puis arroser trois fois pour voir la jeune plante. Le jardin et le stock d'eau sont conservés dans SQLite avec Drift. Flame dessine uniquement la parcelle ; les règles sont en Dart pur.

## Démarrer

Avec Flutter stable installé :

```sh
flutter pub get
flutter run
```

L'écran indique clairement que les pas sont simulés. La lecture des vrais pas appartient au [ticket #5](https://github.com/rturcey/growstep/issues/5).

## Vérifier

```sh
flutter analyze
flutter test
```

Après une modification du schéma Drift :

```sh
dart run build_runner build
```

La génération iOS et l'exécution sur iPhone nécessitent un environnement macOS avec Xcode. Le dépôt peut être analysé et testé sur Linux.

# Gabarit visuel du jardin

Le gabarit Flame de l'écran principal sert à vérifier la géométrie de [`ART_BIBLE.md`](../ART_BIBLE.md) avant la production des sprites. Les formes colorées sont des repères, pas des assets finaux.

Ce document décrit le gabarit de l'implémentation actuelle, antérieur à la décision des [trois îlots distincts à débloquer](adr/0004-ilots-distincts-a-debloquer.md). Il ne définit plus la navigation cible.

Lancer l'application avec `flutter run`. Le potager s'ouvre au centre ; les flèches passent au jardin fleuri puis au verger avec une caméra à échelle constante. Toucher un emplacement affiche son numéro et son contour. L'icône de toucher affiche ou masque les carrés de cible de 44 × 44 points. « Aperçu de la zone remplie » affiche toutes les positions et des plantes schématiques sans modifier la sauvegarde.

Vérifier le cadrage en portrait à 390 × 844 et 375 × 667 points : huit emplacements visibles dans chacune des deux zones de culture, trois arbres visibles au verger, aucun chevauchement des cibles, et aucun végétal coupé en haut du petit écran. Le plateau garde les mêmes dimensions lors du passage d'une zone à l'autre ; seule la fenêtre se déplace de 340 points, ce qui laisse 50 points de liaison entre deux cadrages.

Les cartes de gestion et les pas simulés sous la scène sont ceux de l'itération actuelle. Ce gabarit ne définit pas encore l'interface finale ni les animations des futurs sprites.

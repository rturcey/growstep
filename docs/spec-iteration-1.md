## Problem Statement

Une personne sédentaire souhaite marcher davantage, mais les objectifs de pas abstraits et les rappels culpabilisants l'aident peu à agir au quotidien. Elle a besoin d'un progrès visible après ses marches, de pauses faciles à lancer et d'une expérience qui ne punit ni les journées calmes ni les interruptions.

## Solution

Créer une application iPhone locale et sans compte où les pas font évoluer un jardin isométrique. Les pas donnent de l'eau ; deux paliers quotidiens donnent de l'engrais. Le joueur plante, arrose et fait mûrir cinq espèces sur quatre parcelles. Des pauses marche de quinze minutes, lancées depuis l'application ou à partir d'une invitation, offrent une dose d'eau bonus si l'objectif réglable est atteint. Les invitations suivent les heures choisies ; le filtre d'inactivité s'applique seulement quand l'application peut vérifier les pas récents. Aucune récompense acquise n'est retirée.

## User Stories

1. En tant que personne sédentaire, je veux voir un jardin évoluer avec mes pas, afin de percevoir immédiatement l'effet de ma marche.
2. En tant que joueur, je veux utiliser l'application sur iPhone sans créer de compte, afin de commencer sans inscription.
3. En tant que joueur, je veux conserver mon jardin localement, afin de le retrouver après fermeture et redémarrage de l'application.
4. En tant que joueur, je veux voir quatre parcelles, afin de choisir où planter.
5. En tant que joueur, je veux choisir librement parmi cinq graines gratuites et illimitées, afin d'essayer les cinq espèces.
6. En tant que joueur, je veux planter un tournesol, une tulipe, une tomate, une lavande ou un petit arbre, afin de composer mon jardin.
7. En tant que joueur, je veux voir les états pousse, jeune plante et plante mature de chaque espèce, afin de comprendre sa progression.
8. En tant que joueur, je veux que mes pas effectués hors de l'application comptent aussi, afin de ne pas devoir garder l'application ouverte.
9. En tant que joueur, je veux recevoir une dose d'eau par tranche complète de 300 pas dans une journée, afin que de courtes marches fassent progresser le jardin.
10. En tant que joueur, je veux voir les doses d'eau disponibles, afin de décider quand et où arroser.
11. En tant que joueur, je veux choisir la plante à arroser, afin d'orienter la croissance du jardin.
12. En tant que joueur, je veux voir la progression de chaque transition sur trois doses d'eau, afin de comprendre ce qui manque à la prochaine étape.
13. En tant que joueur, je veux qu'une plante passe de pousse à jeune plante après trois doses d'eau, afin de voir un résultat concret.
14. En tant que joueur, je veux qu'une jeune plante devienne mature après trois autres doses d'eau, afin d'achever sa croissance.
15. En tant que joueur, je veux recevoir une dose d'engrais à 1 500 puis à 3 000 pas dans la journée, afin que les marches plus longues soient aussi reconnues.
16. En tant que joueur, je veux choisir la plante qui reçoit l'engrais, afin de terminer immédiatement sa transition en cours.
17. En tant que joueur, je veux que l'engrais termine une transition sans eau supplémentaire, afin de pouvoir accélérer une plante même après un arrosage partiel.
18. En tant que joueur, je veux garder une plante mature dans sa parcelle, afin de profiter du jardin obtenu.
19. En tant que joueur, je veux remplacer librement une plante mature par une nouvelle graine, afin de continuer à faire évoluer mon jardin.
20. En tant que joueur, je veux conserver sans plafond mes doses d'eau et d'engrais non utilisées, afin de les employer plus tard.
21. En tant que joueur, je veux choisir autant d'heures d'invitation quotidiennes que je le souhaite, afin de placer les pauses dans mon emploi du temps.
22. En tant que joueur, je veux recevoir au plus une invitation par heure choisie et par jour, afin de connaître le rythme des rappels.
23. En tant que joueur, je veux éviter une invitation si j'ai déjà marché au moins 50 pas dans les 30 minutes précédentes et que l'application peut le vérifier, afin de limiter les rappels inutiles.
24. En tant que joueur, je veux pouvoir lancer une pause manuellement à tout moment, afin de marcher sans attendre une invitation.
25. En tant que joueur, je veux régler l'objectif de pause de 300 à 1 000 pas par incréments de 50, afin de choisir mon défi.
26. En tant que joueur, je veux réussir une pause dès que j'atteins mon objectif dans les quinze minutes, afin de ne pas devoir attendre inutilement.
27. En tant que joueur, je veux que ma pause continue si je verrouille l'iPhone ou quitte l'application, afin de marcher librement.
28. En tant que joueur, je veux que mes pas soient vérifiés à la réouverture, même après quinze minutes, afin de recevoir une récompense gagnée pendant la pause.
29. En tant que joueur, je veux recevoir une dose d'eau bonus pour chaque pause réussie dès que mes pas sont disponibles, afin de voir l'effet de ma marche.
30. En tant que joueur, je veux que mes pas au-delà de l'objectif alimentent le cumul quotidien, afin qu'ils restent utiles.
31. En tant que joueur, je veux recommencer une pause plusieurs fois par jour, afin de multiplier les occasions de marcher.
32. En tant que joueur, je veux ignorer ou interrompre une pause sans malus, afin que l'application reste encourageante.
33. En tant que joueur, je veux que les pas ajoutés tardivement créditent les récompenses manquées, afin que la synchronisation ne me pénalise pas.
34. En tant que joueur, je veux conserver toute récompense déjà obtenue après une correction des pas à la baisse, afin que mon jardin ne régresse jamais.
35. En tant que joueur, je veux consulter mon jardin même si mes pas sont indisponibles, afin de ne pas perdre l'accès à l'application.
36. En tant que joueur, je veux lancer une pause manuelle si je refuse les notifications, afin de garder cette fonction sans rappels.

## Implementation Decisions

- Application iPhone en Flutter ; Flame sert uniquement au rendu du jardin isométrique 2.5D. Aucune logique métier ne dépend de Flame.
- Logique métier en Dart pur, stockage local SQLite/Drift, aucun compte, backend ni cloud.
- `StepProvider` abstrait ; une implémentation factice alimente les tests. Le fournisseur iOS utilise provisoirement HealthKit, selon la recherche documentaire du dépôt. Les totaux quotidiens et les intervalles de pause sont relus par requêtes statistiques cumulatives.
- Un point d'entrée applicatif orchestre les pas, la journée locale, les doses, les parcelles, les pauses et les invitations. Il expose l'état observable à l'interface et reçoit des dépendances remplaçables pour les pas, l'horloge, la persistance et la programmation des notifications.
- La journée de pas suit minuit à minuit dans le fuseau local de l'iPhone. Chaque tranche complète de 300 pas du jour accorde une dose d'eau ; le reliquat est remis à zéro le lendemain. Les stocks de doses d'eau et d'engrais persistent sans plafond.
- Les paliers de 1 500 et 3 000 pas sont attribués une fois chacun par journée. Les lectures répétées, ajouts tardifs et corrections ne créent pas de doublons. Les hausses rétroactives créditent les manques ; aucune baisse ne révoque une récompense, conformément à l'ADR-0001.
- Quatre parcelles ; cinq espèces disponibles sans déblocage. Une plantation commence à l'état pousse. Trois doses d'eau terminent chaque transition. Une dose d'engrais termine la transition courante, même partiellement arrosée ; l'eau déjà versée a contribué à cette transition et ne se reporte pas. Une plante ne peut être remplacée qu'à maturité.
- Une pause capture son début, son objectif réglé pour cette pause et son échéance quinze minutes plus tard. Le comptage porte uniquement sur les pas de cet intervalle. La réussite est créditée au plus une fois ; les pas au-delà de l'objectif ne créent pas de deuxième bonus, mais restent dans le cumul quotidien. L'application relit l'intervalle à la reprise, y compris après l'échéance.
- Les heures d'invitation choisies se répètent quotidiennement sans limite de nombre et produisent au plus une invitation chacune par jour. Lorsque l'application est active, elle supprime l'invitation si au moins 50 pas ont été détectés dans les 30 minutes précédentes ou si une pause est en cours.
- Les notifications locales ne peuvent pas garantir ce filtre lorsque l'application est suspendue ou fermée : une invitation programmée peut donc arriver malgré une marche récente. Cette limite fait partie du comportement annoncé, et une pause manuelle reste possible si les notifications sont refusées.
- Lorsque les pas sont indisponibles, le jardin reste consultable ; la progression par la marche attend des données. HealthKit ne révèle pas si la lecture a été refusée : l'interface ne doit pas présenter un total nul comme la preuve d'un refus. Aucune plante ne meurt, aucune série punitive et aucune perte de ressources ne sont introduites.

## Testing Decisions

- Tester le comportement observable au point d'entrée applicatif en Dart : état du jardin, doses accordées, transition des plantes, pauses et invitations. Utiliser le faux `StepProvider`, une horloge contrôlée et une persistance remplaçable. Éviter les tests qui recopient les détails internes du calcul.
- Couvrir les frontières qui changent le résultat : 299/300 pas, 1 499/1 500 et 2 999/3 000 pas, minuit local, trois doses par transition, engrais après arrosage partiel, objectif de pause atteint juste avant/après quinze minutes, lectures répétées et corrections tardives.
- Vérifier la conservation du stock, le remplacement réservé aux plantes matures, plusieurs pauses dans une journée, une seule dose bonus par réussite et l'absence de malus après pause ignorée ou interrompue.
- Tester les parcours de lecture, reprise et données indisponibles avec le faux `StepProvider`. La latence réelle HealthKit après verrouillage et reprise sera mesurée plus tard, sans bloquer l'implémentation initiale.
- Il n'existe aucun test ni code antérieur dans le dépôt ; aucun modèle de test existant ne peut être repris. Le scénario applicatif ci-dessus est donc le premier point de test proposé.

## Out of Scope

Android ; backend et cloud ; compte utilisateur ; chien et mode Promener ; boutique et achats ; décoration avancée ; géolocalisation ; fonctionnalités sociales ; malus, plantes mortes et séries punitives.

## Further Notes

- Le choix HealthKit est provisoire. La documentation Apple permet de concevoir la lecture de l'historique et la reprise, mais ne garantit pas le délai d'arrivée des pas ; un essai sur appareil pourra être fait plus tard.
- Une invitation à heure fixe peut arriver alors que la personne a déjà marché si l'application ne pouvait pas vérifier son activité juste avant l'envoi.
- Le vocabulaire métier et l'ADR-0001 du dépôt font autorité pour les termes et le traitement des corrections de pas.

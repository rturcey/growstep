# Première itération — cadrage

## Intention

Aider une personne sédentaire à marcher davantage grâce à un jardin virtuel isométrique 2.5D qui progresse avec ses pas. La progression doit rester encourageante : aucun malus, aucune plante morte et aucune série punitive.

## Périmètre

- Application iPhone, sans compte, utilisable localement.
- Petit jardin isométrique, quatre parcelles ; tournesol, tulipe, tomate, lavande et petit arbre, chacun avec les étapes pousse, jeune plante et plante mature.
- Choix d'une graine et plantation dans une parcelle.
- Récupération automatique des pas ; les pas alimentent l'eau et les paliers quotidiens accordent de l'engrais.
- Mode anti-sédentarité pendant des horaires choisis, avec invitations à faire une pause marche et récompense visible dès que les pas de la pause sont disponibles.

Hors périmètre : Android, backend, cloud, compte utilisateur, chien et mode Promener, boutique et achats, décoration avancée, géolocalisation, fonctionnalités sociales.

## Règles retenues

1. Tous les pas de la journée récupérés sur l'iPhone contribuent au jardin, y compris ceux effectués hors de l'application. Chaque tranche complète de 300 pas dans la journée crée une dose d'eau ; le reliquat repart à zéro le lendemain. Le joueur choisit la plante qui reçoit chaque dose.
2. Les cinq graines sont disponibles gratuitement et sans limite dès le départ. Il faut trois doses d'eau pour passer de pousse à jeune plante, puis trois autres pour atteindre la maturité. Seule une plante mature peut être remplacée ; elle peut aussi rester dans sa parcelle. Les doses d'eau et d'engrais non utilisées se conservent d'un jour à l'autre sans plafond.
3. À 1 500 puis 3 000 pas dans la journée, le joueur reçoit chaque fois une dose d'engrais. Il choisit la plante ; une dose d'engrais termine immédiatement la transition en cours sans consommer d'eau supplémentaire. Les doses d'eau déjà versées ont contribué à cette transition et ne se reportent pas sur la suivante.
4. Des invitations sont programmées aux heures choisies. Lorsque l'application est active, une invitation est supprimée si au moins 50 pas ont été détectés pendant les 30 minutes précédentes. Lorsque l'application est suspendue ou fermée, l'invitation peut arriver même si la personne a marché.
5. Le joueur lance une pause marche avec « Commencer ». La réussite dépend d'un objectif initial de 300 pas dans les 15 minutes qui suivent, sans durée minimale obligatoire. Le joueur peut régler l'objectif de 300 à 1 000 pas par incréments de 50. Les pas au-delà de l'objectif continuent d'alimenter le cumul quotidien, sans récompense de pause supplémentaire. Une pause continue à être mesurée si l'iPhone est verrouillé ou l'application quittée ; les pas sont relus à la reprise, même après les 15 minutes, et la récompense est créditée si l'objectif avait été atteint à temps.
6. Une pause réussie accorde une dose d'eau bonus, quel que soit l'objectif choisi, distincte des doses obtenues par le cumul quotidien. Elle apparaît dès que les pas nécessaires sont disponibles si l'application est active, ou à la réouverture après vérification des pas. Un échec, une interruption ou une invitation ignorée ne retirent aucune ressource ni progression.
7. Le joueur peut choisir sans limite le nombre d'heures d'invitation quotidiennes. Chaque heure se répète tous les jours et donne au plus une invitation par jour ; lorsqu'une pause est en cours et que l'application peut le vérifier, l'invitation est supprimée. Les pauses peuvent aussi être lancées manuellement à tout moment, plusieurs fois par jour, avec une dose bonus à chaque réussite.
8. La journée de pas suit minuit à minuit dans le fuseau local de l'iPhone. Si des pas d'une journée passée sont ajoutés avec retard, les doses d'eau et d'engrais manquées sont créditées ; une correction à la baisse ne retire jamais une récompense déjà donnée.
9. Si les pas ne sont pas accessibles, le jardin reste consultable mais sa progression par la marche attend des données. L'application ne peut pas distinguer avec certitude un refus de lecture HealthKit d'une absence de pas. Si les notifications sont refusées, les pauses restent accessibles manuellement dans l'application.

## Contraintes techniques déjà décidées

- Flutter pour l'application ; Flame uniquement pour le jardin.
- SQLite/Drift pour le stockage local ; logique métier en Dart pur.
- Interface `StepProvider` abstraite et faux fournisseur de pas pour les tests.
- `StepProvider` iOS fondé provisoirement sur HealthKit, selon [la recherche documentaire](research/lecture-pas-ios.md).
- Notifications locales pour les invitations.

## Contrainte iOS vérifiée

Une notification locale ne peut pas être garantie comme conditionnée aux pas des 30 minutes précédentes quand l'application est suspendue ou fermée. Core Motion permet de relire les pas, mais son flux direct s'arrête pendant la suspension ; les réveils HealthKit en arrière-plan pour les pas ne sont pas assez fréquents pour garantir cette condition à une heure précise. Les invitations à heures fixes restent donc possibles, avec filtrage de l'inactivité lorsque l'application est active. Sources : [Core Motion](https://developer.apple.com/documentation/coremotion/cmpedometer/startupdates%28from%3Awithhandler%3A%29), [HealthKit](https://developer.apple.com/documentation/healthkit/hkhealthstore/enablebackgrounddelivery%28for%3Afrequency%3Awithcompletion%3A%29), [notifications locales](https://developer.apple.com/documentation/usernotifications/scheduling-a-notification-locally-from-your-app).

## Vérifications techniques pendant l'implémentation

- Vérifier par tests de la logique Dart le calcul des pas d'une pause, la relecture après reprise et les récompenses uniques ; la latence réelle HealthKit sera mesurée plus tard sur appareil.
- Garantir le crédit unique des doses et paliers lors de relectures, corrections tardives et changements de fuseau horaire.
- Vérifier la programmation et l'annulation des notifications locales pour des heures rapprochées, une pause en cours et un refus d'autorisation.

## ADR

- [ADR-0001 — Ne pas retirer les récompenses déjà accordées](adr/0001-recompenses-irrevocables.md) : les corrections tardives des pas ne peuvent pas rendre le jardin punitif.

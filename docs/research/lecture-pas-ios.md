# Lecture des pas sur iPhone — choix provisoire

## Décision de travail

Utiliser **HealthKit** comme source canonique des pas pour la première itération, derrière `StepProvider`. Lire le total des pas par journée locale et le total sur l'intervalle d'une pause avec des requêtes statistiques cumulatives. Relire les périodes concernées à l'ouverture de l'application et lors des mises à jour reçues ; la logique métier crédite uniquement les récompenses encore dues.

Ce choix est provisoire : il repose sur la documentation Apple et pourra être revu lorsque l'application sera exécutée sur un véritable iPhone. Il ne constitue pas une validation de latence ni de fiabilité sur appareil.

## Faits documentés

- HealthKit enregistre les pas provenant de l'iPhone et de l'Apple Watch. Ses requêtes statistiques peuvent calculer des totaux sur des intervalles et fusionnent les sources par défaut. [Pas HealthKit](https://developer.apple.com/documentation/healthkit/hkquantitytypeidentifier/stepcount) · [Requêtes statistiques](https://developer.apple.com/documentation/healthkit/executing-statistics-collection-queries) · [Fusion des sources](https://developer.apple.com/documentation/healthkit/hkstatistics)
- Une requête statistique suivie peut recevoir des mises à jour quand le magasin HealthKit change. Cette possibilité ne garantit aucun délai précis entre un pas et son apparition dans l'application. [Requêtes statistiques suivies](https://developer.apple.com/documentation/healthkit/hkstatisticscollectionquerydescriptor)
- Pour les pas, les réveils HealthKit en arrière-plan ont une fréquence maximale horaire. Ils ne permettent pas de vérifier de manière garantie les 30 dernières minutes juste avant une invitation. [Livraison en arrière-plan](https://developer.apple.com/documentation/healthkit/hkhealthstore/enablebackgrounddelivery%28for%3Afrequency%3Awithcompletion%3A%29)
- `CMPedometer` peut relire un intervalle historique, mais seulement dans les sept derniers jours. Son flux direct ne règle pas le besoin de récompenser les corrections plus anciennes. [Historique CMPedometer](https://developer.apple.com/documentation/coremotion/cmpedometer/querypedometerdata%28from%3Ato%3Awithhandler%3A%29)
- Apple ne révèle pas à l'application si la lecture HealthKit a été refusée : une réponse vide ne distingue pas un refus d'une absence de pas. Le jardin doit rester consultable et l'interface doit parler de **pas indisponibles**, sans affirmer que l'autorisation a été refusée. [Autorisation HealthKit](https://developer.apple.com/documentation/healthkit/authorizing-access-to-health-data)
- Une notification locale se programme sur une heure, un intervalle ou un lieu ; elle n'a pas de condition native fondée sur les pas. [Notifications locales](https://developer.apple.com/documentation/usernotifications/scheduling-a-notification-locally-from-your-app)

## Conséquences pour la première itération

- Les pas du jour, les pas ajoutés tardivement et les pas des pauses sont relus dans HealthKit ; les récompenses déjà données restent irrévocables conformément à l'ADR-0001.
- Une pause peut être validée après la réouverture en relisant ses quinze minutes. Quand l'application est active, la dose bonus apparaît dès que les données nécessaires sont disponibles ; l'instant exact n'est pas garanti par la documentation.
- Les invitations restent à heures fixes. Le filtre des 50 pas sur 30 minutes ne s'applique que lorsque l'application est active et peut interroger les données récentes.
- Si HealthKit ne livre aucune donnée lisible, le jardin reste consultable et l'application explique comment vérifier l'accès aux pas dans Santé. Elle ne diagnostique pas un refus à partir d'un total nul.

## À revisiter plus tard

Lorsque l'application pourra être exécutée sur un véritable iPhone, mesurer le délai d'apparition des pas dans HealthKit pendant une pause et après verrouillage. Si ce délai gêne la récompense immédiate, évaluer `CMPedometer` uniquement comme source de progression en direct pour la pause, en conservant HealthKit comme source canonique du cumul quotidien. Éviter d'additionner les deux sources dans le même total.

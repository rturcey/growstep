# Jardin de marche

Une application iPhone où la marche fait grandir et embellir un jardin virtuel. Les règles et valeurs de test figurent dans [le game design](docs/game-design.md).

## Language

**Jardin** : espace virtuel du joueur comprenant un potager, un jardin fleuri et un verger.

**Zone** : partie du jardin dédiée à une famille de plantes : légumes, fleurs ou arbres fruitiers.

**Emplacement de plantation** : place d'une zone pouvant accueillir une plante.
_Avoid_ : Parcelle

**Graine** : ressource d'une espèce donnée qui permet de démarrer une plante dans un emplacement.

**Plante** : végétal issu d'une graine, qui grandit avec les pas du joueur.

**Étape de croissance** : forme visible d'une plante entre sa germination et sa maturité.

**Plante mature** : plante arrivée à sa forme finale, qui peut être récoltée puis produire à nouveau tout en gardant sa taille.

**Cycle de production** : période pendant laquelle une plante mature accumule de nouveaux pas jusqu'à pouvoir être récoltée de nouveau.

**Récolte** : action du joueur qui reçoit les récompenses d'une plante prête et lance son éventuel cycle suivant sans retirer la plante.

**Variante brillante** : apparence très rare d'une espèce, plus longue à faire pousser que sa forme ordinaire.

**Florin** : monnaie unique du jardin, gagnée grâce à la marche ou achetée avec des euros.

**Quota quotidien de florins des plantes** : maximum de florins que les récoltes peuvent accorder au cours d'une journée.

**Palier quotidien** : seuil de pas d'une journée qui accorde un lot annoncé à l'avance.

**Palier d'embellissement** : transformation permanente du terrain débloquée par les pas cumulés du joueur.

**Engrais** : ressource appliquée à une plante pour accélérer sa croissance ou son cycle de production en cours.

**Décor** : objet permanent que le joueur peut placer et déplacer dans son jardin.

**Invitation à marcher** : rappel qui propose au joueur de lancer une pause marche.

**Pause marche** : marche volontaire dont la réussite dépend d'un objectif de pas à atteindre dans un délai donné.

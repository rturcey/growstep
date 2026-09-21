# Jardin de marche

Une application iPhone dans laquelle la marche fait progresser un jardin virtuel.

## Language

**Jardin** : espace virtuel contenant quatre parcelles et les plantes du joueur.

**Parcelle** : emplacement du jardin dans lequel le joueur peut planter une graine.

**Graine** : choix gratuit et disponible sans limite qui permet de démarrer une plante dans une parcelle ; cinq espèces sont proposées.

**Plante** : végétal issu d'une graine plantée dans une parcelle ; les cinq espèces disponibles sont le tournesol, la tulipe, la tomate, la lavande et le petit arbre.

**Étape de croissance** : état visible d'une plante entre sa plantation et sa forme finale ; chaque espèce en compte trois : pousse, jeune plante et plante mature. Trois doses d'eau font passer à l'étape suivante.

**Dose d'eau** : ressource obtenue par tranche complète de 300 pas dans une journée et attribuée par le joueur à une plante pour contribuer à sa prochaine étape de croissance ; le reliquat de pas repart à zéro le lendemain, mais les doses non utilisées se conservent sans plafond.

**Plante mature** : plante ayant atteint sa dernière étape de croissance ; le joueur peut la conserver ou la remplacer dans sa parcelle. Une plante encore en croissance ne peut pas être remplacée.

**Palier quotidien** : nombre de pas atteint dans une journée qui accorde une dose d'engrais ; les paliers sont de 1 500 et 3 000 pas chaque jour.

**Dose d'engrais** : ressource gagnée à un palier quotidien et attribuée par le joueur à une plante pour terminer immédiatement une étape de croissance sans dépenser d'eau. Les doses non utilisées se conservent sans plafond.

**Invitation à marcher** : proposition de pause marche à une heure choisie, répétée chaque jour ; elle peut être supprimée si au moins 50 pas ont été détectés pendant les 30 minutes précédentes.

**Pause marche** : marche commencée volontairement, depuis une invitation ou directement dans le jardin ; sa réussite dépend d'un objectif de pas mesuré pendant la pause.

**Objectif de pause** : nombre de pas à atteindre dans les quinze minutes d'une pause marche ; sa valeur initiale est de 300 pas et le joueur peut la régler jusqu'à 1 000 par incréments de 50 pas.

**Dose d'eau bonus** : dose d'eau accordée après une pause marche réussie, en plus des doses issues des pas quotidiens.

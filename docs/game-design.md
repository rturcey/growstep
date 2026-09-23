# Game design — Jardin de marche

Ce document décrit le design convenu pendant l'entretien. Les nombres indiqués comme **valeurs de test** servent à un premier équilibrage ; ils ne constituent pas encore des prix ou probabilités définitifs. La première itération technique décrite dans `docs/iteration-1.md` utilise encore l'ancien modèle à eau et engrais : elle ne décrit pas ce nouveau design.

## Promesse

Plus le joueur marche, plus son jardin se développe et devient beau : prendre soin de soi se traduit par cultiver son jardin. Le retour après une période sans marche reste accueillant. Aucune plante ne meurt, aucune ressource ni amélioration acquise ne disparaît, et aucune série punitive n'est prévue.

## Jardin et démarrage

Le jardin comporte trois zones sur trois îlots distincts : un potager, un jardin fleuri et un verger. Seul le potager est ouvert au lancement, avec 4 emplacements. Le jardin fleuri et le verger s'achètent de manière permanente uniquement avec des florins, aux prix de test de 100 et 250 florins. Le joueur peut acheter le verger en premier s'il en a les moyens. Aucun seuil de pas ni récompense de connexion ne les ouvre automatiquement. Ils disposent respectivement de 4 et 1 emplacements lorsqu'ils ouvrent ; leurs limites de test sont 8, 8 et 3. Une jeune carotte et un pied de tomate presque mature sont déjà visibles dans une nouvelle partie ; ce sont des cultures de départ offertes, exception explicite à la progression par les seuls pas du joueur. Une troisième platebande est réservée à la première plantation guidée et une quatrième reste vide. Chaque nouvel emplacement est choisi et acheté séparément dans sa zone. Les prix de test par zone sont 30, puis 45, 60 et 75 florins ; le verger n'utilise que les deux premiers prix.

Les huit espèces initiales sont communes : tomate, carotte et courgette au potager ; tournesol, tulipe et lavande au jardin fleuri ; pommier et poirier au verger. Le joueur choisit une graine commune offerte dans chaque zone au moment où elle s'ouvre. Tous les emplacements du jardin fleuri et du verger sont vides à leur ouverture ; leur terrain est déjà décoré et vivant. Une première plantation est guidée. Les zones personnalisées, pouvant mélanger les familles, sont une possibilité future.

Le terrain lui-même connaît cinq transformations permanentes, indépendantes des achats. Leurs seuils cumulés de test sont 1 000, 5 000, 15 000, 35 000 et 75 000 pas. Le palier atteint est commun aux trois îlots : un îlot ouvert plus tard affiche immédiatement les embellissements déjà acquis. Après le cinquième palier, la variété vient des plantes, emplacements et décors ; les pas continuent de servir à la croissance et aux récompenses. Les transformations déjà obtenues ne sont jamais retirées après une correction des pas.

## Croissance et récolte

Chaque plante démarre à zéro lors de sa plantation. Seuls les nouveaux pas la font progresser, et les mêmes pas font progresser simultanément toutes les plantes présentes. Le compteur de la plante sélectionnée indique les pas jusqu'à sa prochaine étape ; les plantes récoltables portent un signe discret permanent. À zéro pas, l'emplacement est à l'état semé. Dès le premier nouveau pas apparaît la graine germée, puis viennent le jeune plant à 30 %, le plant presque mature à 70 % et la plante mature et récoltable à 100 % du seuil total.

| Catégorie | Pas jusqu'à la première maturité, valeur de test | Florins par récolte, valeur de test |
| --- | ---: | ---: |
| Commune | 1 000 | 5 |
| Peu commune | 2 500 | 8 |
| Rare | 6 000 | 12 |
| Variante brillante | 15 000 | 12 |

La plante mûre attend un clic pour être récoltée. La récolte accorde ses récompenses et laisse la plante visible. Elle démarre alors un nouveau cycle de production demandant la moitié des pas de la première croissance ; ce cycle garde la plante à sa taille mature, d'abord sans production, puis avec une production naissante à 50 % du cycle, et enfin récoltable à 100 %. Les règles de récompense sont les mêmes à chaque cycle. Une plante prête à récolter ne stocke pas les pas destinés aux cycles suivants : une seule récolte peut être en attente. Le joueur peut supprimer une plante à tout moment, même avant sa maturité ; l'emplacement revient alors à son état vide. Une action groupée permet de récolter plusieurs plantes prêtes, après affichage du gain réel compte tenu du quota du jour.

Chaque récolte garantit une graine de la même espèce ordinaire ; les graines supplémentaires sont plus probables pour les espèces communes. Une plante brillante garantit une graine ordinaire de son espèce et donne, en plus, une graine brillante avec une chance de test de 5 %, identique pour chaque espèce. Les probabilités de graines supplémentaires sont affichées. Les graines excédentaires peuvent être conservées ou supprimées, sans conversion en florins.

Pour cette première implémentation, la chance de recevoir une deuxième graine ordinaire est de 50 % pour une plante commune, 30 % pour une peu commune et 10 % pour une rare. Les huit espèces de départ étant communes, leur variante brillante garde la chance de 50 % pour cette deuxième graine ordinaire. Le gain de chaque plante est tiré et sauvegardé dès qu'elle devient récoltable, pour que l'aperçu d'une récolte groupée annonce le nombre exact de graines avant confirmation.

Un engrais accélère le compteur à partir de son application, jusqu'à la fin du cycle en cours. Un seul engrais peut être actif sur une plante à la fois. Les multiplicateurs de test sont ×1,25 (basique), ×1,5 (super) et ×2 (méga). Il n'y a plus de ressource « eau ».

Un engrais basique est offert une fois au joueur lors de son premier chargement, y compris lors de la reprise d'une sauvegarde créée avant l'arrivée des engrais. Son attribution est mémorisée pour éviter tout doublon.

## Récompenses de la marche

Les paliers quotidiens de test sont 1 000, 3 000, 6 000 et 10 000 pas. Les quatre lots du jour sont tirés au début de la journée et affichés avant la marche. Leur valeur minimale est respectivement commune, peu commune, peu commune avec un lot plus généreux, puis rare. Un lot peut contenir des florins, graines, engrais ou certains décors ; « rare » qualifie la valeur du lot et ne signifie pas nécessairement une graine rare. Certains jours, le premier palier ne donne aucun florin. Les pas arrivés en retard créditent le lot du jour où ils ont été effectués si son palier était atteint.

Une seule graine brillante peut figurer parmi les lots d'une journée. Les chances cumulées de test de l'obtenir en atteignant au moins 1 000, 3 000, 6 000 ou 10 000 pas sont respectivement 2 %, 3 %, 4 % et 5 %. Le tirage détermine dès le début du jour le palier et l'espèce exacte ; les chances sont affichées. Aucun achat ne permet de retirer les lots. Les autres probabilités et quantités des lots restent à équilibrer.

Le joueur peut lancer une pause marche librement, depuis une invitation à heure choisie ou après une invitation liée à l'inactivité. La réussite demande, comme première valeur de test, 300 pas en 10 minutes et donne un engrais basique, au maximum trois fois par jour. Une pause reste possible après ce maximum ; ses pas servent encore aux plantes et aux paliers. Une marche détectée de 300 pas, pendant ou hors pause, remet le compteur d'inactivité à zéro ; lancer ou abandonner une pause ne le fait pas. Après 60 minutes d'inactivité, l'interface peut proposer au joueur de prendre l'initiative ; un rappel peut être envoyé après 90 minutes. Les invitations quotidiennes à heures choisies restent disponibles. Toutes les pauses réussies suivent la même règle de récompense.

## Florins, boutique et décors

Les récoltes accordent au plus 20 florins par jour, ou 40 avec abonnement, en valeurs de test. Ce quota concerne uniquement les récoltes, pas les lots des paliers. Si une récolte dépasse le quota restant, elle accorde seulement les florins encore disponibles, mais toujours ses graines. Le quota s'applique le jour du clic de récolte, même si la plante était prête depuis la veille. Le gain réel est montré avant une récolte groupée.

Le florin est la seule monnaie. Il s'obtient en marchant et peut aussi être acheté avec des euros. La boutique propose dès le départ les graines rares ordinaires, sans limite quotidienne d'achat, à prix élevé. Les prix de test sont 5 florins pour une graine commune, 20 pour une peu commune, 60 pour une rare, puis 10, 20 et 40 florins pour les engrais basique, super et méga. Un décor acheté est permanent, déplaçable, et chaque achat ajoute un exemplaire. Certains décors figurent aussi parmi les lots de marche.

L'abonnement n'apporte pour l'instant que le quota de récolte plus élevé. Les achats de florins peuvent accélérer l'aménagement, l'accès aux graines rares ordinaires et la croissance par l'engrais, sans faire pousser une plante sans nouveaux pas. Aucun objet, espèce ou décor n'est exclusif aux euros. Les variantes brillantes ne sont jamais vendues et aucun tirage supplémentaire ne peut être acheté. Les prix en euros et les probabilités non citées seront décidés après simulation de plusieurs profils de marche et de dépense.

## Règle de conservation

Une absence ne cause aucune perte. Les corrections tardives des pas créditent les récompenses manquées et ne retirent jamais les plantes, lots, florins, graines, engrais, décors ou paliers déjà obtenus. Voir [ADR-0001](adr/0001-recompenses-irrevocables.md).

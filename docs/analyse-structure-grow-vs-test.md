# Analyse structurelle : `grow.png` face à `test.png`

> Les sections chronologiques conservent les hypothèses explorées pendant l'entretien. Les règles finales sont dans `ART_BIBLE.md`, `docs/geometrie-ilots.md` et les ADR 0004–0005.

## Portée de la comparaison

- `grow.png` (490 × 660 px) montre le monde du potager, sans l'interface Flutter. `test.png` (1254 × 1254 px) est une composition complète avec interface et un jardin beaucoup plus avancé. Leur nombre brut d'objets ne mesure donc pas, à lui seul, un défaut de densité.
- L'analyse porte sur les relations spatiales : projection, contour du terrain, trame d'herbe, implantation des emplacements, chemins, couches et cadrage. Elle ne prescrit pas encore de changement de topologie des trois zones.
- Les tailles ci-dessous sont celles du code en points logiques, et non des mesures déduites des pixels des captures.

## Constats visuels

| Sujet | `test.png` | `grow.png` | Effet perceptible |
| --- | --- | --- | --- |
| Terrain | Îlot fini, avec retours obliques, coins visibles et terre en relief sur plusieurs bords. | Surface d'herbe coupée à gauche et à droite ; façade de terre horizontale sur toute la largeur. | Le jardin perd la silhouette de maquette et ressemble à une bande de décor que la caméra traverse. |
| Plan d'herbe | L'herbe relie les cultures, les chemins et les bordures ; la structure de pose ne dessine pas un quadrillage. | Le petit motif d'herbe se répète à intervalles réguliers sur un grand plan presque uniforme. | La répétition se voit davantage que la construction du terrain. |
| Chemins | Réseau de pas irréguliers qui suit les circulations entre les plantations ; l'herbe reste visible. | Axe vertical au milieu, deux branches horizontales et plusieurs pierres isolées, avec des intervalles mécaniques. | Les pierres se lisent comme des éléments posés sur le fond, moins comme une circulation du jardin. |
| Emplacements | Répartition dans le plan du jardin, avec des allées qui passent entre les cultures. | Quatre platebandes visibles, disposées en deux colonnes étagées ; leur implantation et celle des chemins ne partagent pas un plan de pose explicite. | L'espace se lit comme deux colonnes de cartes séparées par une colonne de pierres. |
| Bords et décor | Variations de hauteur, feuillage et objets aux coins ; les bordures expliquent la profondeur du sol. | Frise répétée de feuillage puis bande de terre rectiligne ; les limites latérales sont hors image. | La profondeur est portée par les sprites seuls, peu par le terrain. |
| Titre de la zone | Le titre principal appartient à l'interface ; le petit panneau en bois au bord droit est un décor secondaire. | Le panneau « Mon potager » est centré dans le monde, devant la clôture, et occupe une place comparable à une plantation. | Un objet non interactif prend le rôle de point focal et ferme l'espace arrière. |

La projection locale des platebandes et des dalles est globalement compatible avec un losange 2:1. Le problème principal n'est donc pas un simple « mauvais angle isométrique » : c'est l'absence d'une géométrie de scène commune, visible dans les rapports entre terrain, chemins et cultures.

## Causes vérifiées dans le code

1. **Un seul terrain en bande.** `GardenGame._drawTerrain` construit un polygone allant de `x = 0` à `x = 1070` (`340 × 2 + 390`), avec un plateau de `y = 20` à `y = 410` et une face avant jusqu'à `y = 436`. Ses extrémités obliques existent seulement aux deux bouts de la bande totale. La vue centrale ne peut donc montrer aucun coin d'îlot sur les côtés.
2. **Une texture de cases, pas un terrain assemblé en cases.** Le sprite d'herbe 80 × 42 est répété tous les 80 points en `x` et 20 points en `y`, avec décalage de 40 points une ligne sur deux, à 25 % d'opacité. Il est découpé par le grand polygone. Aucune cellule de terrain distincte ne détermine les bords, l'occupation ou la topologie. Cela ne réalise qu'en apparence la règle de l'`ART_BIBLE.md` sur les cases carrées d'herbe 80 × 40 avec terre aux seuls bords extérieurs.
3. **Plusieurs systèmes de coordonnées sans contrat visuel commun.** Les huit centres possibles du potager sont deux colonnes en `x = 110` et `x = 230`, décalées de 20 points en `y` ; cette implantation est régulière en elle-même. Les 19 pas de pierre par zone utilisent une autre logique : axe central alternant `x = 165/175`, pas de 32 points en `y`, et branches aux `y = 216/312`. Les sections de bordure utilisent encore un pas de 235 points. Le fait qu'un emplacement puisse être entre deux cellules d'herbe est expressément autorisé par la bible ; le défaut à résoudre est leur **relation visuelle** avec le motif, les chemins et les limites, pas nécessairement leur coïncidence mathématique.
4. **Échelle de scène variable.** `_sceneScale()` vaut `min(hauteur_du_monde / 450, 1.32)`. L'UI fixe la hauteur du monde à `(hauteur_écran − 274).clamp(430, 570)`. Sur 390 × 844, l'échelle vaut environ 1,267 et seuls 308 des 390 points logiques de largeur de zone sont visibles : environ 41 points sont coupés de chaque côté. Les vues voisines ne fournissent alors qu'environ 9 points visibles chacune, malgré la bande de liaison de 50 points définie dans la bible. Sur 375 × 667, l'échelle vaut environ 0,956. Le rapport entre les deux tailles apparentes est d'environ 1,33, alors que la bible demande une échelle stable et la réduction des seules marges sur petit écran.
5. **Emprise des platebandes non conforme.** `_drawBed` affiche le sprite en 100 × 72 points. La bible limite la largeur visible d'une platebande à 80 points et son dessus à 80 × 40. Ce surplus réduit les couloirs d'herbe et durcit l'effet de colonnes.
6. **Ordre de profondeur non spatial.** Le terrain et ses décors sont dessinés d'abord, puis chaque emplacement dans l'ordre de la liste, avec base et plante consécutives. Aucun tri par coordonnée de contact au sol ne contrôle l'occlusion, contrairement à la règle de la bible. Des objets proches peuvent passer derrière ou devant selon leur index plutôt que leur position.
7. **Densité d'ornements générés par règle répétée.** Chaque zone ajoute neuf buissons intérieurs, onze buissons de premier plan, six touffes et cinq groupes de fleurs, plus des arbres de bord. La bible limite une zone saturée à trois petits groupes de végétation environnementale. Même si beaucoup de ces objets sont rognés ou cachés, cette répétition alourdit la façade et accentue l'effet de bande.
8. **Titre redoublé dans le monde.** `_drawZone` appelle `_zoneSign` à chaque vue. Le grand panneau de 112 × 70 points devient l'élément le plus lisible du bord arrière, alors que le nom de la zone relève déjà de l'interface Flutter. La capture de référence utilise un panneau de jardin plus petit comme décoration latérale, distinct du titre UI.
9. **Achat d'emplacement et position encore couplés dans les données.** La bible prévoit que le joueur choisit quel emplacement fixe acheter. Le modèle courant stocke chaque zone comme une liste des seuls emplacements acquis et le rendu dessine les premiers ancrages selon la longueur de cette liste. Il ne peut pas représenter un emplacement non acheté entre deux emplacements achetés. La migration vers des identifiants de position stables est nécessaire avant de proposer un achat à emplacement choisi.

## Ce que la comparaison ne démontre pas

- `test.png` montre environ un jardin mûr, tandis que `grow.png` ne montre que quatre emplacements achetés et une culture développée. Il faut comparer des états de jeu équivalents avant de conclure que le nombre de cultures est insuffisant.
- La capture de référence est une composition fixe, alors que Growstep prévoit trois zones voisines et une caméra qui glisse. La forme exacte des trois zones ne peut pas être copiée directement sans décider comment leurs bords communs s'assemblent.
- La capture seule ne prouve pas que tous les centres d'emplacements doivent être les centres des cases d'herbe. La bible autorise explicitement des centres entre cellules.

## Ordre logique de résolution proposé

1. Décider la topologie visible du terrain et le traitement des bordures communes pendant la navigation.
2. Fixer un contrat géométrique partagé pour la trame d'herbe, les axes de circulation, les emplacements et les bordures, avec tolérances explicites.
3. Dessiner une scène étalon à états initial et saturé, puis vérifier les deux tailles d'écran prévues dans la bible.
4. Corriger échelle, emprise et tri de profondeur avant de juger les sprites un par un.

## Décisions du premier tour

Les décisions relatives à la continuité entre zones ci-dessous ont été remplacées par la décision finale d'îlots distincts, consignée en fin de document.

- Les trois zones restent sur un terrain continu, mais chaque cadrage doit rendre visibles des retours obliques et une tranche de terre, avec un raccord commun aux vues voisines.
- La grille d'herbe 80 × 40 devient la base géométrique commune du terrain, des emprises et des chemins. Les décalages des emplacements entre cellules sont permis s'ils sont spécifiés.
- Les pierres matérialisent un itinéraire continu entre les plantations et entre zones, avec de l'herbe visible entre les pas.
- La cible visuelle annoncée pour le premier lancement est deux ou trois cultures du potager à des stades différents, avec au moins une platebande vide. Ce point contredit actuellement `docs/game-design.md`, qui prévoit une graine offerte dans chaque zone et une première plantation guidée, ainsi que `GardenSnapshot.initial()`, qui crée tous les emplacements vides. Il reste à décider si la cible désigne l'état réel du nouveau joueur ou une scène étalon après quelques actions.

Restent à chiffrer le contour des raccords, les décalages admissibles, la largeur des passages et les critères de validation des chemins.

## Décisions du deuxième tour

La décision de raccords latéraux ci-dessous a été remplacée par la décision finale d'îlots distincts.

- Une partie neuve contient deux cultures offertes, déjà visibles à des stades différents dans le potager ; une troisième plantation est guidée dans une platebande vide. Cette exception à la progression par les pas est inscrite dans le game design. Leurs espèces et stades exacts restent à fixer.
- Les raccords latéraux sont en herbe, empruntés par le chemin, sans pont ni coupure ; les bords obliques restent visibles de part et d'autre.
- Les coordonnées d'emplacements existantes peuvent être remplacées par un nouveau plan commun, en conservant le nombre, l'ordre des index, la visibilité et les cibles tactiles des emplacements.
- La végétation continue des bords relève d'un budget distinct des trois groupes décoratifs indépendants autorisés par zone. Elle reste contrôlée et sans répétition mécanique.

## Troisième tour : décisions et bifurcation

- La composition 3–2–3 des huit emplacements est acceptée **si le modèle à trois zones est conservé**. La proposition ultérieure d'un seul jardin mixte plus grand remet son application en question.
- Le potager initial montre une jeune carotte et une tomate presque mature ; une platebande attend la plantation guidée et une reste vide.
- Les volumes végétaux hauts se placent à l'arrière et sur les côtés ; le bord avant reste plus bas.
- Le raccord latéral des trois zones reste à décider. La question d'une zone visuelle unique doit être tranchée avant de chiffrer le raccord.

## Quatrième tour : chemin et architecture du jardin

- Le chemin comporte quelques pas de pierre crème dès le lancement. Le deuxième palier complète et soigne leur pose sur le même itinéraire, en laissant l'herbe visible.
- L'architecture spatiale reste ouverte : un seul grand îlot mixte, ou plusieurs îlots complets révélés progressivement et accessibles par leur nom. Ce choix détermine si le raccord latéral et la composition 3–2–3 restent pertinents. Aucune de ces deux architectures n'est encore validée.

### Comparaison des deux architectures encore ouvertes

| Critère | Grand îlot mixte unique | Îlots séparés, révélés progressivement |
| --- | --- | --- |
| Ressemblance structurelle avec `test.png` | Un îlot fini et un mélange de cultures peuvent en reprendre la logique. | Chaque vue peut être un îlot fini complet ; le potager initial peut avoir la densité lisible de la référence. |
| Échelle sur téléphone | Les 19 emplacements actuels (8 légumes, 8 fleurs, 3 arbres) dans un seul cadrage de 390 × 450 points demanderaient de réduire leur taille ou d'accepter une forte occlusion ; une caméra mobile ou une baisse du nombre visible devient probable. | Chaque vue porte au plus 8 emplacements de culture ou 3 arbres ; leur taille peut rester conforme à la bible. |
| Règles de jeu et sauvegardes | Les espèces sont aujourd'hui liées à un `ZoneType`, et les emplacements sauvegardés dans trois listes. Il faut définir les nouveaux emplacements mixtes et la correspondance des sauvegardes. | Les trois listes, leurs espèces et les index d'emplacements peuvent être conservés. Il faut ajouter un état de déverrouillage et revoir les graines offertes dans les zones encore fermées. |
| Travail visuel | Un grand plan de terrain, mais une composition plus difficile à rendre lisible à maturité. | Trois contours et compositions à produire, mais chacun se valide indépendamment ; pas de raccord physique entre vues. |
| Progression ressentie | Tout le jardin existe d'emblée ; l'expansion passe par des emplacements ou une caméra. | L'ouverture du jardin fleuri et du verger devient un changement visuel majeur, explicite dans l'interface. |

Le code existant attend une première plantation dans un jardin entièrement vide (`GardenSnapshot.needsFirstPlanting`) et ouvre actuellement les trois zones. Les deux cultures offertes déjà décidées imposeront donc de modifier ce critère d'accueil, quelle que soit l'architecture retenue. Si les îlots sont déverrouillés progressivement, l'offre actuelle d'une graine de départ par zone devra aussi attendre l'ouverture de la zone correspondante.

## Architecture retenue

Le jardin comporte trois îlots finis et séparés, chacun correspondant à une zone. Seul le potager est ouvert au lancement ; le jardin fleuri et le verger deviennent des récompenses de progression accessibles par leur nom. Il n'y a plus de raccord de terrain ni de défilement de caméra entre zones. La composition 3–2–3 des huit emplacements reste valable pour chacun des deux îlots de culture. Cette décision remplace toutes les hypothèses de bande continue ou de raccord latéral analysées plus haut ; voir [ADR-0004](adr/0004-ilots-distincts-a-debloquer.md).

## Décisions sur la première visite et l'interface

- Les noms des îlots fermés et leurs objectifs sont visibles dans l'interface ; leurs scènes ne le sont pas.
- Le jardin fleuri et le verger s'ouvrent avec leurs emplacements de plantation vides, mais une bordure et des décors déjà vivants.
- Les cinq paliers d'embellissement sont communs aux trois îlots et s'appliquent immédiatement à celui qui vient d'être ouvert.
- Le mécanisme de déblocage reste ouvert : pas cumulés, récompenses de connexion ou monnaie. Dans le vocabulaire actuel de `CONTEXT.md`, la seule monnaie est le florin ; « jeton » n'a pas encore de sens défini.

### Achat anticipé avec des florins : hypothèse à valider

Un îlot est un contenu permanent et visible, avec nouveaux emplacements et espèces ; il peut donc porter une offre d'achat plus compréhensible qu'un petit consommable. Cela ne démontre aucune volonté réelle de payer. Le florin est aussi achetable en euros, si bien qu'un prix en florins rendrait l'ouverture accélérable par paiement. Pour un marcheur à 10 000 pas par jour, des seuils de 15 000 et 35 000 pas cumulés correspondraient environ aux jours 2 et 4 ; la valeur perçue de quelques euros pour avancer de deux jours reste inconnue. À 2 000 pas par jour, les mêmes seuils se situeraient vers les jours 8 et 18, ce qui augmente l'intérêt d'un raccourci mais aussi le risque de ressentir un blocage.

Avant de fixer un prix ou une équivalence en euros, il faut simuler l'acquisition et les dépenses de florins pour plusieurs profils de marche, puis tester si les joueurs comprennent les bénéfices d'un nouvel îlot et souhaitent réellement payer pour l'ouvrir plus tôt. Aucun taux de conversion, prix ou mécanique d'achat n'est validé par la présente analyse.

**Décision ultérieure :** l'hypothèse d'achat anticipé a été remplacée par un déblocage uniquement en florins, sans ouverture automatique par les pas. Voir [ADR-0005](adr/0005-debloquer-les-ilots-en-florins.md). Le paragraphe précédent reste un raisonnement exploratoire, pas la règle finale.

**Précision validée :** l'ordre d'achat est libre, avec des prix de test de 100 florins pour le jardin fleuri et 250 pour le verger. Ces nombres ne sont pas des prix définitifs ; la simulation des profils de marche, de récolte et de dépense reste requise.

## Règles structurelles confirmées après le choix des îlots

- Chaque îlot possède un contour fini propre, dérivé du même gabarit de cases d'herbe 80 × 40 ; les épaisseurs de terre restent comparables.
- Les centres des platebandes, arbres et pas de chemin utilisent les centres des cases ou des décalages de demi-case définis par le gabarit. Les coordonnées libres de la scène actuelle ne sont plus une référence.
- Le sélecteur des trois noms reste compact et hors du monde Flame. Un îlot fermé ouvre un panneau Flutter avec prix en florins et confirmation d'achat ; aucune grande carte d'achat ne recouvre durablement le terrain.

## Hypothèse ouverte : agrandir un îlot

« Agrandir » recouvre trois changements différents :

| Variante | Emplacements finaux | Caméra | Tension avec les règles actuelles |
| --- | --- | --- | --- |
| Révéler progressivement le terrain jusqu'à la capacité déjà prévue | 8 au potager et au jardin fleuri, 3 au verger | Fixe si le contour final tient dans 390 × 450 et 375 × 667 points | Les emplacements possibles ne seraient plus tous suggérés dans le terrain initial ; la scène de départ doit rester assez grande pour éviter l'ancien défaut de jardin trop petit. |
| Ajouter du terrain et des emplacements au-delà des capacités prévues | Plus de 8 ou plus de 3 | Déplacement ou réduction d'échelle vraisemblablement nécessaire | Contredit la vue intégrale de l'îlot, l'échelle fixe et les budgets de densité ; demande de revoir grille, chemins, sélection tactile et sauvegardes. |
| Embellir le terrain existant sans nouveau sol jouable | Inchangés | Fixe | Déjà couvert en partie par les cinq paliers d'embellissement ; récompense moins forte qu'un vrai gain d'espace. |

L'agrandissement n'implique donc une caméra déplaçable que s'il dépasse la surface maximale qui tient à l'échelle retenue sur téléphone. Ajouter en plus un prix en florins distinct des emplacements et des nouveaux îlots augmenterait la concurrence entre dépenses ; ce point demanderait une décision spécifique.

**Décision :** aucun agrandissement physique d'îlot ni caméra déplaçable dans cette version. Les capacités restent de huit emplacements au potager et au jardin fleuri et de trois au verger. La question d'un terrain agrandi est reportée à une version future.

## Gabarit chiffré validé

Le [gabarit géométrique](geometrie-ilots.md) sert de référence de validation : enveloppe d'environ 360 × 365 points dans le canevas 390 × 450, tranche de terre de 20 à 28 points et visibilité intégrale sur le petit écran sans changement d'échelle. Les centres 3–2–3 proposés y ménagent 40 points d'herbe entre platebandes d'une rangée et 80 points dans l'ouverture centrale. Les ancrages exacts seront figés après revue de la scène réelle. Le chemin entre par l'avant et se ramifie sans pierre sous les platebandes. Le panneau d'achat d'un îlot fermé affiche prix, espèces et nombre d'emplacements initiaux, mais pas la scène avant l'achat.

## Composition finale du gabarit initial

- Le grand panneau central « Mon potager » disparaît ; le titre reste dans l'interface. Un petit panneau latéral peut rester comme décor.
- Les chemins emploient trois ou quatre silhouettes de pierre compatibles, distribuées de façon stable sans répétition adjacente systématique.
- Au moins 40 % de la tranche de terre avant reste visible malgré la végétation basse du bord.
- Les quatre premiers index du potager sont répartis entre l'arrière gauche, le milieu droit, l'avant gauche et l'avant droit ; tomate et carotte occupent les deux premiers, le troisième reçoit la plantation guidée, le quatrième reste vide.

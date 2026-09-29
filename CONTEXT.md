# Jardin de marche

Une application iPhone où la marche fait grandir et embellir un jardin virtuel. Les règles et valeurs de test figurent dans [le game design](docs/game-design.md) ; l'économie de référence détaillée dans [l'économie](docs/economie.md).

## Language

**Jardin** : espace virtuel du joueur comprenant un potager, un jardin fleuri et un verger.

**Zone** : partie du jardin dédiée à une famille de plantes : légumes, fleurs ou arbres fruitiers.

**Îlot** : terrain visible d'une seule zone. Le potager, le jardin fleuri et le verger occupent chacun un îlot distinct ; leurs terrains ne se touchent pas.

**Déblocage d'îlot** : acquisition permanente, en florins, du droit de visiter et cultiver un îlot autre que le potager.

**Emplacement de plantation** : place d'une zone pouvant accueillir une plante.
_Avoid_ : Parcelle

**Platebande** : support de terre surélevé utilisé dans le jardin fleuri. Dans le Potager, un emplacement acheté est matérialisé par une empreinte de terre plate liée à son contact de grille ; le Verger n'a pas de platebande.

**Espèce découverte** : espèce dont le joueur a obtenu une première graine ; elle reste découverte pour toujours et n'est jamais reperdue. La découverte est la base de la collection.

**Graine** : consommable d'une espèce donnée, nécessaire pour démarrer une plante dans un emplacement. Une graine plantée est consommée puis rendue à la récolte (ou à la suppression prématurée) : une espèce découverte ne se perd jamais. Les copies supplémentaires d'une espèce s'achètent en florins.
_Avoid_ : graine bonus, graine illimitée

**État semé** : état d'un emplacement contenant une graine plantée avant l'apparition de la première pousse visible.

**Plante** : végétal issu d'une graine, qui grandit avec les pas du joueur.

**Étape de croissance** : forme visible d'une plante entre sa germination et sa maturité.

**Plante mature** : plante arrivée à sa forme finale, récoltable. Pour une culture, la récolte retire la plante et libère l'emplacement ; pour un arbre, elle garde l'arbre.

**Cycle de production** (arbres uniquement) : période pendant laquelle un arbre mature accumule de nouveaux pas jusqu'à pouvoir être récolté de nouveau, sans retirer l'arbre.

**Récolte** : action du joueur qui reçoit les récompenses d'une plante prête : produits (vendus au marché) et une graine de la même espèce garantie. Une culture récoltée disparaît ; un arbre reste.

**Produit** : sortie d'une récolte, vendue automatiquement au marché. Pas d'inventaire de produits.

**Marché** : unique générateur de florins du jeu. Il achète automatiquement les produits des récoltes selon sa courbe de prix du jour, par espèce.

**Courbe de prix du marché** : règle d'achat par espèce : les premières récoltes du jour (quota) se vendent à plein tarif, les suivantes à tarif réduit (30 %). Rendement marginal réduit/contrôlé, jamais un plafond dur.

**Variante brillante** : apparence très rare d'une espèce, plus longue à faire pousser que sa forme ordinaire (15 000 pas). Il n'en existe qu'une par espèce ; une brillante récoltée rend une graine brillante de la même espèce garantie. Les brillantes ne sont jamais vendues.

**Florin** : monnaie unique du jardin, gagnée **exclusivement** par la vente des récoltes au marché. Jamais achetée en euros, jamais créditée par les pas directs ni par les lots.

**Palier quotidien** : seuil de pas d'une journée qui accorde un lot annoncé à l'avance, jamais de florins.

**Palier de pas cumulés** : seuil de pas cumulés qui accorde une récompense cosmétique ou de collection, jamais de florins.

**Engrais** : ressource appliquée à une plante pour accélérer son cycle de croissance en cours. Son achat en florins n'a jamais un rendement en florins supérieur à son prix.

**Décor** : objet permanent que le joueur peut placer et déplacer dans son jardin.

**Expansion de surface** : achat en florins qui agrandit la surface construisible d'un îlot, purement esthétique : il ne modifie jamais la capacité productive.

**Invitation à marcher** : rappel qui propose au joueur de lancer une pause marche.

**Pause marche** : marche volontaire dont la réussite dépend d'un objectif de pas à atteindre dans un délai donné.

**Contact au sol** : point où un objet touche le sol dans le canevas de l'artboard. Sert d'ancre de placement pour le rendu, de cible tactile et de clé de tri en profondeur.
_Avoid_ : position, centre de l'image

**Élément d'ambiance fixe** : objet visuel purement décoratif placé dans la composition, sans état de jeu ni interaction. Se distingue du décor joueur, qui est achetable, déplaçable et possédé.
_Avoid_ : accessoire, décoration

**Rendu hybride** : terrain du Potager historiquement en Canvas, désormais rendu par une carte Tiled 2D orthogonale (tuiles + sprites du kit retenu) ; le jardin fleuri et le verger conservent le rendu hybride Canvas + sprites PNG modulaires selon leur famille. Voir [docs/art-direction.md](docs/art-direction.md).
_Avoid_ : rendu 100 % Canvas, rendu 100 % sprites

**Anchored sprite** : sprite PNG vertical transparent, ancré au sol par un point de contact du manifeste et trié en profondeur. Suit le pipeline 4× complet (ORA, YAML, manifeste, exports 2×/3×).
_Avoid_ : sprite (préférer « anchored sprite » quand la distinction importe)

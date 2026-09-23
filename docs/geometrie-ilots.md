# Gabarit géométrique des îlots

> Statut : gabarit approuvé. Les coordonnées des emplacements sont des positions de validation ; elles seront arrêtées définitivement après revue de la scène complète à taille réelle.

## Référentiel commun

- Canevas logique de référence : 390 × 450 points. Centre du terrain de référence : `(195, 230)`.
- Les cases carrées d'herbe ont un dessus losange de 80 × 40 points. Ses axes projetés sont `u = (40, 20)` et `v = (-40, 20)`. Un centre de case est `O + i·u + j·v`, où `i` et `j` sont des entiers.
- Un ancrage d'objet ou de pas de chemin peut aussi employer `i` et `j` demi-entiers. Aucun pas libre en pixels ne sert à composer une rangée, un chemin ou une bordure.
- Les losanges voisins composent une seule surface d'herbe ; la case logique ne doit ni être cernée de terre ni devenir un motif répété visible. Les bords de terre appartiennent seulement au contour extérieur.

## Cadrage proposé

- À 390 × 450 points, l'îlot complet, tranche de terre comprise, est contenu dans `x = 15…375` et `y = 40…405`. L'épaisseur apparente de terre sur les bords visibles vise 24 points, tolérance de 20 à 28.
- À 375 × 667 points, la même échelle est gardée. En prenant le pire cadrage autorisé de 375 × 380 points sur le canevas de référence, la fenêtre visible est `x = 7,5…382,5`, `y = 35…415` : le contour proposé garde au moins 5 points de marge verticale. Les objets interactifs doivent également rester visibles dans cette fenêtre.
- Chaque îlot emploie une silhouette finie différente, composée sur le même treillis. Les variations locales de bord ne créent jamais de joint entre deux cases intérieures ni de longue façade de terre horizontale identique à `grow.png`.

## Implantation de travail des deux îlots de culture

Cette implantation est le gabarit de validation approuvé, à éprouver dans la scène avant de figer les ancrages définitifs.

| Rangée | Centres des emplacements, points logiques |
| --- | --- |
| Arrière, 3 | `(75, 150)`, `(195, 150)`, `(315, 150)` |
| Milieu, 2 | `(115, 230)`, `(275, 230)` |
| Avant, 3 | `(75, 310)`, `(195, 310)`, `(315, 310)` |

Ces huit centres respectent les décalages en demi-cases du treillis autour de `O = (195, 230)`. Avec des platebandes larges d'au plus 80 points, les trois emplacements d'une même rangée laissent environ 40 points d'herbe entre eux. Le milieu garde une ouverture de 80 points entre les deux platebandes. L'ordre des index de sauvegarde et les quatre emplacements disponibles au départ doivent être distribués parmi ces positions sans créer un bloc compact. Le jardin fleuri peut décaler certains centres d'une demi-case définie, tout en gardant la répartition 3–2–3 et les mêmes distances minimales.

Les quatre premiers index du potager utilisent les positions suivantes dans le gabarit :

| Index sauvegardé | Position | État dans une partie neuve |
| ---: | --- | --- |
| 0 | Arrière gauche `(75, 150)` | Tomate presque mature |
| 1 | Milieu droit `(275, 230)` | Jeune carotte |
| 2 | Avant gauche `(75, 310)` | Vide, destiné à la plantation guidée |
| 3 | Avant droit `(315, 310)` | Vide |

Les index supplémentaires utilisent les quatre centres restants pour la validation : `4 = arrière centre (195, 150)`, `5 = milieu gauche (115, 230)`, `6 = avant centre (195, 310)`, `7 = arrière droit (315, 150)`. L'index identifie une position et ne dicte pas l'ordre dans lequel le joueur peut acheter les emplacements. Le jardin fleuri part du même plan de validation ; tout décalage ultérieur d'une demi-case sera consigné dans son manifeste de scène avant production des assets.

Le verger utilise comme gabarit de validation un triangle de trois contacts au sol : `0 = arrière centre (195, 190)`, `1 = avant gauche (115, 325)`, `2 = avant droit (275, 325)`. Avec une couronne large d'au plus 160 points et haute d'au plus 150 points, ce plan garde les trois arbres dans le cadrage réduit. Les positions définitives seront revues avec les couronnes réelles et le chemin.

## Réseau de chemin

- Un îlot possède un graphe de circulation unique et connecté. Le chemin entre depuis le bord avant, se ramifie pour approcher les emplacements et ne traverse aucune emprise de platebande ou d'arbre.
- Les centres des pierres suivent les nœuds de demi-case du treillis. Des intervalles d'herbe de quelques points séparent les sprites de pierre ; la continuité est celle du trajet lisible, pas d'un pavage minéral jointif.
- Trois ou quatre variantes de pierre gardent le même ancrage, la même gamme de taille et la même lumière. Le choix de variante est déterministe selon le nœud du chemin et ne répète pas la même silhouette sur deux pas adjacents lorsque le parcours le permet.
- Une pierre ne masque pas une cible tactile de 44 × 44 points ni le contact au sol d'une plante. Les trois îlots n'ont pas besoin du même nombre de pierres, mais partagent leur échelle et leur matériau.

## Vérifications objectives avant validation graphique

1. Un seul composant connexe de cellules d'herbe par îlot ; aucun trou intérieur ni terre apparente entre cellules.
2. Tous les ancrages de plantation appartiennent au terrain ; les emprises et cibles tactiles ne se chevauchent pas.
3. Tous les ancrages et nœuds de chemin sont exprimables sur le treillis entier ou demi-entier, avec origine et axes consignés dans les métadonnées de la scène.
4. Le réseau de chemin est connexe et ne coupe aucune emprise interactive.
5. À 390 × 844 et 375 × 667, l'îlot, sa tranche de terre et les objets interactifs restent visibles à la même échelle ; aucune bordure n'est coupée par la fenêtre.
6. Le rendu trie les objets mobiles et végétaux selon leur point de contact au sol, puis superpose les signes d'interface.
7. Au moins 40 % de la longueur projetée de la tranche de terre du bord avant reste visible ; aucun grand panneau de titre ne recouvre le centre de l'îlot.

Ces contrôles peuvent être automatisés à partir d'un manifeste de scène. L'absence de joints d'herbe perceptibles, la qualité du contour et la lisibilité du trajet demandent aussi une revue humaine sur la scène complète.

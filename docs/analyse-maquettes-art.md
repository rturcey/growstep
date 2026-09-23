# Growstep — analyse graphique des trois maquettes

> Analyse historique des maquettes `art-mockups/`. Pour le terrain herbeux, les trois îlots séparés et la scène initiale actuelle, suivre `ART_BIBLE.md` et `docs/geometrie-ilots.md` ; leurs décisions priment sur les interprétations de ce document.

Analyse des images de `art-mockups/` (853 × 1844 px chacune, soit le rapport de l'écran 390 × 844). Ces maquettes sont des références de composition et de rendu, pas des assets à afficher dans le jeu. Les cultures de l'application continuent à provenir de la sauvegarde réelle.

## Langage commun aux trois images

| Aspect | Ce que montrent les maquettes | Règle de production à en tirer |
| --- | --- | --- |
| Composition | Une cour claire occupe le centre et la majeure partie du monde. L'herbe forme un pourtour ; feuillages et clôtures encadrent la cour. | Dessiner de grandes masses avant les objets : fond, cour, bord végétal, éléments interactifs, avant-plan. La scène doit rester lisible sans cultures. |
| Projection | Sol et bacs ont des axes diagonaux cohérents et des verticales courtes. La caméra ne crée presque aucune convergence. | Garder la grille 2:1 et un même angle pour dalles, bacs, panneaux et ombres. Éviter les éléments vus strictement de face au milieu du jardin. |
| Échelle | Les bacs sont de grandes formes distinctes, environ un quart à un tiers de la largeur utile de la cour. Chaque lit de culture est reconnaissable au premier regard. | Donner d'abord de l'espace aux parcelles et aux arbres. Les décorations restent secondaires. |
| Cour pavée | Plusieurs dalles crème chaudes restent visibles entre les bacs. Leur teinte varie faiblement ; les joints sont fins. La cour est une surface continue, pas une suite de pierres isolées. | Environ six à huit joints/rythmes de dalle sont perceptibles sur la largeur utile. Variation de valeur faible et non répétitive ; pas de quadrillage à contraste fort. |
| Bacs | Dessus de terre brun sombre, rebord de bois clair, faces avant plus sombres, petits montants aux coins. On distingue le dessus, la face et leur ombre de contact. | Un bac doit conserver trois plans lisibles et une ombre courte. Ajouter des marques de terre discrètes, sans texture qui concurrence la culture. |
| Végétaux | Les silhouettes sont généreuses mais structurées en petits groupes. Les zones de feuilles claires et foncées créent le volume ; les détails ne sont pas distribués uniformément. | Un emplacement mature est une composition de plusieurs tiges/volumes appartenant à une seule plante de gameplay. Dessiner ses sous-volumes selon l'espèce et le stade, avec une lumière haut-gauche. |
| Bord du jardin | La densité monte sur les côtés et en bas : haies, touffes, pierres ou clôtures encadrent la cour. Le centre garde des interstices lisibles. | Concentrer le détail sur les bordures. Éviter à la fois le champ vert nu et le tapis de micro-objets partout. |
| Matières et lumière | Pierre mate crème, terre granuleuse chaude, bois légèrement marqué, feuilles en plusieurs valeurs de vert. Ombres douces vers le bas-droite. | Utiliser des valeurs, des plans et une texture mate subtile. Ni disque de couleur uniforme, ni gros contour, ni ombre ovale sombre sous chaque objet. |
| Profondeur | Clôture et végétation haute derrière la cour ; cultures et arbres au milieu ; haie et clôture basse devant. | Composer en couches suivant le point d'ancrage au sol. Un élément du fond ne doit pas passer artificiellement devant un bac. |

Les dimensions visuelles ci-dessus sont des estimations à l'échelle 390 × 844, pas des coordonnées d'export. La bible fixe les ancrages et la grille du jeu.

## Comment les assets sont dessinés

Le rendu des maquettes n'est pas défini par la seule liste d'objets. Un bac, un arbre ou une dalle y possède une construction visuelle répétable. C'est cette construction qu'il faut transposer aux éléments mobiles du jeu.

### Silhouettes et contours

- Les formes principales ont des contours légèrement irréguliers et des proportions compactes. Les plantes présentent des masses de feuilles avec quelques creux qui laissent voir la tige ou le fond. Les couronnes ne sont pas trois cercles accolés ; les buissons ne sont pas une chaîne de disques identiques.
- Les limites sont faites par des facettes de valeur et des occlusions courtes. Une arête de bois ou de pierre peut avoir un trait coloré très fin ; l'objet entier n'a pas de contour dessiné continu.
- L'asymétrie est contrôlée : les deux côtés d'un arbre restent équilibrés en masse, mais les groupes de feuilles, les fruits et les vides ne se répètent pas en miroir.

### Couleur et volume

- Chaque matière utilise une famille de couleurs cohérente : lumière chaude sur le dessus et en haut-gauche, valeur moyenne sur la masse principale, valeur plus sombre sous les feuilles et sur la face droite/avant. L'écart est plus fort entre deux plans qu'entre deux marques de texture du même plan.
- Les ombres de contact sont courtes et suivent les pieds, les troncs et les bacs. Une grande ellipse uniforme sous chaque asset donne l'impression que les objets flottent.
- Les accents (fruit rouge, pétale rose, jaune de tournesol, violet de lavande) sont de petites zones focales posées sur des masses végétales vertes. Ils ne sont pas des points répartis régulièrement dans toute la scène.

### Matières

| Matière | Construction observée | Erreur à éviter |
| --- | --- | --- |
| Bois | Rebord supérieur miel clair, face avant ocre, côté brun plus sombre, petits montants aux coins ; très peu de veinage, placé le long des planches. | Un seul polygone brun bordé d'une ligne ou des rayures régulières sur toutes les faces. |
| Terre cultivée | Surface sombre, légèrement bosselée, avec quelques clods/semis de tailles différentes ; la base de la plante entre dans la terre. | Losange brun plat, six tirets identiques ou plante semblant posée dessus. |
| Pierre pavée | Grandes dalles crème aux coins un peu adoucis, variations subtiles de chaud/froid, joints fins, quelques usures localisées. | Damier blanc très contrasté ou copie exacte de la même dalle sur toute la cour. |
| Feuillage | Couche inférieure olive sombre, groupes médians vert mousse, quelques feuilles de lumière sauge/jaune vert en haut-gauche ; petits vides internes. | Bulles circulaires vertes avec des points jaunes uniformes. |
| Tronc | Base légèrement évasée, branches visibles sous la couronne, face lumineuse étroite et face ombrée ; hauteur cohérente avec l'espèce. | Bâton de largeur constante terminé par une boule. |
| Herbe | Masse du terrain assez calme, touffes isolées de plusieurs brins à la bordure ou entre les dalles. | Motif de touffes régulièrement espacées partout. |

### Détails au format téléphone

Les maquettes gardent leur charme à environ 390 points de large parce que le détail sert les volumes : quelques feuilles assez grandes, quelques fruits bien séparés, quelques traces de matière visibles. La prochaine passe doit être contrôlée à 100 % de la taille cible. Tout détail qui se réduit à un pixel ou qui ne change pas la reconnaissance de l'asset peut disparaître. À l'inverse, les feuilles structurantes, les facettes du bois et les joints de pierre doivent survivre à cette réduction.

### Assemblage

Une culture mature de la maquette ressemble à plusieurs pousses, mais reste **un seul emplacement de gameplay**. Ses sous-parties doivent être rendues ensemble autour d'un ancrage unique : groupe de trois tomates, rang de fanes de carottes, masse de courgette, groupe de tulipes, etc. Leur ombre et leur contact avec la terre doivent être cohérents. Les motifs peuvent varier par emplacement avec une graine déterministe, sans changer la silhouette de l'espèce ni l'emprise tactile.

Un élément de décor suit les mêmes règles de projection et de lumière que les cultures. Les clôtures et les panneaux ne peuvent pas être de simples pictogrammes plats si les bacs ont des faces épaisses et ombrées.

## Particularités par zone

### Potager

- La maquette présente **huit bacs** en deux colonnes sur quatre niveaux, reliés par la cour pavée. Les bacs occupent le centre ; ils ne sont pas de petits losanges dispersés dans l'herbe.
- Une plantation mature de tomates forme un buisson avec plusieurs tiges, feuilles et quelques fruits visibles. Les carottes apparaissent en petite rangée ; les courgettes forment une masse basse à grandes feuilles. Les trois espèces ont des silhouettes immédiatement différentes.
- Il y a un mélange d'états : bacs vides, sol semé, pousse, plante en développement et récoltable. Cette diversité crée une bonne partie de la sensation de vie ; elle ne vient pas du décor seul.
- Clôture et panneau au fond, un petit arrosoir et de la végétation latérale suffisent. Les accessoires ne remplacent pas les cultures.

### Jardin fleuri

- La structure de cour et de bacs reste la même, mais les **floraisons** changent nettement la silhouette du centre.
- Un emplacement de tournesols montre plusieurs hampes et trois têtes à hauteurs différentes ; les tulipes forment un groupe compact de fleurs dressées ; la lavande est une masse basse de plusieurs épis violets.
- Les accents sont concentrés dans les bacs. Les fleurs sauvages de bordure restent petites et rares : la zone se reconnaît grâce à ses cultures, pas à un fond recouvert de fleurs.
- Le rose/jaune/violet ne supprime pas les verts sombres et les bruns qui donnent profondeur et lisibilité.

### Verger

- Il n'y a **aucun bac**. Trois arbres occupent un triangle ouvert sur la même cour claire ; les espaces entre troncs et couronnes restent lisibles.
- Les stades changent de silhouette : jeune tronc ramifié, couronne en formation, arbre adulte large. Un arbre mature a un tronc qui se divise, des masses de feuillage superposées et quelques fruits bien séparés.
- Le pommier et le poirier se distinguent par les fruits et par le port de la couronne, pas uniquement par la couleur. La zone laisse plus d'air entre les objets que les deux autres.
- Un seul banc et la végétation de bordure apportent l'échelle humaine. L'arbre mature est le sujet principal.

## Écarts du rendu Flame actuel

| Priorité | Écart concret | Correction graphique attendue |
| --- | --- | --- |
| 1 | `_plantShape` dessine une plante surtout autour d'une tige centrale. Dans les maquettes, chaque parcelle cultivée contient un **groupe** caractéristique de l'espèce. | Créer un rendu modulaire par espèce et par stade : tomate buissonnante, rang de carottes, courgette basse, plusieurs tournesols/tulipes/épis, arbre à couronne ramifiée. Conserver un seul objet de gameplay et un seul ancrage par emplacement. |
| 2 | La cour actuelle possède des dalles grandes et régulières, qui donnent encore l'impression d'un motif géométrique. | Raffiner la trame : dalles plus petites, joints discrets, quelques variations de forme et de valeur, tout en gardant la projection constante. |
| 3 | Bacs, clôture, arbres de bord et haies sont assemblés avec des formes répétées et peu de valeurs. | Dessiner les faces, les ombres de contact et des sous-volumes asymétriques. Le détail doit suivre la lumière et la matière, pas être tamponné à intervalle constant. |
| 4 | Les trois zones partagent beaucoup de décor. Leur identité vient surtout de l'étiquette et de quelques accessoires. | Faire porter l'identité d'abord par la famille de végétaux et l'implantation ; garder la cour, le bois et la lumière communs. |
| 5 | L'état initial réel a quatre bacs au potager/jardin fleuri et un emplacement au verger ; les maquettes montrent un état plus développé. | Comparer les rendus sur des **fixtures de test** initiales, intermédiaires et saturées, sans afficher de plantes fictives dans la partie. Ne pas juger l'état vide contre une maquette saturée. |
| 6 | Le bord gauche de chaque terrain est trop rogné dans la capture de l'application ; le bord droit est acceptable. | Faire rentrer la cour et les éléments structurants de gauche dans le cadre visible. Garder leur projection et le cadrage vertical validé, sans agrandir le vide à droite. Contrôler les trois zones sur une capture réelle. |

Le cadrage portrait actuel a été validé par l'utilisateur et reste fixe pendant ces corrections. La navigation et les actions déjà validées ne sont pas l'objet de cette passe graphique. Les images de `art-mockups/` ne sont pas chargées par l'application.

## Critères de revue de la prochaine passe

1. À 390 × 844, masquer l'UI : potager, jardin fleuri et verger doivent être distinguables immédiatement, même en niveaux de gris.
2. Une parcelle adulte doit pouvoir être identifiée par sa silhouette avant de lire son nom ; tomate, carotte et courgette ne doivent plus partager la même construction.
3. Les bacs, la cour et les arbres doivent partager les mêmes axes isométriques, direction de lumière et longueur d'ombre.
4. À l'état initial, les zones vides restent composées et calmes ; à l'état saturé, les cultures restent séparables et touchables.
5. Revoir les trois zones aux stades initial, intermédiaire et saturé, à 390 × 844 et 375 × 667, sans zoomer l'image pendant la revue.
6. Le bord gauche montre clairement le départ du terrain et des éléments de bordure ; aucune culture ni panneau utile n'est coupé. Le bord droit garde sa position actuelle.

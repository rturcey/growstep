# Potager saturé : analyse visuelle et cible (#41)

Comparer la [capture de l'application à 390 × 844](application_potager_sature_390x844.png)
à la [maquette cible](potager_ideal_concept.png). La maquette a été générée par
édition de cette capture. Son format de sortie est 853 × 1844 : elle conserve
approximativement le rapport de l'écran, mais ses coordonnées ne sont pas un
gabarit de placement au pixel près. La capture reste la seule preuve du rendu
réel dans l'application.

## Diagnostic, par ordre d'impact

| Dans la capture actuelle | Effet à 390 × 844 | Direction montrée par la cible |
| --- | --- | --- |
| La bande supérieure du panneau de jardin reste vide sur environ 125 px avant le sommet de l'îlot. | Le potager paraît petit dans son cadre et peu accueillant malgré huit cultures. | Faire monter une couronne végétale irrégulière derrière le terrain, sans agrandir les cibles tactiles ni cacher les cultures. |
| La pelouse intérieure est une surface verte de tonalité quasi uniforme. | Les chemins, bacs et accessoires ont l'air simplement déposés sur une aire de jeu. | Introduire des masses discrètes de gazon, terre, mousse et herbes au contact des grands éléments, et laisser une zone plus calme à l'avant droit. |
| La haie arrière et les buissons latéraux apparaissent comme plusieurs paquets séparés ; les deux buissons bas sont particulièrement isolés. | La périphérie ne cadre pas le lieu ; elle accentue l'impression d'objets indépendants. | Relier arrière et côtés par une sous-couche basse continue, puis varier et chevaucher les volumes de feuillage au-dessus. Garder l'entrée avant ouverte. |
| Les dalles sont lisibles mais clairsemées dans de larges intervalles d'herbe nue. | La circulation semble surimposée plutôt qu'usée et entretenue. | Garder les pas séparés et le graphe connecté, puis travailler leurs raccords : ombre douce, herbe basse et changements subtils de sol. |
| Les huit bacs ont le même volume régulier et leurs contours sont très nets. | Le motif 3–2–3 et la répétition des caisses dominent avant le jardin. | Conserver les huit emplacements et le bois bas, mais renforcer la terre visible, varier légèrement les contacts et laisser quelques pousses traverser les jonctions. |
| Les plants sont très compacts et presque identiques à l'intérieur d'une même espèce. | Les légumes se lisent, mais la scène manque de vie et de profondeur. | Employer plusieurs silhouettes de feuillage et quelques orientations de fruits par stade ; maintenir chaque culture reconnaissable en petit. |
| L'arche, le tonneau et l'arrosoir restent peu liés aux zones voisines. | Ces signes de soin deviennent des accessoires ponctuels, sans histoire spatiale. | Asseoir l'arche dans la haie et former un seul coin d'entretien tonneau–arrosoir, avec ombres et végétation basse à leur pied. |
| Le bord extérieur est un polygone aux arêtes nettes, avec une grande tranche de terre uniforme. | Le potager lit davantage comme une plate-forme flottante que comme un morceau de jardin. | Casser localement le bord supérieur par des touffes, fleurs et petites pierres, sans cacher la tranche de terre ni sortir du cadrage approuvé. |

Un contrôle du code révèle aussi un écart de gabarit : le contour actuel du
potager descend jusqu'à `y = 410` dans le canevas logique, puis la tranche de
terre est dessinée encore plus bas. Le maximum documenté pour l'îlot complet
est `y = 405`. Plusieurs ancres de décor sont définies en pixels libres alors
que le gabarit prévoit le treillis isométrique entier ou demi-entier. Ces deux
points doivent être corrigés lors du recalage de la composition réelle.

Le nombre d'objets n'est pas le problème principal. La cible fonctionne mieux
par continuité des masses et qualité des raccords. Les cultures et les pas
restent plus contrastés que les détails ; l'avant reste respirant. Les petites
fleurs sont secondaires et ne doivent pas devenir une pluie de points blancs.

## Traduction compatible avec le projet

La maquette doit être reconstruite avec le terrain Canvas, les pas de chemin,
les huit platebandes interactives, des variantes de végétation et quelques
accessoires modulaires. Elle ne doit pas remplacer la scène par une image de
fond. Les huit centres de parcelle et leurs index de sauvegarde restent ceux de
`docs/geometrie-ilots.md` ; le chemin reste sur son treillis entier ou
demi-entier, connecté depuis l'entrée. Le contour complet reste dans le
gabarit du canevas logique, y compris sa tranche de terre.

Ordre de correction proposé pour le ticket #41 :

1. Recomposer le cadre arrière et latéral en une masse continue, puis corriger
   son contact avec le terrain et le cadrage du contour.
2. Traiter les jonctions des bacs, des pas, de l'arche et du coin d'entretien
   avec quelques variantes répétables de sol et de végétation basse.
3. Ajuster les volumes et variantes des plantes et du bois, en vérifiant à
   390 × 844 et 375 × 667 que les huit bacs restent évidents et sélectionnables.
4. Recapturer les états initial, intermédiaire et saturé en couleur et en gris.
   Le résultat réel à taille 1:1 doit être validé explicitement avant toute
   généralisation au jardin fleuri ou au verger.

La maquette exagère la finesse des feuilles et des textures, et elle a
légèrement réinterprété la typographie de l'interface. Ces détails ne sont pas
des consignes de reproduction ; sa valeur est la composition du lieu, sa
hiérarchie visuelle et l'intégration des éléments.

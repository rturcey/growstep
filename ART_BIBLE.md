# Growstep — bible graphique

> Statut : accepté. Cette bible fixe les règles de production des assets Growstep.

## Autorité et intention

`test.png` est la référence principale pour la douceur, la perspective de maquette, la composition mobile et la reconnaissance immédiate des cultures. Ses microfleurs, ses feuillages détaillés, ses incohérences de projection et son compteur d'eau ne sont pas des règles à reproduire. Cette bible prévaut sur la capture pour tout nouvel asset. Le [glossaire](CONTEXT.md) nomme les objets du jardin ; le [game design](docs/game-design.md) fixe leurs règles de jeu.

Le monde est un diorama en sprites 2D orthographiques, calme, lumineux, naturel et contemporain. Une silhouette lisible prime sur la texture ; une scène respirante prime sur le remplissage. Aucun rendu 3D plastique, pixel art, aquarelle, anime, fantasy, vectoriel plat ou illustration promotionnelle saturée de détails.

## Écran, caméra et géométrie

| Paramètre | Règle |
| --- | --- |
| Écran de référence | iPhone portrait, 390 × 844 points logiques. Vérification obligatoire à 375 × 667 points. |
| Hauteur du monde | Cible de 450 points sur l'écran de référence ; au moins 380 points sur le petit écran. Les panneaux secondaires s'ouvrent hors de la scène. |
| Caméra | Orthographique fixe, même échelle dans les trois zones, sans rotation ni déplacement libre au doigt. |
| Projection | Grille à losanges 2:1 : une unité mesure 80 × 40 points logiques. Aucun point de fuite ni convergence. |
| Export | Master raster à 4× : une unité de grille mesure 320 × 160 pixels. Les exports plus légers sont dérivés du master, jamais agrandis. |
| Origine d'un sprite | Point de contact au sol, à la base et au centre de son emprise logique. Le tri en profondeur suit ce point. |
| Navigation | Le potager est la vue d'accueil. Les noms du jardin fleuri et du verger restent visibles dans l'interface avec leur état verrouillé et leur prix de test de 100 et 250 florins ; le verger peut être acheté en premier. Leurs scènes restent cachées jusqu'à l'achat. Changer d'îlot ouvert change de vue sans déplacement de caméra entre terrains ; aucun zoom ni déplacement libre au doigt. |

Chaque zone occupe un îlot distinct et fini. Chaque cadrage montre tout son contour, avec des retours obliques et une tranche de terre visibles ; aucun bord n'est artificiellement coupé pour suggérer un terrain voisin. Les trois contours sont distincts mais dérivent d'un même gabarit de cases d'herbe 80 × 40, avec une épaisseur de terre comparable. Le [gabarit géométrique](docs/geometrie-ilots.md) consigne les contours actuels dans le canevas 390 × 450 et une tranche de terre de 20 à 28 points ; la silhouette entière doit rester visible à 375 × 667 sans changement d'échelle. Les trois îlots utilisent la même projection, la même échelle apparente, les mêmes matériaux et la même lumière, mais n'ont aucun raccord physique. Le fond crème vert pâle reste indépendant de l'îlot, avec au plus quelques silhouettes végétales très discrètes. Aucune vue d'ensemble n'est obligatoire.

Une vue doit montrer simultanément ses huit emplacements possibles au potager ou au jardin fleuri, ou ses trois emplacements au verger. L'échelle ne diminue pas sur le petit écran : seules les marges de terrain sont réduites. Les grandes couronnes ne peuvent pas sortir de la zone utile lorsqu'elles portent une interaction.

### Implantation étalon

Les anciennes coordonnées des emplacements ne sont plus un gabarit : le plan commun du terrain, des chemins et des plantations doit être redessiné avant d'arrêter de nouveaux points de contact au sol. Le potager et le jardin fleuri répartissent chacun leurs huit emplacements en trois rangées décalées de 3, 2 et 3, avec une ouverture centrale dans la rangée du milieu ; les [centres du gabarit](docs/geometrie-ilots.md) laissent 40 points d'herbe entre platebandes d'une même rangée et 80 points au milieu. Les quatre emplacements disponibles à l'ouverture de chaque zone ne forment pas un bloc compact. Le verger réserve trois emplacements d'arbre. Tous les emplacements possibles restent visibles dans leur vue, avec un ordre d'index stable pour préserver les sauvegardes existantes.

Les centres de deux emplacements interactifs sont séparés suffisamment pour accueillir chacun une cible de 44 × 44 points sans chevauchement. La grille 80 × 40 est la base géométrique commune du terrain, des emprises et des axes de circulation. Les centres des platebandes, arbres et pas de chemin se placent sur les centres des cases d'herbe ou sur les décalages de demi-case fixés par le gabarit ; aucune coordonnée indépendante n'est choisie objet par objet. Les positions possibles existent dès le départ ; le joueur choisit l'ordre de leur achat, pas leurs coordonnées. Les emplacements non achetés ne sont suggérés que par une légère variation d'herbe ; un repère explicite apparaît en mode achat. Les cinq paliers d'embellissement ne déplacent aucun emplacement.

### Échelle des objets

| Famille | Largeur visible maximale à 1× | Hauteur au-dessus du contact | Emprise |
| --- | ---: | ---: | --- |
| Platebande | 80 points ; dessus 80 × 40 | 12 points de bordure au plus | 1 unité |
| Plante de platebande | 72 points | 90 points | 1 unité |
| Arbre adulte | 160 points | 150 points | Réservation de 2 unités de large autour d'un emplacement |
| Grande décoration | 160 points | 100 points | 2 unités de large au plus |
| Petite décoration | 80 points | 70 points | 1 unité |
| Petit animal | 60 points | 55 points | Contact ponctuel ; aucune place de culture bloquée |

Les silhouettes peuvent être plus petites selon l'espèce ; une espèce ne dépasse jamais sa classe pour devenir plus spectaculaire. L'arbre porte au plus quelques fruits agrandis pour être identifiables ; ses feuilles forment une masse principale et deux ou trois sous-volumes, pas une multitude de feuilles indépendantes. Une fleur ou un légume privilégie la forme de ses feuilles, de sa fleur ou de son fruit à la finesse botanique.

## Composition et zones

Le potager aligne ses platebandes compactes et des chemins de pierre crème clairement lisibles. Le jardin fleuri conserve huit emplacements distincts, avec des bordures plus souples et des groupes de floraison, sans tapis continu de fleurs. Le verger ménage de l'herbe ouverte autour de trois arbres et évite toute couronne couvrant un autre emplacement. Lors de leur première ouverture, le jardin fleuri et le verger montrent un terrain et une bordure déjà vivants, mais tous leurs emplacements de plantation sont vides pour la graine offerte choisie par le joueur. Les trois îlots partagent les mêmes matériaux et la même lumière ; couleur seule ne suffit jamais à les distinguer. Les espèces initiales sont tomate, carotte et courgette ; tournesol, tulipe et lavande ; pommier et poirier, respectivement. Toute nouvelle espèce suit les mêmes tailles et états que sa famille.

Le gameplay reste au premier plan : cultures interactives, platebandes et chemin, grandes masses paysagères, décors secondaires, puis microdétails. Le détail et le contraste décroissent dans cet ordre ; les cultures restent reconnaissables en couleur et en gris. Les volumes hauts se concentrent à l'arrière et sur les côtés ; le bord avant reste bas, ouvert et laisse voir au moins 40 % de sa tranche de terre. Au plus deux familles d'accents colorés dominent simultanément. Le nom de zone reste dans l'interface Flutter : aucun grand panneau de titre n'occupe le centre du monde ; un petit panneau décoratif peut se placer sur un côté. Les décors achetés en excès restent disponibles hors de la scène ; ils ne sont jamais placés automatiquement. Leur placement s'aimante à des positions autorisées et refuse visuellement une position qui masque une plante, coupe un chemin ou dépasse du terrain.

### Doctrine de composition paysagère

Composer chaque îlot comme un petit paysage avant de disposer ses objets : **silhouette du terrain → circulation → masses végétales principales → emplacements interactifs → espaces négatifs → décors secondaires → microdétails**. Une accumulation de bons sprites ne suffit pas. Préférer une grande forme simple à une succession d'éléments indépendants. La grille 80 × 40 règle les positions et le gameplay ; elle ne doit pas devenir un motif visible. Le plan 3 / 2 / 3 et les index restent stables, mais le chemin, les masses, les ouvertures et les différences de densité doivent empêcher sa lecture immédiate comme trois rangées de cases.

La végétation environnementale se mesure en **masses paysagères perceptives**, jamais en nombre de sprites. Plusieurs arbustes proches et chevauchés forment un bosquet unique ; rochers, herbes et feuillages peuvent composer une même masse. À l'inverse, six buissons espacés restent six éléments perceptifs. Pour un îlot saturé, viser selon le besoin **2 à 4 masses périphériques principales**, **0 à 2 masses secondaires de transition**, **au moins une grande zone calme** et **au plus deux grandes décorations indépendantes**. Ces bornes ne sont pas des quotas à remplir. Une masse principale occupe une portion significative du bord et possède une silhouette commune ; une masse secondaire relie, équilibre ou adoucit une jonction. Quelques fleurs ou herbes peuvent ponctuer une masse, sans constituer une couche de remplissage ni se répandre uniformément dans la scène. Augmenter la surface végétalisée par de grands volumes simples, sans augmenter le bruit visuel.

Les végétaux et objets de décor dont la silhouette participe au paysage utilisent des sprites RGBA modulaires, ancrés au sol et triés en profondeur. Un même sprite peut servir à plusieurs tailles et dans plusieurs masses ; les formes de terrain, les transitions d'herbe et les tracés de chemin peuvent rester en Canvas. La composition des masses et les espaces négatifs priment sur le nombre de fichiers.

La profondeur se lit en trois plans, sans changer la perspective : **avant** relativement dégagé, herbe et végétation basse avec tranche visible ; **centre** réservé aux cultures, platebandes, chemin et interactions ; **arrière et côtés** porteurs des masses hautes et des éventuelles clôtures ou grandes décorations. Chevauchements, ombres, tailles et points de contact au sol créent la profondeur. Répartir des poids différents de chaque côté, avec une ouverture et une surface significative d'herbe calme : ni symétrie automatique, ni densité identique partout. La végétation ou quelques pierres peuvent assouplir localement le contour visible, sans modifier la géométrie logique ni masquer la tranche avant.

Le paysage permanent doit paraître achevé avec 4, 6 ou 8 emplacements achetés. Les cultures viennent l'habiter progressivement ; l'état initial ne paraît pas inachevé et l'état saturé ne devient pas encombré. Garder tous les emplacements visibles et touchables. Chaque grand décor indépendant doit équilibrer une masse, créer une verticale, signaler l'entrée ou rompre une répétition ; aucune liste de décors ne constitue une obligation d'ajout.

Un objet de premier plan ne peut pas masquer durablement une interaction. Une couronne peut devenir temporairement translucide pendant la sélection si un chevauchement ponctuel subsiste. Le chien peut passer devant des objets, mais un toucher sur une plante reste prioritaire. Son tri visuel suit son contact au sol. Il peut sortir du cadre lors d'un changement de zone.

### Terrain et cinq embellissements

Le sol jouable est formé de **cases carrées d'herbe en projection 80 × 40**. Leurs dessus s'assemblent en une surface végétale continue : aucun joint de terre ni quadrillage permanent ne doit apparaître entre deux cases intérieures. La terre brune en relief n'est visible que sur les bords extérieurs de l'îlot. Le modèle de cette tranche et de sa bordure herbeuse est `test.png`. L'herbe reste visible sous les objets et entre les chemins dans chaque zone.

Les pas de pierre crème peuvent être dessinés en Canvas ou rendus par des sprites RGBA modulaires. Chaque îlot possède d'abord un tracé complet : entrée claire depuis le bord avant, axe principal légèrement sinueux et ramifications courtes vers les cultures. Les pierres sont ensuite distribuées sur ce tracé, jamais placées isolément ou pseudo-aléatoirement ; ni espacement identique, ni séquence répétitive, ni parfaite symétrie. Le chemin évite les platebandes et respecte la grille logique. Les variantes de pierre partagent matière, lumière, emprise et ancrage ; leur épaisseur est faible, leurs bords légèrement irréguliers, et de l'herbe reste visible entre elles. Elles ne forment jamais un sol minéral continu ni une cour pavée. Le jardin reste visuellement herbeux même lorsque tous les emplacements sont occupés. Le contrat spatial du Potager et sa migration progressive figurent dans la [spécification de composition](docs/MAP_COMPOSITION_SPEC.md).

Les paliers d'embellissement sont communs aux trois îlots : un îlot ouvert plus tard affiche immédiatement le palier déjà gagné par le jardin. Ils remplacent ou raffinent des éléments existants ; ils ne superposent pas cinq couches de décor. Leur progression visuelle est :

1. Contour herbeux et tranche de terre simples ; bordure entretenue après le premier palier.
2. Chemin déjà ponctué de quelques pas de pierre crème au départ ; le palier complète et soigne les pas sur le même itinéraire, sans accroître son emprise ni retirer l'herbe entre eux.
3. Quelques segments de clôture basse sur le bord arrière extérieur, sans traverser la silhouette d'une plante interactive.
4. Bordure herbeuse plus riche avec quelques fleurs intégrées aux masses paysagères, sans créer de nouveaux points isolés.
5. Entrée de chemin mieux finie en bois et pierre, en remplacement de sa version précédente, sans nouveau point focal majeur.

L'herbe et la tranche de terre restent lisibles à chaque palier. La grille logique n'est jamais dessinée en permanence. Les formes des chemins et les platebandes révèlent où placer et toucher les objets.

## Couleur, lumière et matières

Les codes suivants sont les **ancrages de production**, en sRGB hexadécimal. Ils forment une identité Growstep originale inspirée de l'équilibre de la capture, sans en échantillonner les pixels. Sur les grandes surfaces d'un même matériau, les variations restent à ±8° de teinte, ±12 points de saturation et ±10 points de luminosité HSL autour de l'ancrage. Les ombres et rehauts peuvent sortir de cette plage s'ils respectent la direction de lumière et ne deviennent pas noirs ou blancs purs.

| Rôle | Ancrage |
| --- | --- |
| Fond hors jardin | `#E4EBD5` |
| Herbe éclairée | `#B5CE85` |
| Herbe principale | `#9DBF72` |
| Herbe ombrée | `#79995B` |
| Feuillage sauge | `#829E70` |
| Feuillage profond | `#52764F` |
| Terre de culture | `#6C503C` |
| Terre de tranche | `#8A674A` |
| Bois chaud | `#B98A5A` |
| Pierre crème | `#D9D0B8` |
| Surface UI | `#FBF8F0` |
| Texte UI | `#2B3C32` |
| Action UI | `#63845B` |

Accents de départ : rose `#D98FA3`, jaune `#E5C75F`, rouge fruit `#C96955`, bleu doux `#83A9B7`, violet `#9C8BB5`, blanc floral `#F5EDDA`. Une espèce conserve ses accents entre étapes ; on ajuste leur valeur si le fond les absorbe. Les masses interactives doivent rester reconnaissables en niveaux de gris. Cibles internes de contraste à 1× : limite de platebande contre herbe ≥ 1,5:1 ; signe « récoltable » contre son voisinage ≥ 3:1 ; texte UI contre sa surface ≥ 4,5:1 ; icône UI active ≥ 3:1. La scène est contrôlée aussi en niveaux de gris, car une couleur seule ne doit pas indiquer un état.

Lumière diffuse de journée claire, venant du haut-gauche de l'écran. Dessus et côté gauche plus clairs ; face avant et droite légèrement plus sombres. Ombre portée séparée vers le bas-droite, longueur ordinaire au plus un tiers de la largeur de l'objet ; arbre : exception documentée si sa couronne l'exige. Ombre de contact séparée sous le point d'appui. Ombres chaudes ou vert gris, bords doux, jamais noires, jamais intégrées à la couleur du sprite mobile. L'opacité cible est de 10 à 22 % au contact et de 8 à 16 % pour l'ombre portée. Aucun bloom, halo constant, rim light ou reflet plastique.

Les matières sont légèrement peintes et mates. À l'échelle normale, une masse principale et au plus trois sous-volumes portent la forme. Une plante de taille unitaire a au plus cinq marques décoratives isolées ; un arbre peut en avoir davantage proportionnellement à sa largeur. Un détail purement décoratif qui devient un point isolé de moins de 3 points à 1× est supprimé. Un trait local de séparation peut mesurer au plus 1 point apparent, dans une couleur liée à l'objet ; aucun contour continu autour de la silhouette. Les textures restent sous la silhouette en importance.

## États des plantes et signes de jeu

| État visible | Déclencheur | Silhouette attendue |
| --- | --- | --- |
| Semé | Plantation, 0 nouveau pas | Terre semée ; aucune pousse visible. |
| Graine germée | Premier nouveau pas | Très petite émergence spécifique à la famille. |
| Jeune plant | 30 % du seuil | Feuilles ou tiges reconnaissables, forme distincte. |
| Presque mature | 70 % | Volume adulte en devenir, sans simple agrandissement uniforme. |
| Récoltable | 100 % du premier cycle | Forme adulte et fruits/fleurs visibles ; signe UI discret commun. |
| Adulte sans production | Juste après récolte | Même taille adulte ; signes de production retirés. |
| Production naissante | 50 % du cycle suivant | Fruits/fleurs en formation, sans signe « récoltable ». |
| Récoltable à nouveau | 100 % du cycle suivant | Retour à l'image récoltable. |

Le compteur de pas jusqu'à la prochaine étape apparaît pour la plante sélectionnée. Le signe commun « récoltable » reste visible, sans clignotement ; le sprite porte aussi ses fruits ou fleurs. L'engrais est indiqué dans l'UI de la plante sélectionnée et ne crée pas de version recolorée du végétal. La suppression remet immédiatement l'emplacement acheté à son aspect vide propre. Il n'existe pas d'état « humide » obligatoire : le jeu n'a plus d'eau comme ressource.

Une variante brillante garde exactement l'emprise et les états de l'espèce ordinaire. Elle possède un motif fixe propre à l'espèce et un petit éclat clair commun sur deux ou trois feuilles, fleurs ou fruits ; elle se reconnaît sans animation. Pas de halo, pluie de particules ou saturation métallique. À l'état semé, son type est disponible dans l'UI de sélection ; le sol ne révèle pas de nouveau code de couleur.

## Animation

Tout état possède une image fixe complète. Les animations ambiantes sont intermittentes : au plus deux éléments bougent simultanément par vue, déplacement de feuillage inférieur à 3 points, cycle de 4 à 8 secondes. Croissance et récolte utilisent des transitions de 0,25 à 0,5 seconde, sobres et de faible amplitude. L'animal peut avoir une marche de 4 à 6 images et un idle de 2 à 3 images ; il peut dépasser temporairement le budget ambiant pendant une interaction. Un mouvement ne doit pas modifier le point d'ancrage au sol ni la cible tactile.

Un sprite fixe par état est le point de départ. On sépare en deux ou trois couches seulement ce qui doit réellement bouger, comme couronne et tronc, ou eau et bassin. Les frames d'une animation partagent canevas, ancrage, emprise et lumière. En mode réduction des mouvements, chaque état reste compréhensible à l'arrêt ; les transitions deviennent immédiates ou fondues sans déplacement.

## Interface Flutter

L'UI est une application mobile contemporaine distincte du monde peint : surfaces crème, texte vert sombre, boutons d'action vert naturel, grandes formes arrondies et pictogrammes simples à trait régulier. Typographie sans-serif système, chiffres de pas immédiatement lisibles ; aucun bois autour des boutons, aucune bordure médiévale. La texture reste dans le jardin.

Sur la vue principale restent visibles : pas du jour, nom de la zone, sélecteur compact des trois îlots hors de la scène Flame, une action principale contextuelle et navigation de l'application. Un appui sur un îlot fermé ouvre un panneau Flutter indiquant son prix en florins, ses espèces et son nombre d'emplacements initiaux, puis demandant confirmation de l'achat ; sa scène reste cachée jusqu'à l'achat. Florins et autres compteurs vivent dans des panneaux dédiés. Aucun compteur d'eau. Les panneaux secondaires ne couvrent pas durablement la scène. Titres de zone : 20 points ; nombres de pas et actions : 16 points ou plus ; navigation : 14 points ou plus. Pictogrammes UI à trait régulier de 2 points apparents, coins de cartes de 16 points, boutons principaux de 24 points ou en pilule. Une cible interactive mesure au moins 44 × 44 points même si son image est plus petite ; les cibles prioritaires ne se chevauchent pas.

## Fichiers et pipeline

Chaque asset possède un identifiant stable sous la forme `zone_famille_espece-ou-objet_etat_variante_frame`, en minuscules ASCII et underscores. Exemple : `potager_plante_tomate_jeune_ordinaire_00`. Les mots d'état sont `seme`, `germee`, `jeune`, `presque_mature`, `recoltable`, `adulte_sans_production`, `production_naissante`. Les variantes sont `ordinaire` et `brillante`. Le même nom sert à relier source, PNG master, ombre et fiche.

Livrables : source modifiable OpenRaster (`.ora`) avec couches utiles, PNG RGBA transparent sRGB à 4×, ombre(s) séparée(s), fiche YAML de métadonnées, et, pour une génération d'image, prompt, références, graine si disponible, retouches et version du modèle. La fiche porte dimensions du canevas, point d'ancrage en pixels, emprise en unités, état, variante, frames, direction de lumière et rôles de palette. Chaque canevas possède au moins 4 pixels masters de marge transparente autour de la silhouette ; les ombres utilisent leur propre canevas. Les frames d'un même état animé gardent exactement les mêmes dimensions et le même point d'ancrage. Aucun fond opaque, frange blanche ou halo de détourage. Des PNG à 2× et 3× sont dérivés du master pour le jeu selon la densité d'écran, sans retouche manuelle divergente.

Une image générée n'est qu'une source de travail. Elle est détourée, corrigée à la projection et à l'échelle, découpée si nécessaire, puis vue dans une scène complète. On ne valide jamais un asset seulement agrandi ou isolé sur fond blanc. L'export pour le jeu est dérivé du master sans changer la silhouette ni les coordonnées d'ancrage.

Le [pipeline des sprites intégrés](docs/sprite-pipeline.md) précise le manifeste de cadrage utilisé par Flame. Seuls les sprites transparents modulaires sont déclarés dans `pubspec.yaml` ; les captures et maquettes d'écran restent des références hors du bundle.

## Validation et changement des règles

La scène étalon montre chaque îlot aux états initial, intermédiaire et saturé : 4, 6 puis 8 emplacements au potager et au jardin fleuri ; 1, 2 puis 3 au verger. Au premier lancement, le potager montre une jeune carotte, un pied de tomate presque mature, une platebande pour la plantation guidée et une platebande vide. Elle inclut chemins, un arbre, un animal, décors, états de plante, variante brillante, UI, ombres et végétation environnementale. Elle est revue à 390 × 844 et 375 × 667 points, à 100 %, en niveaux de gris, avec animation coupée et après le changement d'îlot. Les huit emplacements d'une zone et les trois arbres doivent rester visibles et touchables.

Les contrôles automatiques rejettent nom ou métadonnées manquants, dimensions ou alpha invalides, marge insuffisante, ancrage hors canevas, incohérence entre frames et mauvais rapport de grille. La revue humaine vérifie silhouette, matière, lumière, palette, densité, charme et hiérarchie de gameplay. Un refus consigne son motif. Un asset charmant qui enfreint une règle ne devient pas une exception isolée : la règle est révisée pour sa famille et les assets existants sont revus, ou l'asset est corrigé.

## Hors périmètre de la première bible

Printemps lumineux permanent. Pas de saisons, météo, nuit, zones personnalisées mixtes, agrandissement physique des îlots au-delà du plan fixe, caméra déplaçable, zoom d'inspection ou rotation de caméra. Leur arrivée demanderait une révision de la bible et une nouvelle scène étalon.

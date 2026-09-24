# Composition spatiale du Potager — spécification

> Statut : spécification pour découpage en tickets. La [bible graphique](../ART_BIBLE.md) fixe l'apparence ; ce document fixe la composition spatiale et son contrat de rendu. Périmètre de production : Potager uniquement. Les autres îlots restent inchangés, mais la grammaire de scène doit pouvoir leur servir plus tard.

## Problem Statement

Le Potager est jouable, mais sa map reste décidée à plusieurs endroits du code : géométrie et ancrages dans le renderer Flame, chemin dans une classe dédiée, masses dans une autre, références des sprites dans des callbacks de rendu. Les quatre premiers emplacements et les achats supplémentaires fonctionnent, mais cette dispersion rend difficile la revue de la composition, le remplacement d'une famille graphique et la conservation de la lisibilité à 4, 6 et 8 emplacements. Le nouveau pack d'environnement ne doit pas conduire à une nouvelle accumulation de coordonnées et d'objets épars.

## Solution

Décrire une seule composition du Potager, écrite à la main, déterministe et vérifiable. Le renderer Flame existant la dessine sans choisir les positions ni les variantes. Les emplacements de plantation restent reliés au modèle métier par leur index stable ; les éléments d'ambiance fixes restent purement visuels. Intégrer le pack famille par famille, avec capture et revue après chaque étape. Préserver le terrain, la projection et les cultures actuelles.

## User Stories

1. En tant que joueur, je veux reconnaître chaque emplacement de plantation et chaque culture, afin de planter et récolter sans hésitation.
2. En tant que joueur, je veux conserver mes huit positions et leur progression sauvegardée, afin que la nouvelle apparence ne déplace rien dans ma partie.
3. En tant que joueur, je veux toucher chacun des emplacements sur petit ou grand téléphone, afin que le décor ne bloque jamais une action.
4. En tant que joueur, je veux suivre un chemin de pierres espacées depuis l'avant de l'îlot, afin de lire le jardin comme un lieu parcourable.
5. En tant que joueur, je veux voir des bosquets, rochers et bordures variés mais groupés, afin que le jardin paraisse naturel et calme.
6. En tant que joueur, je veux voir le Potager achevé avec quatre emplacements et respirant avec huit, afin que sa qualité ne dépende pas du nombre de cultures.
7. En tant que joueur, je veux retrouver les tomates, carottes et courgettes dans leurs formes et états actuels, afin de reconnaître immédiatement leur croissance.
8. En tant que joueur, je veux voir le contour et la tranche de l'îlot malgré les débordements végétaux, afin de comprendre l'espace disponible.
9. En tant que joueur, je veux une arche lisible et quelques outils de jardin, afin que le lieu paraisse entretenu sans détourner l'attention des cultures.
10. En tant que développeur, je veux retrouver tous les choix de placement dans une composition centralisée, afin de modifier le paysage sans chercher des constantes dans le renderer.
11. En tant que développeur, je veux un ancrage au sol et un tri en profondeur reproductibles, afin que les chevauchements restent justes lorsque les sprites changent.
12. En tant que développeur, je veux utiliser les métadonnées du manifeste pour les dimensions et ancrages, afin que les marges transparentes ne décalent pas la scène.
13. En tant que développeur, je veux des variantes de platebande choisies par index et stables, afin que deux rendus de la même sauvegarde soient identiques.
14. En tant que développeur, je veux un contrôle visuel des ancres, couches, IDs et cibles tactiles, afin de diagnostiquer vite une erreur de composition.
15. En tant que relecteur, je veux une capture reproductible par état et viewport après chaque ticket, afin de comparer précisément l'avant et l'après.
16. En tant que responsable artistique, je veux que l'environnement reste moins contrasté que les cultures, afin que la densité végétale n'efface pas le gameplay.
17. En tant que responsable du pipeline, je veux valider les IDs, sources et résolutions du pack avant l'intégration, afin d'éviter un écrasement silencieux d'assets déjà canoniques.
18. En tant que développeur d'un futur îlot, je veux réutiliser la grammaire d'objets, d'ancres et de couches, afin de composer ce nouvel îlot sans refaire l'architecture du Potager.

## État actuel vérifié et problèmes

| Sujet | Constat dans le dépôt | Conséquence |
| --- | --- | --- |
| Moteur et UI | `GardenGame` hérite de `FlameGame`, est affiché par `GameWidget` dans l'UI Flutter. Le monde est rendu au `Canvas` Flame. | Garder Flame, le layout Flutter et la navigation existants. |
| Artboard | Référence 390 × 450, échelle 1, centrage dans le viewport. Le petit écran 375 × 667 laisse une fenêtre utile d'environ 375 × 430. | Une seule transformation artboard → écran suffit ; à ces deux formats l'échelle reste inchangée. |
| Projection | Grille 2:1 de 80 × 40 ; axes `(40,20)` et `(-40,20)` autour de `(195,230)`. | Contacts sur treillis entier ou demi-entier ; ne pas déplacer les huit contacts. |
| Emplacements | Les index 0…7 et les ancres 3 / 2 / 3 sont dans `GardenGame`. Quatre emplacements sont achetés au départ ; le tableau de `GardenSnapshot` porte les plantes. Cible actuelle : carré 44 × 44 indépendant des PNG. | Sortir la carte index → ancre vers la composition sans changer index, sauvegarde ou hitbox. |
| Terrain | Contour Potager polygonal, herbe et tranche de terre Canvas ; texture de sol issue d'un générateur à graine fixe. | Conserver la géométrie et la matière ; cette texture déterministe n'est pas le placement artistique des nouveaux objets. |
| Chemin | Tracé connecté et pierres Canvas, avec deux traits continus de 27 et 14 points. | La bande usée peut encore lire comme un sol continu ; remplacer visuellement par pas japonais espacés, herbe visible. |
| Décor | Masses déclarées séparément, mais choix de sprite, tailles et opacités déduits dans `_environmentObjects` ; autres objets et fallbacks Canvas dans le renderer. | Centraliser les choix artistiques et le modèle d'objet. |
| Profondeur | `_SceneObject` trie les éléments verticaux au Y de l'ancre ; terrain et chemin sont préalablement dessinés, puis sélection et debug. | Préserver le principe et rendre les égalités, ombres et couches explicites. |
| Assets | `pubspec.yaml` déclare `assets/sprites/` ; `GardenSprites` charge le manifeste et chaque PNG 4× avec `rootBundle`, puis décode à largeur cible 512. Exports 2×/3× hors bundle. | Ne pas embarquer trois résolutions par asset ; revoir seulement le décodage si coût mesuré. |
| Pack reçu | Le dossier de travail contient 71 PNG runtime, 71 sources ORA, 71 exports 2× et un manifeste de 71 entrées, avec les familles annoncées. | Le pack est disponible, mais son intégration et la qualité de chaque asset restent à valider. |
| Tests visuels | Fixtures déterministes et captures monde 390 × 844 / 375 × 667, couleur et gris ; tests de tap sur les huit index. | Réutiliser cette voie de validation, plus une capture d'application si nécessaire. |

Le glossaire appelle **emplacement de plantation** l'entité fonctionnelle et **platebande** son support graphique. Il réserve **décor** à un objet permanent que le joueur peut acheter, placer et déplacer. Les accessoires de cette spécification sont des **éléments d'ambiance fixes** : ils ne créent pas un nouveau décor joueur.

L'ADR-0006 décrit encore les bacs, chemins, bordures et accessoires comme exclusivement Canvas, tandis que la bible actuelle autorise les sprites RGBA modulaires et que le Potager en utilise déjà. L'itération 0 doit mettre cet ADR en cohérence avec le contrat effectif, sans modifier la politique du terrain Canvas ni les plantes. La bible donne encore les dalles Canvas comme pratique courante ; une modification ponctuelle doit y autoriser les pas japonais sprites, avec renvoi à ce document.

## Implementation Decisions

1. **Source de vérité.** Une définition Dart immuable par îlot contiendra l'artboard, les contacts fonctionnels, le réseau de chemin, les objets fixes et les zones calmes. La composition du Potager sera écrite à la main. Le renderer n'ajoute pas de coordonnées, de variantes ou d'opacités décoratives. Ce modèle restera volontairement petit ; aucun moteur de niveaux ni DSL externe.
2. **Artboard et projection.** Employer les coordonnées logiques existantes de 390 × 450 plutôt que des coordonnées normalisées. La conversion en pixels d'écran est centralisée : translation de centrage et facteur d'échelle uniforme. Le treillis 80 × 40 et ses demi-pas restent la référence des contacts et du chemin. La largeur ou la hauteur du téléphone ne déplace jamais un objet seul. À 390 × 844 et 375 × 667, facteur 1 conformément à la bible ; tout autre cadrage est traité uniformément et garde l'îlot entier et les cibles utiles visibles.
3. **Contact au sol.** Un objet possède un ID stable, une référence d'asset, une ancre d'artboard au contact au sol, une couche, une catégorie de taille et, exceptionnellement, un petit biais de profondeur justifié. Le manifeste fournit l'ancre en pixels master 4× et la bbox alpha ; le loader les convertit en coordonnées visibles. Une ancre de bitmap au centre n'est jamais implicite pour un objet vertical.
4. **Couches.** Conserver peu de phases : fond, terrain, chemin plat, objets à profondeur (platebandes, structures, plantes, végétation ambiante), puis signes de sélection et debug. Le classement sémantique des objets peut distinguer structure, plantation et ambiance sans imposer huit piles étanches qui annuleraient la profondeur. Dans la phase à profondeur, trier par `anchorY + zBias`, puis par priorité locale connue (ombre/platebande/plante/signe), puis par ID stable pour les égalités. Une ombre se dessine immédiatement avant son objet avec la même ancre. Les signes d'interface restent au-dessus.
5. **Tailles.** Définir un petit nombre de classes (petit, moyen, grand, repère) dérivées des limites de la bible et des tailles visibles du manifeste. Une exception numérique doit être documentée dans la composition. Préserver le ratio natif du sprite : aucune largeur et hauteur arbitraires contradictoires. Les plantes gardent leur gamme actuelle.
6. **Nature des objets.** Les emplacements fonctionnels relient index sauvegardé, contact, hitbox et rendu de platebande. Les plantes proviennent seulement de `GardenSnapshot` et sont dessinées sur l'emplacement correspondant. Les éléments d'ambiance fixes ont zéro callback de tap et zéro effet sur les données métier. Les décors joueur existants, s'ils sont effectivement rendus dans cette zone, gardent leur comportement propre et ne sont pas confondus avec ces éléments fixes.
7. **Zones spatiales.** Décrire au moins les emprises des huit platebandes, cibles 44 × 44, chemin, structures, bordures, regroupements végétaux et une grande zone calme. Les objets fixes n'empiètent pas sur les cibles, n'occultent pas une culture et ne coupent pas le trajet. Les positions inoccupées peuvent rester suggérées sans bac acheté, selon le rendu actuel. Les masses sont perceptives : 2 à 4 principales, 0 à 2 secondaires, au moins une zone calme ; maximum deux grandes décorations indépendantes. Ce sont des limites visuelles et non un comptage de sprites.
8. **Emplacements et bacs.** Conserver exactement la carte d'index 0…7 et les ancres du gabarit, la taille de cible, l'emprise de jeu et l'ordre 3 / 2 / 3. Choisir explicitement, pour chaque index, l'une des quatre variantes de platebande ; aucune décision par hasard, état de plante ou ordre d'achat. Plante et cadre restent deux objets conceptuels indépendants.
9. **Chemin.** Décrire un graphe connecté dont l'entrée reste `(195,410)`, l'axe monte en serpentant et les branches s'approchent des cultures. Encoder chaque pierre par asset parmi les six pas individuels et ancre explicite, avec intervalles irréguliers mais sans chevauchement. L'herbe reste visible entre deux pierres ; si une trace Canvas existe, elle doit être discrète et discontinue en perception. Les sprites de chemin préassemblé ne servent qu'à un besoin local justifié.
10. **Végétation, rochers, bordure.** Composer quelques masses asymétriques : arrière gauche plus végétal, arrière droit mixte ou vertical, un côté intermédiaire ; garder une ouverture et l'avant bas. Variantes de buissons et de rochers choisies explicitement. Touffes, herbes folles, trèfles et fleurs relient les masses ou accompagnent quelques pierres et platebandes ; aucune distribution uniforme. Les overlays de bordure sont ponctuels, conservent le contour logique et laissent au moins 40 % de la tranche avant lisible.
11. **Arche et objets héros.** Garder le treillis comme repère en haut, selon sa variante simple ou fleurie. Mettre en scène au plus deux grands groupes indépendants d'outils/objets de jardin, dans les masses ou en bordure. Aucune mécanique liée à l'arche ni à ces accessoires.
12. **Ombres.** Le manifeste et un audit visuel décident si le sprite a déjà une ombre perceptible. Un objet n'en reçoit qu'une : Canvas existant ou sprite de contact du pack, jamais les deux. Choisir explicitement petite, moyenne, large ou allongée lorsque nécessaire ; aligner au même contact au sol et dessiner sous l'objet. Les entrées des sprites d'ombre portent elles-mêmes `separate_contact` dans le manifeste reçu : cette métadonnée doit être corrigée ou neutralisée dans le rendu pour éviter une ombre sous l'ombre.
13. **Assets canoniques.** Le pack reçu contient déjà des IDs actifs du dépôt, notamment les variantes `00` de certains bosquets et plusieurs objets. Avant copie ou régénération, comparer ID, dimensions, bbox, ancre et empreinte des fichiers ; choisir une seule version canonique par ID et relever les différences. Les `.ora` sont des sources, les YAML des fiches, les PNG master 4× et le manifeste alimentent le runtime. Les exports 2×/3× restent hors bundle selon la convention actuelle. Valider transparence, marges, orientation, lumière et intégrité du manifeste avec le pipeline existant ; aucune capture de planche n'est un sprite runtime.
14. **Debug.** Une option de développement, désactivée en production, montre limites d'artboard, contacts, IDs, profondeur/couche et cibles tactiles. Elle s'appuie sur la même composition et le même transform que le renderer ; aucun éditeur interactif.
15. **Responsive et performance.** Le viewport de l'application garde ses zones UI actuelles. Toutes les transformations de rendu et de hit test utilisent la même conversion. Charger uniquement les assets nécessaires au rendu ou mesurer le chargement global existant avant d'y toucher ; vérifier temps de chargement, mémoire et fluidité après l'arrivée des 40 nouveaux PNG du pack.
16. **Déterminisme.** La composition ne contient aucune décision artistique aléatoire au runtime. Les variantes, positions, couches et tailles sont explicites. Le générateur de grain du sol existant, à graine stable, relève d'une texture de matière et peut rester tant qu'il ne place pas des objets de composition.

## Composition cible par famille

| Famille | Intention et limite | Vérification observable |
| --- | --- | --- |
| Terrain | Contour logique inchangé, pelouse centrale et tranche conservées. | Îlot entier visible ; au moins 40 % de la tranche avant visible. |
| Platebandes | Quatre variantes, choix fixe par index ; contact et hitbox inchangés. | Huit index touchables ; cadres variés, plantes inchangées. |
| Chemin | Pierres individuelles des six variantes, espacées sur graphe explicite. | Entrée avant évidente ; herbe entre pas ; aucune cour pavée. |
| Bosquets | Variantes basses/hautes combinées en quelques masses perceptives. | Pas de frise répétitive ; centre et avant respirent. |
| Rochers | Variantes localisées près des masses, chemins et limites. | Aucune dispersion uniforme ; pas d'obstacle à un emplacement. |
| Petite végétation | Quelques points de liaison, très peu de fleurs isolées. | Cultures plus saillantes en couleur et en gris. |
| Bordures | Quatre overlays possibles mais seulement là où le contour en bénéficie. | Falaise encore lisible ; aucun clipping. |
| Treillis et objets | Repère arrière, un ou deux groupes narratifs cohérents. | Aucun nouveau point focal au centre, aucune interaction parasite. |
| Ombres | Une ombre par objet qui en a besoin, alignée au contact. | Aucune double ombre ni flottement. |

## Plan de migration et points de revue

Chaque itération est un ticket reviewable, garde l'application fonctionnelle et produit une capture comparable. Le découpage futur visera environ neuf tickets, éventuellement en regroupant l'audit et la primitive si leur taille le permet ; ne pas fusionner plusieurs familles graphiques en un ticket massif.

| Ordre | Livraison isolée | Conditions pour passer à la suite |
| --- | --- | --- |
| 0 — Audit et contrat | Inventaire des coordonnées/objets/assets, emprises et captures de départ ; présent document ; clarification de l'ADR et du court passage de bible sur les chemins. | Carte index → contact et stratégie de collision d'IDs vérifiées ; aucun changement visuel requis. |
| 1 — Primitive | Petit modèle immuable et renderer minimal, avec quelques éléments représentatifs seulement ; overlay de debug. | Transform aller/retour, ancre et profondeur prouvés sans régression de tap. |
| 2 — Platebandes | Huit emplacements via le modèle, quatre cadres sprites attribués par index. | États, plantes, achats, sauvegarde et huit taps intacts aux deux formats. |
| 3 — Chemin | Pas japonais du pack à positions explicites ; ancien dessin du chemin remplacé localement. | Entrée et branches lisibles ; herbe entre pierres ; zéro contact bloqué. |
| 4 — Structure végétale | Bosquets, rochers, treillis et structures existantes migrés avec variantes. | Quelques masses cohérentes, profondeur juste, arrière ouvert par endroits. |
| 5 — Bordure | Overlays d'îlot ponctuels. | Contour intact, 40 % de tranche avant, rien de coupé aux deux formats. |
| 6 — Microdécoration | Touffes, herbes folles, trèfles et fleurs placés explicitement. | Densité contrôlée, zone calme réelle, cultures dominantes en gris. |
| 7 — Objets et ombres | Groupes héros rares et stratégie de contact par objet. | Deux grandes décorations indépendantes au maximum, pas de double ombre. |
| 8 — Polish | Supprimer le code de composition mort après substitution complète, compléter docs, mesurer performance. | Captures 4/6/8 et petit écran validées, tests et analyse statique propres. |

## Testing Decisions

Le **test principal** doit rester au niveau du rendu `GardenGame` avec un `GardenSnapshot` déterministe et des dimensions de viewport contrôlées : c'est la couture existante la plus haute qui couvre composition, chargement d'assets, transform et état de jeu sans multiplier les abstractions de test. Les tests doivent observer pixels/captures, contacts sélectionnables et stabilité du résultat, plutôt que les détails privés du renderer. Compléter par le validateur d'assets existant pour le contrat source/manifest, et par quelques contrôles purs sur la composition si le test au niveau scène ne peut pas distinguer une erreur de profondeur ou d'index.

Automatiser au minimum :

- identité de la composition entre deux constructions et deux rendus d'un même état ; aucune sélection de variante aléatoire ;
- conversion artboard ↔ écran à 390 × 844 et 375 × 667, puis hit test de chaque index avec cible d'au moins 44 × 44 ;
- carte stable index → contact → variante de platebande et conservation des plantes et états du snapshot ;
- ordre de profondeur pour ancres différentes et égalités, avec ombre immédiatement sous son objet ;
- existence de chaque asset référencé dans le manifeste et cohérence source 4×/exports/ancre/bbox via les scripts de validation ;
- graphe de chemin connecté, pierres non chevauchantes, aucune collision avec les cibles ;
- aucune référence de nouvelle variante ou modification de logique de tomate, carotte ou courgette.

Les tests existants de scène, de chemin, des huit contacts et de capture fournissent le point de départ. Conserver les captures reproductibles, couleur et niveaux de gris, du Potager à 390 × 844 pour 4, 6 et 8 emplacements, puis à 375 × 667 pour 4 et 8. Inclure si possible la capture monde sans UI et une capture d'application pour vérifier la coexistence avec les commandes Flutter. Comparer avant/après et inspecter réellement chaque image : lisibilité de grille, répétition, masse, profondeur, entrée, herbe entre pierres, zone calme, tranche, clipping et culture noyée. Une seule passe de tests verts ne vaut pas validation graphique. N'ajouter de goldens ciblés que si l'infrastructure existante les stabilise sans coût disproportionné.

## Critères d'acceptation finaux

**Fonctionnels et techniques.** Les huit index, positions, sauvegardes, états et interactions subsistent ; les cultures et leur logique sont inchangées. La composition est centralisée, déclarative, déterministe et séparée du renderer et du métier. Le tri utilise le contact au sol ; les cibles ne dépendent pas des marges transparentes. Les assets sont canoniques, modulaires et correctement référencés ; les exports 2×/3× ne grossissent pas le bundle sans nécessité. Le responsive garde l'artboard cohérent. Le vieux code ne disparaît qu'après remplacement. Tests et lints passent.

**Visuels.** Le Potager ressemble d'abord à un jardin habité. Le terrain reste entièrement visible, avec sa tranche avant. Les emplacements se lisent et se touchent, mais le motif 3 / 2 / 3 n'est pas la première impression. Le chemin entre clairement par l'avant, mène à l'arrière et laisse voir de l'herbe entre ses pierres. Quelques masses végétales périphériques asymétriques, des rochers limités et une zone calme donnent de la profondeur sans encombrer. Les cultures dominent en couleur et en gris. Les états 4, 6 et 8 tiennent à 390 × 844 ; les états 4 et 8 tiennent à 375 × 667.

## Out of Scope

- Refonte de l'interface Flutter, navigation, caméra, perspective, terrain procédural ou moteur de jeu.
- Changement du jardin fleuri ou du verger dans cette série de tickets.
- Nouveaux sprites, variantes, états ou règles métier de tomate, carotte et courgette ; économie, ressources, croissance, récolte, achats ou progression.
- Mécanique de progression de l'arche ou des objets héros ; nouveaux décors joueur achetables ou déplaçables.
- Génération artistique runtime, moteur générique de niveaux, éditeur visuel, base de données ou format externe de scène.
- Background monolithique, image de capture utilisée comme terrain ou copie runtime des sources `.ora`.

## Further Notes

**Risques.** (1) Le pack de 71 assets contient des IDs déjà actifs : une copie directe peut remplacer les sprites du travail précédent ; audit d'empreintes et de métadonnées obligatoire. (2) L'ADR-0006 et la phrase actuelle de la bible sur les chemins Canvas ne décrivent pas encore l'emploi demandé des nouveaux sprites : mise en cohérence documentaire en itération 0. (3) Le loader actuel décode toutes les entrées du manifeste à 512 pixels de large, y compris des PNG sources plus petits ; l'ajout des assets peut accroître mémoire et délai d'ouverture, à mesurer avant optimisation. (4) Les ombres de contact peuvent doubler le halo automatique actuel ; leurs propres entrées portent aussi la directive d'ombre séparée. (5) Une pile de couches trop rigide peut casser les croisements : la phase à profondeur reste commune aux objets verticaux. (6) Des pas très espacés peuvent perdre la lisibilité du trajet ; vérifier ensemble le graphe et la capture. (7) L'aperçu du pack suggère que certains accents floraux et accessoires intégrés aux variantes de platebande sont plus saillants que leur nom ; accepter les assets selon la capture réelle en scène, sans obligation d'utiliser chaque variante ou microdétail.

**Fichiers probablement touchés au fil des tickets.** `ART_BIBLE.md`, `CONTEXT.md` si le vocabulaire d'ambiance fixe doit être précisé, `docs/adr/0006-rendu-hybride-canvas-sprites.md`, `docs/geometrie-ilots.md`, `docs/sprite-pipeline.md`, `pubspec.yaml` uniquement si la politique de bundle change, `lib/garden/garden_game.dart`, `lib/garden/garden_sprites.dart`, `lib/garden/potager_composition.dart`, `lib/garden/potager_path.dart`, les nouveaux modules de description de scène, `assets/sprites/`, `assets/sprite_sources/`, `assets/sprite_exports/`, les scripts de validation d'assets, les tests de scène/chemin/contacts/capture et `docs/visual-review/`. Aucun changement de modèle ou de base métier n'est prévu.

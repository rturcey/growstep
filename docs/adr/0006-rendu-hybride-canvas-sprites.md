# Rendu hybride : Canvas pour le terrain, sprites modulaires pour les silhouettes

> **Partiellement supersedée pour la décision terrain/composition** : la décision de garder le terrain en Canvas est remplacée par la migration progressive vers les `surface_tile` décrite dans [ADR-0008](0008-tiled-composition-visuelle.md) (section « Migration du terrain ») et [ADR-0009](0009-surface-tile-classe-asset.md). La décision sur les sprites verticaux modulaires (cultures, arbres, éléments d'environnement) reste valable.
>
> Décision actualisée pour la composition du Potager, issue #47. La [bible graphique](../../ART_BIBLE.md) fixe l'apparence ; la [spécification de composition](../MAP_COMPOSITION_SPEC.md) fixe l'artboard et les couches.

Le terrain, sa tranche et ses variations de matière restent dessinés en Canvas dans le renderer Flame existant. Les plantes cultivées et les arbres conservent leurs sprites PNG. Les végétaux d'ambiance, les accessoires, les bordures ponctuelles, les platebandes et les pas de pierre peuvent également être des sprites RGBA modulaires lorsqu'une silhouette peinte apporte un gain visible. Le tracé, les transitions d'herbe et les effets de sol peuvent rester en Canvas. Le choix s'applique par famille, sans background monolithique ni changement de caméra, de projection 80 × 40 ou de moteur.

Le manifeste donne l'ancre interne du bitmap au contact visible du sol ; la composition donne la position de ce contact dans l'artboard. Le renderer fait coïncider ces deux points pour placer l'objet, son ombre et calculer sa profondeur. Une ombre séparée n'est dessinée qu'une fois, avant l'objet correspondant. Les formes Canvas de secours restent un squelette de développement quand un sprite manque ; elles ne décident pas la composition.

Cette décision autorise une migration progressive : un îlot peut mêler platebandes Canvas et platebandes sprites tant que ses index sauvegardés, ses cibles tactiles et sa scène complète restent valides. Le Potager est le premier périmètre de cette migration. Les autres îlots gardent leur rendu actuel jusqu'à leurs propres tickets.

## Historique de la décision initiale

Le texte ci-dessous décrit un état antérieur au Potager paysager de #41 et à l'audit de #47. Ses nombres de PNG et sa restriction des sprites aux seules cultures sont historiques ; ils ne décrivent pas le manifeste actuel. La décision actualisée ci-dessus prévaut.

Le terrain (herbe, terre, contour), les bacs, les chemins, les bordures végétales et les accessoires sont rendus par des formes Canvas natif avec gradients, facettes et ombres douces. Seules les plantes cultivées (légumes, fleurs) et les arbres sont rendus par des sprites PNG modulaires transparents, validés par le contrat #22. Le chien est supprimé du rendu.

Le dépôt compte 40 PNG : 24 de plantes ou d'arbres (dont un seul possède déjà une fiche YAML et une source ORA) et 16 de décor, pied d'arbre compris. La refonte archivera les 16 PNG de décor hors du bundle et les retirera du rendu ; elle normalisera les 23 végétaux hérités au master 4×, avec exports 2× et 3×, fiche et source ORA. Leurs points de contact dans la scène seront recalés sur le treillis entier ou demi-entier sans changer les index de sauvegarde. Les ombres de contact seront dessinées séparément du PNG, juste avant chaque objet dans l'ordre de profondeur. Les variantes brillantes garderont les sprites ordinaires et recevront un motif et de petits éclats Canvas propres à chaque espèce.

Le rendu Canvas seul a un plafond esthétique dur pour les silhouettes organiques : des `drawOval` empilés ne reproduisent pas la matière peinte de la référence. Le rendu 100 % sprites demande une source artistique pour chaque élément de décor, ce qui n'est pas réaliste pour le terrain. L'hybride utilise le Canvas là où il excelle (plans facettés, gradients de matière, texture procédurale) et les sprites là où ils sont indispensables (silhouettes d'espèces, fruits, fleurs). Les fallback shapes Canvas restent comme squelette de développement quand un sprite manque.

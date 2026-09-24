# Kit de matière du terrain

Le terrain est composé comme une petite carte, plutôt que comme une seule forme remplie :

1. le contour d'herbe et sa tranche de terre ;
2. une couche de tuiles de matière (`grain`, `blades`, `clover`, `highlight`) placées avec un léger décalage déterministe ;
3. les variations douces de couleur et de fibres ;
4. les objets de décor, les supports de culture et les plantes, triés par contact au sol.

Le premier kit est vectoriel et dessiné par Canvas dans `GardenGame`. Il établit le contrat de composition et permet de remplacer chaque variante par une case d'atlas PNG plus tard, sans changer la carte ni les index de sauvegarde. Les trois zones partagent ce vocabulaire, mais gardent leur contour et leurs accessoires propres. Les pierres sont volontairement absentes jusqu'à une itération dédiée du chemin.

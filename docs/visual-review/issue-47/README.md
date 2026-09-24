# Ticket #47 — audit et contrat de composition du Potager

Cet état de référence précède la migration déclarative. Aucune coordonnée, interaction, plante ni famille graphique n'est modifiée par le ticket. Les **captures** proviennent d'un export propre du commit `856d91c`, point Git de comparaison de #47 ; elles sont donc indépendantes des assets non committés. L'**inventaire du pack** décrit séparément le workspace fourni avec le chantier, où une migration d'assets végétaux préexistante n'est pas encore committée.

## Carte fonctionnelle et emprises

Le monde est un artboard de **390 × 450** points, centré dans le viewport Flame et rendu à l'échelle **1** sur les deux écrans de validation. La caméra reste fixe. La projection logique 2:1 utilise une case **80 × 40**, avec `O=(195,230)`, `u=(40,20)` et `v=(-40,20)` ; les contacts peuvent être sur demi-cases. Le terrain Potager a un contour de `x=24…376`, `y=68…410`, puis une tranche de terre de 24 points. La cible tactile est un carré **44 × 44** centré sur le contact de chaque emplacement acheté, indépendant des pixels transparents du sprite. L'ordre ci-dessous est aussi celui du tableau sauvegardé ; il n'est pas l'ordre de lecture des rangées.

| Index sauvegardé | Contact au sol | Cible dans l'artboard | Disponible au départ | Rangée visuelle |
| ---: | --- | --- | --- | --- |
| 0 | `(75,150)` | `x=53…97, y=128…172` | Oui, tomate | Arrière gauche |
| 1 | `(275,230)` | `x=253…297, y=208…252` | Oui, carotte | Milieu droit |
| 2 | `(75,310)` | `x=53…97, y=288…332` | Oui, vide pour guidage | Avant gauche |
| 3 | `(315,310)` | `x=293…337, y=288…332` | Oui, vide | Avant droit |
| 4 | `(195,150)` | `x=173…217, y=128…172` | Non | Arrière centre |
| 5 | `(115,230)` | `x=93…137, y=208…252` | Non | Milieu gauche |
| 6 | `(195,310)` | `x=173…217, y=288…332` | Non | Avant centre |
| 7 | `(315,150)` | `x=293…337, y=128…172` | Non | Arrière droit |

La platebande occupe au plus une case logique de dessus **80 × 40**. Seuls les emplacements achetés produisent un bac et répondent au tap ; les huit contacts possibles restent fixes. Le hit test soustrait la translation de centrage puis inverse l'échelle avant de comparer au carré de 44 points. Le renderer dessine le terrain et le chemin avant les objets verticaux, trie ces derniers par Y du contact au sol, et dessine les cibles de debug après eux. Les égalités de profondeur, catégories de taille et types d'objet ne sont pas encore formalisés.

## Zones à réserver dans la composition

| Zone actuelle | Contacts ou emprise constatés | Contrat de migration |
| --- | --- | --- |
| Culture | Huit cases et cibles ci-dessus. | Aucun élément fixe sur une cible ou devant une culture lisible. Index, sauvegarde et cible inchangés. |
| Circulation | Réseau explicite de cinq routes ; entrée `(195,410)`, axe vers `(195,190)`, trois branches et arc latéral. Douze pas Canvas. | Garder la connexion et l'entrée ; réserver l'herbe entre les futurs pas sprites. |
| Structure arrière | Treillis `(155,150)` ; bosquet gauche de huit arbustes `x=35…155`, `y=90…250` ; bosquet droit de quatre arbustes `x=255…355`, `y=80…190`. | Les contacts sont ceux du sol, pas le sommet des silhouettes. Préserver des ouvertures derrière les cultures. |
| Transition minérale | Deux groupes de rochers `(355,150)` et `(355,270)` ; franges basses `(75,390)`, `(95,400)`, `(295,400)`. | Pas de nouvelle frise régulière ; avant bas et tranche lisible. |
| Accessoires fixes | Tonneau `(355,230)`, arrosoir `(335,220)`, caisse `(95,360)`. | Ils ne sont ni des emplacements ni des décors achetables ; aucun hitbox. |
| Pelouse calme | Aucune zone calme n'est encodée comme emprise dans les données ; l'avant droit paraît plus ouvert dans les captures. | Délimiter explicitement une zone calme à l'itération de composition avant d'ajouter les détails. |

Le chemin actuel emploie deux traces colorées continues de 27 et 14 points sous les pierres. Les coordonnées sont réparties entre le renderer, les routes et la composition des masses ; le choix des sprites et des dimensions des décors est encore décidé dans le renderer. Le sol utilise un grain à graine fixe, distinct du placement artistique des objets. Ces constats définissent le travail des tickets suivants ; ils ne justifient pas un déplacement de gameplay dans #47.

## Inventaire et résolution des collisions d'assets

Le [CSV exhaustif](asset_inventory.csv) compare **chaque ID du manifeste de travail** au manifest et au PNG du commit `856d91c`. Il donne SHA-256, dimensions, bbox déclarée, bbox mesurée au seuil alpha du pipeline (`>32`), ancre, directive d'ombre, état par rapport au commit de référence et présence identique dans l'archive `assets/sprite.zip`. Les 31 PNG de cette archive sont octet pour octet identiques aux 31 mêmes IDs du dossier de travail. L'archive est le socle canonique du pack ; les 40 autres PNG du dossier constituent l'ajout d'environnement.

| Comparaison avec `856d91c` | IDs | Décision pour #47 |
| --- | ---: | --- |
| Identiques, PNG **et** métadonnées | 8 | Réutiliser sans copie ni nouvel ID. |
| Existants mais différents | 23 | Ce sont uniquement les plantes et arbres de la migration préexistante. **La version fournie dans l'archive, identique au dossier de travail, est la version canonique à conserver lors de l'intégration du pack** ; les anciens PNG du commit restent la référence de comparaison. Ne pas les écraser, retoucher ni les faire entrer dans le commit #47 : leur adoption dans Git relève de la migration séparée déjà engagée. |
| Nouveaux | 40 | Aucun conflit de nom avec `856d91c`. Conserver ORA/PNG comme candidats du pack ; intégrer par famille seulement après correction de leur contrat de métadonnées et revue en scène. |

Seize anciens IDs de décor du commit sont absents du manifeste de travail et sont en cours d'archivage dans le workspace. Aucun de ces 16 IDs n'est réutilisé pour un nouveau sprite. Le ticket #47 ne valide pas cette suppression et ne l'inclut pas dans son commit.

**Contrôle du contrat.** Le validateur actuel retourne **117 diagnostics sur 39 assets**, tous issus du pack nouveau : 27 emprises de grille invalides, 26 classes de taille inconnues, 17 ancres hors contact visible, 17 incohérences entre suffixe d'ID et fiche, 17 bbox de manifeste différentes des pixels visibles au seuil `>32`, 11 rôles de palette inconnus et 2 dépassements de classe. Les 17 bbox concernent précisément quatre platebandes, six pas individuels, trois chemins préassemblés et quatre ombres. Les quatre sprites d'ombre portent eux-mêmes `separate_contact` dans le manifeste : le renderer leur ajouterait une deuxième ombre s'ils étaient employés tels quels. **Aucun asset de ces familles ne doit être rendu par les tickets suivants avant mise en conformité ou correction explicite du contrat partagé.** Les corrections d'asset appartiennent aux tickets de famille, sans variation de tomate, carotte ou courgette.

**Inspection des ombres peintes.** Les six pas japonais montrent déjà un léger halo sombre au bas de leur silhouette, visible sur les PNG isolés et dans l'aperçu du pack : une ombre supplémentaire doit d'abord être éprouvée en scène. Le bac `00` présente surtout une face avant sombre, sans ombre projetée extérieure évidente ; le bosquet bas `01`, les rochers `00` et le groupe « coin jardinage » ont une base assombrie, sans halo au sol aussi distinct que celui des pierres. Cette lecture visuelle est une décision d'audit, pas une consigne d'ajouter une ombre à toute la famille. Les tickets de placement vérifieront chaque variante retenue à taille réelle avant d'activer une ombre séparée.

Le chargement actuel parcourt toutes les entrées du manifeste au démarrage, même celles qu'aucune scène n'utilise encore, et demande un décodage à largeur 512 pixels. L'augmentation de 31 à 71 entrées peut donc coûter en mémoire et en délai avant toute nouvelle composition ; mesurer avant optimisation, puis traiter ce point dans le ticket final.

## Captures de référence

Les six captures de l'application complète ci-dessous, produites depuis un **export propre de `856d91c`**, montrent l'état déterministe avec **4, 6 et 8 emplacements achetés** ; chaque vue existe aussi en niveaux de gris. Les dimensions des PNG ont été contrôlées. Les états 6 et 8 remplissent les emplacements de cultures mûres pour éprouver la saturation ; les plantes de départ sont conservées dans l'état 4.

| Emplacements | 390 × 844 | 375 × 667 |
| --- | --- | --- |
| 4 | [Couleur](application_potager_initial_390x844.png) · [Gris](application_potager_initial_390x844_gris.png) | [Couleur](application_potager_initial_375x667.png) · [Gris](application_potager_initial_375x667_gris.png) |
| 6 | [Couleur](application_potager_intermediaire_390x844.png) · [Gris](application_potager_intermediaire_390x844_gris.png) | [Couleur](application_potager_intermediaire_375x667.png) · [Gris](application_potager_intermediaire_375x667_gris.png) |
| 8 | [Couleur](application_potager_sature_390x844.png) · [Gris](application_potager_sature_390x844_gris.png) | [Couleur](application_potager_sature_375x667.png) · [Gris](application_potager_sature_375x667_gris.png) |

**Inspection.** Les deux formats cadrent entièrement le terrain et conservent la tranche avant. Les cultures restent dominantes en couleur et en gris. La structure 3 / 2 / 3 des bacs redevient immédiatement perceptible à huit emplacements ; le chemin apparaît comme un tracé vert continu avec des pierres posées dessus. Le Potager de quatre emplacements paraît plus ouvert, mais les zones calmes ne sont pas encore nommées dans les données. Le bord arrière est déjà formé par des masses ; les futurs tickets devront conserver leurs ouvertures et éviter d'ajouter de petits éléments partout. Aucun de ces points n'est corrigé dans l'audit #47.

### Reproduction

Dans une copie propre du commit `856d91c`, disposer du runner Linux (le générer avec `flutter create --platforms=linux .` s'il est absent), puis lancer pour chacun des états `initial`, `intermediaire`, `sature` :

```sh
flutter build linux --debug -t lib/potager_visual_fixture.dart --dart-define=GROWSTEP_POTAGER_STATE=<état>
GROWSTEP_CAPTURE_DIR=docs/visual-review/issue-47 xvfb-run -a -s '-screen 0 390x844x24' python3 scripts/capture_potager_visuals.py <état> 390 844
GROWSTEP_CAPTURE_DIR=docs/visual-review/issue-47 xvfb-run -a -s '-screen 0 375x667x24' python3 scripts/capture_potager_visuals.py <état> 375 667
```

Les captures ont été produites avec le manifeste SHA-256 `e6c7be62f990b7f8e88453449de371a30159304c7621a571bd45162a5bafead6`, le renderer SHA-256 `97eba0fb0adaf2e677f49dd238178cba607eeeaff839b060005905e5ed17b1e1` et la fixture SHA-256 `2efb31e6b27da40c9e4467898bc4c4e1a92a8df8c23afc3151ff01da7c43cc50`, tous suivis dans `856d91c`. La fixture et le script de capture existaient déjà dans ce commit. Les 40 sprites entrants restent des fichiers de travail fournis avec le chantier et ne sont pas intégrés par #47 ; le CSV fige leurs caractéristiques pour les prochains tickets, mais les captures de référence ne dépendent pas d'eux.

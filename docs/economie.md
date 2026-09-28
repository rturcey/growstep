# Économie Growstep — Proposition finale (v3, après re-grilling + vérifications)

> Document de référence de l'économie du jeu, issu du grilling, du re-grilling et de
> vérifications mathématiques. Les valeurs marquées **valeurs de test** seront confirmées
> par playtest ; les **formules et invariants** font autorité. L'implémentation ne doit
> pas être modifiée tant que cette économie n'est pas validée.

## Décisions verrouillées (journal)

1. **Récolte = suppression + replantation**, avec ≥ 1 graine de même espèce garantie à chaque récolte.
2. **Espèce découverte ≠ graine** : l'**espèce découverte** est permanente (jamais reperdue, c'est la collection) ; la **graine** est un **consommable** nécessaire pour planter, rendue à la récolte ou à la suppression prématurée. **Les graines bonus aléatoires sont supprimées** ; **les copies supplémentaires d'une espèce s'achètent en florins** (sink).
3. **Le marché est le seul générateur de florins** ; aucune conversion directe pas → florins.
4. **Marché = vente automatique à la récolte**, avec courbe de prix par espèce (quota à plein tarif, surplus à tarif réduit). Pas d'inventaire de produits, pas de stockage.
5. **Lots quotidiens 100 % non-florins** (graines, engrais, décors, chance brillante). Un seul robinet de florins : le marché.
6. **Terrain = canevas posé par le joueur** : pas d'évolution automatique. Expansions (surface, esthétique), emplacements (production), décors (personnalisation) achetés en florins.
7. **Placement sur grille**, liberté totale de choix quoi/où, réorganisation sans frais (ADR-0008).
8. **Invariant terrain** : l'expansion visuelle ne modifie jamais la capacité productive ; seuls les emplacements agricoles achetés le font.
9. **Échelle de prix montante** : facile en début, sommet multi-semaines ; gros achats mesurés en jours/semaines de revenu marché ; catalogue alimenté par le contenu ; abondance tardive = victoire.
10. **Rendements décroissants (soft cap) par espèce** : quota quotidien à plein tarif, surplus à tarif réduit (30 %). **Le revenu total n'est pas borné** : au-delà du quota, chaque vente supplémentaire rapporte 30 % — c'est un **rendement marginal réduit/contrôlé**, pas un plafond dur. Chaque pas conserve une valeur ; le spam n'explose jamais.
11. **Frontière monétaire** : aucun achat en euros n'existe dans la v3. Les florins sont gagnés exclusivement par la marche (vente des récoltes au marché). Le jeu est 100 % gratuit, aucune partie n'est paywalled.
12. **Format commercial** : aucun achat en euros dans la v3. La monétisation est reportée à une décision ultérieure, sous l'invariant « aucun euro n'augmente la capacité productive ». Le jeu est entièrement gratuit.
13. **Engrais = accélération pure**, achetable + gagnable, **ROI en florins mathématiquement négatif** (prix 25/45/70, tous strictement supérieurs au gain marginal maximal de 21 florins).
14. **La rareté est intrinsèque à l'espèce** ; modèle produit `Y × P` par récolte ; **anti-méta avec ±5-10 % de variance assumée**.
15. **Arbres = production persistante** (exception au modèle récolte/suppression).
16. **Brillantes ciblées par cadence** : ~1 découverte toutes les 1-3 semaines pour un joueur actif ; **1 par espèce** ; retour garanti à la récolte ; pity invisible ; jamais achetables.
17. **Boutique de graines = « graine supplémentaire d'une espèce découverte » uniquement** ; les nouvelles espèces/raretés arrivent par les lots et paliers cumulés (la découverte est une récompense).

## 1. Boucles économiques

**Boucle minute/session** : j'ouvre le jeu → je récolte les plantes prêtes (clic) → je reçois produits (auto-vendus au marché) + ma graine garantie → je replante → j'applique éventuellement un engrais → je vois mes florins grimper et le marché afficher sa courbe de prix du jour.

**Boucle journée** : je marche → tous mes emplacements poussent → je récolte (les premières ventes de chaque espèce se font à plein tarif, le surplus à tarif réduit) → les paliers 1k/3k/6k/10k créditent mes lots (graines/engrais/décors/chance brillante, jamais de florins) → je dépense mes florins (emplacement, décor, graine supplémentaire, engrais).

**Boucle semaine** : je vise un gros achat (îlot, expansion) → j'épargne plusieurs jours → je l'achète → le jardin grandit/change visiblement.

**Boucle mois/endgame** : j'enrichis le catalogue (décors/expansions), je poursuis la collection (brillantes = quête non plafonnée, ~1 découverte/1-3 semaines), le catalogue s'enrichit avec le contenu (le contenu EST le sink long-terme) ; l'abondance tardive de florins = victoire (jardin construit) et le sink engrais → brillantes absorbe les excédents.

## 2. Sources et sinks

| Ressource | Source | Sink | Rôle | Rareté voulue | Plafond |
|---|---|---|---|---|---|
| **Pas** | marche réelle | croissance, paliers, paliers cumulés | seule entrée de tout | — | cumulés sans fin |
| **Produits** | récolte | vente automatique au marché | conversion jardin → florins | selon espèce | rendement marginal réduit par espèce |
| **Florins** | **marché uniquement** | emplacements, îlots, expansions, décors, graines supplémentaires, engrais | construction | medium | rendement marginal réduit par espèce |
| **Espèces découvertes** | lots, paliers cumulés, récoltes | collection (jamais reperdue) | collection permanente | — | catalogue fixe |
| **Graines (consommables)** | récolte (garantie), lots, boutique | plantation, **copies supplémentaires** | conserver/amplifier une espèce | commune abondante, rare rare | inventaire libre |
| **Engrais** | pauses, lots, boutique | consommation (accélération) | commodité + mini-sink | bas | 1 actif/plante |
| **Décors** | boutique + lots | placement | personnalisation (cœur long-terme) | catalogue | — |
| **Brillantes** | récolte (0,3 %), lots, paliers | collection (1 par espèce) | endgame soft | très rare | 1/espèce |

## 3. Cultures — formules et valeurs de test

**Maître-formule du marché (soft cap)** :

```
Revenu/jour ≈ Σ espèces [ min(ventes_s, quota_s) × prix_s + max(0, ventes_s − quota_s) × 30 % × prix_s ]

avec  ventes_s = nbPlantes_s × pas/jour ÷ T_s
      quota_s = nb de ventes à plein tarif par jour
```

La vente est **automatique à la récolte** : les `quota_s` premières récoltes de l'espèce se vendent à plein tarif, le surplus à 30 %. **Ce n'est pas un plafond dur** : chaque vente au-delà du quota rapporte 30 % — rendement marginal réduit/contrôlé, jamais un mur.

| Espèce | Rareté | T (maturité) | Prix/récolte | Quota/jour (plein tarif) | Surplus | Budget max/jour (typique) |
|---|---|---|---|---|---|---|
| tomate, carotte, courgette, tournesol, tulipe, lavande | commune | 1 000 | 5 | 8 | 30 % | ~40 plein + surplus |
| *(futures)* | peu commune | 2 500 | 10 | 3 | 30 % | ~30 + surplus |
| *(futures)* | rare | 6 000 | 21 | 1 | 30 % | ~21 + surplus |
| pommier, poirier (arbres persistants) | commune | 2 000 (maturité) / fruit 1 000 | 5 | 3 | 30 % | ~15 + surplus |
| brillante (variante, 1/espèce) | — | 15 000 | = espèce de base | partagée avec l'espèce | — | collection, pas revenu |

Règles :

- **Rareté intrinsèque à l'espèce** (répare l'incohérence actuelle où une graine « rare » plante une plante commune).
- **Modèle produit `Y × P`** : chaque récolte donne des produits d'espèce (ex. 5 tomates × 1 = 5 florins), auto-vendus.
- **Graine garantie** à chaque récolte (même espèce) : conservation parfaite, une variété ne se perd jamais. **Pas de graines bonus aléatoires** (la génération infinie de graines est supprimée).
- **Copies supplémentaires = sink de florins** : pour avoir une 2ᵉ, 3ᵉ… plante d'une espèce, on achète une **« graine supplémentaire d'une espèce découverte »** (prix de test : commune 20, peu commune 40, rare 80, arbre 20). Une copie ne rapporte que du surplus (30 %) et fait perdre un emplacement qui aurait pu porter une nouvelle espèce à plein tarif → **la diversité bat toujours les copies** ; acheter des copies n'est jamais une stratégie de revenu dominante, c'est un choix de confort/esthétique/collection.
- **Supprimer une plante prématurément rend sa graine** (jamais de perte).
- **Anti-méta avec variance assumée** : aucune rareté ne domine le budget journalier de façon significative ; une différence de ±5-10 % est volontaire pour laisser émerger des styles.
- **Arbres persistants** : plantés, ils atteignent leur taille (2 000 pas), puis produisent des fruits périodiquement sans être retirés.

### Brillantes (probabilités ciblées par cadence)

Objectif : **~1 nouvelle découverte toutes les 1-3 semaines** pour un joueur actif (≈15 récoltes/jour, palier 10k atteint), au moins en début de partie.

| Source | Valeur de test |
|---|---|
| Récolte d'une plante ordinaire | **0,3 %** par récolte, espèce de la plante, **uniquement si sa brillante n'est pas encore découverte** |
| Palier quotidien 10k | ~3 % (espèce non découverte) |
| Paliers de pas cumulés | garanties ponctuelles de graines brillantes |
| **Pity invisible** | après ~25 jours sans brillante, la chance est multipliée (~×3) jusqu'à obtention |
| **Récolte d'une brillante** | produits normaux + **1 graine brillante de la même espèce garantie** + petite chance d'une seconde |

Conséquences : une brillante découverte est **auto-suffisante et permanente** (on ne détruit jamais son objet rare) ; la rareté porte sur la **découverte**, pas sur le maintien ; collection complète ≈ 3-4 mois. Les brillantes ne sont jamais vendues ni achetables.

## 4. Florins

- **Production** : voir la simulation (§ 9). Ordre de grandeur (jardin diversifié) : 2 000 pas ≈ 260/jour ; 5 000 ≈ 384 ; 8 000 ≈ 501 ; 12 000 ≈ 657 ; 20 000 ≈ 969. Rendements décroissants : chaque pas conserve une valeur, aucun n'est inutile.
- **Sinks** : îlots 100/250 ; emplacements 30 → 75 ; expansions 150 → 8 000 ; décors 8 → 50 (+ tiers) ; **graines supplémentaires d'espèces découvertes** (20/40/80) ; engrais 25/45/70.
- **Prix relatifs (jours de revenu d'un jardin adapté)** : petit décor < 1 j ; emplacement ~1 j ; îlot 1-3 j ; expansion 500 ~3-5 j ; expansion 2 500 ~2-3 semaines ; sommet du catalogue ~1-2 mois ; catalogue de base ~3-6 mois selon profil.
- **Prévention de l'inflation** : rendements décroissants par espèce (le revenu total suit les pas à rendement marginal réduit, sans explosion) ; les lots ne donnent jamais de florins ; l'expansion visuelle n'ajoute aucune production ; la diversité bat les copies.
- **Stock moyen souhaitable** : 0-3 jours de revenu en caisse (objectifs visibles) ; au-delà, épargne pour un gros achat ; en endgame, le sink engrais → brillantes absorbe les excédents.

## 5. Terrain

- **Terrain visible** : le canevas isométrique (2D), beau dès le départ.
- **Terrain constructible** : s'étend par **expansions de surface achetées en florins** (purement esthétiques).
- **Emplacements agricoles** : achetés séparément (8/8/3), **seuls à augmenter la capacité productive** (et à rendement marginal réduit via le soft cap).
- **Invariant** : expansion visuelle ≠ capacité productive.

## 6. Récompenses quotidiennes

- **Paliers 1k/3k/6k/10k** → lots **non-florins** : graines (espèces non découvertes de préférence), engrais, décors, ~3 % de brillante (espèce non découverte) au palier 10k. Auto-crédités.
- **Paliers de pas cumulés** (10k/50k/100k/250k/500k) → récompenses cosmétiques/collection (décor spécial, graine rare, graine brillante garantie ponctuelle).
- **Jamais de florins dans les lots** → ne cannibalisent pas le marché.

## 7. Engrais

Rôle : **accélération pure** (×1,25 / ×1,5 / ×2), surtout précieux sur les cultures longues (rare/brillante) et pour « finir aujourd'hui ». Sources : pauses (300 pas/10 min → basique, max 3/j), lots quotidiens, boutique. Sink mineur ; en endgame, pont **florins → collection** (accélérer les brillantes).

**Vérification mathématique du ROI (toutes raretés × tous états du soft cap)** :

Une application d'engrais accélère **un seul cycle d'une seule plante**. Le nombre maximal de récoltes supplémentaires qu'elle peut permettre en une journée est **1** (la différence de pas économisés est < T). Le gain marginal maximal est donc **1 récolte × prix effectif**, selon l'état du soft cap :

| Espèce | Sous quota (plein) | Sur quota (30 %) | Max marginal |
|---|---|---|---|
| Commune | 5 | 1,5 | 5 |
| Peu commune | 10 | 3,0 | 10 |
| Rare | 21 | 6,3 | **21** |
| Arbre | 5 | 1,5 | 5 |

Le maximum global est **21 florins** (rare sous quota). Pour que l'invariant tienne, **tous les prix d'engrais doivent être strictement supérieurs à 21** :

| Engrais | Ancien prix (violé) | Nouveau prix | Delta vs 21 |
|---|---|---|---|
| Basique ×1,25 | 10 (ROI +11) | **25** | +4 ✓ |
| Super ×1,5 | 20 (ROI +1) | **45** | +24 ✓ |
| Méga ×2 | 40 | **70** | +49 ✓ |

> **Invariant vérifié mathématiquement : un engrais acheté en florins n'a jamais une espérance de rendement en florins supérieure à son prix.** Un engrais acheté sert à « voir pousser plus vite », jamais à « investir pour farmer davantage » (l'engrais gagné en marchant reste gratuit).

## 8. Monétisation

- **Point de départ : boutique cosmétique à la carte** (décors, packs thématiques, palettes de terrain) + **vitrine** (partage d'image, événements) comme prérequis de conversion.
- **Format commercial ouvert aux tests** : packs premium one-time, DLC cosmétiques saisonniers, abonnement esthétique — sous l'invariant : **aucun euro n'augmente la capacité productive**. Le format qui convertit ne se connaîtra qu'avec de vrais utilisateurs.
- **Frontière** : l'euro n'achète **jamais** pas, florins, emplacements, expansions, engrais, graines à avantage, brillantes, lots. **Aucun contenu fonctionnel exclusif.**
- **Joueur gratuit** : 19 emplacements, toutes espèces, toutes graines (garanties), engrais gagnables, catalogue de base (décors + expansions), brillantes, tout le gameplay.
- **Joueur payant** : uniquement le cosmétique exclusif. Aucun avantage de progression.

## 9. Simulations

*Modèle v3 : récolte = suppression + replantage, soft cap par espèce (quota plein / surplus 30 %), vente automatique, 1 plante/espèce offerte puis copies payantes (20), engrais non acheté pour le revenu (ROI négatif), 2 sessions/jour, catalogue de base ≈ 30 000 florins.*

| Marcheur | Sem. 1 | Mois 1 | Mois 3 | Mois 6 | Mois 12 | Jard. fleuri (j) | Verger (j) |
|---|---|---|---|---|---|---|---|
| 2 000 | 210 | 1 590 | 12 080 | 24 700 | 60 205 | 17 | 30 |
| 5 000 | 729 | 7 642 | 26 632 | 54 700 | 113 672 | 5 | 10 |
| 8 000 | 1 809 | 10 848 | 34 428 | 68 500 | 142 503 | 1 | 6 |
| 12 000 | 2 277 | 13 662 | 43 362 | 86 400 | 179 487 | 1 | 2 |
| 20 000 | 3 297 | 19 374 | 61 314 | 121 000 | 253 539 | 1 | 2 |

*(Mois 6 interpolé du modèle ; les autres valeurs sont issues de la simulation.)*

### Nouvelles cassures introduites par cette révision (v2 → v3)

1. **Ralentissement du début de partie pour le marcheur léger** : le jardin fleuri passe de J11 → **J17**, le verger de J20 → **J30**, et la semaine 1 ne rapporte plus que 210 (vs 300). Cause : avec les graines bonus supprimées et les copies payantes, le joueur léger a moins de plantes → revenu plus faible. **À atténuer** : garantir assez de plantes de départ (2 plantes offertes + première plantation guidée + une graine offerte par zone), éventuellement une petite avance de florins.
2. **Sink « copies » faible pour les gros marcheurs** : 11 copies ≈ 220 florins, négligeable face à ~250k de revenu annuel. Ce n'est pas une fuite économique : c'est un **portail de diversité**, pas un drain. Les vrais sinks restent îlots/emplacements/catalogue.
3. **Le marcheur 5k touche ~0 florins en caisse au mois 3** (catalogue acheté) avant de ré-accumuler. Pas une rupture, mais à surveiller au playtest (sensation de « tout dépensé »).
4. **Prix d'engrais relevés (25/45/70)** : sans impact sur le revenu (ROI négatif → personne ne les achète pour farmer), mais à valider au playtest : le basique acheté doit rester un plaisir abordable (les engrais gagnés en marchant restent la source principale).

**Non-régression confirmée** : la différenciation des profils tient (mois 12 : 60k → 253k, ratio ~4,2×) ; plus de convergence 8k≈12k≈20k ; le catalogue de base tient ~6 mois pour le 2k, ~3 mois pour les 5k+ ; pas d'explosion du spam.

## 10. Invariants économiques (à ne jamais violer)

1. **Le marché est le seul générateur de florins** ; les lots et paliers cumulés ne donnent jamais de florins.
2. **Une espèce découverte ne peut jamais être perdue** ; une graine consommée est toujours rendue à la récolte (ou à la suppression prématurée).
3. **Aucune génération infinie de graines bonus** : les copies supplémentaires d'une espèce passent par l'achat en florins (sink), jamais par des graines gratuites illimitées.
4. **Le revenu d'une espèce suit une courbe de rendement marginal réduit** (quota plein + surplus à 30 %) : aucune culture ne devient un robinet infini, et **aucun pas ne devient économiquement inutile** (pas de mur dur).
5. **L'expansion visuelle du terrain ne modifie jamais la capacité productive** ; seuls les emplacements agricoles achetés le font.
6. **Aucune rareté ne domine le budget journalier de façon significative** (anti-méta, ±5-10 % de variance assumée) ; **la diversité bat toujours les copies supplémentaires**.
7. **L'argent réel n'achète que le cosmétique et la QoL** ; jamais pas, florins, croissance, brillantes, ni contenu fonctionnel exclusif ; **aucun euro n'augmente la capacité productive** (quel que soit le format commercial).
8. **Aucune récompense déjà accordée n'est jamais retirée** (y compris après correction des pas) — ADR-0001.
9. **Aucune pénalité d'absence** : vente automatique, pas de taxe, pas d'entretien, pas de péremption.
10. **Les prix en florins s'expriment en jours de revenu marché** d'un jardin adapté (lisibilité), pas en valeurs absolues arbitraires.
11. **Une récolte ne vaut que des pas réels** : rien ne peut pousser ou être récolté sans pas du joueur.
12. **Un engrais acheté en florins n'a jamais une espérance de rendement en florins supérieure à son prix** — vérifié mathématiquement : gain marginal max = 21 (rare sous quota) < prix minimal 25.
13. **Une brillante récoltée rend toujours une graine brillante de la même espèce** (on ne détruit jamais son objet rare) ; les brillantes restent 1 par espèce et jamais achetables.

## Documentation à prévoir (après validation)

- **`docs/game-design.md`** — réécriture : modèle récolte (suppression + replantation), espèce découverte ≠ graine consommable, marché unique avec rendements décroissants, suppression marche → florins / quota, lots non-florins, brillantes à cadence, arbres persistants, suppression des paliers d'embellissement, monétisation boutique.
- **`CONTEXT.md`** — « Plante mature », « Cycle de production », « Récolte », « Quota quotidien de florins », « Palier d'embellissement » à réviser/supprimer ; ajouts : « Espèce découverte », « Graine », « Marché », « Courbe de prix du marché », « Expansion de surface ».
- **Contradictions ADR** : ADR-0002 (quota remplacé par rendements décroissants), ADR-0003 (florins achetables + abonnement + aucun contenu exclusif → entièrement contredit), ADR-0005 (raisonnement partiellement obsolète), issues #1/#15/#17/#19/#20 (modèle persistant + quota + abonnement).
- **Nouveaux ADR** : récolte = suppression + replantation avec graine garantie ; espèce découverte ≠ graine consommable (copies = sink) ; le marché comme seul générateur de florins avec rendements décroissants ; rareté intrinsèque à l'espèce ; arbres persistants ; brillantes ciblées par cadence (retour garanti) ; frontière monétaire (révise ADR-0003) ; terrain = canevas posé par le joueur.

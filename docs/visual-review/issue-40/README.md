# Potager — revue du chemin (#40)

Captures de l'application complète à l'échelle 1:1, après chargement des sprites,
avec un potager initial et un potager aux huit parcelles plantées. Chaque état
est montré à 390 × 844 et 375 × 667 points, en couleur et en niveaux de gris.

| État | 390 × 844 | 375 × 667 |
| --- | --- | --- |
| Initial | [Couleur](application_potager_initial_390x844.png) · [Gris](application_potager_initial_390x844_gris.png) | [Couleur](application_potager_initial_375x667.png) · [Gris](application_potager_initial_375x667_gris.png) |
| Saturé | [Couleur](application_potager_sature_390x844.png) · [Gris](application_potager_sature_390x844_gris.png) | [Couleur](application_potager_sature_375x667.png) · [Gris](application_potager_sature_375x667_gris.png) |

Les captures montrent l'entrée au bord avant, la division du chemin vers les
platebandes, les intervalles d'herbe entre les pierres et l'absence de coupure
du terrain. `test/potager_path_test.dart` vérifie les huit approches, le treillis,
les cibles tactiles et la présence visuelle du chemin ;
`test/potager_path_slots_test.dart` vérifie la sélection des huit index
dans l'application aux deux tailles.

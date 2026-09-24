import 'dart:ui';

import 'garden_scene.dart';

/// The Potager's hand-authored walking routes and individual stepping stones.
///
/// Route points describe the connected circulation; stones are placed on that
/// network with visible grass between them. Coordinates are artboard contacts.
class PotagerPath {
  PotagerPath._();

  static const _spine = <Offset>[
    Offset(195, 410),
    Offset(195, 370),
    Offset(155, 350),
    Offset(135, 320),
    Offset(155, 290),
    Offset(175, 260),
    Offset(195, 230),
    Offset(195, 190),
  ];

  static const _frontRightBranch = <Offset>[
    Offset(195, 230),
    Offset(215, 260),
    Offset(235, 270),
    Offset(275, 290),
  ];

  static const _middleLeftBranch = <Offset>[Offset(155, 290), Offset(115, 270)];

  static const _middleRightBranch = <Offset>[
    Offset(195, 230),
    Offset(235, 210),
  ];

  static const routes = <List<Offset>>[
    _spine,
    _frontRightBranch,
    _middleLeftBranch,
    _middleRightBranch,
  ];

  // Main stones use 1.2x the visible 1x bounds (PNG source is 4x). Narrow
  // approaches use 1x or 0.8x to keep the painted stone off touch targets.
  static const _stone00 = Size(38.7, 26.4);
  static const _stone01 = Size(39, 27);
  static const _stone02 = Size(42, 27.3);
  static const _stone03 = Size(39.9, 27);
  static const _stone04 = Size(39, 25.2);
  static const _stone05 = Size(38.7, 25.5);
  static const _mediumStone03 = Size(33.25, 22.5);
  static const _smallStone00 = Size(25.8, 17.6);

  static const stones = <GardenSpriteObject>[
    GardenSpriteObject(
      id: 'path_entrance',
      asset: 'commun_sol_pas_pierre_statique_ordinaire_02.png',
      contact: Offset(195, 410),
      size: _stone02,
      layer: GardenLayer.path,
    ),
    GardenSpriteObject(
      id: 'path_lower_spine',
      asset: 'commun_sol_pas_pierre_statique_ordinaire_05.png',
      contact: Offset(195, 370),
      size: _stone05,
      layer: GardenLayer.path,
    ),
    GardenSpriteObject(
      id: 'path_left_turn',
      asset: 'commun_sol_pas_pierre_statique_ordinaire_00.png',
      contact: Offset(155, 350),
      size: _stone00,
      layer: GardenLayer.path,
    ),
    GardenSpriteObject(
      id: 'path_middle_left',
      asset: 'commun_sol_pas_pierre_statique_ordinaire_03.png',
      contact: Offset(135, 320),
      size: _stone03,
      layer: GardenLayer.path,
    ),
    GardenSpriteObject(
      id: 'path_upper_left',
      asset: 'commun_sol_pas_pierre_statique_ordinaire_04.png',
      contact: Offset(155, 290),
      size: _stone04,
      layer: GardenLayer.path,
    ),
    GardenSpriteObject(
      id: 'path_middle_left_spur',
      asset: 'commun_sol_pas_pierre_statique_ordinaire_00.png',
      contact: Offset(115, 270),
      size: _smallStone00,
      layer: GardenLayer.path,
    ),
    GardenSpriteObject(
      id: 'path_upper_turn',
      asset: 'commun_sol_pas_pierre_statique_ordinaire_02.png',
      contact: Offset(175, 260),
      size: _stone02,
      layer: GardenLayer.path,
    ),
    GardenSpriteObject(
      id: 'path_north_junction',
      asset: 'commun_sol_pas_pierre_statique_ordinaire_01.png',
      contact: Offset(195, 230),
      size: _stone01,
      layer: GardenLayer.path,
    ),
    GardenSpriteObject(
      id: 'path_north_end',
      asset: 'commun_sol_pas_pierre_statique_ordinaire_00.png',
      contact: Offset(195, 190),
      size: _smallStone00,
      layer: GardenLayer.path,
    ),
    GardenSpriteObject(
      id: 'path_right_upper',
      asset: 'commun_sol_pas_pierre_statique_ordinaire_03.png',
      contact: Offset(235, 210),
      size: _mediumStone03,
      layer: GardenLayer.path,
    ),
    GardenSpriteObject(
      id: 'path_right_middle',
      asset: 'commun_sol_pas_pierre_statique_ordinaire_05.png',
      contact: Offset(235, 270),
      size: _stone05,
      layer: GardenLayer.path,
    ),
    GardenSpriteObject(
      id: 'path_right_end',
      asset: 'commun_sol_pas_pierre_statique_ordinaire_04.png',
      contact: Offset(275, 290),
      size: _stone04,
      layer: GardenLayer.path,
    ),
  ];
}

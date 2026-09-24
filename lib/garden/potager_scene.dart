import 'dart:ui';

import 'garden_scene.dart';

/// First two migrated objects. Their exact display sizes preserve the current
/// scene; later family tickets can introduce shared size classes and variants.
class PotagerPilotScene {
  const PotagerPilotScene._();

  static const rock = GardenSpriteObject(
    id: 'east_upper_rock',
    asset: 'commun_decor_rochers_herbe_statique_ordinaire_00.png',
    contact: Offset(355, 150),
    size: Size(41.4, 23),
    layer: GardenLayer.depth,
    opacity: 0.82,
  );

  static const barrel = GardenSpriteObject(
    id: 'east_barrel',
    asset: 'commun_decor_tonneau_bois_statique_ordinaire_00.png',
    contact: Offset(355, 230),
    size: Size(32, 35),
    layer: GardenLayer.depth,
    opacity: 0.88,
  );

  static const objects = <GardenSpriteObject>[rock, barrel];
}

/// The eight potager planting slots rendered as declarative sprite objects.
/// Each index references one of the four hand-authored platebande variants;
/// no variant is chosen by calculation, random, or plant state.
class PotagerBeds {
  const PotagerBeds._();

  static const _bedWidth = 52.25;

  static const _v00 = 'potager_decor_bac_potager_statique_ordinaire_00.png';
  static const _v01 = 'potager_decor_bac_potager_statique_ordinaire_01.png';
  static const _v02 = 'potager_decor_bac_potager_statique_ordinaire_02.png';
  static const _v03 = 'potager_decor_bac_potager_statique_ordinaire_03.png';

  static const beds = <GardenSpriteObject>[
    GardenSpriteObject(
      id: 'bed_0',
      asset: _v00,
      contact: Offset(75, 150),
      size: Size(_bedWidth, 40.5),
      layer: GardenLayer.depth,
    ),
    GardenSpriteObject(
      id: 'bed_1',
      asset: _v01,
      contact: Offset(275, 230),
      size: Size(_bedWidth, 46.75),
      layer: GardenLayer.depth,
    ),
    GardenSpriteObject(
      id: 'bed_2',
      asset: _v02,
      contact: Offset(75, 310),
      size: Size(_bedWidth, 48.0),
      layer: GardenLayer.depth,
    ),
    GardenSpriteObject(
      id: 'bed_3',
      asset: _v03,
      contact: Offset(315, 310),
      size: Size(_bedWidth, 45.5),
      layer: GardenLayer.depth,
    ),
    GardenSpriteObject(
      id: 'bed_4',
      asset: _v01,
      contact: Offset(195, 150),
      size: Size(_bedWidth, 46.75),
      layer: GardenLayer.depth,
    ),
    GardenSpriteObject(
      id: 'bed_5',
      asset: _v03,
      contact: Offset(115, 230),
      size: Size(_bedWidth, 45.5),
      layer: GardenLayer.depth,
    ),
    GardenSpriteObject(
      id: 'bed_6',
      asset: _v00,
      contact: Offset(195, 310),
      size: Size(_bedWidth, 40.5),
      layer: GardenLayer.depth,
    ),
    GardenSpriteObject(
      id: 'bed_7',
      asset: _v02,
      contact: Offset(315, 150),
      size: Size(_bedWidth, 48.0),
      layer: GardenLayer.depth,
    ),
  ];
}

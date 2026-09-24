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
/// Each index references an explicitly authored platebande variant;
/// no variant is chosen by calculation, random, or plant state.
///
/// Only variant 00 is used: its YAML palette_roles are bois_chaud and
/// terre_humide alone — no integrated stone or foliage accessory that could
/// cross or compete with a crop. Variants 01–03 carry pierre_creme and
/// feuillage_sauge integrated structures deemed too present for a frame.
class PotagerBeds {
  const PotagerBeds._();

  static const _bedWidth = 52.25;
  static const _bedHeight = 40.5;

  static const _v00 = 'potager_decor_bac_potager_statique_ordinaire_00.png';

  static const beds = <GardenSpriteObject>[
    GardenSpriteObject(
      id: 'bed_0',
      asset: _v00,
      contact: Offset(75, 150),
      size: Size(_bedWidth, _bedHeight),
      layer: GardenLayer.depth,
    ),
    GardenSpriteObject(
      id: 'bed_1',
      asset: _v00,
      contact: Offset(275, 230),
      size: Size(_bedWidth, _bedHeight),
      layer: GardenLayer.depth,
    ),
    GardenSpriteObject(
      id: 'bed_2',
      asset: _v00,
      contact: Offset(75, 310),
      size: Size(_bedWidth, _bedHeight),
      layer: GardenLayer.depth,
    ),
    GardenSpriteObject(
      id: 'bed_3',
      asset: _v00,
      contact: Offset(315, 310),
      size: Size(_bedWidth, _bedHeight),
      layer: GardenLayer.depth,
    ),
    GardenSpriteObject(
      id: 'bed_4',
      asset: _v00,
      contact: Offset(195, 150),
      size: Size(_bedWidth, _bedHeight),
      layer: GardenLayer.depth,
    ),
    GardenSpriteObject(
      id: 'bed_5',
      asset: _v00,
      contact: Offset(115, 230),
      size: Size(_bedWidth, _bedHeight),
      layer: GardenLayer.depth,
    ),
    GardenSpriteObject(
      id: 'bed_6',
      asset: _v00,
      contact: Offset(195, 310),
      size: Size(_bedWidth, _bedHeight),
      layer: GardenLayer.depth,
    ),
    GardenSpriteObject(
      id: 'bed_7',
      asset: _v00,
      contact: Offset(315, 150),
      size: Size(_bedWidth, _bedHeight),
      layer: GardenLayer.depth,
    ),
  ];
}

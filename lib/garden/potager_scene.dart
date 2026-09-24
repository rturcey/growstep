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
/// Two variants are used: v00 (bois + terre, fully neutral) and v01 (bois +
/// terre + pierre + feuillage). v01's extra 6.25 visible px of accessories
/// sit at the top of the sprite, above the wooden frame. At the 66 px render
/// width they are compact enough to read as a detail of the bed rather than
/// a structure crossing the crop. v01 is kept away from the trellis (index 4)
/// and from the back-left corner (index 0) to avoid compounding structures.
class PotagerBeds {
  const PotagerBeds._();

  static const _bedWidth = 66.0;
  static const _v00Height = 51.2;
  static const _v01Height = 59.1;

  static const _v00 = 'potager_decor_bac_potager_statique_ordinaire_00.png';
  static const _v01 = 'potager_decor_bac_potager_statique_ordinaire_01.png';

  static const beds = <GardenSpriteObject>[
    GardenSpriteObject(
      id: 'bed_0',
      asset: _v00,
      contact: Offset(75, 150),
      size: Size(_bedWidth, _v00Height),
      layer: GardenLayer.depth,
    ),
    GardenSpriteObject(
      id: 'bed_1',
      asset: _v01,
      contact: Offset(275, 230),
      size: Size(_bedWidth, _v01Height),
      layer: GardenLayer.depth,
    ),
    GardenSpriteObject(
      id: 'bed_2',
      asset: _v00,
      contact: Offset(75, 310),
      size: Size(_bedWidth, _v00Height),
      layer: GardenLayer.depth,
    ),
    GardenSpriteObject(
      id: 'bed_3',
      asset: _v01,
      contact: Offset(315, 310),
      size: Size(_bedWidth, _v01Height),
      layer: GardenLayer.depth,
    ),
    GardenSpriteObject(
      id: 'bed_4',
      asset: _v00,
      contact: Offset(195, 150),
      size: Size(_bedWidth, _v00Height),
      layer: GardenLayer.depth,
    ),
    GardenSpriteObject(
      id: 'bed_5',
      asset: _v01,
      contact: Offset(115, 230),
      size: Size(_bedWidth, _v01Height),
      layer: GardenLayer.depth,
    ),
    GardenSpriteObject(
      id: 'bed_6',
      asset: _v00,
      contact: Offset(195, 310),
      size: Size(_bedWidth, _v00Height),
      layer: GardenLayer.depth,
    ),
    GardenSpriteObject(
      id: 'bed_7',
      asset: _v01,
      contact: Offset(315, 150),
      size: Size(_bedWidth, _v01Height),
      layer: GardenLayer.depth,
    ),
  ];
}

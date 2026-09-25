import 'dart:ui';

import 'package:tiled/tiled.dart';

import 'garden_scene.dart';
import 'garden_sprite_metadata.dart';
import 'potager_grid_adapter.dart';

/// Read-only Potager objects authored in Tiled. Plot contacts are kept as a
/// shadow of the existing saved-slot layout during the PoC.
class PotagerTiledObjects {
  const PotagerTiledObjects._(
    this.rock,
    this.rockAnchorDelta,
    this.plotContacts,
    this.sceneObjects,
  );

  final GardenSpriteObject rock;
  final Offset rockAnchorDelta;
  final Map<String, Offset> plotContacts;
  final List<GardenSpriteObject> sceneObjects;

  static double _gridProperty(TiledObject object, String name) =>
      object.properties.getValue<double>(name) ??
      (throw FormatException('${object.name} is missing $name'));

  static GardenShadow? _shadowOverride(TiledObject object) {
    final value = object.properties.getValue<String>('shadow');
    if (value == null) return null;
    for (final option in GardenShadow.values) {
      if (option.name == value) return option;
    }
    throw FormatException('${object.name} has invalid shadow: $value');
  }

  factory PotagerTiledObjects.fromMap(
    TiledMap map,
    Map<String, GardenSpriteMetadata> spriteManifest, {
    PotagerGridAdapter adapter = const PotagerGridAdapter(),
  }) {
    final props = map.layerByName('props') as ObjectGroup;
    final plots = map.layerByName('plots') as ObjectGroup;
    final rockObject = props.objects.singleWhere(
      (object) => object.name == 'east_upper_rock',
    );
    if (rockObject.class_ != 'prop' || rockObject.gid == null) {
      throw FormatException('east_upper_rock must be a Tiled prop tile object');
    }
    final image = map.tileByGid(rockObject.gid!)?.image;
    final source = image?.source;
    if (source == null) {
      throw FormatException('east_upper_rock has no sprite image');
    }
    final asset = source.split('/').last;
    final metadata = spriteManifest[asset];
    if (metadata == null) {
      throw FormatException('Missing sprite manifest entry for $asset');
    }

    final fullImageSize = Size(rockObject.width, rockObject.height);
    final anchorDelta = metadata.bottomCenterToGroundAt(fullImageSize);
    final contact = adapter.fromTiledProperties(
      _gridProperty(rockObject, 'gridCol'),
      _gridProperty(rockObject, 'gridRow'),
    );
    final rock = GardenSpriteObject(
      id: rockObject.name,
      asset: asset,
      contact: contact,
      size: metadata.visibleSizeAt(fullImageSize),
      layer: GardenLayer.depth,
      opacity: rockObject.properties.getValue<double>('opacity') ?? 1,
      shadowOverride: _shadowOverride(rockObject),
    );

    final sceneObjects = <GardenSpriteObject>[];
    const visualGroups = {
      'floor_decor',
      'vegetation',
      'rocks',
      'structures',
      'props',
      'edge_overlays',
    };
    for (final group in map.layers.whereType<ObjectGroup>()) {
      if (!visualGroups.contains(group.name)) continue;
      for (final object in group.objects) {
        if (identical(object, rockObject)) {
          sceneObjects.add(rock);
          continue;
        }
        final gid = object.gid;
        if (gid == null) {
          throw FormatException('${object.name} must be a Tiled tile object');
        }
        final source = map.tileByGid(gid)?.image?.source;
        final asset = source?.split('/').last;
        final metadata = asset == null ? null : spriteManifest[asset];
        if (asset == null || metadata == null) {
          throw FormatException('${object.name} has no sprite manifest entry');
        }
        final contact = adapter.fromTiledProperties(
          _gridProperty(object, 'gridCol'),
          _gridProperty(object, 'gridRow'),
        );
        sceneObjects.add(
          GardenSpriteObject(
            id: object.name,
            asset: asset,
            contact: contact,
            size: metadata.visibleSizeAt(Size(object.width, object.height)),
            layer: GardenLayer.depth,
            opacity: object.properties.getValue<double>('opacity') ?? 1,
            shadowOverride: _shadowOverride(object),
            zBias: object.properties.getValue<double>('zBias') ?? 0,
          ),
        );
      }
    }

    return PotagerTiledObjects._(
      rock,
      anchorDelta,
      Map.unmodifiable({
        for (final plot in plots.objects)
          if (plot.class_ == 'plot')
            plot.name: adapter.fromTiledProperties(
              _gridProperty(plot, 'gridCol'),
              _gridProperty(plot, 'gridRow'),
            ),
      }),
      List.unmodifiable(sceneObjects),
    );
  }
}

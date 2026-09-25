import 'dart:ui';

import 'garden_scene.dart';
import 'garden_sprites.dart';

/// Executes authored placement. It never chooses coordinates or variants.
class GardenSceneRenderer {
  const GardenSceneRenderer._();

  static const _pathContrast = ColorFilter.matrix([
    1.2,
    0,
    0,
    0,
    -18,
    0,
    1.2,
    0,
    0,
    -18,
    0,
    0,
    1.2,
    0,
    -18,
    0,
    0,
    0,
    1,
    0,
  ]);

  static List<T> depthOrder<T extends GardenPlacedObject>(List<T> objects) {
    final indexed = objects.indexed.toList();
    indexed.sort((a, b) {
      final byLayer = a.$2.layer.index.compareTo(b.$2.layer.index);
      if (byLayer != 0) return byLayer;
      final byDepth = a.$2.depth.compareTo(b.$2.depth);
      if (byDepth != 0) return byDepth;
      if (a.$2.id.isEmpty != b.$2.id.isEmpty) {
        return a.$2.id.isEmpty ? -1 : 1;
      }
      if (a.$2.id.isNotEmpty && b.$2.id.isNotEmpty) {
        final byId = a.$2.id.compareTo(b.$2.id);
        if (byId != 0) return byId;
      }
      return a.$1.compareTo(b.$1);
    });
    return [for (final entry in indexed) entry.$2];
  }

  static bool drawSprite(
    Canvas canvas,
    GardenSpriteObject object,
    GardenSprites sprites,
  ) {
    // Flat path sprites already carry their soft ground contact in the PNG.
    final shadow =
        object.shadowOverride ??
        (sprites.hasContactShadow(object.asset)
            ? GardenShadow.medium
            : GardenShadow.none);
    if (object.layer != GardenLayer.path && shadow != GardenShadow.none) {
      sprites.drawContactShadow(
        canvas,
        object.contact,
        object.size.width,
        object.size.height,
        style: shadow,
      );
    }
    return sprites.draw(
      canvas,
      object.asset,
      object.contact,
      object.size.width,
      object.size.height,
      opacity: object.opacity,
      includeContactShadow: false,
      colorFilter: object.layer == GardenLayer.path ? _pathContrast : null,
    );
  }
}

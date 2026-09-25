import 'dart:ui';

import 'package:tiled/tiled.dart';

import 'garden_scene.dart';

/// Converts logical Potager grid coordinates to artboard ground contacts.
class PotagerGridAdapter {
  const PotagerGridAdapter();

  static const grid = IsoGrid(Offset(195, 230));
  static const tiledOriginCol = 7;
  static const tiledOriginRow = 9;

  Offset toArtboard(double gridCol, double gridRow) =>
      grid.toScreen(gridCol, gridRow);

  /// Decimal whole or half-cell properties are authoritative for placement.
  Offset fromTiledProperties(double gridCol, double gridRow) {
    if (!gridCol.isFinite ||
        !gridRow.isFinite ||
        gridCol * 2 != (gridCol * 2).roundToDouble() ||
        gridRow * 2 != (gridRow * 2).roundToDouble()) {
      throw const FormatException(
        'Potager grid coordinates must use whole or half cells',
      );
    }
    return toArtboard(gridCol, gridRow);
  }

  /// Tiled stores isometric object positions in projected 40px square space.
  /// A point at the center of tile (7,9) is the Potager's logical (0,0).
  /// Use this for comparison; custom grid properties remain authoritative.
  Offset fromTiledObject(double x, double y) => toArtboard(
    x / IsoGrid.cellHeight - tiledOriginCol - 0.5,
    y / IsoGrid.cellHeight - tiledOriginRow - 0.5,
  );

  /// Translation from flame_tiled's isometric image centers to the artboard.
  /// Its tile center includes a horizontal shift of half the map height.
  Offset tileMapOffset(TiledMap map) {
    final halfWidth = map.tileWidth / 2;
    final halfHeight = map.tileHeight / 2;
    final originTileCenter = Offset(
      (tiledOriginCol - tiledOriginRow + map.height) * halfWidth,
      (tiledOriginCol + tiledOriginRow + 1) * halfHeight,
    );
    return toArtboard(0, 0) - originTileCenter;
  }
}

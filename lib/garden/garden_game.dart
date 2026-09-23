import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import 'garden_state.dart';
import 'garden_sprites.dart';

/// Flame draws the garden; planting controls and rules live outside the canvas.
class GardenGame extends FlameGame {
  final GardenSprites _sprites = GardenSprites();
  GardenSnapshot snapshot = GardenSnapshot.initial();

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    await _sprites.load();
  }

  @override
  void onRemove() {
    _sprites.dispose();
    super.onRemove();
  }

  @override
  Color backgroundColor() => const Color(0xFF193627);

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    for (var index = 0; index < ZoneType.values.length; index++) {
      final zone = ZoneType.values[index];
      final center = Offset(size.x * (index + 1) / 4, size.y / 2 + 12);
      _drawZone(canvas, center, zone, snapshot.zones[zone]!);
    }
  }

  void _drawZone(
    Canvas canvas,
    Offset center,
    ZoneType zone,
    List<Plant?> slots,
  ) {
    final halfWidth = size.x / 8 - 8;
    const halfHeight = 52.0;
    final ground = Path()
      ..moveTo(center.dx, center.dy - halfHeight)
      ..lineTo(center.dx + halfWidth, center.dy)
      ..lineTo(center.dx, center.dy + halfHeight)
      ..lineTo(center.dx - halfWidth, center.dy)
      ..close();
    final color = switch (zone) {
      ZoneType.potager => const Color(0xFFA16D43),
      ZoneType.jardinFleuri => const Color(0xFF759E63),
      ZoneType.verger => const Color(0xFF5F8E58),
    };
    canvas.drawPath(ground, Paint()..color = color);
    canvas.drawPath(
      ground,
      Paint()
        ..color = const Color(0xFFE3CA9A)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );

    for (var index = 0; index < slots.length; index++) {
      final column = index % 2;
      final row = index ~/ 2;
      final position = Offset(
        center.dx + (column == 0 ? -1 : 1) * halfWidth * 0.32,
        center.dy - 20 + row * 14,
      );
      final plant = slots[index];
      if (plant == null) {
        canvas.drawCircle(
          position,
          4,
          Paint()..color = const Color(0xFF4B382B),
        );
      } else {
        _drawPlant(canvas, position, plant);
      }
    }
  }

  void _drawPlant(Canvas canvas, Offset position, Plant plant) {
    final height = switch (plant.stage) {
      PlantStage.graineGermee => 7.0,
      PlantStage.jeunePlant => 13.0,
      PlantStage.presqueMature => 19.0,
      PlantStage.mature => 25.0,
    };
    if (plant.species == Species.tomate &&
        plant.stage == PlantStage.jeunePlant &&
        _sprites.draw(
          canvas,
          'potager_plante_tomate_jeune_ordinaire_00.png',
          position,
          48,
          38,
        )) {
      return;
    }
    final tip = Offset(position.dx, position.dy - height);
    canvas.drawLine(
      position,
      tip,
      Paint()
        ..color = const Color(0xFF376944)
        ..strokeWidth = 3,
    );
    canvas.drawCircle(
      tip,
      height / 4 + 2,
      Paint()
        ..color = plant.species.zone == ZoneType.jardinFleuri
            ? const Color(0xFFF4D16D)
            : const Color(0xFF7BC579),
    );
    if (plant.tier == GrowthTier.brillante) {
      canvas.drawCircle(
        tip,
        height / 4 + 4,
        Paint()
          ..color = const Color(0xFFFFF5C2)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
    }
  }
}

import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import 'garden_state.dart';

/// Flame owns the isometric garden drawing; Flutter owns the controls around it.
class GardenGame extends FlameGame {
  GardenSnapshot snapshot = GardenSnapshot.empty;

  @override
  Color backgroundColor() => const Color(0xFF193627);

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    final center = Offset(size.x / 2, size.y / 2 + 42);
    final top = Path()
      ..moveTo(center.dx, center.dy - 75)
      ..lineTo(center.dx + 128, center.dy)
      ..lineTo(center.dx, center.dy + 75)
      ..lineTo(center.dx - 128, center.dy)
      ..close();
    final leftSide = Path()
      ..moveTo(center.dx - 128, center.dy)
      ..lineTo(center.dx, center.dy + 75)
      ..lineTo(center.dx, center.dy + 94)
      ..lineTo(center.dx - 128, center.dy + 18)
      ..close();
    final rightSide = Path()
      ..moveTo(center.dx, center.dy + 75)
      ..lineTo(center.dx + 128, center.dy)
      ..lineTo(center.dx + 128, center.dy + 18)
      ..lineTo(center.dx, center.dy + 94)
      ..close();

    canvas.drawPath(leftSide, Paint()..color = const Color(0xFF604532));
    canvas.drawPath(rightSide, Paint()..color = const Color(0xFF4B382B));
    canvas.drawPath(top, Paint()..color = const Color(0xFF8D6844));
    canvas.drawPath(
      top,
      Paint()
        ..color = const Color(0xFFC19463)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );

    if (snapshot.plantStage == null) {
      canvas.drawCircle(
        Offset(center.dx, center.dy - 12),
        8,
        Paint()..color = const Color(0xFF3D2B20),
      );
      return;
    }

    final young = snapshot.plantStage == PlantStage.jeunePlante;
    final base = Offset(center.dx, center.dy - 10);
    final tip = Offset(center.dx, center.dy - (young ? 105 : 58));
    canvas.drawLine(
      base,
      tip,
      Paint()
        ..color = const Color(0xFF75B971)
        ..strokeWidth = young ? 9 : 6
        ..strokeCap = StrokeCap.round,
    );
    _leaf(canvas, Offset(center.dx - 20, tip.dy + 25), true, young);
    _leaf(canvas, Offset(center.dx + 20, tip.dy + 38), false, young);
    if (young) {
      _leaf(canvas, Offset(center.dx - 28, tip.dy + 60), true, true);
      canvas.drawCircle(tip, 18, Paint()..color = const Color(0xFFF2C66E));
      canvas.drawCircle(tip, 8, Paint()..color = const Color(0xFF6A4734));
    }
  }

  void _leaf(Canvas canvas, Offset point, bool left, bool young) {
    final direction = left ? -1.0 : 1.0;
    final width = young ? 34.0 : 25.0;
    final leaf = Path()
      ..moveTo(point.dx - direction * width, point.dy - 11)
      ..quadraticBezierTo(
        point.dx - direction * width / 2,
        point.dy + 13,
        point.dx,
        point.dy,
      )
      ..quadraticBezierTo(
        point.dx - direction * width / 2,
        point.dy - 20,
        point.dx - direction * width,
        point.dy - 11,
      );
    canvas.drawPath(leaf, Paint()..color = const Color(0xFF79C381));
  }
}

import 'package:flutter/material.dart';

/// The potager's first walkable composition. Its contacts use the same
/// integer/half-integer 80 × 40 lattice as the saved planting locations.
///
/// Kept specific to the potager until its full-size scene has been reviewed.
class PotagerPath {
  const PotagerPath._();

  static const _leftRoute = <Offset>[
    Offset(195, 390), // entrance
    Offset(195, 370),
    Offset(155, 350),
    Offset(135, 320),
    Offset(135, 280),
    Offset(155, 290), // front-center bed
    Offset(155, 270),
    Offset(155, 250),
    Offset(175, 220),
    Offset(195, 190),
  ];

  static const _rightRoute = <Offset>[
    Offset(195, 370),
    Offset(235, 350),
    Offset(255, 320),
    Offset(255, 280),
    Offset(235, 290), // front-center bed
    Offset(235, 270),
    Offset(235, 250),
    Offset(215, 220),
    Offset(195, 190),
  ];

  static const _frontLeftSpur = <Offset>[
    Offset(135, 320),
    Offset(115, 330), // front-left bed
  ];

  static const _frontRightSpur = <Offset>[
    Offset(255, 320),
    Offset(275, 330), // front-right bed
  ];

  static const _backLeftRoute = <Offset>[
    Offset(195, 190),
    Offset(155, 170),
    Offset(135, 160),
    Offset(115, 170), // back-left bed
  ];

  static const _backRightRoute = <Offset>[
    Offset(195, 190),
    Offset(235, 170),
    Offset(255, 160),
    Offset(275, 170), // back-right bed
  ];

  /// Connected stepping-stone routes; exposed for geometry acceptance checks.
  static const routes = <List<Offset>>[
    _leftRoute,
    _rightRoute,
    _frontLeftSpur,
    _frontRightSpur,
    _backLeftRoute,
    _backRightRoute,
  ];

  static void draw(Canvas canvas) {
    final contacts = <Offset>{for (final route in routes) ...route}.toList();
    for (var index = 0; index < contacts.length; index++) {
      _drawStone(canvas, contacts[index], index);
    }
  }

  static void _drawStone(Canvas canvas, Offset point, int index) {
    final variation = index % 4;
    final halfWidth = [12.0, 10.5, 12.5, 11.0][variation];
    final halfHeight = [6.0, 5.5, 6.5, 5.5][variation];
    canvas.save();
    canvas.translate(point.dx, point.dy);
    canvas.rotate([-0.09, 0.07, 0.03, -0.05][variation]);
    final left = -halfWidth;
    final right = halfWidth;
    final top = -halfHeight;
    final bottom = halfHeight;
    final stone = Path()
      ..moveTo(left + 3, top + 1)
      ..quadraticBezierTo(-2, top - variation * 0.35, right - 3, top)
      ..quadraticBezierTo(right + 1, -1, right - 1, bottom - 2)
      ..quadraticBezierTo(4, bottom + 1, left + 2, bottom)
      ..quadraticBezierTo(left - 1, 1, left + 3, top + 1)
      ..close();
    canvas.drawPath(
      stone.shift(const Offset(1.5, 2.5)),
      Paint()..color = const Color(0x586B7657),
    );
    canvas.drawPath(
      stone,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: variation.isEven
              ? const [Color(0xFFE6DFC9), Color(0xFFC8BDA2)]
              : const [Color(0xFFDDD5C0), Color(0xFFBFB397)],
        ).createShader(stone.getBounds()),
    );
    canvas.restore();
  }

  static void drawBedContact(Canvas canvas, Offset point) {
    canvas.drawOval(
      Rect.fromCenter(center: point.translate(0, 13), width: 89, height: 38),
      Paint()..color = const Color(0x26806E43),
    );
    for (final offset in const [
      Offset(-46, 12),
      Offset(45, 10),
      Offset(-25, 35),
      Offset(25, 35),
    ]) {
      final root = point + offset;
      final paint = Paint()
        ..color = const Color(0xB16D9452)
        ..strokeWidth = 1.6
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(root, root.translate(-3, -6), paint);
      canvas.drawLine(root, root.translate(1, -8), paint);
      canvas.drawLine(root, root.translate(4, -5), paint);
    }
  }
}

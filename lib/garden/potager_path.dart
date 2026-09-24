import 'package:flutter/material.dart';

/// A complete walk through the potager, placed on the integer/half-integer
/// 80 × 40 lattice. A long curving spine takes priority over short bed spurs.
class PotagerPath {
  const PotagerPath._();

  static const _spine = <Offset>[
    Offset(195, 410), // entrance on the front lip
    Offset(195, 370),
    Offset(155, 350),
    Offset(155, 330), // front-center approach
    Offset(135, 320),
    Offset(135, 280),
    Offset(155, 250),
    Offset(175, 220),
    Offset(195, 190),
  ];

  static const _rightArc = <Offset>[
    Offset(175, 220),
    Offset(215, 220),
    Offset(235, 250),
    Offset(255, 280),
    Offset(255, 320),
    Offset(275, 330), // approach to front-right bed
  ];

  static const _frontLeftSpur = <Offset>[Offset(135, 320), Offset(115, 330)];

  static const _backLeftRoute = <Offset>[
    Offset(195, 190),
    Offset(155, 170),
    Offset(115, 170), // back-left bed
  ];

  static const _backRightRoute = <Offset>[
    Offset(195, 190),
    Offset(235, 170),
    Offset(275, 170), // back-right bed
  ];

  /// Connected stepping-stone routes; exposed for geometry acceptance checks.
  static const routes = <List<Offset>>[
    _spine,
    _rightArc,
    _frontLeftSpur,
    _backLeftRoute,
    _backRightRoute,
  ];

  static void draw(Canvas canvas) {
    for (final route in routes) {
      final trace = _smoothTrace(route);
      canvas.drawPath(
        trace,
        Paint()
          ..color = const Color(0x577F9360)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 27
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      );
      canvas.drawPath(
        trace,
        Paint()
          ..color = const Color(0x72C3BF91)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 14
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      );
    }
    // The full worn trace stays connected; stone intervals vary along it.
    const contacts = <Offset>[
      Offset(195, 410),
      Offset(195, 370),
      Offset(155, 350),
      Offset(135, 320),
      Offset(135, 280),
      Offset(175, 220),
      Offset(195, 190),
      Offset(235, 250),
      Offset(255, 320),
      Offset(115, 330),
      Offset(115, 170),
      Offset(275, 170),
    ];
    for (var index = 0; index < contacts.length; index++) {
      _drawStone(canvas, contacts[index], index);
    }
  }

  static Path _smoothTrace(List<Offset> route) {
    final trace = Path()..moveTo(route.first.dx, route.first.dy);
    for (var index = 1; index < route.length - 1; index++) {
      final point = route[index];
      final next = route[index + 1];
      trace.quadraticBezierTo(
        point.dx,
        point.dy,
        (point.dx + next.dx) / 2,
        (point.dy + next.dy) / 2,
      );
    }
    trace.lineTo(route.last.dx, route.last.dy);
    return trace;
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

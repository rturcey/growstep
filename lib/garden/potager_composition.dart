import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'landscape_mass.dart';
import 'potager_scene.dart';

/// The potager's fixed environmental composition. It remains specific to this
/// island until the complete scene has been approved at phone size.
class PotagerComposition {
  const PotagerComposition._();

  static const trellisAnchor = Offset(155, 150);
  static final barrelAnchor = PotagerPilotScene.barrel.contact;
  static const wateringCanAnchor = Offset(335, 220);
  static const nurseryCrateAnchor = Offset(95, 360);
  static const rimGrass = <Offset>[
    Offset(75, 390),
    Offset(95, 400),
    Offset(295, 400),
  ];
  static const embeddedBeds = <Offset>[
    Offset(75, 150),
    Offset(115, 230),
    Offset(315, 310),
  ];

  /// Two connected border masses frame the center without closing the front.
  static const masses = <LandscapeMass>[
    LandscapeMass(
      shrubs: [
        LandscapeShrub(Offset(35, 250), 24, ShrubPalette.sage),
        LandscapeShrub(Offset(35, 210), 25, ShrubPalette.moss),
        LandscapeShrub(Offset(55, 220), 20, ShrubPalette.olive),
        LandscapeShrub(Offset(35, 170), 28, ShrubPalette.olive),
        LandscapeShrub(Offset(75, 130), 28, ShrubPalette.moss),
        LandscapeShrub(Offset(75, 90), 32, ShrubPalette.sage),
        LandscapeShrub(Offset(115, 90), 35, ShrubPalette.moss),
        LandscapeShrub(Offset(155, 90), 29, ShrubPalette.olive),
      ],
    ),
    LandscapeMass(
      shrubs: [
        LandscapeShrub(Offset(255, 80), 32, ShrubPalette.sage),
        LandscapeShrub(Offset(295, 100), 35, ShrubPalette.moss),
        LandscapeShrub(Offset(335, 140), 28, ShrubPalette.olive),
        LandscapeShrub(Offset(355, 190), 13, ShrubPalette.sage),
      ],
      rocks: [
        LandscapeRock(Offset(355, 270), 22),
      ],
    ),
  ];

  static void drawGround(Canvas canvas, Path contour) {
    canvas.save();
    canvas.clipPath(contour);
    for (final mass in masses) {
      LandscapeMassPainter.drawGround(canvas, mass);
    }
    // Wide low growth ties the left beds to their border mass. The right
    // transition is shorter and lighter, preserving an asymmetric open lawn.
    final leftGrowth = Path()
      ..moveTo(55, 140)
      ..quadraticBezierTo(49, 186, 85, 225);
    canvas.drawPath(
      leftGrowth,
      Paint()
        ..color = const Color(0x5A5D844D)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 46
        ..strokeCap = StrokeCap.round,
    );
    final rightGrowth = Path()
      ..moveTo(355, 190)
      ..quadraticBezierTo(353, 224, 330, 250);
    canvas.drawPath(
      rightGrowth,
      Paint()
        ..color = const Color(0x2B668651)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 26
        ..strokeCap = StrokeCap.round,
    );
    final rng = math.Random(4106);
    for (var index = 0; index < 38; index++) {
      final x = 36 + rng.nextDouble() * 318;
      final y = 101 + rng.nextDouble() * 285;
      if (x > 230 && y > 325) continue; // deliberate quiet lawn
      final radius = 4.0 + rng.nextDouble() * 9.0;
      final patch = Path()
        ..moveTo(x - radius, y)
        ..quadraticBezierTo(
          x - radius * 0.7,
          y - radius * 0.45,
          x,
          y - radius * 0.32,
        )
        ..quadraticBezierTo(x + radius * 0.7, y - radius * 0.35, x + radius, y)
        ..quadraticBezierTo(
          x + radius * 0.3,
          y + radius * 0.4,
          x - radius * 0.6,
          y + radius * 0.25,
        )
        ..close();
      canvas.drawPath(
        patch,
        Paint()
          ..color = index.isEven
              ? const Color(0x1F5E864E)
              : const Color(0x24D3E39B),
      );
    }
    for (var index = 0; index < 28; index++) {
      final center = Offset(
        38 + rng.nextDouble() * 314,
        111 + rng.nextDouble() * 271,
      );
      if (center.dx > 230 && center.dy > 325) continue;
      final blade = Paint()
        ..color = index.isEven
            ? const Color(0x33638548)
            : const Color(0x4092B565)
        ..strokeWidth = 1.1
        ..strokeCap = StrokeCap.round;
      final length = 3.5 + rng.nextDouble() * 3.5;
      canvas.drawLine(center, center.translate(-1.5, -length), blade);
      if (index % 3 == 0) {
        canvas.drawLine(
          center.translate(1.5, 0),
          center.translate(3, -length * 0.8),
          blade,
        );
      }
    }
    // These small patches join the two care objects to their ground contact.
    for (final (center, width) in const [
      (Offset(146, 146), 75.0),
      (Offset(345, 232), 55.0),
      (Offset(94, 358), 59.0),
    ]) {
      canvas.drawOval(
        Rect.fromCenter(center: center, width: width, height: 17),
        Paint()..color = const Color(0x295D824D),
      );
    }
    canvas.restore();
    drawFrontFringe(canvas);
  }

  /// Low turf softens the visible outline without covering the earth slice.
  static void drawFrontFringe(Canvas canvas) {
    final fringe = Path()
      ..moveTo(59, 373)
      ..quadraticBezierTo(68, 378, 76, 381)
      ..quadraticBezierTo(91, 390, 103, 395)
      ..quadraticBezierTo(123, 403, 143, 408)
      ..quadraticBezierTo(161, 408, 173, 411)
      ..quadraticBezierTo(193, 409, 207, 411)
      ..quadraticBezierTo(229, 408, 249, 408)
      ..quadraticBezierTo(276, 402, 291, 393)
      ..quadraticBezierTo(315, 383, 330, 373)
      ..lineTo(327, 379)
      ..quadraticBezierTo(307, 393, 286, 401)
      ..quadraticBezierTo(267, 411, 246, 413)
      ..quadraticBezierTo(225, 415, 206, 414)
      ..quadraticBezierTo(182, 416, 163, 413)
      ..quadraticBezierTo(139, 414, 121, 406)
      ..quadraticBezierTo(87, 396, 57, 378)
      ..close();
    canvas.drawPath(fringe, Paint()..color = const Color(0xC780A95B));
  }

  /// The same planted-ground silhouette is reused for three embedded beds.
  /// Its bounds remain inside the logical 80 × 40 slot footprint.
  static Path embeddedRim(Offset point) => Path()
    ..moveTo(point.dx - 39, point.dy)
    ..quadraticBezierTo(
      point.dx - 36,
      point.dy - 8,
      point.dx - 21,
      point.dy - 10,
    )
    ..quadraticBezierTo(point.dx - 12, point.dy - 18, point.dx, point.dy - 19)
    ..quadraticBezierTo(
      point.dx + 17,
      point.dy - 15,
      point.dx + 26,
      point.dy - 9,
    )
    ..quadraticBezierTo(
      point.dx + 39,
      point.dy - 5,
      point.dx + 39,
      point.dy + 1,
    )
    ..quadraticBezierTo(
      point.dx + 24,
      point.dy + 12,
      point.dx + 5,
      point.dy + 18,
    )
    ..quadraticBezierTo(
      point.dx - 9,
      point.dy + 19,
      point.dx - 18,
      point.dy + 14,
    )
    ..quadraticBezierTo(point.dx - 37, point.dy + 7, point.dx - 39, point.dy)
    ..close();

  static Path embeddedSoil(Offset point) => Path()
    ..moveTo(point.dx - 35, point.dy)
    ..quadraticBezierTo(
      point.dx - 31,
      point.dy - 7,
      point.dx - 18,
      point.dy - 8,
    )
    ..quadraticBezierTo(
      point.dx - 9,
      point.dy - 15,
      point.dx + 1,
      point.dy - 16,
    )
    ..quadraticBezierTo(
      point.dx + 16,
      point.dy - 12,
      point.dx + 24,
      point.dy - 7,
    )
    ..quadraticBezierTo(
      point.dx + 34,
      point.dy - 4,
      point.dx + 35,
      point.dy + 1,
    )
    ..quadraticBezierTo(
      point.dx + 21,
      point.dy + 10,
      point.dx + 3,
      point.dy + 15,
    )
    ..quadraticBezierTo(
      point.dx - 9,
      point.dy + 16,
      point.dx - 18,
      point.dy + 11,
    )
    ..quadraticBezierTo(point.dx - 34, point.dy + 6, point.dx - 35, point.dy)
    ..close();

  static void drawRimGrass(Canvas canvas, Offset point) {
    canvas.drawOval(
      Rect.fromCenter(center: point.translate(1, 2), width: 30, height: 8),
      Paint()..color = const Color(0x6654773F),
    );
    for (final (dx, width) in [(-8.0, 14.0), (1.0, 18.0), (9.0, 11.0)]) {
      canvas.drawOval(
        Rect.fromCenter(
          center: point.translate(dx, -6),
          width: width,
          height: 13,
        ),
        Paint()..color = const Color(0xFF8CAF60),
      );
    }
    final paint = Paint()
      ..color = const Color(0xFF739952)
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;
    for (final dx in [-5.0, 0.0, 5.0]) {
      final root = point.translate(dx, 1);
      canvas.drawLine(root, root.translate(dx < 0 ? -3 : 2, -7), paint);
    }
  }

  static void drawBedOvergrowth(Canvas canvas, Offset point) {
    if (!embeddedBeds.contains(point)) return;
    for (final (offset, width) in const [
      (Offset(-37, 8), 32.0),
      (Offset(-25, 22), 28.0),
    ]) {
      final root = point + offset;
      canvas.drawOval(
        Rect.fromCenter(center: root, width: width, height: 11),
        Paint()..color = const Color(0xD2789D56),
      );
      final blade = Paint()
        ..color = const Color(0xFF61864B)
        ..strokeWidth = 1.5
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(root, root.translate(-3, -9), blade);
      canvas.drawLine(root, root.translate(2, -7), blade);
    }
  }

  static void drawTrellis(Canvas canvas) {
    final point = trellisAnchor;
    canvas.drawOval(
      Rect.fromCenter(center: point.translate(2, 2), width: 68, height: 11),
      Paint()..color = const Color(0x2D536547),
    );
    for (final dx in [-26.0, 26.0]) {
      final base = point.translate(dx, 0);
      canvas.drawLine(
        base.translate(2, 2),
        base.translate(2, -34),
        Paint()
          ..color = const Color(0xFF8C6545)
          ..strokeWidth = 6
          ..strokeCap = StrokeCap.round,
      );
      canvas.drawLine(
        base,
        base.translate(0, -35),
        Paint()
          ..color = const Color(0xFFC49A68)
          ..strokeWidth = 5
          ..strokeCap = StrokeCap.round,
      );
    }
    final top = Path()
      ..moveTo(point.dx - 27, point.dy - 34)
      ..quadraticBezierTo(
        point.dx,
        point.dy - 49,
        point.dx + 27,
        point.dy - 34,
      );
    canvas.drawPath(
      top,
      Paint()
        ..color = const Color(0xFF9C744D)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 6
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawPath(
      top.shift(const Offset(-1, -1)),
      Paint()
        ..color = const Color(0xFFD2AB76)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
    for (final (dx, dy, angle) in const [
      (-27.0, -33.0, -0.5),
      (-22.0, -39.0, -0.3),
      (-14.0, -42.0, 0.2),
      (-5.0, -44.0, -0.4),
      (5.0, -44.0, 0.5),
      (15.0, -42.0, -0.2),
      (23.0, -39.0, 0.4),
      (27.0, -30.0, -0.3),
    ]) {
      canvas.save();
      canvas.translate(point.dx + dx, point.dy + dy);
      canvas.rotate(angle);
      canvas.drawOval(
        const Rect.fromLTWH(-5, -2.5, 10, 5),
        Paint()
          ..color = dx.isNegative
              ? const Color(0xFF668B50)
              : const Color(0xFF7FA15B),
      );
      canvas.restore();
    }
    _smallFlower(canvas, point.translate(-19, -38));
    _smallFlower(canvas, point.translate(20, -37));
    _grass(canvas, point.translate(-28, 2));
    _grass(canvas, point.translate(28, 2));
  }

  static void drawBarrel(Canvas canvas) {
    final point = barrelAnchor;
    canvas.drawOval(
      Rect.fromCenter(center: point.translate(2, 4), width: 47, height: 12),
      Paint()
        ..color = const Color(0x32536B47)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
    );
    final body = Rect.fromLTWH(point.dx - 16, point.dy - 29, 32, 29);
    canvas.drawRRect(
      RRect.fromRectAndRadius(body, const Radius.circular(5)),
      Paint()
        ..shader = const LinearGradient(
          colors: [Color(0xFFC39B6D), Color(0xFF986E48), Color(0xFF77563D)],
        ).createShader(body),
    );
    for (final dx in [-7.0, 2.0, 10.0]) {
      canvas.drawLine(
        point.translate(dx, -27),
        point.translate(dx, -3),
        Paint()
          ..color = const Color(0x69805A3D)
          ..strokeWidth = 1,
      );
    }
    for (final dy in [-22.0, -7.0]) {
      canvas.drawLine(
        point.translate(-16, dy),
        point.translate(16, dy),
        Paint()
          ..color = const Color(0xFF748078)
          ..strokeWidth = 3,
      );
    }
    canvas.drawOval(
      Rect.fromCenter(center: point.translate(0, -29), width: 31, height: 9),
      Paint()..color = const Color(0xFFCFA87B),
    );
    canvas.drawOval(
      Rect.fromCenter(center: point.translate(0, -29), width: 22, height: 5),
      Paint()..color = const Color(0xFF876348),
    );
    canvas.drawLine(
      point.translate(0, -32),
      point.translate(0, -42),
      Paint()
        ..color = const Color(0xFF70847A)
        ..strokeWidth = 4
        ..strokeCap = StrokeCap.round,
    );
    _grass(canvas, point.translate(-19, 2));
  }

  static void _grass(Canvas canvas, Offset point) {
    final paint = Paint()
      ..color = const Color(0xFF6D9254)
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(point, point.translate(-4, -7), paint);
    canvas.drawLine(point, point.translate(0, -9), paint);
    canvas.drawLine(point, point.translate(4, -6), paint);
  }

  static void _smallFlower(Canvas canvas, Offset point) {
    for (final delta in const [
      Offset(-2.5, 0),
      Offset(2.5, 0),
      Offset(0, -2.5),
      Offset(0, 2.5),
    ]) {
      canvas.drawCircle(
        point + delta,
        2.3,
        Paint()..color = const Color(0xFFF2EDDA),
      );
    }
    canvas.drawCircle(point, 1.6, Paint()..color = const Color(0xFFE5C75F));
  }
}

import 'dart:math' as math;

import 'package:flutter/material.dart';

/// The potager's fixed environmental composition. It remains specific to this
/// island until the complete scene has been approved at phone size.
class PotagerComposition {
  const PotagerComposition._();

  static const trellisAnchor = Offset(150, 143);
  static const barrelAnchor = Offset(348, 228);
  static const wateringCanAnchor = Offset(323, 205);
  static const nurseryCrateAnchor = Offset(93, 355);

  /// The shrubs form one irregular border, leaving the front-center open.
  static const shrubs = <PotagerShrub>[
    PotagerShrub(Offset(92, 121), 20, 0),
    PotagerShrub(Offset(114, 113), 13, 2),
    PotagerShrub(Offset(139, 105), 20, 1),
    PotagerShrub(Offset(164, 98), 12, 0),
    PotagerShrub(Offset(190, 93), 14, 2),
    PotagerShrub(Offset(221, 98), 12, 1),
    PotagerShrub(Offset(246, 108), 20, 2),
    PotagerShrub(Offset(271, 116), 12, 0),
    PotagerShrub(Offset(294, 124), 20, 1),
    PotagerShrub(Offset(44, 198), 12, 0),
    PotagerShrub(Offset(43, 223), 11, 1),
    PotagerShrub(Offset(43, 248), 20, 2),
    PotagerShrub(Offset(50, 292), 11, 1),
    PotagerShrub(Offset(345, 195), 12, 1),
    PotagerShrub(Offset(349, 221), 11, 2),
    PotagerShrub(Offset(349, 246), 20, 0),
    PotagerShrub(Offset(338, 292), 11, 2),
  ];

  static void drawGround(Canvas canvas, Path contour) {
    canvas.save();
    canvas.clipPath(contour);
    final rng = math.Random(4106);
    for (var index = 0; index < 82; index++) {
      final x = 36 + rng.nextDouble() * 318;
      final y = 101 + rng.nextDouble() * 285;
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
    for (var index = 0; index < 95; index++) {
      final center = Offset(
        38 + rng.nextDouble() * 314,
        111 + rng.nextDouble() * 271,
      );
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
  }

  static void drawBedSeam(Canvas canvas, Offset point) {
    final variant = ((point.dx + point.dy) / 40).round().abs() % 3;
    for (final side in [-1.0, 1.0]) {
      final center = point.translate(
        side * (27 + variant * 2),
        24.0 + (side < 0 ? variant : 2 - variant),
      );
      canvas.drawOval(
        Rect.fromCenter(
          center: center,
          width: 24.0 + variant * 3,
          height: 7.0 + variant,
        ),
        Paint()..color = const Color(0x23577F49),
      );
    }
  }

  static void drawShrub(Canvas canvas, PotagerShrub shrub) {
    final point = shrub.anchor;
    final radius = shrub.radius;
    final seed = point.dx.round() * 43 + point.dy.round() * 17;
    final rng = math.Random(seed);
    canvas.drawOval(
      Rect.fromCenter(
        center: point.translate(2, 3),
        width: radius * 2.5,
        height: radius * 0.65,
      ),
      Paint()
        ..color = const Color(0x2C4C6340)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
    );

    // Overlapping foliage volumes share one silhouette. The offset and height
    // vary by variant, while the top-left illumination stays consistent.
    for (var index = 0; index < 7; index++) {
      final dx = (index - 3) * radius * (shrub.variant == 1 ? 0.31 : 0.28);
      final dy = -radius * (0.38 + ((index + shrub.variant) % 3) * 0.12);
      canvas.drawCircle(
        point.translate(dx, dy),
        radius * (index.isEven ? 0.47 : 0.39),
        Paint()
          ..color = index < 4
              ? const Color(0xFF50764A)
              : const Color(0xFF436A45),
      );
    }

    const shades = [
      Color(0xFF456F43),
      Color(0xFF5B864E),
      Color(0xFF709A56),
      Color(0xFF89AD62),
      Color(0xFFA6C477),
    ];
    final leafCount = radius > 15 ? 145 : 52;
    for (var index = 0; index < leafCount; index++) {
      final angle = rng.nextDouble() * math.pi * 2;
      final distance = math.sqrt(rng.nextDouble());
      final center = point.translate(
        math.cos(angle) *
            distance *
            radius *
            (shrub.variant == 2 ? 1.07 : 1.12),
        -radius * 0.55 +
            math.sin(angle) *
                distance *
                radius *
                (shrub.variant == 0 ? 0.68 : 0.74),
      );
      canvas.save();
      canvas.translate(center.dx, center.dy);
      canvas.rotate((rng.nextDouble() - 0.5) * 1.7);
      final leafWidth = (radius > 15 ? 3.2 : 2.1) + rng.nextDouble() * 2.4;
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset.zero,
          width: leafWidth * 1.7,
          height: leafWidth * 0.85,
        ),
        Paint()
          ..color =
              shades[(rng.nextInt(4) + (center.dy < point.dy - radius ? 1 : 0))
                  .clamp(0, 4)],
      );
      canvas.restore();
    }

    _grass(canvas, point.translate(-radius * 0.72, 1));
    _grass(canvas, point.translate(radius * 0.67, 1));
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

class PotagerShrub {
  const PotagerShrub(this.anchor, this.radius, this.variant);

  final Offset anchor;
  final double radius;
  final int variant;
}

import 'dart:math' as math;

import 'package:flutter/material.dart';

/// A perceptual landscape mass may contain several reusable scene elements.
/// Its ground layer joins their contacts; the scene still depth-sorts each
/// upright element by its own contact point.
class LandscapeMass {
  const LandscapeMass({required this.shrubs, this.rocks = const []});

  final List<LandscapeShrub> shrubs;
  final List<LandscapeRock> rocks;
}

class LandscapeShrub {
  const LandscapeShrub(this.anchor, this.radius, this.variant);

  final Offset anchor;
  final double radius;
  final ShrubPalette variant;
}

enum ShrubPalette { moss, sage, olive }

class LandscapeRock {
  const LandscapeRock(this.anchor, this.width);

  final Offset anchor;
  final double width;
}

class LandscapeMassPainter {
  const LandscapeMassPainter._();

  static void drawGround(Canvas canvas, LandscapeMass mass) {
    if (mass.shrubs.isEmpty) return;
    final wash = Paint()
      ..color = const Color(0x4665884E)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 30
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final trace = Path()
      ..moveTo(mass.shrubs.first.anchor.dx, mass.shrubs.first.anchor.dy);
    for (final shrub in mass.shrubs.skip(1)) {
      trace.lineTo(shrub.anchor.dx, shrub.anchor.dy);
    }
    canvas.drawPath(trace, wash);
    for (final shrub in mass.shrubs) {
      canvas.drawOval(
        Rect.fromCenter(
          center: shrub.anchor.translate(0, 3),
          width: shrub.radius * 2.8,
          height: shrub.radius * 0.9,
        ),
        Paint()..color = const Color(0x36587E47),
      );
    }
  }

  static void drawShrub(Canvas canvas, LandscapeShrub shrub) {
    final point = shrub.anchor;
    final radius = shrub.radius;
    final seed = point.dx.round() * 43 + point.dy.round() * 17;
    final rng = math.Random(seed);
    canvas.drawOval(
      Rect.fromCenter(
        center: point.translate(2, 3),
        width: radius * 2.4,
        height: radius * 0.6,
      ),
      Paint()..color = const Color(0x30506743),
    );

    // An irregular, continuous canopy keeps neighboring shrubs from reading
    // as a repeated row of circles.
    canvas.save();
    canvas.translate(point.dx, point.dy);
    final sway = switch (shrub.variant) {
      ShrubPalette.moss => 0.0,
      ShrubPalette.sage => -0.09,
      ShrubPalette.olive => 0.08,
    };
    canvas.rotate(sway);
    final canopy = Path()
      ..moveTo(-radius * 1.2, -radius * 0.24)
      ..quadraticBezierTo(
        -radius * 1.28,
        -radius * 0.85,
        -radius * 0.76,
        -radius * 0.89,
      )
      ..quadraticBezierTo(
        -radius * 0.49,
        -radius * 1.40,
        -radius * 0.14,
        -radius * 1.17,
      )
      ..quadraticBezierTo(
        radius * 0.27,
        -radius * 1.49,
        radius * 0.58,
        -radius * 1.05,
      )
      ..quadraticBezierTo(
        radius * 1.08,
        -radius * 1.07,
        radius * 1.19,
        -radius * 0.43,
      )
      ..quadraticBezierTo(
        radius * 1.32,
        -radius * 0.13,
        radius * 0.68,
        -radius * 0.13,
      )
      ..quadraticBezierTo(0, radius * 0.07, -radius * 0.71, -radius * 0.11)
      ..close();
    canvas.drawPath(
      canopy,
      Paint()
        ..color = switch (shrub.variant) {
          ShrubPalette.moss => const Color(0xFF617B52),
          ShrubPalette.sage => const Color(0xFF6B8358),
          ShrubPalette.olive => const Color(0xFF58734D),
        },
    );
    canvas.drawPath(
      Path()
        ..moveTo(-radius * 0.99, -radius * 0.42)
        ..quadraticBezierTo(
          -radius * 1.05,
          -radius * 0.92,
          -radius * 0.58,
          -radius * 0.93,
        )
        ..quadraticBezierTo(
          -radius * 0.23,
          -radius * 1.20,
          radius * 0.13,
          -radius * 0.94,
        )
        ..quadraticBezierTo(
          radius * 0.35,
          -radius * 0.76,
          radius * 0.09,
          -radius * 0.66,
        )
        ..quadraticBezierTo(
          -radius * 0.24,
          -radius * 0.75,
          -radius * 0.47,
          -radius * 0.48,
        )
        ..close(),
      Paint()..color = const Color(0x537FA16A),
    );
    canvas.restore();

    // Sparse matte patches imply leaves without granular noise.
    const leaves = [Color(0xFF829D6A), Color(0xFF91A976), Color(0xFF77945F)];
    const leafCount = 11;
    for (var index = 0; index < leafCount; index++) {
      final angle = rng.nextDouble() * math.pi * 2;
      final distance = math.sqrt(rng.nextDouble());
      final center = point.translate(
        math.cos(angle) * distance * radius * 0.96,
        -radius * 0.64 + math.sin(angle) * distance * radius * 0.46,
      );
      canvas.save();
      canvas.translate(center.dx, center.dy);
      canvas.rotate((rng.nextDouble() - 0.5) * 1.0);
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset.zero,
          width: 7.0 + rng.nextDouble() * 3.0,
          height: 3.5,
        ),
        Paint()..color = leaves[index % leaves.length].withValues(alpha: 0.32),
      );
      canvas.restore();
    }
  }

  static void drawRock(Canvas canvas, LandscapeRock rock) {
    final p = rock.anchor;
    final w = rock.width;
    canvas.drawOval(
      Rect.fromCenter(
        center: p.translate(2, 3),
        width: w * 1.15,
        height: w * 0.34,
      ),
      Paint()..color = const Color(0x36546D48),
    );
    final shape = Path()
      ..moveTo(p.dx - w * 0.52, p.dy)
      ..lineTo(p.dx - w * 0.37, p.dy - w * 0.31)
      ..lineTo(p.dx + w * 0.08, p.dy - w * 0.42)
      ..lineTo(p.dx + w * 0.45, p.dy - w * 0.23)
      ..lineTo(p.dx + w * 0.54, p.dy)
      ..close();
    canvas.drawPath(shape, Paint()..color = const Color(0xFF9BA18A));
    canvas.drawPath(
      Path()
        ..moveTo(p.dx - w * 0.52, p.dy)
        ..lineTo(p.dx - w * 0.37, p.dy - w * 0.31)
        ..lineTo(p.dx + w * 0.08, p.dy - w * 0.42)
        ..lineTo(p.dx + w * 0.02, p.dy - w * 0.1)
        ..close(),
      Paint()..color = const Color(0xFFC5C8AC),
    );
  }
}

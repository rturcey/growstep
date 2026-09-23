import 'dart:async';
import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Transparent, independently replaceable garden assets. The alpha bounds are
/// recorded at production time so generous source margins do not affect scale.
class GardenSprites {
  final Map<String, _SpriteImage> _images = {};

  Future<void> load() async {
    final manifest = jsonDecode(
      await rootBundle.loadString('assets/sprites/manifest.json'),
    ) as Map<String, dynamic>;
    const firstFrame = {
      'commun_parcelle_bois_vide_ordinaire_00.png',
      'commun_dalle_pierre_creme_ordinaire_00.png',
      'commun_terrain_case_herbe_surface_ordinaire_00.png',
      'commun_terrain_bord_terre_herbe_ordinaire_00.png',
      'potager_plante_tomate_jeune_ordinaire_00.png',
    };
    await Future.wait(
      manifest.entries
          .where((entry) => firstFrame.contains(entry.key))
          .map(_loadEntry),
    );
    unawaited(
      _loadRemaining(
        manifest.entries
            .where((entry) => !firstFrame.contains(entry.key))
            .toList(),
      ),
    );
  }

  Future<void> _loadRemaining(List<MapEntry<String, dynamic>> entries) async {
    for (var index = 0; index < entries.length; index += 4) {
      final end = (index + 4).clamp(0, entries.length);
      await Future.wait(entries.sublist(index, end).map(_loadEntry));
    }
  }

  Future<void> _loadEntry(MapEntry<String, dynamic> entry) async {
    final data = entry.value as Map<String, dynamic>;
    final bytes = await rootBundle.load('assets/sprites/${entry.key}');
    final codec = await ui.instantiateImageCodec(
      bytes.buffer.asUint8List(),
      targetWidth: 512,
    );
    final frame = await codec.getNextFrame();
    codec.dispose();
    final sourceWidth = (data['width'] as num).toDouble();
    final sourceHeight = (data['height'] as num).toDouble();
    final bounds = (data['bbox'] as List<dynamic>)
        .map((value) => (value as num).toDouble())
        .toList();
    final crop = Rect.fromLTRB(
      bounds[0] * frame.image.width / sourceWidth,
      bounds[1] * frame.image.height / sourceHeight,
      bounds[2] * frame.image.width / sourceWidth,
      bounds[3] * frame.image.height / sourceHeight,
    );
    final anchor = data['anchor'] as List<dynamic>?;
    final anchorX = anchor == null
        ? 0.5
        : ((anchor[0] as num).toDouble() - bounds[0]) / (bounds[2] - bounds[0]);
    final anchorY = anchor == null
        ? 1.0
        : ((anchor[1] as num).toDouble() - bounds[1]) / (bounds[3] - bounds[1]);
    _images[entry.key] = _SpriteImage(
      frame.image,
      crop,
      anchorX,
      anchorY,
      data['shadow'] == 'separate_contact',
    );
  }

  bool draw(
    Canvas canvas,
    String name,
    Offset groundAnchor,
    double width,
    double height, {
    double opacity = 1,
  }) {
    final sprite = _images[name];
    if (sprite == null) return false;
    if (sprite.contactShadow) {
      canvas.drawOval(
        Rect.fromCenter(
          center: groundAnchor.translate(2, 1),
          width: width * 0.65,
          height: height * 0.12,
        ),
        Paint()
          ..color = const Color(0x2A53614C)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
      );
    }
    canvas.drawImageRect(
      sprite.image,
      sprite.crop,
      Rect.fromLTWH(
        groundAnchor.dx - width * sprite.anchorX,
        groundAnchor.dy - height * sprite.anchorY,
        width,
        height,
      ),
      Paint()
        ..filterQuality = FilterQuality.medium
        ..color = Color.fromRGBO(255, 255, 255, opacity),
    );
    return true;
  }

  void dispose() {
    for (final sprite in _images.values) {
      sprite.image.dispose();
    }
    _images.clear();
  }
}

class _SpriteImage {
  const _SpriteImage(
    this.image,
    this.crop,
    this.anchorX,
    this.anchorY,
    this.contactShadow,
  );

  final ui.Image image;
  final Rect crop;
  final double anchorX;
  final double anchorY;
  final bool contactShadow;
}

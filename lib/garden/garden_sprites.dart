import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'garden_sprite_metadata.dart';
import 'garden_scene.dart';

/// Transparent, independently replaceable garden assets. The alpha bounds are
/// recorded at production time so generous source margins do not affect scale.
class GardenSprites {
  final Map<String, _SpriteImage> _images = {};

  Future<Map<String, GardenSpriteMetadata>> load() async {
    final source = jsonDecode(
      await rootBundle.loadString('assets/sprites/manifest.json'),
    ) as Map<String, dynamic>;
    final manifest = {
      for (final entry in source.entries)
        entry.key: GardenSpriteMetadata.fromJson(
          entry.value as Map<String, dynamic>,
        ),
    };
    await _loadRemaining(manifest.entries.toList());
    return manifest;
  }

  Future<void> _loadRemaining(
    List<MapEntry<String, GardenSpriteMetadata>> entries,
  ) async {
    for (var index = 0; index < entries.length; index += 4) {
      final end = (index + 4).clamp(0, entries.length);
      await Future.wait(entries.sublist(index, end).map(_loadEntry));
    }
  }

  Future<void> _loadEntry(MapEntry<String, GardenSpriteMetadata> entry) async {
    final metadata = entry.value;
    final bytes = await rootBundle.load('assets/sprites/${entry.key}');
    final codec = await ui.instantiateImageCodec(
      bytes.buffer.asUint8List(),
      targetWidth: 512,
    );
    final frame = await codec.getNextFrame();
    codec.dispose();
    final bounds = metadata.bounds;
    final crop = Rect.fromLTRB(
      bounds.left * frame.image.width / metadata.sourceSize.width,
      bounds.top * frame.image.height / metadata.sourceSize.height,
      bounds.right * frame.image.width / metadata.sourceSize.width,
      bounds.bottom * frame.image.height / metadata.sourceSize.height,
    );
    _images[entry.key] = _SpriteImage(
      frame.image,
      crop,
      bounds.size / 4,
      metadata.visibleAnchor.dx,
      metadata.visibleAnchor.dy,
      metadata.separateContactShadow,
    );
  }

  Size? visibleSize(String name) => _images[name]?.visibleSize;

  bool hasContactShadow(String name) => _images[name]?.contactShadow ?? false;

  void drawContactShadow(
    Canvas canvas,
    Offset contact,
    double width,
    double height, {
    GardenShadow style = GardenShadow.medium,
  }) {
    final (widthFactor, heightFactor, blur) = switch (style) {
      GardenShadow.none => (0.0, 0.0, 0.0),
      GardenShadow.small => (0.45, 0.08, 1.5),
      GardenShadow.medium => (0.65, 0.12, 2.0),
      GardenShadow.large => (0.85, 0.16, 3.0),
      GardenShadow.elongated => (1.15, 0.10, 2.5),
    };
    if (style == GardenShadow.none) return;
    canvas.drawOval(
      Rect.fromCenter(
        center: contact.translate(2, 1),
        width: width * widthFactor,
        height: height * heightFactor,
      ),
      Paint()
        ..color = const Color(0x2A53614C)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, blur),
    );
  }

  bool draw(
    Canvas canvas,
    String name,
    Offset groundAnchor,
    double width,
    double height, {
    double opacity = 1,
    bool includeContactShadow = true,
    ColorFilter? colorFilter,
  }) {
    final sprite = _images[name];
    if (sprite == null) return false;
    if (includeContactShadow && sprite.contactShadow) {
      drawContactShadow(canvas, groundAnchor, width, height);
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
        ..color = Color.fromRGBO(255, 255, 255, opacity)
        ..colorFilter = colorFilter,
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
    this.visibleSize,
    this.anchorX,
    this.anchorY,
    this.contactShadow,
  );

  final ui.Image image;
  final Rect crop;
  final Size visibleSize;
  final double anchorX;
  final double anchorY;
  final bool contactShadow;
}

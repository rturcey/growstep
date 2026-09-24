import 'dart:ui';

/// The fixed logical canvas shared by composition, rendering, and hit tests.
class GardenArtboardTransform {
  const GardenArtboardTransform(this.viewport);

  static const width = 390.0;
  static const height = 450.0;
  static const fixedScale = 1.0;

  final Size viewport;

  double get scale => fixedScale;
  Offset get origin => Offset(
    (viewport.width - width * scale) / 2,
    (viewport.height - height * scale) / 2,
  );

  Offset toArtboard(Offset point) => (point - origin) / scale;
  Offset toViewport(Offset point) => origin + point * scale;

  void apply(Canvas canvas) {
    canvas.translate(origin.dx, origin.dy);
    canvas.scale(scale);
  }
}

/// Fixed ground and path phases precede the shared Y-sorted depth phase.
enum GardenLayer { ground, path, depth, foreground }

/// Common depth data for legacy draw calls and declarative sprite objects.
class GardenPlacedObject {
  const GardenPlacedObject(this.id, this.contact, {this.zBias = 0});

  final String id;
  final Offset contact;
  final double zBias;
  GardenLayer get layer => GardenLayer.depth;
  double get depth => contact.dy + zBias;
}

/// A visual object has no hit target or gameplay callback.
class GardenSpriteObject extends GardenPlacedObject {
  const GardenSpriteObject({
    required String id,
    required this.asset,
    required Offset contact,
    required this.size,
    required this.layer,
    this.opacity = 1,
    double zBias = 0,
  }) : super(id, contact, zBias: zBias);

  final String asset;
  final Size size;
  @override
  final GardenLayer layer;
  final double opacity;
}

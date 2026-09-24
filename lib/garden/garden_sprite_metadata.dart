import 'dart:ui';

/// Geometry from the sprite manifest, shared by image drawing and Tiled props.
class GardenSpriteMetadata {
  const GardenSpriteMetadata({
    required this.sourceSize,
    required this.bounds,
    required this.groundAnchor,
    required this.separateContactShadow,
  });

  final Size sourceSize;
  final Rect bounds;
  final Offset groundAnchor;
  final bool separateContactShadow;

  factory GardenSpriteMetadata.fromJson(Map<String, dynamic> data) {
    final boundsValues = (data['bbox'] as List<dynamic>)
        .map((value) => (value as num).toDouble())
        .toList();
    final bounds = Rect.fromLTRB(
      boundsValues[0],
      boundsValues[1],
      boundsValues[2],
      boundsValues[3],
    );
    final anchorValues = data['anchor'] as List<dynamic>?;
    return GardenSpriteMetadata(
      sourceSize: Size(
        (data['width'] as num).toDouble(),
        (data['height'] as num).toDouble(),
      ),
      bounds: bounds,
      groundAnchor: anchorValues == null
          ? Offset(bounds.center.dx, bounds.bottom)
          : Offset(
              (anchorValues[0] as num).toDouble(),
              (anchorValues[1] as num).toDouble(),
            ),
      separateContactShadow: data['shadow'] == 'separate_contact',
    );
  }

  /// Where the manifest ground anchor lies within the cropped visible image.
  Offset get visibleAnchor => Offset(
    (groundAnchor.dx - bounds.left) / bounds.width,
    (groundAnchor.dy - bounds.top) / bounds.height,
  );

  Size visibleSizeAt(Size fullImageSize) => Size(
    bounds.width * fullImageSize.width / sourceSize.width,
    bounds.height * fullImageSize.height / sourceSize.height,
  );

  /// Offset from Tiled's full-image bottom-center to the manifest contact.
  Offset bottomCenterToGroundAt(Size fullImageSize) => Offset(
    (groundAnchor.dx - sourceSize.width / 2) *
        fullImageSize.width /
        sourceSize.width,
    (groundAnchor.dy - sourceSize.height) *
        fullImageSize.height /
        sourceSize.height,
  );
}

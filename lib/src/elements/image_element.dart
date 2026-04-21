import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:meta/meta.dart';

import '../contracts/print_context.dart';
import '../contracts/print_element.dart';
import '../exceptions.dart';

/// Paints a raster image within the receipt.
@immutable
class ImageElement extends PrintElement {
  /// Creates a new [ImageElement] from encoded image bytes.
  const ImageElement.memory(
    Uint8List this.bytes, {
    this.fit,
    this.width,
    this.height,
  }) : assetPath = null,
       image = null;

  /// Creates a new [ImageElement] from an asset path.
  const ImageElement.asset(
    String this.assetPath, {
    this.fit,
    this.width,
    this.height,
  }) : bytes = null,
       image = null;

  /// Creates a new [ImageElement] from an already-decoded [ui.Image].
  const ImageElement.image(
    ui.Image this.image, {
    this.fit,
    this.width,
    this.height,
  }) : bytes = null,
       assetPath = null;

  /// Raw encoded image bytes.
  final Uint8List? bytes;

  /// An asset path resolved through [rootBundle].
  final String? assetPath;

  /// An already-decoded image.
  final ui.Image? image;

  /// The fitting mode applied when the image must scale into a box.
  final BoxFit? fit;

  /// An optional explicit target width in dots.
  final double? width;

  /// An optional explicit target height in dots.
  final double? height;

  static final Map<int, _ResolvedImage> _resolvedImages =
      <int, _ResolvedImage>{};

  /// Pre-decodes this element's image source for synchronous layout and paint.
  static Future<void> precache(ImageElement element) async {
    final int key = identityHashCode(element);
    if (_resolvedImages.containsKey(key)) {
      return;
    }

    if (element.image case final ui.Image decodedImage?) {
      _resolvedImages[key] = _ResolvedImage(decodedImage, false);
      return;
    }

    final Uint8List sourceBytes;
    if (element.bytes case final Uint8List rawBytes?) {
      sourceBytes = rawBytes;
    } else if (element.assetPath case final String path?) {
      final ByteData byteData = await rootBundle.load(path);
      sourceBytes = byteData.buffer.asUint8List();
    } else {
      throw const ValidationException(
        'ImageElement requires bytes, an asset path, or a decoded image.',
      );
    }

    final ui.Codec codec = await ui.instantiateImageCodec(sourceBytes);
    final ui.FrameInfo frame = await codec.getNextFrame();
    _resolvedImages[key] = _ResolvedImage(frame.image, true);
  }

  /// Releases any decoded image owned by this element.
  static void release(ImageElement element) {
    final _ResolvedImage? resolved = _resolvedImages.remove(
      identityHashCode(element),
    );
    if (resolved != null && resolved.isOwned) {
      resolved.image.dispose();
    }
  }

  @override
  Size measure(BoxConstraints constraints, PrintContext context) {
    final _ResolvedImage resolved = _resolveImage();
    final Size targetSize = _layoutSize(
      constraints,
      resolved.image.width.toDouble(),
      resolved.image.height.toDouble(),
    );
    return constraints.constrain(targetSize);
  }

  @override
  void paint(ui.Canvas canvas, ui.Size size, PrintContext context) {
    final _ResolvedImage resolved = _resolveImage();
    final ui.Rect source =
        ui.Offset.zero &
        ui.Size(
          resolved.image.width.toDouble(),
          resolved.image.height.toDouble(),
        );
    final ui.Rect destination = ui.Offset.zero & size;
    canvas.drawImageRect(resolved.image, source, destination, ui.Paint());
  }

  _ResolvedImage _resolveImage() {
    final _ResolvedImage? resolved = _resolvedImages[identityHashCode(this)];
    if (resolved == null) {
      throw const ValidationException(
        'ImageElement has not been precached. Use Receipt.rasterize() or Receipt.printTo().',
      );
    }
    return resolved;
  }

  Size _layoutSize(
    BoxConstraints constraints,
    double intrinsicWidth,
    double intrinsicHeight,
  ) {
    final double aspectRatio = intrinsicWidth / intrinsicHeight;

    Size preferredSize;
    if (width != null && height != null) {
      preferredSize = Size(width!, height!);
    } else if (width != null) {
      preferredSize = Size(width!, width! / aspectRatio);
    } else if (height != null) {
      preferredSize = Size(height! * aspectRatio, height!);
    } else {
      preferredSize = Size(intrinsicWidth, intrinsicHeight);
    }

    if (fit == null) {
      if (width == null &&
          height == null &&
          constraints.hasBoundedWidth &&
          intrinsicWidth > constraints.maxWidth) {
        throw ValidationException(
          'Image width ${intrinsicWidth.toInt()} exceeds the paper width '
          '${constraints.maxWidth.toInt()} and no fit was provided.',
        );
      }
      return constraints.constrain(preferredSize);
    }

    final Size boundingBox = Size(
      width ??
          (constraints.hasBoundedWidth
              ? constraints.maxWidth
              : preferredSize.width),
      height ??
          (constraints.hasBoundedHeight
              ? constraints.maxHeight
              : preferredSize.height),
    );
    final FittedSizes fitted = applyBoxFit(
      fit!,
      Size(intrinsicWidth, intrinsicHeight),
      boundingBox,
    );

    final Size destination = Size(
      math.min(
        fitted.destination.width,
        constraints.hasBoundedWidth
            ? constraints.maxWidth
            : fitted.destination.width,
      ),
      math.min(
        fitted.destination.height,
        constraints.hasBoundedHeight
            ? constraints.maxHeight
            : fitted.destination.height,
      ),
    );
    return constraints.constrain(destination);
  }
}

class _ResolvedImage {
  const _ResolvedImage(this.image, this.isOwned);

  final ui.Image image;
  final bool isOwned;
}

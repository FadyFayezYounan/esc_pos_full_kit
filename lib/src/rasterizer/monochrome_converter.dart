import 'dart:typed_data';

/// Dithering mode for monochrome conversion.
enum DitherMode {
  /// Enable dithering only when raster images are present.
  auto,

  /// Use simple thresholding.
  off,

  /// Use Floyd-Steinberg error diffusion.
  on,
}

/// Converts RGBA image data into packed 1-bit monochrome bytes.
abstract final class MonochromeConverter {
  /// Converts [rgbaBytes] into packed monochrome bits.
  static Uint8List convert(
    ByteData rgbaBytes,
    int widthPixels,
    int heightPixels, {
    required DitherMode mode,
  }) {
    assert(
      mode != DitherMode.auto,
      'Resolve DitherMode.auto before conversion.',
    );

    final int widthBytes = (widthPixels + 7) >> 3;
    final Uint8List output = Uint8List(widthBytes * heightPixels);

    switch (mode) {
      case DitherMode.off:
        _applyThreshold(
          rgbaBytes,
          output,
          widthPixels: widthPixels,
          heightPixels: heightPixels,
          widthBytes: widthBytes,
        );
      case DitherMode.on:
        _applyFloydSteinberg(
          rgbaBytes,
          output,
          widthPixels: widthPixels,
          heightPixels: heightPixels,
          widthBytes: widthBytes,
        );
      case DitherMode.auto:
        throw StateError('DitherMode.auto must be resolved before conversion.');
    }

    return output;
  }

  static void _applyThreshold(
    ByteData rgbaBytes,
    Uint8List output, {
    required int widthPixels,
    required int heightPixels,
    required int widthBytes,
  }) {
    for (int y = 0; y < heightPixels; y += 1) {
      for (int x = 0; x < widthPixels; x += 1) {
        if (_luminanceAt(rgbaBytes, x, y, widthPixels) < 128) {
          output[(y * widthBytes) + (x >> 3)] |= 0x80 >> (x & 7);
        }
      }
    }
  }

  static void _applyFloydSteinberg(
    ByteData rgbaBytes,
    Uint8List output, {
    required int widthPixels,
    required int heightPixels,
    required int widthBytes,
  }) {
    final Float64List luminance = Float64List(widthPixels * heightPixels);

    for (int y = 0; y < heightPixels; y += 1) {
      for (int x = 0; x < widthPixels; x += 1) {
        luminance[(y * widthPixels) + x] = _luminanceAt(
          rgbaBytes,
          x,
          y,
          widthPixels,
        );
      }
    }

    for (int y = 0; y < heightPixels; y += 1) {
      final bool leftToRight = y.isEven;
      final int startX = leftToRight ? 0 : widthPixels - 1;
      final int endX = leftToRight ? widthPixels : -1;
      final int step = leftToRight ? 1 : -1;

      for (int x = startX; x != endX; x += step) {
        final int index = (y * widthPixels) + x;
        final double oldValue = luminance[index];
        final double newValue = oldValue < 128 ? 0 : 255;
        final double error = oldValue - newValue;

        if (newValue == 0) {
          output[(y * widthBytes) + (x >> 3)] |= 0x80 >> (x & 7);
        }

        if (leftToRight) {
          _diffuse(
            luminance,
            widthPixels,
            heightPixels,
            x + 1,
            y,
            error * 7 / 16,
          );
          _diffuse(
            luminance,
            widthPixels,
            heightPixels,
            x - 1,
            y + 1,
            error * 3 / 16,
          );
          _diffuse(
            luminance,
            widthPixels,
            heightPixels,
            x,
            y + 1,
            error * 5 / 16,
          );
          _diffuse(
            luminance,
            widthPixels,
            heightPixels,
            x + 1,
            y + 1,
            error * 1 / 16,
          );
        } else {
          _diffuse(
            luminance,
            widthPixels,
            heightPixels,
            x - 1,
            y,
            error * 7 / 16,
          );
          _diffuse(
            luminance,
            widthPixels,
            heightPixels,
            x + 1,
            y + 1,
            error * 3 / 16,
          );
          _diffuse(
            luminance,
            widthPixels,
            heightPixels,
            x,
            y + 1,
            error * 5 / 16,
          );
          _diffuse(
            luminance,
            widthPixels,
            heightPixels,
            x - 1,
            y + 1,
            error * 1 / 16,
          );
        }
      }
    }
  }

  static void _diffuse(
    Float64List luminance,
    int widthPixels,
    int heightPixels,
    int x,
    int y,
    double amount,
  ) {
    if (x < 0 || y < 0 || x >= widthPixels || y >= heightPixels) {
      return;
    }
    final int index = (y * widthPixels) + x;
    luminance[index] = (luminance[index] + amount).clamp(0, 255);
  }

  static double _luminanceAt(
    ByteData rgbaBytes,
    int x,
    int y,
    int widthPixels,
  ) {
    final int index = ((y * widthPixels) + x) * 4;
    final double red = rgbaBytes.getUint8(index).toDouble();
    final double green = rgbaBytes.getUint8(index + 1).toDouble();
    final double blue = rgbaBytes.getUint8(index + 2).toDouble();
    final double alpha = rgbaBytes.getUint8(index + 3) / 255.0;

    final double blendedRed = 255 - ((255 - red) * alpha);
    final double blendedGreen = 255 - ((255 - green) * alpha);
    final double blendedBlue = 255 - ((255 - blue) * alpha);

    return (0.299 * blendedRed) +
        (0.587 * blendedGreen) +
        (0.114 * blendedBlue);
  }
}

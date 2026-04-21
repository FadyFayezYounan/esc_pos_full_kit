import 'dart:developer' as developer;
import 'dart:math' as math;
import 'dart:typed_data';

import '../contracts/printer_profile.dart';
import '../exceptions.dart';
import '../receipt/receipt.dart';

/// Stateless helpers for assembling ESC/POS byte streams.
abstract final class EscPosEncoder {
  /// ESC @
  static const List<int> init = <int>[0x1B, 0x40];

  /// ESC d n
  static List<int> feed(int lines) => <int>[0x1B, 0x64, lines.clamp(0, 255)];

  /// GS V 0
  static List<int> cutFull() => const <int>[0x1D, 0x56, 0x00];

  /// GS V 1
  static List<int> cutPartial() => const <int>[0x1D, 0x56, 0x01];

  /// ESC p
  static List<int> openDrawer({int pin = 0, int t1 = 25, int t2 = 250}) {
    return <int>[0x1B, 0x70, pin & 0x01, t1 & 0xFF, t2 & 0xFF];
  }

  /// ESC B
  static List<int> beep(int times, int duration) {
    return <int>[0x1B, 0x42, times.clamp(0, 255), duration.clamp(0, 255)];
  }

  /// GS v 0 raster bit image for a single band.
  static List<int> rasterBand({
    required int widthBytes,
    required int heightRows,
    required List<int> bits,
    int mode = 0,
  }) {
    return <int>[
      0x1D,
      0x76,
      0x30,
      mode & 0xFF,
      widthBytes & 0xFF,
      (widthBytes >> 8) & 0xFF,
      heightRows & 0xFF,
      (heightRows >> 8) & 0xFF,
      ...bits,
    ];
  }

  /// Builds the full ESC/POS stream for [receipt].
  static List<int> assembleReceipt(
    RasterizedReceipt rasterizedReceipt,
    PrinterProfile profile,
    Receipt receipt,
  ) {
    if (!profile.features.bitImageRaster) {
      throw UnsupportedFeatureException(
        'Printer profile "${profile.id}" does not support GS v 0 raster images.',
      );
    }

    final BytesBuilder builder = BytesBuilder(copy: false);
    builder.add(init);

    const int maxBandRows = 255;
    for (
      int row = 0;
      row < rasterizedReceipt.heightPixels;
      row += maxBandRows
    ) {
      final int bandRows = math.min(
        maxBandRows,
        rasterizedReceipt.heightPixels - row,
      );
      final int start = row * rasterizedReceipt.widthBytes;
      final int end = start + (bandRows * rasterizedReceipt.widthBytes);
      builder.add(
        rasterBand(
          widthBytes: rasterizedReceipt.widthBytes,
          heightRows: bandRows,
          bits: rasterizedReceipt.monochromeBits.sublist(start, end),
        ),
      );
    }

    if (receipt.cut) {
      builder.add(feed(receipt.feedBeforeCut));
      if (profile.features.paperFullCut) {
        builder.add(cutFull());
      } else if (profile.features.paperPartCut) {
        builder.add(cutPartial());
      } else {
        _handleOptionalFeature(
          receipt.strictFeatures,
          'Printer profile "${profile.id}" does not support paper cutting.',
        );
      }
    }

    if (receipt.openDrawer) {
      if (profile.features.pulseStandard) {
        builder.add(openDrawer());
      } else {
        _handleOptionalFeature(
          receipt.strictFeatures,
          'Printer profile "${profile.id}" does not support the drawer pulse command.',
        );
      }
    }

    if (receipt.beep) {
      if (profile.features.pulseBel) {
        builder.add(beep(1, 3));
      } else {
        _handleOptionalFeature(
          receipt.strictFeatures,
          'Printer profile "${profile.id}" does not support the beep command.',
        );
      }
    }

    return builder.takeBytes();
  }

  static void _handleOptionalFeature(bool strict, String message) {
    if (strict) {
      throw UnsupportedFeatureException(message);
    }
    developer.log(message, name: 'esc_pos_full_kit.features');
  }
}

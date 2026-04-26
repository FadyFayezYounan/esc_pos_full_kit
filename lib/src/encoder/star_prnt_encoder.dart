import 'dart:developer' as developer;
import 'dart:math' as math;
import 'dart:typed_data';

import '../contracts/printer_profile.dart';
import '../exceptions.dart';
import '../receipt/receipt.dart';

/// Stateless helpers for assembling StarPRNT byte streams.
abstract final class StarPrntEncoder {
  /// ESC @
  static const List<int> init = <int>[0x1B, 0x40];

  /// ESC a n
  static List<int> feed(int lines) => <int>[0x1B, 0x61, lines.clamp(0, 255)];

  /// ESC d 0
  static List<int> cutFull() => const <int>[0x1B, 0x64, 0x00];

  /// ESC d 1
  static List<int> cutPartial() => const <int>[0x1B, 0x64, 0x01];

  /// ESC BEL n1 n2
  static List<int> setExternalDevicePulse({
    int energizing = 20,
    int delay = 20,
  }) {
    return <int>[0x1B, 0x07, energizing.clamp(1, 127), delay.clamp(1, 127)];
  }

  /// BEL
  static List<int> openDrawer() => const <int>[0x07];

  /// ESC GS S raster graphics data for a single band.
  static List<int> rasterBand({
    required int widthBytes,
    required int heightRows,
    required List<int> bits,
    int tone = 1,
    int color = 0,
  }) {
    return <int>[
      0x1B,
      0x1D,
      0x53,
      tone & 0xFF,
      widthBytes & 0xFF,
      (widthBytes >> 8) & 0xFF,
      heightRows & 0xFF,
      (heightRows >> 8) & 0xFF,
      color & 0xFF,
      ...bits,
    ];
  }

  /// Builds the full StarPRNT stream for [receipt].
  static List<int> assembleReceipt(
    RasterizedReceipt rasterizedReceipt,
    PrinterProfile profile,
    Receipt receipt,
  ) {
    if (profile.commandDialect != PrinterCommandDialect.starPrnt) {
      throw UnsupportedFeatureException(
        'Printer profile "${profile.id}" does not use StarPRNT commands.',
      );
    }
    if (!profile.features.bitImageRaster) {
      throw UnsupportedFeatureException(
        'Printer profile "${profile.id}" does not support StarPRNT raster images.',
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
        builder.add(setExternalDevicePulse());
        builder.add(openDrawer());
      } else {
        _handleOptionalFeature(
          receipt.strictFeatures,
          'Printer profile "${profile.id}" does not support the drawer pulse command.',
        );
      }
    }

    if (receipt.beep) {
      _handleOptionalFeature(
        receipt.strictFeatures,
        'Printer profile "${profile.id}" does not support the beep command.',
      );
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

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
  static List<int> feed(int lines) => <int>[
    0x1B,
    0x61,
    lines.clamp(1, 127).toInt(),
  ];

  /// ESC d 0
  static List<int> cutFull() => const <int>[0x1B, 0x64, 0x00];

  /// ESC d 1
  static List<int> cutPartial() => const <int>[0x1B, 0x64, 0x01];

  /// ESC BEL n1 n2, BEL.
  static List<int> openDrawer({int onTime = 20, int offTime = 20}) {
    return <int>[
      0x1B,
      0x07,
      onTime.clamp(1, 127).toInt(),
      offTime.clamp(1, 127).toInt(),
      0x07,
    ];
  }

  /// ESC GS S raster graphics data for a single band.
  static List<int> rasterBand({
    required int widthBytes,
    required int heightRows,
    required List<int> bits,
  }) {
    if (widthBytes < 1 || widthBytes > 128) {
      throw RangeError.range(widthBytes, 1, 128, 'widthBytes');
    }
    if (heightRows < 1 || heightRows > 65535) {
      throw RangeError.range(heightRows, 1, 65535, 'heightRows');
    }

    return <int>[
      0x1B,
      0x1D,
      0x53,
      0x01,
      widthBytes & 0xFF,
      (widthBytes >> 8) & 0xFF,
      heightRows & 0xFF,
      (heightRows >> 8) & 0xFF,
      0x00,
      ...bits,
    ];
  }

  /// Builds the full StarPRNT stream for [receipt].
  static List<int> assembleReceipt(
    RasterizedReceipt rasterizedReceipt,
    PrinterProfile profile,
    Receipt receipt,
  ) {
    if (!profile.features.starCommands) {
      throw UnsupportedFeatureException(
        'Printer profile "${profile.id}" does not target StarPRNT commands.',
      );
    }
    if (!profile.features.bitImageRaster) {
      throw UnsupportedFeatureException(
        'Printer profile "${profile.id}" does not support raster images.',
      );
    }

    final BytesBuilder builder = BytesBuilder(copy: false)..add(init);

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
      if (receipt.feedBeforeCut > 0) {
        builder.add(feed(receipt.feedBeforeCut));
      }
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

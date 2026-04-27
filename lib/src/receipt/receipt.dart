import 'dart:typed_data';
import 'dart:ui' show Locale, TextDirection, Image;

import 'package:flutter/painting.dart';
import 'package:meta/meta.dart';

import '../contracts/print_element.dart';
import '../contracts/printer_profile.dart';
import '../contracts/printer_transport.dart';
import '../encoder/receipt_encoder.dart';
import '../rasterizer/monochrome_converter.dart';
import '../rasterizer/receipt_rasterizer.dart';

/// The rasterized output of a [Receipt].
@immutable
class RasterizedReceipt {
  /// Creates a new [RasterizedReceipt].
  const RasterizedReceipt({
    required this.image,
    required this.monochromeBits,
    required this.widthPixels,
    required this.heightPixels,
    required this.widthBytes,
  });

  /// The preview image produced by the rasterizer.
  final Image image;

  /// Packed monochrome bits in row-major order, MSB-first.
  final Uint8List monochromeBits;

  /// The raster width in pixels.
  final int widthPixels;

  /// The raster height in pixels.
  final int heightPixels;

  /// The number of packed bytes per row.
  final int widthBytes;

  /// Releases the preview image backing this rasterized receipt.
  void dispose() {
    image.dispose();
  }
}

/// Immutable receipt configuration and printable content.
@immutable
class Receipt {
  /// Creates a new [Receipt].
  const Receipt({
    required this.children,
    this.padding = EdgeInsets.zero,
    this.cut = true,
    this.feedBeforeCut = 3,
    this.openDrawer = false,
    this.beep = false,
    this.dither = DitherMode.auto,
    this.supersample = 3,
    this.strictFeatures = false,
  }) : assert(feedBeforeCut >= 0, 'feedBeforeCut must be non-negative'),
       assert(supersample >= 1, 'supersample must be >= 1');

  /// The elements that make up this receipt.
  final List<PrintElement> children;

  /// Padding applied around the root column.
  final EdgeInsets padding;

  /// Whether a cut command should be appended after printing.
  final bool cut;

  /// Number of feed lines to emit before cutting.
  final int feedBeforeCut;

  /// Whether to trigger the cash drawer pulse after printing.
  final bool openDrawer;

  /// Whether to emit a beep command after printing.
  final bool beep;

  /// The monochrome conversion strategy.
  final DitherMode dither;

  /// Oversampling factor for rasterization.
  ///
  /// The widget tree is painted at `supersample` times the printer's dot
  /// resolution and then box-filter downsampled back to native resolution
  /// before monochrome conversion. This preserves antialiasing as true
  /// grayscale, which Floyd-Steinberg dithering can turn into crisp output.
  ///
  /// `1` disables supersampling (fastest, matches the pre-quality behavior).
  /// `2`-`4` trade quadratic CPU/memory for sharper glyphs. `3` is the sweet
  /// spot for 203 DPI thermal printers.
  final int supersample;

  /// Whether unsupported optional features should throw instead of logging.
  final bool strictFeatures;

  /// Rasterizes this receipt for the provided [profile].
  Future<RasterizedReceipt> rasterize(
    PrinterProfile profile, {
    Locale? locale,
    TextDirection? textDirection,
  }) {
    return const ReceiptRasterizer().rasterize(
      this,
      profile,
      locale: locale,
      textDirection: textDirection,
    );
  }

  /// Rasterizes, encodes, and sends this receipt through [transport].
  Future<void> printTo(
    PrinterTransport transport,
    PrinterProfile profile, {
    Locale? locale,
    TextDirection? textDirection,
  }) async {
    final RasterizedReceipt rasterizedReceipt = await rasterize(
      profile,
      locale: locale,
      textDirection: textDirection,
    );

    try {
      final List<int> bytes = ReceiptEncoder.assembleReceipt(
        rasterizedReceipt,
        profile,
        this,
      );
      await transport.connect();
      try {
        await transport.write(bytes);
        await transport.flush();
      } finally {
        await transport.disconnect();
      }
    } finally {
      rasterizedReceipt.dispose();
    }
  }
}

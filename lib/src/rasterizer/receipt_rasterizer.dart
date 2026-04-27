import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';

import '../contracts/print_context.dart';
import '../contracts/print_element.dart';
import '../contracts/printer_profile.dart';
import '../elements/align_element.dart';
import '../elements/column_element.dart';
import '../elements/image_element.dart';
import '../elements/padding_element.dart';
import '../elements/row_element.dart';
import '../elements/row_cell.dart';
import '../exceptions.dart';
import '../receipt/receipt.dart';
import 'monochrome_converter.dart';

/// Orchestrates the layout, paint, and monochrome conversion pipeline.
final class ReceiptRasterizer {
  /// Creates a new [ReceiptRasterizer].
  const ReceiptRasterizer();

  /// Rasterizes [receipt] for [profile].
  Future<RasterizedReceipt> rasterize(
    Receipt receipt,
    PrinterProfile profile, {
    ui.Locale? locale,
    ui.TextDirection? textDirection,
  }) async {
    final int? paperWidth = profile.media.widthPixels;
    if (paperWidth == null) {
      throw ValidationException(
        'Printer profile "${profile.id}" does not define a printable width.',
      );
    }
    if (!profile.features.bitImageRaster && !profile.features.bitImageColumn) {
      throw UnsupportedFeatureException(
        'Printer profile "${profile.id}" does not support image printing.',
      );
    }

    final ui.Locale resolvedLocale =
        locale ?? ui.PlatformDispatcher.instance.locale;
    final ui.TextDirection resolvedTextDirection =
        textDirection ?? _defaultTextDirectionForLocale(resolvedLocale);

    final PrintContext context = PrintContext(
      textDirection: resolvedTextDirection,
      locale: resolvedLocale,
      paperPixelWidth: paperWidth,
    );
    final PrintElement root = PaddingElement(
      padding: receipt.padding,
      child: ColumnElement(receipt.children),
    );
    final List<ImageElement> images = _collectImageElements(root);

    try {
      await Future.wait(images.map(ImageElement.precache));
      final Size measuredSize = root.measure(
        BoxConstraints.tightFor(width: paperWidth.toDouble()),
        context,
      );
      final int imageHeight = measuredSize.height.ceil().clamp(1, 1 << 20);

      final int supersample = receipt.supersample < 1 ? 1 : receipt.supersample;
      final int scaledWidth = paperWidth * supersample;
      final int scaledHeight = imageHeight * supersample;

      final ui.PictureRecorder recorder = ui.PictureRecorder();
      final ui.Canvas canvas = ui.Canvas(
        recorder,
        ui.Rect.fromLTWH(0, 0, scaledWidth.toDouble(), scaledHeight.toDouble()),
      );
      if (supersample != 1) {
        canvas.scale(supersample.toDouble());
      }
      canvas.drawColor(context.background, BlendMode.src);
      root.paint(
        canvas,
        Size(paperWidth.toDouble(), measuredSize.height),
        context,
      );

      final ui.Picture picture = recorder.endRecording();
      final ui.Image highResImage;
      try {
        highResImage = await picture.toImage(scaledWidth, scaledHeight);
      } finally {
        picture.dispose();
      }

      final ByteData? highResBytes = await highResImage.toByteData(
        format: ui.ImageByteFormat.rawRgba,
      );
      if (highResBytes == null) {
        highResImage.dispose();
        throw const RasterizationException(
          'Failed to read rasterized image bytes.',
        );
      }

      final ByteData nativeBytes;
      final ui.Image previewImage;
      if (supersample == 1) {
        nativeBytes = highResBytes;
        previewImage = highResImage;
      } else {
        nativeBytes = _downsampleRgbaBoxFilter(
          highResBytes,
          scaledWidth,
          scaledHeight,
          supersample,
        );
        highResImage.dispose();
        previewImage = await _imageFromRgba(
          nativeBytes,
          paperWidth,
          imageHeight,
        );
      }

      final DitherMode mode = _resolveDitherMode(receipt.dither);
      final Uint8List monochromeBits = MonochromeConverter.convert(
        nativeBytes,
        paperWidth,
        imageHeight,
        mode: mode,
      );

      return RasterizedReceipt(
        image: previewImage,
        monochromeBits: monochromeBits,
        widthPixels: paperWidth,
        heightPixels: imageHeight,
        widthBytes: (paperWidth + 7) >> 3,
      );
    } on PrintException {
      rethrow;
    } on Exception catch (error) {
      throw RasterizationException('Failed to rasterize receipt.', error);
    } finally {
      for (final ImageElement image in images) {
        ImageElement.release(image);
      }
    }
  }

  /// Averages each [factor]x[factor] block of [src] into a single destination
  /// pixel, returning RGBA bytes at `srcWidth / factor` by `srcHeight / factor`.
  static ByteData _downsampleRgbaBoxFilter(
    ByteData src,
    int srcWidth,
    int srcHeight,
    int factor,
  ) {
    final int dstWidth = srcWidth ~/ factor;
    final int dstHeight = srcHeight ~/ factor;
    final Uint8List dst = Uint8List(dstWidth * dstHeight * 4);
    final int blockPixels = factor * factor;
    final int srcStride = srcWidth * 4;

    for (int dy = 0; dy < dstHeight; dy += 1) {
      final int srcY0 = dy * factor;
      for (int dx = 0; dx < dstWidth; dx += 1) {
        final int srcX0 = dx * factor;
        int rSum = 0;
        int gSum = 0;
        int bSum = 0;
        int aSum = 0;
        for (int by = 0; by < factor; by += 1) {
          final int rowOffset = (srcY0 + by) * srcStride;
          for (int bx = 0; bx < factor; bx += 1) {
            final int i = rowOffset + ((srcX0 + bx) * 4);
            rSum += src.getUint8(i);
            gSum += src.getUint8(i + 1);
            bSum += src.getUint8(i + 2);
            aSum += src.getUint8(i + 3);
          }
        }
        final int dstIndex = ((dy * dstWidth) + dx) * 4;
        dst[dstIndex] = rSum ~/ blockPixels;
        dst[dstIndex + 1] = gSum ~/ blockPixels;
        dst[dstIndex + 2] = bSum ~/ blockPixels;
        dst[dstIndex + 3] = aSum ~/ blockPixels;
      }
    }

    return ByteData.sublistView(dst);
  }

  static Future<ui.Image> _imageFromRgba(
    ByteData rgba,
    int width,
    int height,
  ) async {
    final ui.ImmutableBuffer buffer = await ui.ImmutableBuffer.fromUint8List(
      rgba.buffer.asUint8List(rgba.offsetInBytes, rgba.lengthInBytes),
    );
    try {
      final ui.ImageDescriptor descriptor = ui.ImageDescriptor.raw(
        buffer,
        width: width,
        height: height,
        pixelFormat: ui.PixelFormat.rgba8888,
      );
      try {
        final ui.Codec codec = await descriptor.instantiateCodec();
        try {
          final ui.FrameInfo frame = await codec.getNextFrame();
          return frame.image;
        } finally {
          codec.dispose();
        }
      } finally {
        descriptor.dispose();
      }
    } finally {
      buffer.dispose();
    }
  }

  DitherMode _resolveDitherMode(DitherMode configuredMode) {
    return switch (configuredMode) {
      DitherMode.auto => DitherMode.on,
      DitherMode.off => DitherMode.off,
      DitherMode.on => DitherMode.on,
    };
  }

  List<ImageElement> _collectImageElements(PrintElement element) {
    final List<ImageElement> images = <ImageElement>[];
    void visit(PrintElement current) {
      if (current is ImageElement) {
        images.add(current);
      }
      for (final PrintElement child in _childElements(current)) {
        visit(child);
      }
    }

    visit(element);
    return images;
  }

  Iterable<PrintElement> _childElements(PrintElement element) {
    return switch (element) {
      ColumnElement(:final List<PrintElement> children) => children,
      PaddingElement(:final PrintElement child) => <PrintElement>[child],
      AlignElement(:final PrintElement child) => <PrintElement>[child],
      RowElement(:final List<RowCell> cells) => cells.map(
        (RowCell cell) => cell.element,
      ),
      CompositeElement(:final List<PrintElement> children) => children,
      _ => const <PrintElement>[],
    };
  }

  ui.TextDirection _defaultTextDirectionForLocale(ui.Locale locale) {
    const Set<String> rtlLanguages = <String>{
      'ar',
      'fa',
      'he',
      'ku',
      'ps',
      'ur',
    };
    return rtlLanguages.contains(locale.languageCode.toLowerCase())
        ? ui.TextDirection.rtl
        : ui.TextDirection.ltr;
  }
}

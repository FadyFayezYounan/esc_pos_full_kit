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
    if (!profile.features.bitImageRaster) {
      throw UnsupportedFeatureException(
        'Printer profile "${profile.id}" does not support raster bit images.',
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

      final ui.PictureRecorder recorder = ui.PictureRecorder();
      final ui.Canvas canvas = ui.Canvas(
        recorder,
        ui.Rect.fromLTWH(0, 0, paperWidth.toDouble(), measuredSize.height),
      );
      canvas.drawColor(context.background, BlendMode.src);
      root.paint(
        canvas,
        Size(paperWidth.toDouble(), measuredSize.height),
        context,
      );

      final ui.Picture picture = recorder.endRecording();
      final ui.Image image = await picture.toImage(paperWidth, imageHeight);
      final ByteData? rgbaBytes = await image.toByteData(
        format: ui.ImageByteFormat.rawRgba,
      );
      if (rgbaBytes == null) {
        image.dispose();
        throw const RasterizationException(
          'Failed to read rasterized image bytes.',
        );
      }

      final DitherMode mode = _resolveDitherMode(receipt.dither, root);
      final Uint8List monochromeBits = MonochromeConverter.convert(
        rgbaBytes,
        paperWidth,
        imageHeight,
        mode: mode,
      );

      return RasterizedReceipt(
        image: image,
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

  DitherMode _resolveDitherMode(DitherMode configuredMode, PrintElement root) {
    return switch (configuredMode) {
      DitherMode.auto => _containsImage(root) ? DitherMode.on : DitherMode.off,
      DitherMode.off => DitherMode.off,
      DitherMode.on => DitherMode.on,
    };
  }

  bool _containsImage(PrintElement element) {
    if (element is ImageElement) {
      return true;
    }
    for (final PrintElement child in _childElements(element)) {
      if (_containsImage(child)) {
        return true;
      }
    }
    return false;
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

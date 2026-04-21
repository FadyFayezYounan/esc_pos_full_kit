import 'dart:math' as math;
import 'package:barcode/barcode.dart' as barcode;
import 'package:flutter/rendering.dart';
import 'package:meta/meta.dart';

import '../contracts/print_context.dart';
import '../contracts/print_element.dart';
import '../exceptions.dart';

/// Supported barcode symbologies for [BarcodeElement].
enum BarcodeElementType {
  /// Code 128.
  code128,

  /// Code 39.
  code39,

  /// EAN-13.
  ean13,

  /// EAN-8.
  ean8,

  /// UPC-A.
  upcA,

  /// UPC-E.
  upcE,

  /// Codabar.
  codabar,

  /// ITF.
  itf,

  /// PDF417.
  pdf417,

  /// Data Matrix.
  dataMatrix,
}

/// Paints a one-dimensional or two-dimensional barcode directly on the canvas.
@immutable
class BarcodeElement extends PrintElement {
  /// Creates a new [BarcodeElement].
  const BarcodeElement(
    this.data, {
    required this.type,
    this.height = 80,
    this.displayValue = true,
    this.textStyle,
  }) : assert(height > 0, 'height must be greater than zero');

  /// The encoded payload.
  final String data;

  /// The barcode symbology to generate.
  final BarcodeElementType type;

  /// The nominal barcode height in dots.
  final double height;

  /// Whether to draw the encoded value below the bars when supported.
  final bool displayValue;

  /// An optional text style for the rendered value.
  final TextStyle? textStyle;

  @override
  Size measure(BoxConstraints constraints, PrintContext context) {
    if (!constraints.hasBoundedWidth) {
      throw const ValidationException(
        'BarcodeElement requires a bounded width during layout.',
      );
    }
    final _BarcodeLayout layout = _createLayout(constraints.maxWidth, context);
    return constraints.constrain(Size(constraints.maxWidth, layout.height));
  }

  @override
  void paint(Canvas canvas, Size size, PrintContext context) {
    final _BarcodeLayout layout = _createLayout(size.width, context);
    final Paint paint = Paint()..color = context.foreground;

    for (final barcode.BarcodeElement element in layout.operations) {
      switch (element) {
        case barcode.BarcodeBar(:final bool black):
          if (!black) {
            continue;
          }
          canvas.drawRect(
            Rect.fromLTWH(
              element.left,
              element.top,
              element.width,
              element.height,
            ),
            paint,
          );
        case barcode.BarcodeText():
          _paintBarcodeText(canvas, element, context);
      }
    }
  }

  _BarcodeLayout _createLayout(double width, PrintContext context) {
    try {
      final List<barcode.BarcodeElement> operations = _resolveBarcode(type)
          .make(
            data,
            width: width,
            height: height,
            drawText: displayValue,
            fontHeight:
                textStyle?.fontSize ??
                math.max(12, context.defaultFontSize * 0.75),
            textPadding: context.pxForMm(0.5),
          )
          .toList(growable: false);

      final double totalHeight = operations.fold<double>(
        height,
        (double maxBottom, barcode.BarcodeElement element) =>
            math.max(maxBottom, element.bottom),
      );

      return _BarcodeLayout(operations: operations, height: totalHeight);
    } on barcode.BarcodeException catch (error) {
      throw ValidationException('Unable to encode barcode "$data".', error);
    }
  }

  void _paintBarcodeText(
    Canvas canvas,
    barcode.BarcodeText element,
    PrintContext context,
  ) {
    final TextStyle resolvedStyle = (textStyle ?? const TextStyle()).copyWith(
      fontSize:
          textStyle?.fontSize ?? math.max(12, context.defaultFontSize * 0.75),
      fontFamily: textStyle?.fontFamily ?? context.defaultFontFamily,
      fontWeight: textStyle?.fontWeight ?? context.defaultFontWeight,
      color: textStyle?.color ?? context.foreground,
    );

    final TextAlign align = switch (element.align) {
      barcode.BarcodeTextAlign.center => TextAlign.center,
      barcode.BarcodeTextAlign.right => TextAlign.right,
      barcode.BarcodeTextAlign.left => TextAlign.left,
    };

    final TextPainter painter = TextPainter(
      text: TextSpan(text: element.text, style: resolvedStyle),
      textAlign: align,
      textDirection: context.textDirection,
      locale: context.locale,
      textScaler: context.textScaler,
    )..layout(minWidth: element.width, maxWidth: element.width);

    painter.paint(canvas, Offset(element.left, element.top));
  }

  barcode.Barcode _resolveBarcode(BarcodeElementType type) {
    return switch (type) {
      BarcodeElementType.code128 => barcode.Barcode.code128(),
      BarcodeElementType.code39 => barcode.Barcode.code39(),
      BarcodeElementType.ean13 => barcode.Barcode.ean13(),
      BarcodeElementType.ean8 => barcode.Barcode.ean8(),
      BarcodeElementType.upcA => barcode.Barcode.upcA(),
      BarcodeElementType.upcE => barcode.Barcode.upcE(),
      BarcodeElementType.codabar => barcode.Barcode.codabar(),
      BarcodeElementType.itf => barcode.Barcode.itf(),
      BarcodeElementType.pdf417 => barcode.Barcode.pdf417(),
      BarcodeElementType.dataMatrix => barcode.Barcode.dataMatrix(),
    };
  }
}

class _BarcodeLayout {
  const _BarcodeLayout({required this.operations, required this.height});

  final List<barcode.BarcodeElement> operations;
  final double height;
}

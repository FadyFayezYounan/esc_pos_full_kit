import 'dart:math' as math;
import 'package:flutter/rendering.dart';
import 'package:meta/meta.dart';
import 'package:qr/qr.dart';

import '../contracts/print_context.dart';
import '../contracts/print_element.dart';
import '../exceptions.dart';

/// Paints a QR code using the `qr` package.
@immutable
class QrCodeElement extends PrintElement {
  /// Creates a new [QrCodeElement].
  const QrCodeElement(
    this.data, {
    this.size = 200,
    this.errorCorrection = QrErrorCorrectLevel.M,
  }) : assert(size > 0, 'size must be greater than zero');

  /// The encoded payload.
  final String data;

  /// The target square size in dots.
  final double size;

  /// The QR error correction level.
  final int errorCorrection;

  @override
  Size measure(BoxConstraints constraints, PrintContext context) {
    final Size constrained = constraints.constrain(Size.square(size));
    final double side = math.min(constrained.width, constrained.height);
    return constraints.constrain(Size.square(side));
  }

  @override
  void paint(Canvas canvas, Size size, PrintContext context) {
    final QrImage image;
    try {
      image = QrImage(
        QrCode.fromData(data: data, errorCorrectLevel: errorCorrection),
      );
    } on Exception catch (error) {
      throw ValidationException('Unable to encode QR data.', error);
    }

    final double moduleSize =
        math.min(size.width, size.height) / image.moduleCount;
    final double actualSide = moduleSize * image.moduleCount;
    final Offset origin = Offset(
      (size.width - actualSide) / 2,
      (size.height - actualSide) / 2,
    );
    final Paint paint = Paint()..color = context.foreground;

    for (int row = 0; row < image.moduleCount; row += 1) {
      for (int column = 0; column < image.moduleCount; column += 1) {
        if (!image.isDark(row, column)) {
          continue;
        }
        canvas.drawRect(
          Rect.fromLTWH(
            origin.dx + (column * moduleSize),
            origin.dy + (row * moduleSize),
            moduleSize,
            moduleSize,
          ),
          paint,
        );
      }
    }
  }
}

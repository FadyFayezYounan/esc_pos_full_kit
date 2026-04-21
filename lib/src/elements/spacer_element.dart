import 'package:flutter/rendering.dart';
import 'package:meta/meta.dart';

import '../contracts/print_context.dart';
import '../contracts/print_element.dart';

/// Inserts fixed vertical whitespace into a receipt.
@immutable
class SpacerElement extends PrintElement {
  /// Creates a new [SpacerElement].
  const SpacerElement({this.height = 0})
    : assert(height >= 0, 'height must be non-negative');

  /// The spacer height in dots.
  final double height;

  @override
  Size measure(BoxConstraints constraints, PrintContext context) {
    return constraints.constrain(
      Size(constraints.hasBoundedWidth ? constraints.maxWidth : 0, height),
    );
  }

  @override
  void paint(Canvas canvas, Size size, PrintContext context) {}
}

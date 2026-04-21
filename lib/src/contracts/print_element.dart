import 'dart:math' as math;
import 'package:flutter/rendering.dart';
import 'package:meta/meta.dart';

import 'print_context.dart';

/// Base contract for every printable element.
@immutable
abstract class PrintElement {
  /// Creates a new [PrintElement].
  const PrintElement();

  /// Reports the size this element needs under [constraints].
  Size measure(BoxConstraints constraints, PrintContext context);

  /// Paints this element within the provided [size].
  void paint(Canvas canvas, Size size, PrintContext context);
}

/// A convenience base class for elements that compose a vertical list of children.
@immutable
abstract class CompositeElement extends PrintElement {
  /// Creates a new [CompositeElement].
  const CompositeElement(this.children);

  /// The children painted by this element.
  final List<PrintElement> children;

  @override
  Size measure(BoxConstraints constraints, PrintContext context) {
    final double maxWidth = constraints.hasBoundedWidth
        ? constraints.maxWidth
        : math.max(
            0,
            children
                .map(
                  (PrintElement child) =>
                      child.measure(constraints.loosen(), context).width,
                )
                .fold<double>(0, math.max),
          );

    double height = 0;
    for (final PrintElement child in children) {
      final Size childSize = child.measure(
        BoxConstraints(maxWidth: maxWidth),
        context,
      );
      height += childSize.height;
    }

    return constraints.constrain(Size(maxWidth, height));
  }

  @override
  void paint(Canvas canvas, Size size, PrintContext context) {
    double dy = 0;
    for (final PrintElement child in children) {
      final Size childSize = child.measure(
        BoxConstraints(maxWidth: size.width),
        context,
      );
      canvas.save();
      canvas.translate(0, dy);
      child.paint(canvas, childSize, context);
      canvas.restore();
      dy += childSize.height;
    }
  }
}

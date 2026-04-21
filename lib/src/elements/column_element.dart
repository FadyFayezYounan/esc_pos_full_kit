import 'dart:math' as math;
import 'package:flutter/rendering.dart';
import 'package:meta/meta.dart';

import '../contracts/print_context.dart';
import '../contracts/print_element.dart';

/// Lays out children vertically from top to bottom.
@immutable
class ColumnElement extends CompositeElement {
  /// Creates a new [ColumnElement].
  const ColumnElement(
    super.children, {
    this.gap = 0,
    this.crossAxisAlignment = CrossAxisAlignment.stretch,
  });

  /// Vertical space inserted between children.
  final double gap;

  /// Horizontal alignment for non-stretched children.
  final CrossAxisAlignment crossAxisAlignment;

  @override
  Size measure(BoxConstraints constraints, PrintContext context) {
    if (children.isEmpty) {
      return constraints.constrain(Size.zero);
    }

    final double availableWidth = constraints.hasBoundedWidth
        ? constraints.maxWidth
        : double.infinity;
    double width = 0;
    double height = gap * math.max(0, children.length - 1);

    for (final PrintElement child in children) {
      final Size childSize = child.measure(
        _childConstraints(constraints, availableWidth),
        context,
      );
      width = math.max(width, childSize.width);
      height += childSize.height;
    }

    final double resolvedWidth = constraints.hasBoundedWidth
        ? constraints.maxWidth
        : width;
    return constraints.constrain(Size(resolvedWidth, height));
  }

  @override
  void paint(Canvas canvas, Size size, PrintContext context) {
    double dy = 0;
    for (final PrintElement child in children) {
      final Size childSize = child.measure(
        _childConstraints(
          BoxConstraints.tightFor(
            width: size.width,
            height: math.max(0, size.height - dy),
          ),
          size.width,
        ),
        context,
      );

      final double dx = switch (crossAxisAlignment) {
        CrossAxisAlignment.center => (size.width - childSize.width) / 2,
        CrossAxisAlignment.end => size.width - childSize.width,
        CrossAxisAlignment.stretch => 0,
        CrossAxisAlignment.baseline => 0,
        CrossAxisAlignment.start => 0,
      };

      canvas.save();
      canvas.translate(dx, dy);
      child.paint(
        canvas,
        crossAxisAlignment == CrossAxisAlignment.stretch
            ? Size(size.width, childSize.height)
            : childSize,
        context,
      );
      canvas.restore();
      dy += childSize.height + gap;
    }
  }

  BoxConstraints _childConstraints(
    BoxConstraints constraints,
    double availableWidth,
  ) {
    if (crossAxisAlignment == CrossAxisAlignment.stretch &&
        availableWidth.isFinite) {
      return BoxConstraints.tightFor(width: availableWidth);
    }
    return BoxConstraints(maxWidth: availableWidth);
  }
}

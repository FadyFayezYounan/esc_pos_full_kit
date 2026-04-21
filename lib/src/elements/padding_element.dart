import 'dart:math' as math;
import 'package:flutter/rendering.dart';
import 'package:meta/meta.dart';

import '../contracts/print_context.dart';
import '../contracts/print_element.dart';

/// Insets a child by a fixed amount of padding.
@immutable
class PaddingElement extends PrintElement {
  /// Creates a new [PaddingElement].
  const PaddingElement({required this.child, this.padding = EdgeInsets.zero});

  /// The child element to inset.
  final PrintElement child;

  /// Empty space around the child.
  final EdgeInsets padding;

  @override
  Size measure(BoxConstraints constraints, PrintContext context) {
    final Size childSize = child.measure(constraints.deflate(padding), context);
    return constraints.constrain(
      Size(
        childSize.width + padding.horizontal,
        childSize.height + padding.vertical,
      ),
    );
  }

  @override
  void paint(Canvas canvas, Size size, PrintContext context) {
    final Size availableSize = Size(
      math.max(0, size.width - padding.horizontal),
      math.max(0, size.height - padding.vertical),
    );
    final Size childSize = child.measure(
      BoxConstraints(maxWidth: availableSize.width),
      context,
    );

    canvas.save();
    canvas.translate(padding.left, padding.top);
    child.paint(canvas, childSize, context);
    canvas.restore();
  }
}

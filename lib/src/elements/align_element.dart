import 'package:flutter/rendering.dart';
import 'package:meta/meta.dart';

import '../contracts/print_context.dart';
import '../contracts/print_element.dart';

/// Positions a child within the available box using an [Alignment].
@immutable
class AlignElement extends PrintElement {
  /// Creates a new [AlignElement].
  const AlignElement({required this.child, this.alignment = Alignment.center});

  /// The child element being positioned.
  final PrintElement child;

  /// The alignment applied to the child within this element's bounds.
  final Alignment alignment;

  @override
  Size measure(BoxConstraints constraints, PrintContext context) {
    final Size childSize = child.measure(constraints.loosen(), context);
    final double width = constraints.hasBoundedWidth
        ? constraints.maxWidth
        : childSize.width;
    final double height = constraints.hasBoundedHeight
        ? constraints.maxHeight
        : childSize.height;
    return constraints.constrain(Size(width, height));
  }

  @override
  void paint(Canvas canvas, Size size, PrintContext context) {
    final Size childSize = child.measure(BoxConstraints.loose(size), context);
    final Rect rect = alignment.inscribe(childSize, Offset.zero & size);

    canvas.save();
    canvas.translate(rect.left, rect.top);
    child.paint(canvas, rect.size, context);
    canvas.restore();
  }
}

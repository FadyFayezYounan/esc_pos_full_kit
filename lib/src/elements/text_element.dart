import 'package:flutter/rendering.dart';
import 'package:meta/meta.dart';

import '../contracts/print_context.dart';
import '../contracts/print_element.dart';

/// A printable text block rendered with Flutter's text engine.
@immutable
class TextElement extends PrintElement {
  /// Creates a new [TextElement].
  const TextElement(
    this.text, {
    this.style,
    this.textAlign = TextAlign.left,
    this.maxLines,
    this.textDirection,
  });

  /// The text content to paint.
  final String text;

  /// An optional style override.
  final TextStyle? style;

  /// The text alignment inside the available width.
  final TextAlign textAlign;

  /// An optional line limit.
  final int? maxLines;

  /// Overrides [PrintContext.textDirection] for this element only.
  final TextDirection? textDirection;

  @override
  Size measure(BoxConstraints constraints, PrintContext context) {
    final double availableWidth = constraints.hasBoundedWidth
        ? constraints.maxWidth
        : double.infinity;
    final TextPainter painter = _createPainter(availableWidth, context);
    final double width = constraints.hasBoundedWidth
        ? constraints.maxWidth
        : painter.width;
    return constraints.constrain(Size(width, painter.height));
  }

  @override
  void paint(Canvas canvas, Size size, PrintContext context) {
    _createPainter(size.width, context).paint(canvas, Offset.zero);
  }

  TextPainter _createPainter(double width, PrintContext context) {
    final TextStyle resolvedStyle = (style ?? const TextStyle()).copyWith(
      fontSize: style?.fontSize ?? context.defaultFontSize,
      fontFamily: style?.fontFamily ?? context.defaultFontFamily,
      fontWeight: style?.fontWeight ?? context.defaultFontWeight,
      color: style?.color ?? context.foreground,
    );

    final TextPainter painter = TextPainter(
      text: TextSpan(text: text, style: resolvedStyle),
      textAlign: textAlign,
      textDirection: textDirection ?? context.textDirection,
      locale: context.locale,
      maxLines: maxLines,
      ellipsis: maxLines == null ? null : '\u2026',
      textScaler: context.textScaler,
    );

    if (width.isFinite) {
      painter.layout(minWidth: width, maxWidth: width);
    } else {
      painter.layout();
    }

    return painter;
  }
}

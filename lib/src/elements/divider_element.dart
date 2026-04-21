import 'dart:math' as math;
import 'package:flutter/rendering.dart';
import 'package:meta/meta.dart';

import '../contracts/print_context.dart';
import '../contracts/print_element.dart';
import 'text_element.dart';

/// The visual style for a line divider.
enum DashStyle {
  /// A continuous rule.
  solid,

  /// Repeating rectangular dashes.
  dashed,

  /// Repeating dots.
  dotted,
}

/// Draws a horizontal divider.
@immutable
class DividerElement extends PrintElement {
  /// Creates a new [DividerElement].
  const DividerElement({
    this.thickness = 1,
    this.dashChar,
    this.dashStyle = DashStyle.solid,
  }) : assert(thickness > 0, 'thickness must be greater than zero');

  /// The stroke thickness in dots.
  final double thickness;

  /// A character used to paint a text-based divider.
  final String? dashChar;

  /// The geometric line style used when [dashChar] is null.
  final DashStyle dashStyle;

  @override
  Size measure(BoxConstraints constraints, PrintContext context) {
    if (dashChar != null) {
      final TextElement text = TextElement(dashChar!);
      final Size textSize = text.measure(constraints.loosen(), context);
      final double width = constraints.hasBoundedWidth
          ? constraints.maxWidth
          : textSize.width;
      return constraints.constrain(Size(width, textSize.height));
    }

    return constraints.constrain(
      Size(constraints.hasBoundedWidth ? constraints.maxWidth : 0, thickness),
    );
  }

  @override
  void paint(Canvas canvas, Size size, PrintContext context) {
    final String? dividerCharacter = dashChar;
    if (dividerCharacter != null && dividerCharacter.isNotEmpty) {
      final TextPainter probe = TextPainter(
        text: TextSpan(
          text: dividerCharacter,
          style: TextStyle(
            fontSize: context.defaultFontSize,
            fontFamily: context.defaultFontFamily,
            fontWeight: context.defaultFontWeight,
            color: context.foreground,
          ),
        ),
        textDirection: context.textDirection,
        locale: context.locale,
        textScaler: context.textScaler,
      )..layout();

      final int repeatCount = math.max(1, (size.width / probe.width).ceil());
      final String text = List<String>.filled(
        repeatCount,
        dividerCharacter,
      ).join();
      TextElement(text).paint(canvas, size, context);
      return;
    }

    final Paint paint = Paint()
      ..color = context.foreground
      ..strokeCap = StrokeCap.square
      ..strokeWidth = thickness;

    final double y = size.height / 2;
    switch (dashStyle) {
      case DashStyle.solid:
        canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
      case DashStyle.dashed:
        const double dashLength = 12;
        const double gapLength = 6;
        double dx = 0;
        while (dx < size.width) {
          final double end = math.min(size.width, dx + dashLength);
          canvas.drawLine(Offset(dx, y), Offset(end, y), paint);
          dx += dashLength + gapLength;
        }
      case DashStyle.dotted:
        final double radius = thickness / 2;
        final double step = math.max(thickness * 2, 6);
        for (double dx = radius; dx < size.width; dx += step) {
          canvas.drawCircle(Offset(dx, y), radius, paint);
        }
    }
  }
}

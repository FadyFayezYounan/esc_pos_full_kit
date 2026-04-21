import 'dart:math' as math;
import 'package:flutter/rendering.dart';
import 'package:meta/meta.dart';

import '../contracts/print_context.dart';
import '../contracts/print_element.dart';
import '../exceptions.dart';
import 'row_cell.dart';

/// Lays out children horizontally using flex-based cells.
@immutable
class RowElement extends PrintElement {
  /// Creates a new [RowElement].
  const RowElement(
    this.cells, {
    this.gap = 0,
    this.crossAxisAlignment = CrossAxisAlignment.start,
  });

  /// The flex cells that make up the row.
  final List<RowCell> cells;

  /// Horizontal space inserted between cells.
  final double gap;

  /// Vertical alignment for children whose heights differ.
  final CrossAxisAlignment crossAxisAlignment;

  @override
  Size measure(BoxConstraints constraints, PrintContext context) {
    if (cells.isEmpty) {
      return constraints.constrain(Size.zero);
    }
    if (!constraints.hasBoundedWidth) {
      throw const ValidationException(
        'RowElement requires a bounded width during layout.',
      );
    }

    final List<double> widths = _computeCellWidths(constraints.maxWidth);
    double height = 0;

    for (int index = 0; index < cells.length; index += 1) {
      final Size childSize = cells[index].element.measure(
        BoxConstraints(
          maxWidth: widths[index],
          maxHeight: constraints.maxHeight,
        ),
        context,
      );
      height = math.max(height, childSize.height);
    }

    return constraints.constrain(Size(constraints.maxWidth, height));
  }

  @override
  void paint(Canvas canvas, Size size, PrintContext context) {
    if (cells.isEmpty) {
      return;
    }

    final List<double> widths = _computeCellWidths(size.width);
    double dx = 0;

    for (int index = 0; index < cells.length; index += 1) {
      final RowCell cell = cells[index];
      final double cellWidth = widths[index];
      final Size childSize = cell.element.measure(
        BoxConstraints(maxWidth: cellWidth, maxHeight: size.height),
        context,
      );

      final double childDx =
          dx + _horizontalOffset(cell.textAlign, cellWidth, childSize.width);
      final double childDy = switch (crossAxisAlignment) {
        CrossAxisAlignment.center => (size.height - childSize.height) / 2,
        CrossAxisAlignment.end => size.height - childSize.height,
        CrossAxisAlignment.stretch => 0,
        CrossAxisAlignment.baseline => 0,
        CrossAxisAlignment.start => 0,
      };

      canvas.save();
      canvas.translate(childDx, childDy);
      cell.element.paint(
        canvas,
        crossAxisAlignment == CrossAxisAlignment.stretch
            ? Size(cellWidth, size.height)
            : childSize,
        context,
      );
      canvas.restore();

      dx += cellWidth + gap;
    }
  }

  List<double> _computeCellWidths(double totalWidth) {
    final double totalGap = gap * (cells.length - 1);
    final double availableWidth = math.max(0, totalWidth - totalGap);
    final int totalFlex = cells.fold<int>(
      0,
      (int sum, RowCell cell) => sum + cell.flex,
    );

    double consumed = 0;
    final List<double> widths = <double>[];

    for (int index = 0; index < cells.length; index += 1) {
      if (index == cells.length - 1) {
        widths.add(math.max(0, availableWidth - consumed));
      } else {
        final double width = availableWidth * cells[index].flex / totalFlex;
        widths.add(width);
        consumed += width;
      }
    }

    return widths;
  }

  double _horizontalOffset(
    TextAlign align,
    double cellWidth,
    double childWidth,
  ) {
    return switch (align) {
      TextAlign.center => (cellWidth - childWidth) / 2,
      TextAlign.end || TextAlign.right => cellWidth - childWidth,
      TextAlign.justify || TextAlign.left || TextAlign.start => 0,
    };
  }
}

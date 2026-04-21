import 'package:flutter/painting.dart';
import 'package:meta/meta.dart';

import '../contracts/print_element.dart';

/// A flex cell inside a [RowElement].
@immutable
class RowCell {
  /// Creates a new [RowCell].
  const RowCell(this.element, {this.flex = 1, this.textAlign = TextAlign.left})
    : assert(flex > 0, 'flex must be greater than zero');

  /// The child element rendered inside the cell.
  final PrintElement element;

  /// Relative width weight. `flex = 2` is twice as wide as `flex = 1`.
  final int flex;

  /// Horizontal alignment for non-text children inside the cell.
  final TextAlign textAlign;
}

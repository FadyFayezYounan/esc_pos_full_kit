import 'package:flutter/painting.dart';
import 'package:meta/meta.dart';

/// Immutable rendering configuration shared across layout and paint passes.
@immutable
class PrintContext {
  /// Creates a new [PrintContext].
  const PrintContext({
    required this.textDirection,
    required this.locale,
    required this.paperPixelWidth,
    this.dpi = 203,
    this.defaultFontSize = 24,
    this.defaultFontFamily,
    this.defaultFontWeight = FontWeight.normal,
    this.textScaler = TextScaler.noScaling,
    this.foreground = const Color(0xFF000000),
    this.background = const Color(0xFFFFFFFF),
  });

  /// The default text direction used by elements in this print job.
  final TextDirection textDirection;

  /// The locale used for shaping and formatting text.
  final Locale locale;

  /// The printable paper width in printer dots.
  final int paperPixelWidth;

  /// The printer resolution in dots per inch.
  final double dpi;

  /// The default body font size in printer dots.
  final double defaultFontSize;

  /// The default font family applied when an element does not override it.
  final String? defaultFontFamily;

  /// The default font weight applied when an element does not override it.
  final FontWeight defaultFontWeight;

  /// A text scaler used by [TextPainter].
  final TextScaler textScaler;

  /// The default foreground color.
  final Color foreground;

  /// The default background color.
  final Color background;

  /// Converts millimetres to printer dots for the current [dpi].
  double pxForMm(double mm) => mm * dpi / 25.4;

  /// Returns a copy of this context with the given fields replaced.
  PrintContext copyWith({
    TextDirection? textDirection,
    Locale? locale,
    int? paperPixelWidth,
    double? dpi,
    double? defaultFontSize,
    String? defaultFontFamily,
    FontWeight? defaultFontWeight,
    TextScaler? textScaler,
    Color? foreground,
    Color? background,
  }) {
    return PrintContext(
      textDirection: textDirection ?? this.textDirection,
      locale: locale ?? this.locale,
      paperPixelWidth: paperPixelWidth ?? this.paperPixelWidth,
      dpi: dpi ?? this.dpi,
      defaultFontSize: defaultFontSize ?? this.defaultFontSize,
      defaultFontFamily: defaultFontFamily ?? this.defaultFontFamily,
      defaultFontWeight: defaultFontWeight ?? this.defaultFontWeight,
      textScaler: textScaler ?? this.textScaler,
      foreground: foreground ?? this.foreground,
      background: background ?? this.background,
    );
  }
}

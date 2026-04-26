import 'package:meta/meta.dart';

/// The command language used to encode bytes for a printer profile.
enum PrinterCommandDialect {
  /// Epson-compatible ESC/POS commands.
  escPos,

  /// Star Micronics StarPRNT commands.
  starPrnt,
}

/// A typed description of a printer's command capabilities.
@immutable
class PrinterProfile {
  /// Creates a new [PrinterProfile].
  const PrinterProfile({
    required this.id,
    required this.name,
    required this.vendor,
    this.commandDialect = PrinterCommandDialect.escPos,
    this.description = '',
    required this.codePages,
    required this.colors,
    required this.features,
    required this.fonts,
    required this.media,
  });

  /// The unique profile identifier.
  final String id;

  /// The user-facing profile name.
  final String name;

  /// The printer vendor name.
  final String vendor;

  /// The command language used when encoding this profile's byte stream.
  final PrinterCommandDialect commandDialect;

  /// An optional description of the device.
  final String description;

  /// A map of supported ESC/POS code pages.
  final Map<int, String> codePages;

  /// Supported color slots.
  final PrinterColors colors;

  /// Capability flags used by the encoder.
  final PrinterFeatures features;

  /// Supported text fonts.
  final Map<int, PrinterFont> fonts;

  /// Media geometry for the device.
  final PrinterMedia media;
}

/// A typed map of supported print colors.
@immutable
class PrinterColors {
  /// Creates a new [PrinterColors].
  const PrinterColors(this.entries);

  /// The supported color entries keyed by ESC/POS color index.
  final Map<int, String> entries;
}

/// Command feature support flags for a printer.
@immutable
class PrinterFeatures {
  /// Creates a new [PrinterFeatures].
  const PrinterFeatures({
    required this.barcodeA,
    required this.barcodeB,
    required this.bitImageColumn,
    required this.bitImageRaster,
    required this.graphics,
    required this.highDensity,
    required this.paperFullCut,
    required this.paperPartCut,
    required this.pdf417Code,
    required this.pulseBel,
    required this.pulseStandard,
    required this.qrCode,
    required this.starCommands,
  });

  /// Whether barcode type A commands are supported.
  final bool barcodeA;

  /// Whether barcode type B commands are supported.
  final bool barcodeB;

  /// Whether column bit image commands are supported.
  final bool bitImageColumn;

  /// Whether raster bit image commands are supported.
  final bool bitImageRaster;

  /// Whether graphics mode is supported.
  final bool graphics;

  /// Whether high-density printing is supported.
  final bool highDensity;

  /// Whether the printer supports a full cut command.
  final bool paperFullCut;

  /// Whether the printer supports a partial cut command.
  final bool paperPartCut;

  /// Whether PDF417 commands are supported.
  final bool pdf417Code;

  /// Whether BEL/beep commands are supported.
  final bool pulseBel;

  /// Whether cash drawer pulse commands are supported.
  final bool pulseStandard;

  /// Whether native QR commands are supported.
  final bool qrCode;

  /// Whether the profile targets Star printer commands instead of ESC/POS.
  final bool starCommands;
}

/// A printer font definition.
@immutable
class PrinterFont {
  /// Creates a new [PrinterFont].
  const PrinterFont(this.name, {required this.columns});

  /// The font name reported by the capability profile.
  final String name;

  /// The number of columns this font typically supports.
  final int columns;
}

/// Media dimensions for a printer profile.
@immutable
class PrinterMedia {
  /// Creates a new [PrinterMedia].
  const PrinterMedia({this.widthMm, this.widthPixels});

  /// The printable width in millimetres.
  final double? widthMm;

  /// The printable width in dots.
  final int? widthPixels;
}

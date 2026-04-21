# PRD — `esc_pos_full_kit`

> A Flutter package for building ESC/POS receipts with a widget-like element tree, rendering them to a **monochrome raster image**, and sending them to thermal printers over **network TCP** (v1). Bluetooth is on the roadmap for v2.

---

## 1. Context

Thermal receipt libraries like [`esc_pos_utils_plus`](https://pub.dev/packages/esc_pos_utils_plus) encode text as bytes through vendor codepages. This breaks for **Arabic / RTL / complex scripts** because codepage tables do not carry shaping, bidi, or ligature information.

The proven workaround is to **render the entire receipt as a monochrome bitmap** (using Flutter's text engine, which shapes Arabic correctly) and stream it to the printer as a raster image command (`GS v 0`). No codepage negotiation, no text-mode at all.

This package delivers that workaround as a first-class, composable API — a `PrintElement` tree that mirrors Flutter's mental model (measure → paint), plus a pluggable transport layer and a registry of known printer profiles.

**Outcome:** a Dart developer can write
```dart
final receipt = Receipt(children: [TextElement('مرحبا', ...), ...]);
await receipt.printTo(NetworkPrinter('192.168.1.100'), PrinterProfiles.tmT88V);
```
and get a correctly-shaped Arabic receipt, printed raster-perfect, on any TCP-reachable ESC/POS thermal printer.

---

## 2. Scope

### In scope (v1)
- Element tree: `PrintElement` base + concrete elements (text, row, column, padding, align, spacer, divider, barcode, QR, image)
- Two-pass layout/paint pipeline via `ui.PictureRecorder` + `Canvas`
- Rasterization: `ui.Image` → RGBA `Uint8List` → 1-bit monochrome (threshold + optional Floyd-Steinberg dither)
- ESC/POS encoder: INIT, FEED, CUT (full/partial), GS v 0 raster, OPEN_DRAWER, BEEP
- **Transport: `NetworkPrinter` (TCP socket, default port 9100)**
- `PrinterProfile` system with all profiles from the user's spec embedded as typed `const` Dart data
- `ReceiptPreview` Flutter widget (renders the same rasterized output as a preview)
- Example Flutter app demonstrating Arabic, LTR, mixed, and image-heavy receipts
- Android + iOS support (TCP only in v1 — no platform channels needed)

### Out of scope (v1, deferred)
- **Bluetooth Classic SPP** — future v2
- **Bluetooth LE** — future v2
- USB direct, Wi-Fi Direct, Star-native command dialect, desktop platforms
- Text-mode fallback (raster-only by design)
- PDF export
- Rich-text / HTML input

### Non-goals (ever)
- Replacing Flutter's widget system (elements are paint-only, no hit testing, no rebuilds)
- Supporting non-ESC/POS dialects in the same classes (a future Star encoder would live alongside, not inside)

---

## 3. Architecture (layered)

```
┌─────────────────────────────────────────────────┐
│ L6  Facade       Receipt.printTo(...)           │
├─────────────────────────────────────────────────┤
│ L5  Transport    PrinterTransport               │
│                  └─ NetworkPrinter (v1)         │
│                  └─ BluetoothClassicPrinter (v2)│
│                  └─ BluetoothLePrinter     (v2) │
├─────────────────────────────────────────────────┤
│ L4  Encoder      EscPosEncoder (profile-aware)  │
├─────────────────────────────────────────────────┤
│ L3  Rasterizer   ReceiptRasterizer              │
│                  (PictureRecorder → Uint8List)  │
├─────────────────────────────────────────────────┤
│ L2  Elements     TextElement, RowElement, ...   │
├─────────────────────────────────────────────────┤
│ L1  Contracts    PrintElement, PrintContext,    │
│                  PrinterProfile, PrinterTransport│
└─────────────────────────────────────────────────┘
```

Each layer depends only on layers below. No cycles. Public surface at L6.

### Directory layout
```
lib/
├── esc_pos_full_kit.dart              (barrel export)
└── src/
    ├── contracts/
    │   ├── print_element.dart
    │   ├── print_context.dart
    │   ├── printer_profile.dart
    │   └── printer_transport.dart
    ├── elements/
    │   ├── text_element.dart
    │   ├── row_element.dart
    │   ├── row_cell.dart
    │   ├── column_element.dart
    │   ├── padding_element.dart
    │   ├── align_element.dart
    │   ├── spacer_element.dart
    │   ├── divider_element.dart
    │   ├── barcode_element.dart
    │   ├── qr_code_element.dart
    │   └── image_element.dart
    ├── receipt/
    │   ├── receipt.dart
    │   └── receipt_preview.dart
    ├── rasterizer/
    │   ├── receipt_rasterizer.dart
    │   └── monochrome_converter.dart
    ├── encoder/
    │   └── esc_pos_encoder.dart
    ├── transport/
    │   └── network_printer.dart
    ├── profiles/
    │   ├── printer_profile_models.dart  (typed classes)
    │   ├── printer_profiles.dart         (const registry)
    │   └── _profiles/                    (one const per vendor)
    │       ├── epson.dart
    │       ├── star.dart
    │       ├── xprinter.dart
    │       ├── ... (one file per vendor)
    │       └── generic.dart
    └── exceptions.dart
```

---

## 4. Core contracts

### 4.1 `PrintElement`

Single abstract class — **not** split across `Measurable` / `Paintable`. Rationale: every concrete element implements both; a split buys no real ISP benefit and costs API surface. Using `BoxConstraints`/`Size` matches Flutter's mental model and unlocks Row flex math (non-flex children report their intrinsic width first; flex children split the remainder).

```dart
/// Base contract for every printable element.
///
/// A [PrintElement] is immutable and stateless:
/// - [measure] reports the size needed given constraints. Pure, side-effect free.
/// - [paint]   paints at the current canvas origin within the given [size].
///
/// Implementations MUST be `@immutable` and have `const` constructors where possible.
/// All rendering state (e.g. [TextPainter]) must be created inside [paint] or
/// cached lazily inside [measure] — never stored as mutable fields.
///
/// Design note (SOLID):
/// - S — each subclass is one visual concept.
/// - O — new elements extend this contract, never modify it.
/// - L — every PrintElement is substitutable for the base.
/// - I — the contract is minimal: measure + paint. Nothing else.
/// - D — layout engine and renderer depend only on this type.
@immutable
abstract class PrintElement {
  const PrintElement();

  /// Reports the size this element needs under [constraints].
  ///
  /// Called once during layout before [paint]. The returned [Size] must satisfy
  /// [constraints]; implementations should clamp if necessary.
  Size measure(BoxConstraints constraints, PrintContext context);

  /// Paints this element within `Offset.zero & size` on [canvas].
  ///
  /// The canvas origin is already translated to this element's top-left corner
  /// by its parent. [size] is the size previously returned by [measure].
  void paint(Canvas canvas, Size size, PrintContext context);
}
```

### 4.2 `PrintContext`

Immutable bag passed through layout + paint. Carries directionality, locale, and — critically — the printer's **dot resolution**.

```dart
@immutable
class PrintContext {
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

  final TextDirection textDirection;
  final Locale locale;

  /// Total printable width in printer dots (== canvas pixels, 1:1).
  /// Usually derived from `PrinterProfile.media.widthPixels`.
  final int paperPixelWidth;

  /// Printer dot density. 203 dpi is the industry default; 180 on some older units.
  final double dpi;

  /// Default font size in **dots**, not logical Flutter pixels. On a 203-dpi
  /// printer, 24 dots ≈ 3mm tall — a readable body size. See §12 DPI trap.
  final double defaultFontSize;

  final String? defaultFontFamily;
  final FontWeight defaultFontWeight;
  final TextScaler textScaler;
  final Color foreground;
  final Color background;

  /// Helper: convert millimetres to dots at the current dpi.
  double pxForMm(double mm) => mm * dpi / 25.4;

  PrintContext copyWith({ /* ... */ });
}
```

### 4.3 `PrinterTransport`

```dart
abstract class PrinterTransport {
  Future<void> connect();
  Future<void> write(List<int> bytes);
  Future<void> flush();
  Future<void> disconnect();

  /// Hot stream of connection state changes for UI observers.
  Stream<ConnectionState> get state;
}

enum ConnectionState { disconnected, connecting, connected, error }
```

### 4.4 `PrinterProfile` (see §7 for full model + registry)

---

## 5. Elements (v1)

All concrete elements live in `lib/src/elements/`. Every element is `@immutable` with a `const` constructor.

### 5.1 `TextElement`
Delegates to `TextPainter`. **This is what solves the Arabic problem** — Flutter's text engine shapes the run correctly.

```dart
class TextElement extends PrintElement {
  const TextElement(
    this.text, {
    this.style,
    this.textAlign = TextAlign.left,
    this.maxLines,
    this.textDirection,
  });

  final String text;
  final TextStyle? style;
  final TextAlign textAlign;
  final int? maxLines;
  /// Overrides [PrintContext.textDirection] for this element only (e.g. a phone
  /// number or URL that must stay LTR inside an RTL receipt).
  final TextDirection? textDirection;

  @override
  Size measure(BoxConstraints c, PrintContext ctx) {
    final tp = _painter(c.maxWidth, ctx);
    return Size(c.maxWidth, tp.height);
  }

  @override
  void paint(Canvas canvas, Size size, PrintContext ctx) {
    _painter(size.width, ctx).paint(canvas, Offset.zero);
  }

  TextPainter _painter(double w, PrintContext ctx) => TextPainter(
    text: TextSpan(
      text: text,
      style: (style ?? const TextStyle()).copyWith(
        fontSize: style?.fontSize ?? ctx.defaultFontSize,
        fontFamily: style?.fontFamily ?? ctx.defaultFontFamily,
        color: style?.color ?? ctx.foreground,
      ),
    ),
    textAlign: textAlign,
    textDirection: textDirection ?? ctx.textDirection,
    locale: ctx.locale,
    maxLines: maxLines,
    ellipsis: maxLines != null ? '\u2026' : null,
    textScaler: ctx.textScaler,
  )..layout(minWidth: w, maxWidth: w);
}
```

### 5.2 `RowElement` + `RowCell`
Horizontal layout. Children are wrapped in `RowCell` with explicit flex + alignment.

```dart
class RowCell {
  const RowCell(
    this.element, {
    this.flex = 1,
    this.textAlign = TextAlign.left,
  });

  final PrintElement element;
  /// Relative width weight. flex=2 is twice as wide as flex=1.
  final int flex;
  /// Horizontal alignment of [element] within its cell.
  /// When [element] is a [TextElement], prefer setting TextElement.textAlign;
  /// this field exists for non-text children and for documenting intent.
  final TextAlign textAlign;
}

class RowElement extends PrintElement {
  const RowElement(this.cells, {this.gap = 0, this.crossAxisAlignment = CrossAxisAlignment.start});
  final List<RowCell> cells;
  final double gap;
  final CrossAxisAlignment crossAxisAlignment;

  // measure: sum(flex) → divide available width minus gaps → measure each child with tight width.
  // paint: translate canvas horizontally for each cell; paint child; paint next.
  // Cross-axis alignment: align children vertically within the row's max child height.
}
```

**Important:** rows do NOT auto-mirror for RTL contexts. The printer prints LTR pixels; mirroring produces backwards Arabic. Only the `TextElement` content is direction-aware — via `TextPainter`. A `RowElement` in an RTL receipt still lays cells left-to-right by default. Users who want right-to-left column order should reverse the `cells` list explicitly.

### 5.3 `ColumnElement`
Vertical stack. Children measured with `BoxConstraints.tightFor(width: constraints.maxWidth)`, painted top-down with accumulating y-offset plus `gap`.

```dart
class ColumnElement extends PrintElement {
  const ColumnElement(this.children, {this.gap = 0, this.crossAxisAlignment = CrossAxisAlignment.stretch});
  final List<PrintElement> children;
  final double gap;
  final CrossAxisAlignment crossAxisAlignment;
}
```

### 5.4 `PaddingElement`, `AlignElement`, `SpacerElement`
- `PaddingElement(child, EdgeInsets padding)` — measures child with shrunk constraints, paints with translated canvas.
- `AlignElement(child, Alignment alignment)` — measures child loose, positions inside its own box per alignment.
- `SpacerElement({double height = 0})` — vertical whitespace in a Column.

### 5.5 `DividerElement`
```dart
class DividerElement extends PrintElement {
  const DividerElement({this.thickness = 1, this.dashChar, this.dashStyle});
  final double thickness;
  /// Character-based divider (e.g. '-', '='). When non-null, paints text via TextElement.
  final String? dashChar;
  final DashStyle? dashStyle; // solid | dashed | dotted
}
```

### 5.6 `BarcodeElement`
Uses the [`barcode`](https://pub.dev/packages/barcode) package (add as dependency) to produce SVG → raster, or render directly via canvas drawing.

```dart
class BarcodeElement extends PrintElement {
  const BarcodeElement(
    this.data, {
    required this.type,    // BarcodeType.code128, ean13, upcA, ...
    this.height = 80,
    this.displayValue = true,
    this.textStyle,
  });
  final String data;
  final BarcodeType type;
  final double height;
  final bool displayValue;
  final TextStyle? textStyle;
}
```

### 5.7 `QrCodeElement`
Uses [`qr`](https://pub.dev/packages/qr) to generate the matrix; paint draws black squares via canvas.

```dart
class QrCodeElement extends PrintElement {
  const QrCodeElement(this.data, {this.size = 200, this.errorCorrection = QrErrorCorrectLevel.M});
  final String data;
  final double size;
  final int errorCorrection;
}
```

### 5.8 `ImageElement`
Accepts `ui.Image`, `Uint8List` (encoded bytes), or an asset path. Throws `ValidationException` if the image's intrinsic width exceeds `paperPixelWidth` and no `fit` is set.

```dart
class ImageElement extends PrintElement {
  const ImageElement.memory(Uint8List this.bytes, {this.fit, this.width, this.height});
  const ImageElement.asset(String this.assetPath, {this.fit, this.width, this.height});
  const ImageElement.image(ui.Image this.image, {this.fit, this.width, this.height});

  final Uint8List? bytes;
  final String? assetPath;
  final ui.Image? image;
  final BoxFit? fit;
  final double? width;
  final double? height;
}
```

**Note:** no `RawElement`. Invariant: every `PrintElement` renders to pixels. Printer-level commands (cut, drawer, beep) are set on `Receipt`, not as elements.

---

## 6. `Receipt` (L6 facade)

```dart
class Receipt {
  const Receipt({
    required this.children,
    this.padding = EdgeInsets.zero,
    this.cut = true,
    this.feedBeforeCut = 3,
    this.openDrawer = false,
    this.beep = false,
    this.dither = DitherMode.auto,
  });

  final List<PrintElement> children;
  final EdgeInsets padding;
  final bool cut;
  final int feedBeforeCut;
  final bool openDrawer;
  final bool beep;
  /// auto: dither only if an ImageElement is present in the tree; off: threshold only.
  final DitherMode dither;

  /// Rasterize to a monochrome Uint8List sized for [profile].
  Future<RasterizedReceipt> rasterize(PrinterProfile profile, {Locale? locale, TextDirection? textDirection});

  /// Full pipeline: rasterize → encode → write to transport → disconnect.
  Future<void> printTo(
    PrinterTransport transport,
    PrinterProfile profile, {
    Locale? locale,
    TextDirection? textDirection,
  });
}

class RasterizedReceipt {
  final ui.Image image;             // for ReceiptPreview
  final Uint8List monochromeBits;   // 1-bit packed, MSB-first, row-aligned to widthBytes
  final int widthPixels;
  final int heightPixels;
  final int widthBytes;             // = (widthPixels + 7) >> 3
}
```

---

## 7. `PrinterProfile` system

### 7.1 Typed models

```dart
@immutable
class PrinterProfile {
  const PrinterProfile({
    required this.id,
    required this.name,
    required this.vendor,
    this.description = '',
    required this.codePages,
    required this.colors,
    required this.features,
    required this.fonts,
    required this.media,
  });
  final String id, name, vendor, description;
  final Map<int, String> codePages;   // e.g. {0: 'CP437', 16: 'CP1252', ...}
  final PrinterColors colors;
  final PrinterFeatures features;
  final Map<int, PrinterFont> fonts;   // e.g. {0: PrinterFont('Font A', columns: 42)}
  final PrinterMedia media;
}

class PrinterColors { const PrinterColors(this.entries); final Map<int, String> entries; /* {0:'black', 1:'red'} */ }

class PrinterFeatures {
  const PrinterFeatures({
    required this.barcodeA, required this.barcodeB,
    required this.bitImageColumn, required this.bitImageRaster,
    required this.graphics, required this.highDensity,
    required this.paperFullCut, required this.paperPartCut,
    required this.pdf417Code, required this.pulseBel, required this.pulseStandard,
    required this.qrCode, required this.starCommands,
  });
  final bool barcodeA, barcodeB, bitImageColumn, bitImageRaster,
      graphics, highDensity, paperFullCut, paperPartCut,
      pdf417Code, pulseBel, pulseStandard, qrCode, starCommands;
}

class PrinterFont { const PrinterFont(this.name, {required this.columns}); final String name; final int columns; }

class PrinterMedia {
  const PrinterMedia({this.widthMm, this.widthPixels});
  /// Millimetres. null when source JSON said "Unknown".
  final double? widthMm;
  /// Dot width. null when source JSON said "Unknown". Required for rasterization;
  /// if null, the caller must override via PrintContext.paperPixelWidth.
  final int? widthPixels;
}
```

### 7.2 Registry (compile-time `const` Dart, not runtime JSON)

```dart
abstract final class PrinterProfiles {
  // Every profile listed in the source spec, as const instances:
  static const zkp8001     = PrinterProfile(id: 'ZKP8001',      /* ... */);
  static const xpN160i     = PrinterProfile(id: 'XP-N160I',     /* ... */);
  static const rp80use     = PrinterProfile(id: 'RP80USE',      /* ... */);
  static const tp806l      = PrinterProfile(id: 'TP806L',       /* ... */);
  static const af240       = PrinterProfile(id: 'AF-240',       /* ... */);
  static const ctS651      = PrinterProfile(id: 'CT-S651',      /* ... */);
  static const nt5890k     = PrinterProfile(id: 'NT-5890K',     /* ... */);
  static const ocd100      = PrinterProfile(id: 'OCD-100',      /* ... */);
  static const ocd300      = PrinterProfile(id: 'OCD-300',      /* ... */);
  static const p822d       = PrinterProfile(id: 'P822D',        /* ... */);
  static const pos5890     = PrinterProfile(id: 'POS-5890',     /* ... */);
  static const rp326       = PrinterProfile(id: 'RP326',        /* ... */);
  static const sp2000      = PrinterProfile(id: 'SP2000',       /* ... */);
  static const sunmiV2     = PrinterProfile(id: 'Sunmi-V2',     /* ... */);
  static const tep200m     = PrinterProfile(id: 'TEP-200M',     /* ... */);
  static const tmP80       = PrinterProfile(id: 'TM-P80',       /* ... */);
  static const tmP80_42col = PrinterProfile(id: 'TM-P80-42col', /* ... */);
  static const tmT88ii     = PrinterProfile(id: 'TM-T88II',     /* ... */);
  static const tmT88iii    = PrinterProfile(id: 'TM-T88III',    /* ... */);
  static const tmT88iv     = PrinterProfile(id: 'TM-T88IV',     /* ... */);
  static const tmT88ivSa   = PrinterProfile(id: 'TM-T88IV-SA',  /* ... */);
  static const tmT88v      = PrinterProfile(id: 'TM-T88V',      /* ... */);
  static const tmU220      = PrinterProfile(id: 'TM-U220',      /* ... */);
  static const tsp600      = PrinterProfile(id: 'TSP600',       /* ... */);
  static const tup500      = PrinterProfile(id: 'TUP500',       /* ... */);
  static const zj5870      = PrinterProfile(id: 'ZJ-5870',      /* ... */);
  static const default_    = PrinterProfile(id: 'default',      /* ... */);
  static const simple      = PrinterProfile(id: 'simple',       /* ... */);

  static const List<PrinterProfile> all = [zkp8001, xpN160i, /* ... */ default_, simple];

  /// Lookup by id string. Returns null if unknown.
  static PrinterProfile? byId(String id) => /* linear search over all */;

  /// Third-party runtime registration (non-const). Separate mutable registry —
  /// built-ins stay const and tree-shakable.
  static void register(PrinterProfile p) => /* ... */;
}
```

Each profile's `codePages`, `colors`, `features`, `fonts`, and `media` fields are **transcribed verbatim** from the spec JSON the user supplied. `"Unknown"` string values in the source become Dart `null` in the typed model (e.g. `PrinterMedia.widthPixels = null`). `codePages` keys are int; values are string (the codepage name like `"CP437"` or `"Unknown"`).

### 7.3 Where profiles are used in v1
- `media.widthPixels` → `PrintContext.paperPixelWidth` (the single most important field for raster)
- `features.paperFullCut` / `paperPartCut` → whether `Receipt.cut = true` emits the cut command or silently drops it
- `features.bitImageRaster` → required `true` to use `GS v 0`. If `false`, throw `UnsupportedFeatureException` (every profile in the list except a few displays has it true)
- `features.pulseStandard` + `Receipt.openDrawer` → emits `ESC p`
- `codePages` / `fonts` / `colors` — stored but **unused in v1** (raster-only). Preserved for a future text-mode fallback or vendor-specific behavior.

---

## 8. Rendering pipeline (`ReceiptRasterizer`)

```
1. Build PrintContext from profile + user overrides (locale, textDirection).
   paperPixelWidth = profile.media.widthPixels  (throw if null & not overridden)

2. Wrap Receipt.children in an implicit ColumnElement(padding=Receipt.padding).
   root.measure(BoxConstraints.tightFor(width: paperPixelWidth), ctx) → Size(w, totalH)

3. Create ui.PictureRecorder + Canvas(recorder, Rect.fromLTWH(0,0,w,totalH)).
   canvas.drawColor(ctx.background, BlendMode.src);
   root.paint(canvas, Size(w, totalH), ctx);

4. final picture = recorder.endRecording();
   final img = await picture.toImage(w.toInt(), totalH.ceil());

5. final rgba = await img.toByteData(format: ui.ImageByteFormat.rawRgba);
   monochrome = MonochromeConverter.convert(rgba, w, totalH, mode: receipt.dither);
   // returns Uint8List of length widthBytes * heightPixels, MSB-first packed.

6. return RasterizedReceipt(image: img, monochromeBits: monochrome, ...);
```

### 8.1 Monochrome conversion
- **Threshold (default for text-only):** luminance `Y = 0.299R + 0.587G + 0.114B`; bit=1 if Y < 128.
- **Floyd-Steinberg (for images):** classic serpentine distribution. Used when `DitherMode.auto` detects any `ImageElement` in the tree, or `DitherMode.on` is forced.
- Output: row-major, each row padded to `widthBytes = (widthPixels + 7) >> 3` bytes, bits MSB-first.

### 8.2 Slicing into bands for GS v 0
- `GS v 0` parameters: `m` (mode), `xL xH yL yH` where `yL+yH*256` is the band's pixel height and is **capped at 2303** by spec but practically kept ≤ `255` for legacy-printer safety.
- Rasterizer slices the monochrome buffer into bands of at most 255 rows, emits one `GS v 0 0 xL xH yL yH <row_bytes>` packet per band, concatenates them.

---

## 9. Encoder (`EscPosEncoder`)

Pure function helpers returning `List<int>`. No state, no I/O.

```dart
abstract final class EscPosEncoder {
  static const List<int> init = [0x1B, 0x40];
  static List<int> feed(int n)            => [0x1B, 0x64, n & 0xFF];
  static List<int> cutFull()              => [0x1D, 0x56, 0x00];
  static List<int> cutPartial()           => [0x1D, 0x56, 0x01];
  static List<int> openDrawer({int pin = 0, int t1 = 25, int t2 = 250})
                                          => [0x1B, 0x70, pin & 1, t1, t2];
  static List<int> beep(int times, int duration)
                                          => [0x1B, 0x42, times, duration];

  /// GS v 0 raster bit image — one band.
  static List<int> rasterBand({required int widthBytes, required int heightRows, required List<int> bits, int mode = 0})
    => [0x1D, 0x76, 0x30, mode & 0xFF,
        widthBytes & 0xFF, (widthBytes >> 8) & 0xFF,
        heightRows & 0xFF, (heightRows >> 8) & 0xFF,
        ...bits];

  /// Assemble full ESC/POS stream for a rasterized receipt, profile-guarded.
  static List<int> assembleReceipt(RasterizedReceipt r, PrinterProfile p, Receipt cfg);
}
```

`assembleReceipt` does the orchestration:
1. `init`
2. band-slice `r.monochromeBits`, one `rasterBand` per slice
3. `feed(cfg.feedBeforeCut)` if `cfg.cut`
4. `cutFull()` if `cfg.cut && p.features.paperFullCut` else `cutPartial()` if `p.features.paperPartCut` else nothing
5. `openDrawer()` if `cfg.openDrawer && p.features.pulseStandard`
6. `beep(1, 3)` if `cfg.beep && p.features.pulseBel`

---

## 10. Transport (v1: network only)

```dart
class NetworkPrinter implements PrinterTransport {
  NetworkPrinter(this.host, {this.port = 9100, this.connectTimeout = const Duration(seconds: 5)});

  final String host;
  final int port;
  final Duration connectTimeout;

  Socket? _socket;
  final _state = StreamController<ConnectionState>.broadcast();

  @override Stream<ConnectionState> get state => _state.stream;

  @override
  Future<void> connect() async {
    _state.add(ConnectionState.connecting);
    try {
      _socket = await Socket.connect(host, port, timeout: connectTimeout);
      _state.add(ConnectionState.connected);
    } on SocketException catch (e) {
      _state.add(ConnectionState.error);
      throw ConnectionException('Failed to connect to $host:$port', e);
    }
  }

  @override
  Future<void> write(List<int> bytes) async {
    final s = _socket;
    if (s == null) throw ConnectionException('Not connected');
    s.add(bytes);
  }

  @override
  Future<void> flush() async => _socket?.flush();

  @override
  Future<void> disconnect() async {
    await _socket?.flush();
    await _socket?.close();
    _socket?.destroy();
    _socket = null;
    _state.add(ConnectionState.disconnected);
  }
}
```

### 10.1 Future (v2): Bluetooth
Scaffolded interface only — no implementation in v1. Listed in roadmap / CHANGELOG only.
- `BluetoothClassicPrinter(macAddress)` via `print_bluetooth_thermal` (active, Android-only)
- `BluetoothLePrinter(deviceId, writeCharacteristicUuid)` via `flutter_blue_plus`
- iOS BT-Classic will remain unsupported (MFi required).

---

## 11. `ReceiptPreview` widget

```dart
class ReceiptPreview extends StatefulWidget {
  const ReceiptPreview({
    super.key,
    required this.receipt,
    required this.profile,
    this.locale,
    this.textDirection,
    this.placeholder,
    this.backgroundColor = Colors.white,
  });

  final Receipt receipt;
  final PrinterProfile profile;
  final Locale? locale;
  final TextDirection? textDirection;
  final Widget? placeholder;
  final Color backgroundColor;

  // Internally: calls receipt.rasterize() in initState / on didUpdateWidget,
  // displays RasterizedReceipt.image via RawImage (aspect-preserving, fits width).
}
```

The preview renders the **exact same image** the printer receives — a true WYSIWYG preview. Re-rasterizes when `receipt`, `profile`, `locale`, or `textDirection` change.

---

## 12. The DPI trap (call-out for implementers)

Thermal printers are **dot-addressed**, not logical-pixel-addressed. A 203-dpi 80mm printer is exactly 576 dots wide; canvas pixels map 1:1 to printer dots. Therefore:
- `TextStyle(fontSize: 14)` renders as **14 dots tall ≈ 1.75mm** — tiny.
- Recommended defaults: `PrintContext.defaultFontSize = 24` (≈3mm), body text 24–28, headings 32–40.
- Use `PrintContext.pxForMm(double mm)` to convert physical sizes.
- Document this prominently in README under a "Font sizes" heading. This is the #1 thing users will get wrong.

---

## 13. Error handling

```dart
sealed class PrintException implements Exception {
  final String message; final Object? cause;
  const PrintException(this.message, [this.cause]);
}
class ConnectionException    extends PrintException { /* TCP timeouts, refused, lost */ }
class ValidationException    extends PrintException { /* image too wide, paper width unknown */ }
class UnsupportedFeatureException extends PrintException { /* cut on profile w/o cutter, raster on profile w/o bitImageRaster */ }
class RasterizationException extends PrintException { /* toImage / toByteData failed */ }
```

Policy:
- Validation errors throw **early** (before any bytes are sent).
- Unsupported features: by default **silently skip with a logged warning** (`dart:developer` `log()` under a named channel). Configurable via `Receipt(strictFeatures: true)` → throw instead.
- Connection errors always throw, never silent.

---

## 14. Testing strategy

### 14.1 Unit
- Each element's `measure` under fixture `BoxConstraints`: text wrapping, row flex distribution (3 cells flex [1,2,1] at 576px = 144/288/144), column gap math, padding shrinkage.
- `EscPosEncoder.*` byte-exact assertions against known-good command bytes.
- `PrinterProfiles.byId` resolves every advertised id; registry length matches spec.

### 14.2 Golden (regression net for Arabic)
- Canned receipts → `Receipt.rasterize()` → write PNG to `test/goldens/*.png`.
- Receipts: English, Arabic RTL, mixed LTR+RTL, long wrapping, with QR, with image, dithered image.
- Compare via [`matchesGoldenFile`](https://api.flutter.dev/flutter/flutter_test/matchesGoldenFile.html).

### 14.3 Integration
- `MockPrinterTransport` captures all bytes written.
- Print a known receipt, assert the byte stream: `[INIT][GS v 0 ...][FEED 3][CUT]`.

### 14.4 Live (manual, not CI)
- Example app has a "Dump-to-PNG" debug transport that writes the raster image + encoded bytes to a file for inspection.

---

## 15. Example app

`example/` — a Flutter app with four screens:
1. **Builder** — form for merchant name, items, totals, language toggle (English/Arabic/mixed).
2. **Profile picker** — dropdown of `PrinterProfiles.all`.
3. **Transport config** — host + port text fields; "Test connection" button.
4. **Preview + Print** — shows `ReceiptPreview`; "Print" button calls `receipt.printTo(...)`.

Sample receipts must include:
- Arabic-only (proves the Arabic fix works)
- Mixed LTR + RTL
- Logo image at top + QR code at bottom
- Wide table with `RowElement` + 3 `RowCell`s at flex `[2, 1, 1]`

---

## 16. Non-functional requirements

| Concern         | Requirement |
|-----------------|-------------|
| Performance     | < 200ms end-to-end rasterize for a 576×1000 px receipt on mid-range Android (2022 Snapdragon 6-series). |
| Immutability    | Every element and `Receipt` is `@immutable`. No mutable fields, no setters. |
| Global state    | None. `PrinterProfiles` holds only `const` data. Third-party `register()` uses a separate mutable map that is explicitly opt-in. |
| Null safety     | Sound null safety. All public APIs `dartdoc`-complete. |
| Lints           | `flutter_lints` clean at `package:flutter_lints/flutter.yaml` level. |
| Platform        | v1: Android + iOS (TCP only, no platform channels). Desktop works via TCP but untested. |
| Dart/Flutter    | Dart SDK `^3.10.3`, Flutter `>=3.0.0`. |

### 16.1 Dependencies to add (`pubspec.yaml`)
```yaml
dependencies:
  flutter: {sdk: flutter}
  barcode: ^2.2.8            # barcode rendering
  qr: ^3.0.2                 # QR matrix generation
  meta: ^1.12.0              # @immutable
dev_dependencies:
  flutter_test: {sdk: flutter}
  flutter_lints: ^6.0.0
```
No Bluetooth deps in v1 (explicitly deferred).

---

## 17. Extensibility

- Third parties subclass `PrintElement` directly. The contract is two methods.
- A `CompositeElement` helper base is provided for custom elements that compose children:
  ```dart
  abstract class CompositeElement extends PrintElement {
    const CompositeElement(this.children);
    final List<PrintElement> children;
    // default measure: treat as vertical stack
    // default paint:   paint children top-down
  }
  ```
- `PrinterProfiles.register(PrinterProfile)` lets users add custom profiles at runtime.
- `PrinterTransport` is a public interface — users can write their own transport (USB, serial, custom socket) without forking the package.

---

## 18. Critical files (v1 implementation targets)

- `/Users/fady/Documents/Projects/esc_pos_full_kit/pubspec.yaml` — add deps listed in §16.1
- `/Users/fady/Documents/Projects/esc_pos_full_kit/lib/esc_pos_full_kit.dart` — barrel exports
- `/Users/fady/Documents/Projects/esc_pos_full_kit/lib/src/contracts/*.dart` — 4 files (print_element, print_context, printer_profile, printer_transport)
- `/Users/fady/Documents/Projects/esc_pos_full_kit/lib/src/elements/*.dart` — 11 files (one per element + row_cell)
- `/Users/fady/Documents/Projects/esc_pos_full_kit/lib/src/receipt/receipt.dart` and `receipt_preview.dart`
- `/Users/fady/Documents/Projects/esc_pos_full_kit/lib/src/rasterizer/receipt_rasterizer.dart` and `monochrome_converter.dart`
- `/Users/fady/Documents/Projects/esc_pos_full_kit/lib/src/encoder/esc_pos_encoder.dart`
- `/Users/fady/Documents/Projects/esc_pos_full_kit/lib/src/transport/network_printer.dart`
- `/Users/fady/Documents/Projects/esc_pos_full_kit/lib/src/profiles/` — `printer_profile_models.dart`, `printer_profiles.dart`, and per-vendor `const` profile files under `_profiles/`
- `/Users/fady/Documents/Projects/esc_pos_full_kit/lib/src/exceptions.dart`
- `/Users/fady/Documents/Projects/esc_pos_full_kit/test/**` — unit + golden tests
- `/Users/fady/Documents/Projects/esc_pos_full_kit/example/` — new Flutter sample app
- `/Users/fady/Documents/Projects/esc_pos_full_kit/README.md` — usage, DPI trap, Arabic notes
- `/Users/fady/Documents/Projects/esc_pos_full_kit/CHANGELOG.md` — 1.0.0 entry

---

## 19. Verification plan (end-to-end)

Manual verification sequence an implementer (AI or human) runs after build:

1. **Static**
   ```
   dart pub get
   dart analyze
   dart format --set-exit-if-changed .
   ```
2. **Unit + golden**
   ```
   flutter test
   ```
   - All element measure/paint tests pass.
   - Every golden in `test/goldens/` matches (re-run with `--update-goldens` on first generation).
   - Arabic golden (`test/goldens/arabic_receipt.png`) visibly shows correctly-shaped Arabic when opened in an image viewer.
3. **Example app on Android**
   ```
   cd example && flutter run
   ```
   - Build a sample Arabic receipt → `ReceiptPreview` shows Arabic correctly shaped.
   - Hit Print with a real TCP printer at `192.168.x.x:9100` → paper comes out with Arabic correctly shaped, cut performed.
4. **Example app on iOS** — same as above (TCP only).
5. **Bytes inspection** (MockTransport in tests): assert exact byte sequence
   ```
   [0x1B, 0x40,                          // INIT
    0x1D, 0x76, 0x30, 0x00, xL, xH, yL, yH, ...bits,   // one or more GS v 0
    0x1B, 0x64, 0x03,                    // FEED 3
    0x1D, 0x56, 0x00]                    // CUT FULL
   ```
6. **Profile coverage** — parameterized test iterates every `PrinterProfiles.all` entry and asserts:
   - `id`, `name`, `vendor` non-empty
   - `codePages` map populated
   - All `features` flags present (no missing fields)
   - `media.widthPixels` either a valid int or `null` (matches source JSON)

---

## 20. Roadmap / explicitly deferred

| Feature | Version |
|---------|---------|
| Bluetooth Classic SPP (Android) via `print_bluetooth_thermal` | v2 |
| Bluetooth LE via `flutter_blue_plus` (iOS + Android) | v2 |
| USB transport (Android USB-Host) | v2 |
| Star-native command dialect (`starCommands` profiles: SP2000, TSP600, TUP500) | v3 |
| Desktop BT (Windows/macOS/Linux) | v3 |
| ESC * (column mode) fallback for ancient printers w/o `bitImageRaster` | v3 |
| GS ( L (modern graphics) for PDF-417-heavy receipts | v3 |

v1 ships: **network TCP + raster-only + element tree + preview widget + full profile registry**.
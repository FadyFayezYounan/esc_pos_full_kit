# esc_pos_full_kit

`esc_pos_full_kit` is a Flutter package for building ESC/POS receipts as a small element tree, rasterizing them with Flutter's text engine, and sending the resulting monochrome image to thermal printers.

The package is designed around raster-first printing so Arabic, RTL, ligatures, and mixed-direction receipts render correctly without relying on fragile printer code pages.

## Current Scope

- Text, row, column, padding, alignment, spacer, divider, barcode, QR, and image elements
- Receipt rasterization to a monochrome bitmap
- ESC/POS `GS v 0` raster encoding with feed, cut, drawer pulse, and beep support
- TCP transport through `NetworkPrinter`
- Bundled printer profile registry loaded from a local ESC/POS capability dataset
- `ReceiptPreview` for WYSIWYG preview rendering inside Flutter apps

## Usage

```dart
import 'dart:ui' as ui;

import 'package:esc_pos_full_kit/esc_pos_full_kit.dart';

final receipt = Receipt(
  children: <PrintElement>[
    const TextElement(
      'مرحبا',
      textAlign: TextAlign.center,
    ),
    const SpacerElement(height: 16),
    RowElement(<RowCell>[
      const RowCell(TextElement('Coffee x2')),
      const RowCell(
        TextElement('\$7.00', textAlign: TextAlign.right),
      ),
    ]),
    const SpacerElement(height: 16),
    const QrCodeElement('https://example.com/order/42', size: 128),
  ],
);

await receipt.printTo(
  NetworkPrinter('192.168.1.100'),
  PrinterProfiles.tmT88V,
  locale: const ui.Locale('ar'),
  textDirection: ui.TextDirection.rtl,
);
```

To preview the same rasterized output inside Flutter:

```dart
ReceiptPreview(
  receipt: receipt,
  profile: PrinterProfiles.tmT88V,
  locale: const Locale('ar'),
  textDirection: TextDirection.rtl,
)
```

## Font Sizes

Thermal printers are dot-addressed. `fontSize` values map directly to printer dots, not device-independent logical pixels.

- `24` dots is a practical default body size on a 203 DPI printer
- `32` to `40` dots works well for headings
- `PrintContext.pxForMm()` converts physical millimetres into printer dots

If your text looks tiny, the problem is usually using mobile UI font sizes on a printer canvas.

## Notes

- Raster image support requires `ImageElement` to be used through `Receipt.rasterize()` or `Receipt.printTo()`, which pre-decode image sources before layout.
- The full product plan in [PLAN.md](PLAN.md) still includes follow-up work such as a richer example app, broader public docs, and more verification coverage.

import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:esc_pos_full_kit/esc_pos_full_kit.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PrinterProfiles', () {
    test('resolves every built-in profile by id', () {
      for (final PrinterProfile profile in PrinterProfiles.builtIn) {
        expect(PrinterProfiles.byId(profile.id), same(profile));
        expect(profile.id, isNotEmpty);
        expect(profile.name, isNotEmpty);
        expect(profile.vendor, isNotEmpty);
        expect(profile.codePages, isNotEmpty);
      }
    });

    test('includes the Star mC-Print3 profile', () {
      expect(PrinterProfiles.byId('MCP30'), same(PrinterProfiles.mcp30));
      expect(
        PrinterProfiles.mcp30.commandDialect,
        PrinterCommandDialect.starPrnt,
      );
      expect(PrinterProfiles.mcp30.media.widthPixels, 576);
      expect(PrinterProfiles.mcp30.features.bitImageRaster, isTrue);
    });
  });

  group('RowElement', () {
    test('distributes flex widths across cells', () {
      final List<double> measuredWidths = <double>[];
      final RowElement row = RowElement(<RowCell>[
        RowCell(_RecordingElement(measuredWidths, height: 10)),
        RowCell(_RecordingElement(measuredWidths, height: 20), flex: 2),
        RowCell(_RecordingElement(measuredWidths, height: 15)),
      ]);
      const PrintContext context = PrintContext(
        textDirection: ui.TextDirection.ltr,
        locale: ui.Locale('en'),
        paperPixelWidth: 576,
      );

      final Size size = row.measure(
        const BoxConstraints.tightFor(width: 576),
        context,
      );

      expect(size.width, 576);
      expect(size.height, 20);
      expect(measuredWidths, <double>[144, 288, 144]);
    });
  });

  group('ColumnElement', () {
    test('does not force remaining page height onto children during paint', () {
      final List<BoxConstraints> constraintsSeen = <BoxConstraints>[];
      final ColumnElement column = ColumnElement(<PrintElement>[
        _ConstraintRecordingElement(constraintsSeen, height: 12),
        _ConstraintRecordingElement(constraintsSeen, height: 18),
      ], gap: 6);
      const PrintContext context = PrintContext(
        textDirection: ui.TextDirection.ltr,
        locale: ui.Locale('en'),
        paperPixelWidth: 200,
      );

      final Size size = column.measure(
        const BoxConstraints.tightFor(width: 200),
        context,
      );

      final ui.PictureRecorder recorder = ui.PictureRecorder();
      final ui.Canvas canvas = ui.Canvas(
        recorder,
        ui.Rect.fromLTWH(0, 0, size.width, size.height),
      );
      column.paint(canvas, size, context);
      recorder.endRecording();

      expect(size.height, 36);
      expect(constraintsSeen, hasLength(4));
      expect(constraintsSeen[2].hasBoundedHeight, isFalse);
      expect(constraintsSeen[3].hasBoundedHeight, isFalse);
    });
  });

  group('EscPosEncoder', () {
    test('assembles the expected raster stream', () async {
      final RasterizedReceipt rasterizedReceipt = RasterizedReceipt(
        image: await _createImage(8, 2),
        monochromeBits: Uint8List.fromList(<int>[0xA0, 0x40]),
        widthPixels: 8,
        heightPixels: 2,
        widthBytes: 1,
      );

      final List<int> bytes = EscPosEncoder.assembleReceipt(
        rasterizedReceipt,
        PrinterProfiles.tmT88V,
        const Receipt(children: <PrintElement>[]),
      );

      expect(bytes, <int>[
        0x1B,
        0x40,
        0x1D,
        0x76,
        0x30,
        0x00,
        0x01,
        0x00,
        0x02,
        0x00,
        0xA0,
        0x40,
        0x1B,
        0x64,
        0x03,
        0x1D,
        0x56,
        0x00,
      ]);

      rasterizedReceipt.dispose();
    });
  });

  group('StarPrntEncoder', () {
    test('assembles the expected fine bit image stream', () async {
      final RasterizedReceipt rasterizedReceipt = RasterizedReceipt(
        image: await _createImage(8, 2),
        monochromeBits: Uint8List.fromList(<int>[0xA0, 0x40]),
        widthPixels: 8,
        heightPixels: 2,
        widthBytes: 1,
      );

      final List<int> bytes = StarPrntEncoder.assembleReceipt(
        rasterizedReceipt,
        PrinterProfiles.mcp30,
        const Receipt(children: <PrintElement>[]),
      );

      expect(bytes, <int>[
        0x1B,
        0x40,
        0x1B,
        0x1D,
        0x50,
        0x31,
        0x1B,
        0x58,
        0x08,
        0x00,
        0x80,
        0x00,
        0x00,
        0x40,
        0x00,
        0x00,
        0x80,
        0x00,
        0x00,
        0x00,
        0x00,
        0x00,
        0x00,
        0x00,
        0x00,
        0x00,
        0x00,
        0x00,
        0x00,
        0x00,
        0x00,
        0x00,
        0x00,
        0x00,
        0x1B,
        0x61,
        0x03,
        0x1B,
        0x64,
        0x00,
      ]);

      rasterizedReceipt.dispose();
    });

    test('throws for strict unsupported beep', () async {
      final RasterizedReceipt rasterizedReceipt = RasterizedReceipt(
        image: await _createImage(8, 2),
        monochromeBits: Uint8List.fromList(<int>[0x00, 0x00]),
        widthPixels: 8,
        heightPixels: 2,
        widthBytes: 1,
      );

      expect(
        () => StarPrntEncoder.assembleReceipt(
          rasterizedReceipt,
          PrinterProfiles.mcp30,
          const Receipt(
            children: <PrintElement>[],
            beep: true,
            strictFeatures: true,
          ),
        ),
        throwsA(isA<UnsupportedFeatureException>()),
      );

      rasterizedReceipt.dispose();
    });

    test('emits external device pulse for drawer opening', () async {
      final RasterizedReceipt rasterizedReceipt = RasterizedReceipt(
        image: await _createImage(8, 2),
        monochromeBits: Uint8List.fromList(<int>[0x00, 0x00]),
        widthPixels: 8,
        heightPixels: 2,
        widthBytes: 1,
      );

      final List<int> bytes = StarPrntEncoder.assembleReceipt(
        rasterizedReceipt,
        PrinterProfiles.mcp30,
        const Receipt(children: <PrintElement>[], cut: false, openDrawer: true),
      );

      expect(bytes.skip(bytes.length - 5).toList(), <int>[
        0x1B,
        0x07,
        0x14,
        0x14,
        0x07,
      ]);

      rasterizedReceipt.dispose();
    });
  });

  group('ReceiptEncoders', () {
    test('selects ESC/POS for Epson profiles', () async {
      final RasterizedReceipt rasterizedReceipt = RasterizedReceipt(
        image: await _createImage(8, 2),
        monochromeBits: Uint8List.fromList(<int>[0xA0, 0x40]),
        widthPixels: 8,
        heightPixels: 2,
        widthBytes: 1,
      );

      final List<int> bytes = ReceiptEncoders.assembleReceipt(
        rasterizedReceipt,
        PrinterProfiles.tmT88V,
        const Receipt(children: <PrintElement>[]),
      );

      expect(bytes.take(6), <int>[0x1B, 0x40, 0x1D, 0x76, 0x30, 0x00]);

      rasterizedReceipt.dispose();
    });

    test('selects StarPRNT for MCP30 profiles', () async {
      final RasterizedReceipt rasterizedReceipt = RasterizedReceipt(
        image: await _createImage(8, 2),
        monochromeBits: Uint8List.fromList(<int>[0xA0, 0x40]),
        widthPixels: 8,
        heightPixels: 2,
        widthBytes: 1,
      );

      final List<int> bytes = ReceiptEncoders.assembleReceipt(
        rasterizedReceipt,
        PrinterProfiles.mcp30,
        const Receipt(children: <PrintElement>[]),
      );

      expect(bytes.take(6), <int>[0x1B, 0x40, 0x1B, 0x1D, 0x50, 0x31]);

      rasterizedReceipt.dispose();
    });
  });

  group('Receipt', () {
    test('rasterizes Arabic text into monochrome output', () async {
      final Receipt receipt = Receipt(
        children: <PrintElement>[
          const TextElement('مرحبا بالعالم', textAlign: TextAlign.center),
          const SpacerElement(height: 16),
          const QrCodeElement('https://example.com', size: 120),
        ],
      );

      final RasterizedReceipt rasterizedReceipt = await receipt.rasterize(
        PrinterProfiles.tmT88V,
        locale: const ui.Locale('ar'),
        textDirection: ui.TextDirection.rtl,
      );

      expect(rasterizedReceipt.widthPixels, 512);
      expect(rasterizedReceipt.heightPixels, greaterThan(0));
      expect(
        rasterizedReceipt.monochromeBits.any((int byte) => byte != 0),
        isTrue,
      );

      rasterizedReceipt.dispose();
    });
  });
}

class _RecordingElement extends PrintElement {
  const _RecordingElement(this.measuredWidths, {required this.height});

  final List<double> measuredWidths;
  final double height;

  @override
  Size measure(BoxConstraints constraints, PrintContext context) {
    measuredWidths.add(constraints.maxWidth);
    return Size(constraints.maxWidth, height);
  }

  @override
  void paint(ui.Canvas canvas, Size size, PrintContext context) {}
}

class _ConstraintRecordingElement extends PrintElement {
  const _ConstraintRecordingElement(
    this.constraintsSeen, {
    required this.height,
  });

  final List<BoxConstraints> constraintsSeen;
  final double height;

  @override
  Size measure(BoxConstraints constraints, PrintContext context) {
    constraintsSeen.add(constraints);
    final double width = constraints.hasBoundedWidth ? constraints.maxWidth : 0;
    return Size(width, height);
  }

  @override
  void paint(ui.Canvas canvas, Size size, PrintContext context) {}
}

Future<ui.Image> _createImage(int width, int height) async {
  final ui.PictureRecorder recorder = ui.PictureRecorder();
  final ui.Canvas canvas = ui.Canvas(
    recorder,
    ui.Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
  );
  canvas.drawRect(
    ui.Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
    ui.Paint()..color = const ui.Color(0xFFFFFFFF),
  );
  final ui.Picture picture = recorder.endRecording();
  return picture.toImage(width, height);
}

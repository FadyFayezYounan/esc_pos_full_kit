import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../contracts/printer_profile.dart';
import 'receipt.dart';

/// A widget that previews the exact raster image sent to the printer.
class ReceiptPreview extends StatefulWidget {
  /// Creates a new [ReceiptPreview].
  const ReceiptPreview({
    super.key,
    required this.receipt,
    required this.profile,
    this.locale,
    this.textDirection,
    this.placeholder,
    this.backgroundColor = const Color(0xFFFFFFFF),
  });

  /// The receipt to rasterize.
  final Receipt receipt;

  /// The printer profile used to determine receipt width and capabilities.
  final PrinterProfile profile;

  /// An optional locale override for text shaping.
  final Locale? locale;

  /// An optional text direction override.
  final TextDirection? textDirection;

  /// A widget shown while the preview is loading.
  final Widget? placeholder;

  /// The background color behind the rendered image.
  final Color backgroundColor;

  @override
  State<ReceiptPreview> createState() => _ReceiptPreviewState();

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DiagnosticsProperty<Receipt>('receipt', receipt));
    properties.add(DiagnosticsProperty<PrinterProfile>('profile', profile));
    properties.add(
      DiagnosticsProperty<Locale?>('locale', locale, defaultValue: null),
    );
    properties.add(
      EnumProperty<TextDirection?>(
        'textDirection',
        textDirection,
        defaultValue: null,
      ),
    );
    properties.add(
      ColorProperty(
        'backgroundColor',
        backgroundColor,
        defaultValue: const Color(0xFFFFFFFF),
      ),
    );
    properties.add(
      DiagnosticsProperty<Widget?>(
        'placeholder',
        placeholder,
        defaultValue: null,
      ),
    );
  }
}

class _ReceiptPreviewState extends State<ReceiptPreview> {
  RasterizedReceipt? _rasterizedReceipt;
  Object? _error;
  bool _isLoading = true;
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    _loadPreview();
  }

  @override
  void didUpdateWidget(covariant ReceiptPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.receipt != oldWidget.receipt ||
        widget.profile != oldWidget.profile ||
        widget.locale != oldWidget.locale ||
        widget.textDirection != oldWidget.textDirection) {
      _loadPreview();
    }
  }

  @override
  void dispose() {
    _disposeRasterizedReceipt();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final RasterizedReceipt? rasterizedReceipt = _rasterizedReceipt;

    if (rasterizedReceipt != null) {
      return ColoredBox(
        color: widget.backgroundColor,
        child: FittedBox(
          fit: BoxFit.contain,
          alignment: Alignment.topCenter,
          child: SizedBox(
            width: rasterizedReceipt.widthPixels.toDouble(),
            height: rasterizedReceipt.heightPixels.toDouble(),
            child: RawImage(
              image: rasterizedReceipt.image,
              filterQuality: FilterQuality.none,
            ),
          ),
        ),
      );
    }

    if (_error != null) {
      return ColoredBox(
        color: widget.backgroundColor,
        child: Center(
          child: Directionality(
            textDirection: widget.textDirection ?? TextDirection.ltr,
            child: Text(_error.toString(), textAlign: TextAlign.center),
          ),
        ),
      );
    }

    if (_isLoading && widget.placeholder != null) {
      return ColoredBox(
        color: widget.backgroundColor,
        child: widget.placeholder!,
      );
    }

    return ColoredBox(
      color: widget.backgroundColor,
      child: const SizedBox.expand(),
    );
  }

  Future<void> _loadPreview() async {
    final int generation = ++_generation;
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final RasterizedReceipt nextReceipt = await widget.receipt.rasterize(
        widget.profile,
        locale: widget.locale,
        textDirection: widget.textDirection,
      );
      if (!mounted || generation != _generation) {
        nextReceipt.dispose();
        return;
      }

      final RasterizedReceipt? previousReceipt = _rasterizedReceipt;
      setState(() {
        _rasterizedReceipt = nextReceipt;
        _isLoading = false;
      });
      previousReceipt?.dispose();
    } catch (error) {
      if (!mounted || generation != _generation) {
        return;
      }
      _disposeRasterizedReceipt();
      setState(() {
        _error = error;
        _isLoading = false;
      });
    }
  }

  void _disposeRasterizedReceipt() {
    _rasterizedReceipt?.dispose();
    _rasterizedReceipt = null;
  }
}

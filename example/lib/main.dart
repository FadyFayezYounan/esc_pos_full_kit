import 'dart:ui' as ui;

import 'package:esc_pos_full_kit/esc_pos_full_kit.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

void main() {
  GoogleFonts.config.allowRuntimeFetching = false;
  runApp(const ReceiptExampleApp());
}

final List<PrinterProfile> _demoProfiles = List<PrinterProfile>.unmodifiable(
  () {
    final List<PrinterProfile> compatibleProfiles = PrinterProfiles.builtIn
        .where(
          (PrinterProfile profile) =>
              profile.media.widthPixels != null &&
              profile.features.bitImageRaster &&
              !profile.features.starCommands,
        )
        .toList(growable: false);

    return compatibleProfiles.isNotEmpty
        ? compatibleProfiles
        : PrinterProfiles.builtIn;
  }(),
);

const List<_DemoLineItem> _demoLineItems = <_DemoLineItem>[
  _DemoLineItem(
    englishName: 'Brazilian beans 250g',
    arabicName: 'حبوب برازيلية 250 جم',
    quantity: 1,
    price: 185,
  ),
  _DemoLineItem(
    englishName: 'Cardamom cookies',
    arabicName: 'كوكيز الهيل',
    quantity: 2,
    price: 45,
  ),
  _DemoLineItem(
    englishName: 'Cold brew bottle',
    arabicName: 'زجاجة كولد برو',
    quantity: 1,
    price: 95,
  ),
];

TextStyle _receiptTextStyle({
  required String fontFamily,
  required double fontSize,
  FontWeight fontWeight = FontWeight.normal,
  double? letterSpacing,
}) {
  return TextStyle(
    fontFamily: fontFamily,
    fontSize: fontSize,
    fontWeight: fontWeight,
    letterSpacing: letterSpacing,
  );
}

/// A runnable demo app for `esc_pos_full_kit`.
class ReceiptExampleApp extends StatelessWidget {
  /// Creates the example app.
  const ReceiptExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    final String robotoMonoFamily = GoogleFonts.robotoMono().fontFamily!;
    final ColorScheme colorScheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF9C5A2A),
      brightness: Brightness.light,
    );
    final ThemeData baseTheme = ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: const Color(0xFFF8F2E9),
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(28),
          side: BorderSide(color: colorScheme.outlineVariant),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFFFFFBF6),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(18)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: colorScheme.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: colorScheme.primary, width: 1.4),
        ),
      ),
    );
    final TextTheme monoTextTheme = baseTheme.textTheme.apply(
      fontFamily: robotoMonoFamily,
      bodyColor: baseTheme.colorScheme.onSurface,
      displayColor: baseTheme.colorScheme.onSurface,
    );

    return MaterialApp(
      title: 'ESC POS Full Kit Example',
      debugShowCheckedModeBanner: false,
      theme: baseTheme.copyWith(
        textTheme: monoTextTheme,
        primaryTextTheme: monoTextTheme,
      ),
      home: const _ReceiptDemoPage(),
    );
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(StringProperty('title', 'ESC POS Full Kit Example'));
  }
}

enum _ReceiptLanguage { english, arabic, mixed }

class _ReceiptDemoPage extends StatefulWidget {
  const _ReceiptDemoPage();

  @override
  State<_ReceiptDemoPage> createState() => _ReceiptDemoPageState();
}

class _ReceiptDemoPageState extends State<_ReceiptDemoPage> {
  late final TextEditingController _merchantController;
  late final TextEditingController _hostController;
  late final TextEditingController _portController;

  late PrinterProfile _selectedProfile;
  late String _robotoMonoFamily;
  _ReceiptLanguage _language = _ReceiptLanguage.mixed;
  bool _isPrinting = false;
  String? _statusMessage;

  @override
  void initState() {
    super.initState();
    _merchantController = TextEditingController(text: 'Wasfa Roastery');
    _hostController = TextEditingController(text: '192.168.8.52');
    _portController = TextEditingController(text: '9100');
    _robotoMonoFamily = GoogleFonts.robotoMono().fontFamily!;
    _selectedProfile = _demoProfiles.firstWhere(
      (PrinterProfile profile) => profile.id == PrinterProfiles.tmT88V.id,
      orElse: () => _demoProfiles.first,
    );
  }

  @override
  void dispose() {
    _merchantController.dispose();
    _hostController.dispose();
    _portController.dispose();
    super.dispose();
  }

  Receipt get _receipt {
    final String merchantName = _merchantController.text.trim().isEmpty
        ? 'Wasfa Roastery'
        : _merchantController.text.trim();
    final double subtotal = _demoLineItems.fold<double>(
      0,
      (double sum, _DemoLineItem item) => sum + item.total,
    );
    const double tax = 18;
    final double total = subtotal + tax;

    return Receipt(
      padding: const EdgeInsets.all(18),
      children: <PrintElement>[
        TextElement(
          merchantName,
          textAlign: TextAlign.center,
          style: _receiptTextStyle(
            fontFamily: _robotoMonoFamily,
            fontSize: 34,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.3,
          ),
        ),
        const SpacerElement(height: 10),
        TextElement(
          _taglineFor(_language),
          textAlign: TextAlign.center,
          style: _receiptTextStyle(
            fontFamily: _robotoMonoFamily,
            fontSize: 20,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SpacerElement(height: 16),
        const DividerElement(dashStyle: DashStyle.dashed),
        const SpacerElement(height: 14),
        TextElement(
          _headlineFor(_language),
          textAlign: TextAlign.center,
          style: _receiptTextStyle(
            fontFamily: _robotoMonoFamily,
            fontSize: 28,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SpacerElement(height: 14),
        _buildTableHeader(),
        const SpacerElement(height: 8),
        ..._buildItemRows(),
        const SpacerElement(height: 12),
        const DividerElement(dashStyle: DashStyle.dashed),
        const SpacerElement(height: 10),
        _buildSummaryRow(
          label: _labelFor(english: 'Subtotal', arabic: 'المجموع الفرعي'),
          value: subtotal,
        ),
        const SpacerElement(height: 6),
        _buildSummaryRow(
          label: _labelFor(english: 'Tax', arabic: 'الضريبة'),
          value: tax,
        ),
        const SpacerElement(height: 8),
        const DividerElement(thickness: 1.2),
        const SpacerElement(height: 8),
        _buildSummaryRow(
          label: _labelFor(english: 'Total', arabic: 'الإجمالي'),
          value: total,
          isEmphasized: true,
        ),
        const SpacerElement(height: 18),
        TextElement(
          _labelFor(english: 'Order ID', arabic: 'رقم الطلب'),
          textAlign: TextAlign.center,
          style: _receiptTextStyle(
            fontFamily: _robotoMonoFamily,
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SpacerElement(height: 6),
        TextElement(
          '#A-1024-78',
          textAlign: TextAlign.center,
          textDirection: ui.TextDirection.ltr,
          style: _receiptTextStyle(
            fontFamily: _robotoMonoFamily,
            fontSize: 24,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.8,
          ),
        ),
        const SpacerElement(height: 18),
        const BarcodeElement(
          'A102478',
          type: BarcodeElementType.code128,
          height: 72,
        ),
        const SpacerElement(height: 20),
        const QrCodeElement('https://example.com/orders/A102478', size: 140),
        const SpacerElement(height: 16),
        TextElement(
          _footerFor(_language),
          textAlign: TextAlign.center,
          style: _receiptTextStyle(
            fontFamily: _robotoMonoFamily,
            fontSize: 18,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  ui.Locale get _locale {
    return switch (_language) {
      _ReceiptLanguage.english => const ui.Locale('en'),
      _ReceiptLanguage.arabic => const ui.Locale('ar'),
      _ReceiptLanguage.mixed => const ui.Locale('ar'),
    };
  }

  ui.TextDirection get _textDirection {
    return switch (_language) {
      _ReceiptLanguage.english => ui.TextDirection.ltr,
      _ReceiptLanguage.arabic => ui.TextDirection.rtl,
      _ReceiptLanguage.mixed => ui.TextDirection.rtl,
    };
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            final bool isWide = constraints.maxWidth >= 1080;
            final Widget controls = _buildControls(theme);
            final Widget preview = _buildPreview(theme, isWide: isWide);

            return DecoratedBox(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: <Color>[Color(0xFFF9F3EC), Color(0xFFF2E8DB)],
                ),
              ),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    _buildHero(theme),
                    const SizedBox(height: 24),
                    if (isWide)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          SizedBox(width: 380, child: controls),
                          const SizedBox(width: 24),
                          Expanded(child: preview),
                        ],
                      )
                    else
                      Column(
                        children: <Widget>[
                          controls,
                          const SizedBox(height: 24),
                          preview,
                        ],
                      ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildHero(ThemeData theme) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: const Color(0xFF2F2118),
        borderRadius: BorderRadius.circular(32),
      ),
      child: Wrap(
        spacing: 16,
        runSpacing: 16,
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: <Widget>[
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Raster-first ESC/POS demo',
                  style: theme.textTheme.displaySmall?.copyWith(
                    color: const Color(0xFFFFF4E9),
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.8,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Build a receipt from package elements, preview the same '
                  'bitmap sent to the printer, and try real network printing '
                  'against a TCP ESC/POS device.',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: const Color(0xFFF2DAC3),
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            decoration: BoxDecoration(
              color: const Color(0xFF4D3527),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Profile',
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: const Color(0xFFE8C8A8),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _selectedProfile.name,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildControls(ThemeData theme) {
    final String printableWidth = _selectedProfile.media.widthPixels == null
        ? 'Unknown width'
        : '${_selectedProfile.media.widthPixels} px';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'Receipt builder',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Switch language modes, choose a printer profile, and send the '
              'generated receipt over TCP.',
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _merchantController,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                labelText: 'Merchant name',
                hintText: 'Wasfa Roastery',
              ),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<PrinterProfile>(
              isExpanded: true,
              initialValue: _selectedProfile,
              items: _demoProfiles
                  .map(
                    (PrinterProfile profile) =>
                        DropdownMenuItem<PrinterProfile>(
                          value: profile,
                          child: Text(
                            '${profile.vendor} • ${profile.name}',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                  )
                  .toList(growable: false),
              onChanged: (PrinterProfile? profile) {
                if (profile == null) {
                  return;
                }
                setState(() {
                  _selectedProfile = profile;
                });
              },
              decoration: const InputDecoration(labelText: 'Printer profile'),
            ),
            const SizedBox(height: 10),
            Text(
              'Printable width: $printableWidth',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Receipt language',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: <Widget>[
                _buildLanguageChip(
                  context,
                  label: 'English',
                  value: _ReceiptLanguage.english,
                ),
                _buildLanguageChip(
                  context,
                  label: 'Arabic',
                  value: _ReceiptLanguage.arabic,
                ),
                _buildLanguageChip(
                  context,
                  label: 'Mixed',
                  value: _ReceiptLanguage.mixed,
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              children: <Widget>[
                Expanded(
                  child: TextField(
                    controller: _hostController,
                    keyboardType: TextInputType.url,
                    onChanged: (_) => setState(() {}),
                    decoration: const InputDecoration(
                      labelText: 'Printer host',
                      hintText: '192.168.1.100',
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  width: 110,
                  child: TextField(
                    controller: _portController,
                    keyboardType: TextInputType.number,
                    onChanged: (_) => setState(() {}),
                    decoration: const InputDecoration(
                      labelText: 'Port',
                      hintText: '9100',
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            if (_statusMessage != null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF4E7),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: const Color(0xFFE8C8A8)),
                ),
                child: Text(
                  _statusMessage!,
                  style: theme.textTheme.bodyMedium?.copyWith(height: 1.4),
                ),
              ),
            if (_statusMessage != null) const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: <Widget>[
                FilledButton.icon(
                  onPressed: _isPrinting ? null : _handlePrint,
                  icon: _isPrinting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.print_rounded),
                  label: Text(_isPrinting ? 'Printing…' : 'Print over TCP'),
                ),
                OutlinedButton.icon(
                  onPressed: _resetDefaults,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Reset sample'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPreview(ThemeData theme, {required bool isWide}) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'Receipt preview',
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'This uses the same rasterized image that gets encoded '
                        'into ESC/POS bytes.',
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF5E6D3),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    '${_locale.languageCode.toUpperCase()} • '
                    '${_textDirection == ui.TextDirection.rtl ? 'RTL' : 'LTR'}',
                    style: theme.textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Container(
              height: isWide ? 840 : 620,
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: const Color(0xFFECE1D3),
                borderRadius: BorderRadius.circular(24),
              ),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: const Color(0xFFFFFCF8),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: const <BoxShadow>[
                    BoxShadow(
                      color: Color(0x1A000000),
                      blurRadius: 22,
                      offset: Offset(0, 10),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: ReceiptPreview(
                    receipt: _receipt,
                    profile: _selectedProfile,
                    locale: Locale(_locale.languageCode),
                    textDirection: _textDirection,
                    placeholder: const Center(
                      child: CircularProgressIndicator(),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLanguageChip(
    BuildContext context, {
    required String label,
    required _ReceiptLanguage value,
  }) {
    return ChoiceChip(
      label: Text(label),
      selected: _language == value,
      onSelected: (bool selected) {
        if (!selected) {
          return;
        }
        setState(() {
          _language = value;
        });
      },
    );
  }

  List<PrintElement> _buildItemRows() {
    return _demoLineItems
        .map(
          (_DemoLineItem item) => PaddingElement(
            padding: const EdgeInsets.only(bottom: 10),
            child: RowElement(
              <RowCell>[
                RowCell(
                  TextElement(
                    _language == _ReceiptLanguage.english
                        ? item.englishName
                        : _language == _ReceiptLanguage.arabic
                        ? item.arabicName
                        : '${item.arabicName} / ${item.englishName}',
                    style: _receiptTextStyle(
                      fontFamily: _robotoMonoFamily,
                      fontSize: 22,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  flex: 2,
                ),
                RowCell(
                  TextElement(
                    'x${item.quantity}',
                    textAlign: TextAlign.center,
                    textDirection: ui.TextDirection.ltr,
                    style: _receiptTextStyle(
                      fontFamily: _robotoMonoFamily,
                      fontSize: 22,
                    ),
                  ),
                ),
                RowCell(
                  TextElement(
                    _currency(item.total),
                    textAlign: TextAlign.right,
                    textDirection: ui.TextDirection.ltr,
                    style: _receiptTextStyle(
                      fontFamily: _robotoMonoFamily,
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
              gap: 8,
              crossAxisAlignment: CrossAxisAlignment.center,
            ),
          ),
        )
        .toList(growable: false);
  }

  PrintElement _buildTableHeader() {
    return RowElement(
      <RowCell>[
        RowCell(
          TextElement(
            _labelFor(english: 'Item', arabic: 'الصنف'),
            style: _receiptTextStyle(
              fontFamily: _robotoMonoFamily,
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
          flex: 2,
        ),
        RowCell(
          TextElement(
            _labelFor(english: 'Qty', arabic: 'الكمية'),
            textAlign: TextAlign.center,
            style: _receiptTextStyle(
              fontFamily: _robotoMonoFamily,
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        RowCell(
          TextElement(
            _labelFor(english: 'Price', arabic: 'السعر'),
            textAlign: TextAlign.right,
            style: _receiptTextStyle(
              fontFamily: _robotoMonoFamily,
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
      gap: 8,
      crossAxisAlignment: CrossAxisAlignment.center,
    );
  }

  PrintElement _buildSummaryRow({
    required String label,
    required double value,
    bool isEmphasized = false,
  }) {
    final TextStyle style = _receiptTextStyle(
      fontFamily: _robotoMonoFamily,
      fontSize: isEmphasized ? 26 : 22,
      fontWeight: isEmphasized ? FontWeight.w800 : FontWeight.w600,
    );

    return RowElement(
      <RowCell>[
        RowCell(TextElement(label, style: style), flex: 2),
        const RowCell(SpacerElement(height: 0)),
        RowCell(
          TextElement(
            _currency(value),
            style: style,
            textAlign: TextAlign.right,
            textDirection: ui.TextDirection.ltr,
          ),
        ),
      ],
      gap: 8,
      crossAxisAlignment: CrossAxisAlignment.center,
    );
  }

  Future<void> _handlePrint() async {
    final String host = _hostController.text.trim();
    final int? port = int.tryParse(_portController.text.trim());

    if (host.isEmpty || port == null) {
      setState(() {
        _statusMessage =
            'Enter a valid printer host and TCP port before printing.';
      });
      return;
    }

    setState(() {
      _isPrinting = true;
      _statusMessage = 'Sending the rasterized receipt to $host:$port...';
    });

    try {
      await _receipt.printTo(
        NetworkPrinter(host, port: port),
        _selectedProfile,
        locale: _locale,
        textDirection: _textDirection,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _statusMessage = 'Receipt sent successfully to $host:$port.';
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Receipt sent to $host:$port')));
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _statusMessage = 'Printing failed: $error';
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Printing failed: $error')));
    } finally {
      if (mounted) {
        setState(() {
          _isPrinting = false;
        });
      }
    }
  }

  void _resetDefaults() {
    setState(() {
      _merchantController.text = 'Wasfa Roastery';
      _hostController.text = '192.168.1.100';
      _portController.text = '9100';
      _selectedProfile = _demoProfiles.firstWhere(
        (PrinterProfile profile) => profile.id == PrinterProfiles.tmT88V.id,
        orElse: () => _demoProfiles.first,
      );
      _language = _ReceiptLanguage.mixed;
      _statusMessage = 'Sample values restored.';
    });
  }

  String _headlineFor(_ReceiptLanguage language) {
    return switch (language) {
      _ReceiptLanguage.english => 'Fresh roast order',
      _ReceiptLanguage.arabic => 'طلب تحميص طازج',
      _ReceiptLanguage.mixed => 'طلب تحميص طازج • Fresh roast order',
    };
  }

  String _taglineFor(_ReceiptLanguage language) {
    return switch (language) {
      _ReceiptLanguage.english => 'Specialty coffee and warm bakery',
      _ReceiptLanguage.arabic => 'قهوة مختصة ومخبوزات دافئة',
      _ReceiptLanguage.mixed => 'قهوة مختصة • Specialty coffee',
    };
  }

  String _footerFor(_ReceiptLanguage language) {
    return switch (language) {
      _ReceiptLanguage.english => 'Thank you for your order',
      _ReceiptLanguage.arabic => 'شكراً لطلبك',
      _ReceiptLanguage.mixed => 'شكراً لطلبك • Thank you for your order',
    };
  }

  String _labelFor({required String english, required String arabic}) {
    return switch (_language) {
      _ReceiptLanguage.english => english,
      _ReceiptLanguage.arabic => arabic,
      _ReceiptLanguage.mixed => '$arabic / $english',
    };
  }

  String _currency(double value) => '\$${value.toStringAsFixed(2)}';
}

class _DemoLineItem {
  const _DemoLineItem({
    required this.englishName,
    required this.arabicName,
    required this.quantity,
    required this.price,
  });

  final String englishName;
  final String arabicName;
  final int quantity;
  final double price;

  double get total => quantity * price;
}

import 'package:flutter_test/flutter_test.dart';

import 'package:example/main.dart';

void main() {
  testWidgets('renders the receipt example shell', (WidgetTester tester) async {
    await tester.pumpWidget(const ReceiptExampleApp());
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Raster-first ESC/POS demo'), findsOneWidget);
    expect(find.text('Receipt builder'), findsOneWidget);
    expect(find.text('Receipt preview'), findsOneWidget);
    expect(find.text('Print over TCP'), findsOneWidget);
  });
}

# Example App

This example project demonstrates the package in a realistic flow:

- Choose a compatible printer profile
- Switch between English, Arabic, and mixed-direction receipts
- Preview the exact rasterized bitmap through `ReceiptPreview`
- Send the receipt to a TCP thermal printer with `NetworkPrinter`

## Run

```bash
cd example
flutter pub get
flutter run
```

By default the example uses `192.168.1.100:9100`. Change the host and port in the UI before printing to a real printer.

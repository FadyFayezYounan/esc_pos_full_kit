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

By default the example uses the Star Micronics `MCP30` profile and
`192.168.100.120:9100`, matching the attached mC-Print3 self-test print.
Change the host, port, or printer profile in the UI before printing to a
different device.

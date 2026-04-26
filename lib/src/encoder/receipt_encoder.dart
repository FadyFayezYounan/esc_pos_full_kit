import '../contracts/printer_profile.dart';
import '../exceptions.dart';
import '../receipt/receipt.dart';
import 'esc_pos_encoder.dart';
import 'star_prnt_encoder.dart';

/// Encodes a rasterized receipt into printer command bytes.
abstract interface class ReceiptEncoder {
  /// Builds a complete command stream for [rasterizedReceipt].
  List<int> assembleReceipt(
    RasterizedReceipt rasterizedReceipt,
    PrinterProfile profile,
    Receipt receipt,
  );
}

/// Selects receipt encoders for printer profiles.
abstract final class ReceiptEncoders {
  static const ReceiptEncoder _escPos = _EscPosReceiptEncoder();
  static const ReceiptEncoder _starPrnt = _StarPrntReceiptEncoder();

  /// Returns the command encoder for [profile].
  static ReceiptEncoder forProfile(PrinterProfile profile) {
    return switch (profile.commandDialect) {
      PrinterCommandDialect.escPos => _escPos,
      PrinterCommandDialect.starPrnt => _starPrnt,
    };
  }

  /// Builds a complete command stream for [profile].
  static List<int> assembleReceipt(
    RasterizedReceipt rasterizedReceipt,
    PrinterProfile profile,
    Receipt receipt,
  ) {
    return forProfile(
      profile,
    ).assembleReceipt(rasterizedReceipt, profile, receipt);
  }
}

final class _EscPosReceiptEncoder implements ReceiptEncoder {
  const _EscPosReceiptEncoder();

  @override
  List<int> assembleReceipt(
    RasterizedReceipt rasterizedReceipt,
    PrinterProfile profile,
    Receipt receipt,
  ) {
    if (profile.commandDialect != PrinterCommandDialect.escPos) {
      throw UnsupportedFeatureException(
        'Printer profile "${profile.id}" does not use ESC/POS commands.',
      );
    }
    return EscPosEncoder.assembleReceipt(rasterizedReceipt, profile, receipt);
  }
}

final class _StarPrntReceiptEncoder implements ReceiptEncoder {
  const _StarPrntReceiptEncoder();

  @override
  List<int> assembleReceipt(
    RasterizedReceipt rasterizedReceipt,
    PrinterProfile profile,
    Receipt receipt,
  ) {
    return StarPrntEncoder.assembleReceipt(rasterizedReceipt, profile, receipt);
  }
}

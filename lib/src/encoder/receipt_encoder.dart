import '../contracts/printer_profile.dart';
import '../receipt/receipt.dart';
import 'esc_pos_encoder.dart';
import 'star_prnt_encoder.dart';

/// Selects the correct byte encoder for a printer profile.
abstract final class ReceiptEncoder {
  /// Builds a printable byte stream for [receipt].
  static List<int> assembleReceipt(
    RasterizedReceipt rasterizedReceipt,
    PrinterProfile profile,
    Receipt receipt,
  ) {
    if (profile.features.starCommands) {
      return StarPrntEncoder.assembleReceipt(
        rasterizedReceipt,
        profile,
        receipt,
      );
    }

    return EscPosEncoder.assembleReceipt(rasterizedReceipt, profile, receipt);
  }
}

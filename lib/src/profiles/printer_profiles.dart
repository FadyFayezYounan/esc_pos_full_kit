import '../contracts/printer_profile.dart';
import '_profiles/built_in_profiles.dart' as built_in;

/// Built-in printer profiles plus runtime registration for custom profiles.
abstract final class PrinterProfiles {
  static final Map<String, PrinterProfile> _registeredProfiles =
      <String, PrinterProfile>{};

  /// ZKTeco ZKP8001.
  static const PrinterProfile zkp8001 = built_in.zkp8001;

  /// Xprinter XP-N160I.
  static const PrinterProfile xpN160I = built_in.xpN160I;

  /// Rongta RP80USE.
  static const PrinterProfile rp80use = built_in.rp80use;

  /// TP806L.
  static const PrinterProfile tp806l = built_in.tp806l;

  /// AF-240.
  static const PrinterProfile af240 = built_in.af_240;

  /// Citizen CT-S651.
  static const PrinterProfile ctS651 = built_in.ctS651;

  /// NT-5890K.
  static const PrinterProfile nt5890K = built_in.nt_5890K;

  /// OCD-100.
  static const PrinterProfile ocd100 = built_in.ocd_100;

  /// OCD-300.
  static const PrinterProfile ocd300 = built_in.ocd_300;

  /// P822D.
  static const PrinterProfile p822d = built_in.p822d;

  /// POS-5890.
  static const PrinterProfile pos5890 = built_in.pos_5890;

  /// RP326.
  static const PrinterProfile rp326 = built_in.rp326;

  /// Star SP2000.
  static const PrinterProfile sp2000 = built_in.sp2000;

  /// Sunmi V2.
  static const PrinterProfile sunmiV2 = built_in.sunmiV2;

  /// TEP-200M.
  static const PrinterProfile tep200M = built_in.tep_200M;

  /// Epson TM-P80.
  static const PrinterProfile tmP80 = built_in.tmP80;

  /// Epson TM-P80 42-column.
  static const PrinterProfile tmP80_42col = built_in.tmP80_42col;

  /// Epson TM-T88II.
  static const PrinterProfile tmT88II = built_in.tmT88II;

  /// Epson TM-T88III.
  static const PrinterProfile tmT88III = built_in.tmT88III;

  /// Epson TM-T88V.
  static const PrinterProfile tmT88V = built_in.tmT88V;

  /// Epson TM-T88IV.
  static const PrinterProfile tmT88IV = built_in.tmT88IV;

  /// Epson TM-T88IV-SA.
  static const PrinterProfile tmT88IVSA = built_in.tmT88IVSA;

  /// Epson TM-U220.
  static const PrinterProfile tmU220 = built_in.tmU220;

  /// Star TSP600.
  static const PrinterProfile tsp600 = built_in.tsp600;

  /// Star TUP500.
  static const PrinterProfile tup500 = built_in.tup500;

  /// ZJ-5870.
  static const PrinterProfile zj5870 = built_in.zj_5870;

  /// Generic default profile.
  static const PrinterProfile defaultProfile = built_in.default_;

  /// Generic default profile.
  static const PrinterProfile default_ = built_in.default_;

  /// A simple fallback profile.
  static const PrinterProfile simple = built_in.simple;

  /// All built-in profiles bundled with the package.
  static const List<PrinterProfile> builtIn =
      built_in.allBuiltInPrinterProfiles;

  /// All built-in and runtime-registered profiles.
  static List<PrinterProfile> get all {
    if (_registeredProfiles.isEmpty) {
      return builtIn;
    }
    return List<PrinterProfile>.unmodifiable(<PrinterProfile>[
      ...builtIn,
      ..._registeredProfiles.values,
    ]);
  }

  /// Returns the profile for [id], or null when no profile matches.
  static PrinterProfile? byId(String id) {
    for (final PrinterProfile profile in builtIn) {
      if (profile.id == id) {
        return profile;
      }
    }
    return _registeredProfiles[id];
  }

  /// Registers a custom profile for later lookup via [byId].
  static void register(PrinterProfile profile) {
    if (byId(profile.id) case final PrinterProfile existingProfile?
        when identical(existingProfile, profile)) {
      return;
    }
    if (builtIn.any(
      (PrinterProfile builtInProfile) => builtInProfile.id == profile.id,
    )) {
      throw ArgumentError.value(
        profile.id,
        'profile.id',
        'A built-in printer profile with this id already exists.',
      );
    }
    _registeredProfiles[profile.id] = profile;
  }
}

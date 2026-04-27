import 'dart:io';

import 'package:meta/meta.dart';

/// Base exception type for receipt rendering and printing failures.
@immutable
sealed class PrintException implements Exception {
  /// Creates a new [PrintException].
  const PrintException(this.message, [this.cause]);

  /// A human-readable description of the failure.
  final String message;

  /// The underlying error when one exists.
  final Object? cause;

  /// An end-user-oriented description with actionable fix suggestions.
  String get userFacingMessage =>
      'An unexpected printing error occurred: $message';

  @override
  String toString() {
    if (cause == null) {
      return '$runtimeType: $message';
    }
    return '$runtimeType: $message ($cause)';
  }
}

/// Thrown when a printer transport fails to connect or send data.
final class ConnectionException extends PrintException {
  /// Creates a new [ConnectionException].
  const ConnectionException(super.message, [super.cause]);

  @override
  String get userFacingMessage {
    final SocketException? socketError = cause is SocketException
        ? cause as SocketException
        : null;

    final String target = message;
    final String? osMessage = socketError?.osError?.message;
    final int? errorCode = socketError?.osError?.errorCode;

    // Connection timed out (ETIMEDOUT: 60 on macOS/iOS, 110 on Linux/Android)
    if (errorCode == 60 || errorCode == 110) {
      return '$target\n'
          '\nTo fix this:\n'
          '\u2022 Make sure the printer is powered on.\n'
          '\u2022 Verify the IP address is correct.\n'
          '\u2022 Ensure this device and the printer are on the same network.\n'
          '\u2022 Check that no firewall is blocking port ${socketError?.port ?? '9100'}.';
    }

    // Connection refused (ECONNREFUSED: 61 on macOS/iOS, 111 on Linux/Android)
    if (errorCode == 61 || errorCode == 111) {
      return '$target\n'
          '\nTo fix this:\n'
          '\u2022 The printer may be busy processing another job — wait and try again.\n'
          '\u2022 Verify the port number is correct (default is 9100).\n'
          '\u2022 Check that the printer accepts raw TCP connections on this port.';
    }

    // No route to host (EHOSTUNREACH: 65 on macOS/iOS, 113 on Linux/Android)
    // or Network is unreachable (ENETUNREACH: 51 on macOS/iOS, 101 on Linux/Android)
    if (errorCode == 51 ||
        errorCode == 65 ||
        errorCode == 101 ||
        errorCode == 113) {
      return '$target\n'
          '\nTo fix this:\n'
          '\u2022 The IP address may be on a different network — double-check it.\n'
          '\u2022 Ensure your device and the printer are connected to the same WiFi or LAN.';
    }

    // Host not found (EAI_NONAME / resolution failure)
    if (osMessage != null &&
        (osMessage.contains('host') ||
            osMessage.contains('nodename') ||
            osMessage.contains('name'))) {
      return '$target\n'
          '\nTo fix this:\n'
          '\u2022 The printer hostname could not be resolved — try using an IP address instead.\n'
          '\u2022 If using an IP address, check that it is typed correctly.';
    }

    // Not connected before write
    if (message.contains('before connecting')) {
      return '$target\nThis is an internal error — the transport was not connected before sending data.';
    }

    // Generic connection failure
    return '$target\n'
        '\nTo fix this:\n'
        '\u2022 Verify the printer IP address and port are correct.\n'
        '\u2022 Make sure the printer is powered on and connected to the network.\n'
        '\u2022 Check that no firewall is blocking the connection.';
  }
}

/// Thrown when an input cannot be rendered or encoded safely.
final class ValidationException extends PrintException {
  /// Creates a new [ValidationException].
  const ValidationException(super.message, [super.cause]);

  @override
  String get userFacingMessage =>
      '$message\n\nTry selecting a different printer profile or check that the receipt content is valid.';
}

/// Thrown when a requested printer capability is unavailable.
final class UnsupportedFeatureException extends PrintException {
  /// Creates a new [UnsupportedFeatureException].
  const UnsupportedFeatureException(super.message, [super.cause]);

  @override
  String get userFacingMessage =>
      '$message\n\nThe selected printer model does not support a feature used in this receipt. Try a different printer profile.';
}

/// Thrown when rasterization fails after layout has started.
final class RasterizationException extends PrintException {
  /// Creates a new [RasterizationException].
  const RasterizationException(super.message, [super.cause]);

  @override
  String get userFacingMessage =>
      '$message\n\nThis may happen if the receipt content is too large or uses elements that cannot be processed. Try simplifying the receipt.';
}

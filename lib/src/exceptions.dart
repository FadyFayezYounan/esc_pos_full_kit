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
}

/// Thrown when an input cannot be rendered or encoded safely.
final class ValidationException extends PrintException {
  /// Creates a new [ValidationException].
  const ValidationException(super.message, [super.cause]);
}

/// Thrown when a requested printer capability is unavailable.
final class UnsupportedFeatureException extends PrintException {
  /// Creates a new [UnsupportedFeatureException].
  const UnsupportedFeatureException(super.message, [super.cause]);
}

/// Thrown when rasterization fails after layout has started.
final class RasterizationException extends PrintException {
  /// Creates a new [RasterizationException].
  const RasterizationException(super.message, [super.cause]);
}

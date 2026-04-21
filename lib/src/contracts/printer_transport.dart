/// Connection state changes exposed by a [PrinterTransport].
enum PrinterConnectionState {
  /// No printer connection exists.
  disconnected,

  /// A connection attempt is in progress.
  connecting,

  /// The transport is connected and ready to write bytes.
  connected,

  /// The most recent transport action failed.
  error,
}

/// Abstraction for writing encoded bytes to a printer.
abstract class PrinterTransport {
  /// Opens the underlying transport connection.
  Future<void> connect();

  /// Writes raw bytes to the printer.
  Future<void> write(List<int> bytes);

  /// Flushes any buffered bytes.
  Future<void> flush();

  /// Closes the transport connection.
  Future<void> disconnect();

  /// A broadcast stream of connection state changes.
  Stream<PrinterConnectionState> get state;
}

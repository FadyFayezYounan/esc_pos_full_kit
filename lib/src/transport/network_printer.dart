import 'dart:async';
import 'dart:io';

import '../contracts/printer_transport.dart';
import '../exceptions.dart';

/// A TCP socket printer transport.
class NetworkPrinter implements PrinterTransport {
  /// Creates a new [NetworkPrinter].
  NetworkPrinter(
    this.host, {
    this.port = 9100,
    this.connectTimeout = const Duration(seconds: 5),
  });

  /// The target printer host name or IP address.
  final String host;

  /// The printer TCP port.
  final int port;

  /// Timeout applied to the initial socket connection.
  final Duration connectTimeout;

  Socket? _socket;
  final StreamController<PrinterConnectionState> _stateController =
      StreamController<PrinterConnectionState>.broadcast();

  @override
  Stream<PrinterConnectionState> get state => _stateController.stream;

  @override
  Future<void> connect() async {
    _stateController.add(PrinterConnectionState.connecting);
    try {
      _socket = await Socket.connect(host, port, timeout: connectTimeout);
      _stateController.add(PrinterConnectionState.connected);
    } on SocketException catch (error) {
      _stateController.add(PrinterConnectionState.error);
      throw ConnectionException('Failed to connect to $host:$port.', error);
    }
  }

  @override
  Future<void> write(List<int> bytes) async {
    final Socket? socket = _socket;
    if (socket == null) {
      throw const ConnectionException('Cannot write bytes before connecting.');
    }

    try {
      socket.add(bytes);
    } on SocketException catch (error) {
      _stateController.add(PrinterConnectionState.error);
      throw ConnectionException(
        'Failed while writing data to $host:$port.',
        error,
      );
    }
  }

  @override
  Future<void> flush() async {
    try {
      await _socket?.flush();
    } on SocketException catch (error) {
      _stateController.add(PrinterConnectionState.error);
      throw ConnectionException(
        'Failed while flushing data to $host:$port.',
        error,
      );
    }
  }

  @override
  Future<void> disconnect() async {
    final Socket? socket = _socket;
    _socket = null;

    if (socket != null) {
      try {
        await socket.flush();
        await socket.close();
      } finally {
        socket.destroy();
      }
    }

    _stateController.add(PrinterConnectionState.disconnected);
  }
}

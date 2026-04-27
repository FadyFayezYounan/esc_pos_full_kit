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
        // Half-close the write side, sending a TCP FIN so the printer knows
        // we are done transmitting.
        await socket.close();
        // Drain any status bytes the printer may send back before fully
        // tearing down the socket.  Without this the OS may send a TCP RST
        // (triggered by unread bytes in the receive buffer), which can cause
        // some Epson embedded TCP stacks to discard their own receive buffer
        // and silently drop the print job.
        await socket.drain<Object?>().timeout(const Duration(seconds: 2));
      } catch (_) {
        // Timeout is expected (printers rarely close their side); errors here
        // are non-fatal.
      } finally {
        socket.destroy();
      }
    }

    _stateController.add(PrinterConnectionState.disconnected);
  }
}

import 'dart:async';
import 'dart:typed_data';

import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';
import 'package:typed_data/typed_data.dart' as typed;

/// Owns one connection to an MQTT broker for a single sync topic, handling
/// connect/reconnect and exposing raw bytes in and out. Knows nothing about
/// encryption or envelope structure — callers (an app's sync engine)
/// encrypt/decrypt via [SyncCrypto] themselves; this class only moves
/// bytes.
///
/// Defaults to HiveMQ's free public broker (`broker.hivemq.com`). That
/// broker has **no authentication and no access control** — anyone can
/// publish or subscribe to any topic — so every message this class carries
/// must already be ciphertext from the caller, and [topic] (derived from a
/// [SyncKey]) is the only thing standing between "anyone" and "this
/// specific connection's traffic."
class MqttSyncTransport {
  MqttSyncTransport({
    required this.topic,
    required this.clientIdentifier,
    this.host = 'broker.hivemq.com',
    this.tlsPort = 8883,
    this.tlsWebSocketPort = 8884,
  });

  final String topic;

  /// Must be unique per connecting client on the broker; callers should
  /// derive this from their own stable per-device id plus [topic] (or
  /// similar) so two devices on the same topic never collide.
  final String clientIdentifier;
  final String host;
  final int tlsPort;
  final int tlsWebSocketPort;

  MqttServerClient? _client;
  final StreamController<Uint8List> _incoming =
      StreamController<Uint8List>.broadcast();
  StreamSubscription<List<MqttReceivedMessage<MqttMessage>>>? _updatesSub;

  /// Decrypted-by-caller-later raw payload bytes received on [topic].
  Stream<Uint8List> get messages => _incoming.stream;

  bool get isConnected =>
      _client?.connectionStatus?.state == MqttConnectionState.connected;

  /// Connects, trying a plain TLS TCP socket first and falling back to
  /// TLS-over-WebSocket if that fails or times out — covers networks that
  /// block raw MQTT ports but allow HTTPS-looking traffic. Throws
  /// [StateError] if neither transport connects.
  Future<void> connect() async {
    if (isConnected) return;
    final client = await _attempt(tlsPort, useWebSocket: false) ??
        await _attempt(tlsWebSocketPort, useWebSocket: true);
    if (client == null) {
      throw StateError('Could not connect to $host on any transport.');
    }
    _client = client;
    _updatesSub = client.updates!.listen(_onData);
    client.subscribe(topic, MqttQos.atLeastOnce);
  }

  Future<MqttServerClient?> _attempt(
    int port, {
    required bool useWebSocket,
  }) async {
    final client = MqttServerClient(host, clientIdentifier)
      ..port = port
      ..secure = true
      ..useWebSocket = useWebSocket
      ..keepAlivePeriod = 30
      ..autoReconnect = true
      ..logging(on: false);
    try {
      final status = await client
          .connect()
          .timeout(const Duration(seconds: 10));
      if (status?.state == MqttConnectionState.connected) return client;
    } catch (_) {
      // Fall through — caller tries the next transport, or gives up.
    }
    client.disconnect();
    return null;
  }

  void _onData(List<MqttReceivedMessage<MqttMessage>> events) {
    for (final event in events) {
      final publish = event.payload as MqttPublishMessage;
      _incoming.add(
        Uint8List.fromList(publish.payload.message),
      );
    }
  }

  Future<void> publish(Uint8List bytes) async {
    final client = _client;
    if (client == null || !isConnected) {
      throw StateError('Not connected.');
    }
    final builder = MqttClientPayloadBuilder()
      ..addBuffer(typed.Uint8Buffer()..addAll(bytes));
    client.publishMessage(topic, MqttQos.atLeastOnce, builder.payload!);
  }

  Future<void> disconnect() async {
    await _updatesSub?.cancel();
    _updatesSub = null;
    _client?.disconnect();
    _client = null;
  }

  /// Disconnects and closes the message stream. Call when this transport
  /// (and the connection it belongs to) is being torn down for good — not
  /// between reconnects, where [disconnect] followed by [connect] is
  /// enough.
  Future<void> dispose() async {
    await disconnect();
    await _incoming.close();
  }
}

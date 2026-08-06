import 'dart:async';
import 'dart:typed_data';

import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';
import 'package:typed_data/typed_data.dart' as typed;

/// A message received on a sync connection's topic tree, tagged with which
/// subtopic (the path segment(s) after the base [MqttSyncTransport.topic])
/// it arrived on — needed to know *which row* a deletion marker refers to,
/// since an empty payload carries no envelope of its own to read that
/// from. See [MqttSyncTransport]'s doc comment for why every publish is
/// retained and per-row.
class MqttSyncMessage {
  MqttSyncMessage({required this.subtopic, required this.bytes});

  /// E.g. `task/3fae1c9e-...` or `control`.
  final String subtopic;

  /// Empty exactly when this is a retained-message deletion marker (see
  /// [MqttSyncTransport.clearRetained]) — never empty for a real message,
  /// since even the smallest encrypted envelope is well over zero bytes.
  final Uint8List bytes;
}

/// Owns one connection to an MQTT broker for a single sync connection's
/// topic tree, handling connect/reconnect and exposing raw bytes in and
/// out. Knows nothing about encryption or envelope structure — callers (an
/// app's sync engine) encrypt/decrypt via [SyncCrypto] themselves; this
/// class only moves bytes.
///
/// **Every message is published *retained*, one per row, on its own
/// subtopic** (see [publishRetained]/[clearRetained]) — this is
/// deliberate, not an oversight. A plain MQTT publish keeps no history at
/// all: a device that's offline (or hasn't paired yet) when a change goes
/// out would otherwise never see it, even after it reconnects — nothing
/// left to catch up on, no way to tell "nothing changed" from "I missed
/// something." A *retained* message is the one piece of state a broker
/// does keep: the broker stores exactly the last message published to a
/// given topic and delivers it immediately to any client that subscribes
/// (or re-subscribes) to that topic — including one that was offline for
/// the original publish. Giving every row its own subtopic
/// (`<entityType>/<syncId>`) turns the broker into a small, self-pruning
/// key-value store of "current state per row": [connect] subscribes to
/// the whole tree at once (`<topic>/#`), so pairing for the first time or
/// reconnecting after any amount of downtime always replays the full
/// current state of everything published so far, not just live traffic
/// from that moment on. [clearRetained] (an empty-payload retained
/// publish) is how a row's deletion is represented — MQTT's own way of
/// saying "nothing retained here anymore" — and is delivered live to
/// currently-subscribed peers too, so it doubles as the delete
/// notification for them.
///
/// One consequence worth calling out to callers: **the broker now holds a
/// standing copy of the ciphertext for every row a connection has ever
/// published**, not just transient in-flight traffic, until that row is
/// deleted. It's still just ciphertext to anyone without the connection's
/// secret, and still requires knowing the unguessable [topic] to find in
/// the first place — but this is a meaningfully different storage
/// footprint than "nothing is ever stored," and callers presenting this
/// feature to users should describe it accurately (e.g. "no account, and
/// only encrypted data briefly cached on a public broker" rather than "no
/// server storage at all").
///
/// Defaults to HiveMQ's free public broker (`broker.hivemq.com`). That
/// broker has **no authentication and no access control** — anyone can
/// publish or subscribe to any topic — so every message this class carries
/// must already be ciphertext from the caller, and [topic] (derived from a
/// [SyncKey]) is the only thing standing between "anyone" and "this
/// specific connection's traffic." It's also a free public instance, not
/// something this project operates — treat its retained-message store as
/// best-effort, not a guaranteed permanent backup.
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
  final StreamController<MqttSyncMessage> _incoming =
      StreamController<MqttSyncMessage>.broadcast();
  StreamSubscription<List<MqttReceivedMessage<MqttMessage>>>? _updatesSub;

  /// Decrypted-by-caller-later messages received anywhere under [topic],
  /// including retained ones replayed on subscribe — see the class doc
  /// comment.
  Stream<MqttSyncMessage> get messages => _incoming.stream;

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
    // `#` subscribes to every subtopic under [topic] in one call — this is
    // what makes reconnecting (or pairing for the first time) replay every
    // row's retained current state, not just this session's own future
    // traffic. See the class doc comment.
    client.subscribe('$topic/#', MqttQos.atLeastOnce);
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
    final prefix = '$topic/';
    for (final event in events) {
      if (!event.topic.startsWith(prefix)) continue;
      final publish = event.payload as MqttPublishMessage;
      _incoming.add(
        MqttSyncMessage(
          subtopic: event.topic.substring(prefix.length),
          bytes: Uint8List.fromList(publish.payload.message),
        ),
      );
    }
  }

  /// Publishes [bytes] retained to `<topic>/<subtopic>` — see the class
  /// doc comment for why every row's state is published this way.
  Future<void> publishRetained(String subtopic, Uint8List bytes) =>
      _publish(subtopic, bytes, retain: true);

  /// Publishes without retaining — for traffic that shouldn't be replayed
  /// to a peer that subscribes later (e.g. `control`-tier commands, which
  /// are one-off actions, not state to catch up on).
  Future<void> publishEphemeral(String subtopic, Uint8List bytes) =>
      _publish(subtopic, bytes, retain: false);

  /// Deletes the retained message at `<topic>/<subtopic>`, if any. An
  /// empty-payload retained publish is MQTT's own way of representing
  /// "nothing retained here anymore" (the broker drops its stored copy on
  /// receipt) — also delivered live to anyone currently subscribed, so
  /// this doubles as the deletion notification for online peers.
  Future<void> clearRetained(String subtopic) =>
      _publish(subtopic, Uint8List(0), retain: true);

  Future<void> _publish(
    String subtopic,
    Uint8List bytes, {
    required bool retain,
  }) async {
    final client = _client;
    if (client == null || !isConnected) {
      throw StateError('Not connected.');
    }
    final builder = MqttClientPayloadBuilder()
      ..addBuffer(typed.Uint8Buffer()..addAll(bytes));
    client.publishMessage(
      '$topic/$subtopic',
      MqttQos.atLeastOnce,
      builder.payload!,
      retain: retain,
    );
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

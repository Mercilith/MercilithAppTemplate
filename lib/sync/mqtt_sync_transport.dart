import 'dart:async';
import 'dart:typed_data';

import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';
import 'package:typed_data/typed_data.dart' as typed;

/// A message received on any currently-subscribed topic, tagged with which
/// topic and subtopic it arrived on. The topic is exposed (not just the
/// subtopic) because a connection now typically has several topics
/// subscribed at once — a rotating window of time slots, see `SyncKey`'s
/// doc comment — so a caller matching an incoming message back to "which
/// row" or "which slot" needs both.
class MqttSyncMessage {
  MqttSyncMessage({
    required this.topic,
    required this.subtopic,
    required this.bytes,
  });

  /// The base topic (one of the currently-subscribed ones) this message
  /// arrived under.
  final String topic;

  /// E.g. `task/3fae1c9e-...` or `control`.
  final String subtopic;

  /// Empty exactly when this is a retained-message deletion marker (see
  /// [MqttSyncTransport.clearRetained]) — never empty for a real message,
  /// since even the smallest encrypted envelope is well over zero bytes.
  final Uint8List bytes;
}

/// Owns one connection to an MQTT broker and lets a caller subscribe to
/// and publish under any number of topics over that single connection —
/// deliberately not tied to one fixed topic, since a sync connection's
/// topic now rotates every 30 seconds (see `SyncKey.topicForSlot`) and the
/// caller (an app's sync engine) needs to keep a small rotating window of
/// topics subscribed at once to tolerate clock skew between devices,
/// without tearing down and reconnecting the broker connection on every
/// rotation. Knows nothing about encryption, signing, or envelope
/// structure — callers handle all of that themselves; this class only
/// moves bytes.
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
/// key-value store of "current state per row" *within whichever time slot
/// is currently subscribed*; because the topic itself now rotates, a
/// device that's been offline across several slot rotations needs an
/// explicit resync request/response (a sync-engine-level concern, not
/// this class's) rather than relying on retained replay alone to look
/// back at slots it never subscribed to. [clearRetained] (an
/// empty-payload retained publish) is how a row's deletion is represented
/// — MQTT's own way of saying "nothing retained here anymore" — and is
/// delivered live to currently-subscribed peers too, so it doubles as the
/// delete notification for them.
///
/// One consequence worth calling out to callers: **the broker holds a
/// standing copy of the ciphertext for every row published within a given
/// slot's topic**, not just transient in-flight traffic, until either
/// that row is deleted or the slot ages out and traffic moves to a new
/// topic. It's still just ciphertext to anyone without the connection's
/// secret, and still requires knowing the unguessable per-slot topic to
/// find in the first place — but this is a meaningfully different storage
/// footprint than "nothing is ever stored," and callers presenting this
/// feature to users should describe it accurately (e.g. "no account, and
/// only encrypted data briefly cached on a public broker" rather than "no
/// server storage at all").
///
/// Defaults to HiveMQ's free public broker (`broker.hivemq.com`). That
/// broker has **no authentication and no access control** — anyone can
/// publish or subscribe to any topic — so every message this class carries
/// must already be ciphertext from the caller, and each topic (derived
/// from a [SyncKey]) is the only thing standing between "anyone" and "this
/// specific connection's traffic in this specific time slot." It's also a
/// free public instance, not something this project operates — treat its
/// retained-message store as best-effort, not a guaranteed permanent
/// backup.
class MqttSyncTransport {
  MqttSyncTransport({
    required this.clientIdentifier,
    this.host = 'broker.hivemq.com',
    this.tlsPort = 8883,
    this.tlsWebSocketPort = 8884,
  });

  /// Must be unique per connecting client on the broker; callers should
  /// derive this from their own stable per-device id plus the connection
  /// id (or similar) so two devices sharing a connection never collide.
  final String clientIdentifier;
  final String host;
  final int tlsPort;
  final int tlsWebSocketPort;

  MqttServerClient? _client;
  final Set<String> _subscribedTopics = {};
  final StreamController<MqttSyncMessage> _incoming =
      StreamController<MqttSyncMessage>.broadcast();
  StreamSubscription<List<MqttReceivedMessage<MqttMessage>>>? _updatesSub;

  /// Decrypted-by-caller-later messages received on any currently (or
  /// formerly, if delivered just before an unsubscribe took effect)
  /// subscribed topic, including retained ones replayed on subscribe —
  /// see the class doc comment.
  Stream<MqttSyncMessage> get messages => _incoming.stream;

  bool get isConnected =>
      _client?.connectionStatus?.state == MqttConnectionState.connected;

  /// Just establishes the broker connection — subscribe to whichever
  /// topics you need via [subscribeToTopic] afterward. Trying a plain TLS
  /// TCP socket first and falling back to TLS-over-WebSocket if that
  /// fails or times out — covers networks that block raw MQTT ports but
  /// allow HTTPS-looking traffic. Throws [StateError] if neither
  /// transport connects.
  Future<void> connect() async {
    if (isConnected) return;
    final client = await _attempt(tlsPort, useWebSocket: false) ??
        await _attempt(tlsWebSocketPort, useWebSocket: true);
    if (client == null) {
      throw StateError('Could not connect to $host on any transport.');
    }
    _client = client;
    _updatesSub = client.updates!.listen(_onData);
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

  /// Subscribes to `<topic>/#`, replaying every retained message under it
  /// — a no-op if already subscribed to [topic].
  Future<void> subscribeToTopic(String topic) async {
    if (!_subscribedTopics.add(topic)) return;
    _client?.subscribe('$topic/#', MqttQos.atLeastOnce);
  }

  /// Unsubscribes from `<topic>/#` — a no-op if not currently subscribed.
  Future<void> unsubscribeFromTopic(String topic) async {
    if (!_subscribedTopics.remove(topic)) return;
    _client?.unsubscribe('$topic/#');
  }

  void _onData(List<MqttReceivedMessage<MqttMessage>> events) {
    for (final event in events) {
      final topic = _subscribedTopics.firstWhere(
        (t) => event.topic.startsWith('$t/'),
        orElse: () => '',
      );
      if (topic.isEmpty) continue;
      final publish = event.payload as MqttPublishMessage;
      _incoming.add(
        MqttSyncMessage(
          topic: topic,
          subtopic: event.topic.substring(topic.length + 1),
          bytes: Uint8List.fromList(publish.payload.message),
        ),
      );
    }
  }

  /// Publishes [bytes] retained to `<topic>/<subtopic>` — see the class
  /// doc comment for why every row's state is published this way.
  Future<void> publishRetained(
    String topic,
    String subtopic,
    Uint8List bytes,
  ) => _publish(topic, subtopic, bytes, retain: true);

  /// Publishes without retaining — for traffic that shouldn't be replayed
  /// to a peer that subscribes later (e.g. `control`-tier commands and
  /// resync requests, which are one-off actions, not state to catch up
  /// on).
  Future<void> publishEphemeral(
    String topic,
    String subtopic,
    Uint8List bytes,
  ) => _publish(topic, subtopic, bytes, retain: false);

  /// Deletes the retained message at `<topic>/<subtopic>`, if any. An
  /// empty-payload retained publish is MQTT's own way of representing
  /// "nothing retained here anymore" (the broker drops its stored copy on
  /// receipt) — also delivered live to anyone currently subscribed, so
  /// this doubles as the deletion notification for online peers.
  Future<void> clearRetained(String topic, String subtopic) =>
      _publish(topic, subtopic, Uint8List(0), retain: true);

  Future<void> _publish(
    String topic,
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
    _subscribedTopics.clear();
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

import 'dart:convert';
import 'dart:typed_data';

/// Whether a [SyncEnvelope] represents a row being created/changed, or
/// removed.
enum SyncOp { upsert, delete }

/// A generic replication message for [SyncPermission.sync]-tier traffic.
/// `entityType` is a free-form string owned by the consuming app (TaskApp
/// uses e.g. `'task'`, `'completion'`, `'category'`) — this package has no
/// opinion on what's being synced, only how the envelope travels and is
/// framed on the wire. Encode/decode here is plaintext JSON; encryption is
/// a separate step via [SyncCrypto] before handing bytes to
/// `MqttSyncTransport`.
class SyncEnvelope {
  SyncEnvelope({
    required this.id,
    required this.deviceId,
    required this.entityType,
    required this.op,
    required this.updatedAt,
    required this.payload,
  });

  /// The syncable row's own stable cross-device id (not a message id) —
  /// this is what a receiving app upserts/deletes by.
  final String id;

  /// Stable id of the device that produced this envelope, for diagnostics
  /// and future loop-prevention needs beyond the sending app's own
  /// dirty-flag bookkeeping.
  final String deviceId;

  final String entityType;
  final SyncOp op;

  /// Last-write-wins comparison timestamp, always UTC.
  final DateTime updatedAt;

  /// The row's fields, in whatever shape the consuming app's entity codec
  /// produces. Opaque to this package.
  final Map<String, dynamic> payload;

  Map<String, dynamic> toJson() => {
    'id': id,
    'deviceId': deviceId,
    'entityType': entityType,
    'op': op.name,
    'updatedAt': updatedAt.toUtc().toIso8601String(),
    'payload': payload,
  };

  factory SyncEnvelope.fromJson(Map<String, dynamic> json) => SyncEnvelope(
    id: json['id'] as String,
    deviceId: json['deviceId'] as String,
    entityType: json['entityType'] as String,
    op: SyncOp.values.byName(json['op'] as String),
    updatedAt: DateTime.parse(json['updatedAt'] as String),
    payload: Map<String, dynamic>.from(json['payload'] as Map),
  );

  Uint8List encode() => Uint8List.fromList(utf8.encode(jsonEncode(toJson())));

  static SyncEnvelope decode(Uint8List bytes) => SyncEnvelope.fromJson(
    jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>,
  );
}

/// A lightweight remote-command message for [SyncPermission.control]-tier
/// traffic — deliberately much smaller than [SyncEnvelope] since it carries
/// an instruction, not replicated row data. `action`/`args` are free-form
/// for the same reason `entityType` is on [SyncEnvelope].
class SyncCommand {
  SyncCommand({required this.action, required this.args});

  final String action;
  final Map<String, dynamic> args;

  Map<String, dynamic> toJson() => {'action': action, 'args': args};

  factory SyncCommand.fromJson(Map<String, dynamic> json) => SyncCommand(
    action: json['action'] as String,
    args: Map<String, dynamic>.from(json['args'] as Map? ?? const {}),
  );

  Uint8List encode() => Uint8List.fromList(utf8.encode(jsonEncode(toJson())));

  static SyncCommand decode(Uint8List bytes) => SyncCommand.fromJson(
    jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>,
  );
}

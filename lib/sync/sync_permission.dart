/// Permission tiers a [SyncKey] can carry, packed as bitflags into one byte
/// of the key's encoded form. A key can carry any subset — e.g. a key
/// created for "let my other device mirror my tasks" would carry only
/// [sync], while a key meant for a trusted remote-control surface (a
/// companion app, a home-automation hub) might add [control] too.
enum SyncPermission {
  /// Ordinary data replication — the main scope of the sync feature itself.
  sync(1),

  /// Reserved for future non-data messaging (presence, notifications-about-
  /// changes, etc.) that isn't row replication. Not used by TaskApp yet.
  communicate(2),

  /// Permission to send/accept remote action commands (e.g. TaskApp wires
  /// this to its existing Automation executor). Distinct from [sync]
  /// because a key that can *trigger actions* is a materially bigger trust
  /// grant than one that can only mirror data.
  control(4);

  const SyncPermission(this.bit);

  /// This permission's bit in the packed mask.
  final int bit;

  static int packAll(Set<SyncPermission> permissions) =>
      permissions.fold(0, (mask, permission) => mask | permission.bit);

  static Set<SyncPermission> unpackAll(int mask) => {
    for (final permission in SyncPermission.values)
      if (mask & permission.bit != 0) permission,
  };
}

/// How a reminder repeats within its window.
enum NotificationRepeatMode {
  /// Re-fire every N minutes within a window until done.
  repeatUntilDone,

  /// Fire at each of a fixed list of times; skip any that are already moot
  /// (e.g. the underlying task is already complete) when the time arrives.
  fixedSchedule,
}

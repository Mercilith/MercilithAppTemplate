// Design tokens & motion (shared stylization/animation layer — see
// theming/component_themes.dart for how these cascade into ThemeData, and
// widgets/ below for the reusable animated widgets built on top of them)
export 'design/design_tokens.dart';
export 'design/motion_tokens.dart';

// Theming
export 'theming/builtin_themes.dart';
export 'theming/component_themes.dart';
export 'theming/theme_io.dart';
export 'theming/theme_schema.dart';
export 'theming/themed_material_app.dart';
export 'theming/providers/theme_providers.dart';
export 'theming/screens/theme_editor_screen.dart';
export 'theming/screens/theme_gallery_screen.dart';

// DB
export 'db/connection_hardening.dart';
export 'db/theme_kind.dart';
export 'db/theme_repository.dart';
// `db/themes_table.dart` is deliberately NOT exported — it's a copyable
// template for each consuming app's own local `Themes` table, not something
// to import directly. See CLAUDE.md, "The Drift cross-package pattern."

// Backup
export 'backup/backup_file_io.dart';
export 'backup/backup_service.dart';
export 'backup/import_dialog.dart';

// Widgets
export 'widgets/animated_collapse.dart';
export 'widgets/animated_count_text.dart';
export 'widgets/animated_expand_icon.dart';
export 'widgets/animated_progress_bar.dart';
export 'widgets/app_card.dart';
export 'widgets/app_tab_switcher.dart';
export 'widgets/centered_form_width.dart';
export 'widgets/color_picker.dart';
export 'widgets/color_swatch_picker.dart';
export 'widgets/empty_state_view.dart';
export 'widgets/fade_slide_in.dart';
export 'widgets/help_tooltip.dart';
export 'widgets/name_color_dialog.dart';
export 'widgets/pressable_scale.dart';
export 'widgets/shimmer_placeholder.dart';
export 'widgets/staggered_fade_in.dart';
export 'widgets/step_progress_dots.dart';

// Navigation
export 'navigation/adaptive_nav_scaffold.dart';

// Notifications
export 'notifications/fire_times.dart';
export 'notifications/notification_repeat_mode.dart';
export 'notifications/notification_service.dart';

// Sync (cross-device, via HiveMQ or any MQTT broker)
export 'sync/mqtt_sync_transport.dart';
export 'sync/sync_crypto.dart';
export 'sync/sync_envelope.dart';
export 'sync/sync_id.dart';
export 'sync/sync_key.dart';
export 'sync/sync_permission.dart';
export 'sync/sync_signature.dart';
export 'sync/signed_message.dart';
// `sync/base32_crockford.dart` is deliberately NOT exported — internal
// codec detail of `SyncKey`'s text encoding, not a public API surface.

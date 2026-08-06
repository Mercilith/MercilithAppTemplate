# Working Instructions for Claude

## What this repo is

A Flutter *library package*, not an app. It exists purely to share code
across Mercilith's apps (TaskApp today, others later) so theming, backups,
and a few other cross-cutting concerns stay consistent without being
copy-pasted per app. There is no shared runtime state, no cross-app sync,
and no server — every consuming app keeps its own local database; this repo
only ships the *code* that database and UI layer are built from.

Consuming apps depend on this via a git dependency in their `pubspec.yaml`
(see README.md). Because it's a dependency, not a template scaffolded once
and forgotten, changes here should be made with the assumption that at
least one other app is already relying on the current API shape — avoid
breaking changes without checking who else might be affected.

## Commit discipline

Same convention as this org's other repos: commit at every natural stopping
point, and **delegate every commit to the `commit-writer` subagent** rather
than writing the message or running `git commit` yourself — this applies
from the very first commit in this repo, since `.claude/agents/commit-writer.md`
is checked in from day one. Don't wait for explicit permission to commit;
do pause before pushing, force-pushing, or rewriting history.

## Architecture

```
lib/
  mercilith_app_template.dart   # barrel export
  theming/
    theme_schema.dart           # ThemeSchema — pure Dart JSON<->ColorScheme, no DB coupling
    builtin_themes.dart         # the 12 built-in theme definitions
    theme_io.dart                # file export/import (file_picker/share_plus)
    themed_material_app.dart    # MaterialApp wrapper: one active theme drives light/dark
    screens/                    # theme gallery + editor UI
    providers/                  # Riverpod theme_providers, parameterized (see below)
  db/
    theme_kind.dart             # ThemeKind enum (builtInLight/Dark/Monochrome/custom)
    themes_table.dart           # plain Drift Table — see "Drift cross-package pattern"
    theme_repository.dart       # abstract ThemeRepository + plain ThemeRow/NewTheme
    connection_hardening.dart   # prepareConnection/openDatabaseFile/safeAddColumn/busyTimeout
  backup/
    backup_service.dart         # generic BackupService/TableSpec/ImportMode
    backup_file_io.dart         # saveBackupDocToDownloads/writeBackupFileDirect
    import_dialog.dart          # askImportMode
  widgets/                      # help_tooltip, centered_form_width, color pickers, name+color dialog
  navigation/
    adaptive_nav_scaffold.dart  # responsive NavigationBar/NavigationRail shell
  notifications/
    notification_service.dart  # parameterized Android/Windows notification wrapper
    fire_times.dart             # pure fire-time computation
    notification_repeat_mode.dart
  sync/
    sync_key.dart               # SyncKey — rotating-topic derivation + AES secret + signing pubkey + permission bits
    sync_permission.dart        # SyncPermission bitflags (sync/communicate/control)
    sync_crypto.dart            # AES-256-GCM encrypt/decrypt of sync payloads
    sync_signature.dart         # SyncSigner/SyncVerifier — Ed25519 sign/verify
    signed_message.dart         # SignedMessage — wire framing: optional signature + ciphertext
    sync_envelope.dart          # SyncEnvelope (row replication) / SyncCommand (control) wire types
    mqtt_sync_transport.dart    # MqttSyncTransport — connect + multi-topic subscribe/publish, raw bytes only
    base32_crockford.dart       # internal codec for SyncKey's text encoding, not exported
```

## Cross-device sync transport (`sync/`)

Generic building blocks for pairing two (or more) devices over a public
MQTT broker with no server and no accounts — one device generates a
[`SyncKey`], the encoded key string is copied to another device, and from
then on both publish/subscribe on the topic that key derives, encrypting
everything with the key's secret. This package intentionally stops at
*transport* — connecting, encrypting, framing messages — and knows nothing
about what a consuming app actually replicates. TaskApp's `lib/features/
sync/` (not in this package — see the Drift cross-package pattern below
for why the actual DB-touching engine can't live here) is the reference
consumer: it defines its own `entityType` strings, its own DAO-level
upsert-by-id logic, and its own `SyncConnections` table for persisting
paired keys.

**The broker (HiveMQ's public instance, `broker.hivemq.com`, the default
host) has zero authentication or access control** — anyone can publish or
subscribe to any topic. All of this design's actual security comes from
the app layer: the topic itself is unguessable without the key (see the
rotation note below) and [`SyncCrypto`] (AES-256-GCM) is applied to every
payload before [`MqttSyncTransport.publishRetained`]/`publishEphemeral`
ever sees it. Never publish plaintext through `MqttSyncTransport` — it
deliberately has no encryption of its own, by design, so that
responsibility can't be silently skipped by a future change to this file
alone.

**The topic rotates every 30 seconds** (`SyncKey.slotDuration`),
deterministically derived from `sha256(topicSeed ++ slot)` where `slot` is
`SyncKey.slotFor(now)` — UTC-epoch time truncated to 30-second buckets, so
every device computes the same slot from its own clock with no
coordination and no timezone dependence. This is a traffic-analysis
mitigation on top of encryption: a single fixed topic for a connection's
entire lifetime is a stable, observable "channel" on a public broker even
if its contents are opaque; hashing in the current slot means an outside
observer can't trivially tell that two bursts of traffic minutes apart
belong to the same ongoing pairing, even though anyone holding
`topicSeed` can always compute the current (or any past/future) topic
directly. `MqttSyncTransport` itself is topic-agnostic — it's the caller's
job to call `subscribeToTopic`/`unsubscribeFromTopic` to maintain a
rotating window (TaskApp's `SyncService` keeps prev/current/next
subscribed at once, to tolerate minor clock skew between devices) and to
resolve `SyncKey.currentTopic()` before every publish.

**Every message carries an optional Ed25519 signature** (`SyncSigner`/
`SyncVerifier`, framed by `SignedMessage`), because AES-GCM alone can't
answer "which of the several devices holding this shared secret sent
this?" — only that it was encrypted with the secret at all. Only the
device that called `SyncKey.generate` ever holds the private signing key
(`GeneratedSyncKey.signingPrivateKeySeed`, deliberately never part of the
encoded string); every paired device can verify a signature against the
embedded `SyncKey.signingPublicKey`, but only the creator can produce one.
This package doesn't decide when a signature is *required* — that's a
consuming-app policy (TaskApp requires a valid signature for `control`-
tier messages specifically, so a remote device can't trigger real actions
just because it holds the shared secret; regular data sync stays
unrestricted, since bidirectional sync from any paired device is the
point of that tier).

**A plain MQTT broker keeps no message history — a client that's offline
when something is published never sees it, even after reconnecting.**
`MqttSyncTransport` works around this at the *within-one-topic* level by
publishing every row *retained*, one per row on its own subtopic
(`<topic>/<entityType>/<syncId>`) — a retained message is the one piece of
state an MQTT broker does keep, replayed immediately to any client that
(re)subscribes to that topic, whether or not they were online for the
original publish. Row deletion is an empty-payload retained publish
(`clearRetained`) — MQTT's own way of saying "nothing retained here
anymore," delivered live to anyone currently subscribed too, doubling as
the delete notification. **Because the topic itself now rotates, retained
replay alone no longer covers a device that's been offline across several
slot rotations** — it has no way to "look back" at old slot topics it
never subscribed to. That's what an explicit resync request/response
(a consuming-app concern — see TaskApp's `SyncService`) is for: a device
that just reconnected asks whoever's currently listening to republish
their full current state on the current topic, rather than relying on
history that may no longer be reachable.

**Consequence worth flagging to end users**: the broker holds a standing
copy of the ciphertext for every row published within a given slot's
topic, until either that row is deleted or the slot ages out and traffic
moves on — not just transient in-flight traffic. Still just ciphertext,
still gated behind an unguessable (and now short-lived) topic, but a
meaningfully different storage footprint than "nothing is ever stored."
Describe the feature to users as "no account, end-to-end encrypted," not
"no server storage at all."

`SyncPermission` is a set of bitflags (`sync`, `communicate`, `control`)
packed into one byte of the key, not a single enum value — a key can carry
any subset. This package only defines the flags; what each tier actually
authorizes (including whether it requires a valid signature) is entirely
up to the consuming app (TaskApp gates real DB writes with `sync` and
delegates to its existing Automation executor for `control`, requiring a
verified signature from the creator's public key first — see TaskApp's
own CLAUDE.md/feature map, not this repo).

## The Drift cross-package pattern (read this before touching `db/`)

**Drift `Table` classes cannot be shared cross-package with this
toolchain — not even plain, unannotated ones.** This was the original
design (see git history) and it was wrong; it shipped, was tested against a
real `build_runner build` in a consuming app, and failed. Don't re-attempt
it without re-reading this section.

The failure: a plain `Table` subclass (e.g. `Themes`) declared here and
imported into a consuming app's `@DriftDatabase(tables: [..., Themes])`
list produces, when that app runs its own `build_runner build`:

```
W drift_dev on lib/data/db/daos/theme_dao.dart: ...
The referenced element, Themes, is not understood by drift.
```

with **no** `ThemeRow`/`ThemesCompanion` emitted into the app's
`database.g.dart`. The Dart analyzer resolves the import fine — this is a
`drift_dev`-internal gap, not a language-level problem. Root cause,
confirmed by reading `drift_dev`'s own `build.yaml` (not guessed): its main
builder (`discover`/`analyzer`/`driftBuilder`) is declared with
`auto_apply: dependents`, meaning its discovery/analysis phase only scans
`.dart` files inside packages that **themselves** declare `drift_dev` as a
(dev-)dependency. Since this package deliberately has no `drift_dev`
dependency (see gotcha #1), nothing in `db/` is ever scanned by it, so a
consuming app's `build_runner` run can never resolve a `Table` class
declared here — regardless of import path, barrel vs. direct import, or
`.dart_tool/build` cache state.

**Tried and disproven**: adding `drift_dev` as a `dev_dependency` to this
package, then re-resolving and rebuilding in the consuming app after
clearing its `.dart_tool/build` cache. Same failure, unchanged. Do not
re-try this fix — it doesn't address `auto_apply: dependents`, which scopes
by the *consuming* package's own dependency graph, not by whether this
package can run drift_dev on itself.

**So, the actual working pattern**:

- Table classes (like `db/themes_table.dart`'s `Themes`) live in this
  package as **reference/template content only** — deliberately **not**
  exported from `mercilith_app_template.dart`. Each consuming app copies
  the class verbatim into its own `lib/data/db/tables/`, adds it to its own
  `@DriftDatabase(tables: [...])` list, and keeps that copy in sync by hand
  if the template changes.
- What genuinely *does* share cross-package, because none of it goes
  through `drift_dev` codegen: plain enums (`ThemeKind`), abstract
  interfaces (`ThemeRepository`), and hand-written plain data classes
  (`ThemeRow`, `NewTheme`) with no Drift annotations at all. These are
  ordinary Dart types — the Dart analyzer (not drift_dev) resolves them,
  so normal cross-package imports work exactly as expected.
- Each consuming app writes its own small, concrete `@DriftAccessor` DAO
  against its own local copy of the table, then adds a thin adapter class
  implementing the shared `ThemeRepository` interface by wrapping that DAO.
  The shared theme screens/providers in this package depend only on the
  abstract interface, never on any app's generated types or table classes.

**If you add another shared table in the future, follow this exact
pattern** — table class as a copy-paste template (not exported) + abstract
repository interface (exported, genuinely shared) + let each app supply its
own local table + DAO-backed adapter. Do not try to make a table class or a
DAO itself importable; neither will resolve in the consuming app's
`build_runner build`.

## Notification background-handler constraint

`NotificationService`'s Android/Windows background action handler must be a
real top-level function annotated `@pragma('vm:entry-point')` — Dart
isolate entry points cannot be a closure or an instance method, so this
package cannot ship a fixed background handler. `NotificationService.init()`
takes an `onBackgroundResponse` callback; each consuming app defines its own
top-level wrapper function and passes it in.

## Toolchain gotchas (do not "fix" these without understanding why)

1. **No `build_runner`/`drift_dev` dev-dependency in this package, deliberately.** This package has zero `@DriftAccessor`/`@DriftDatabase` classes, and adding `drift_dev` here would *not* make `db/themes_table.dart` resolve in a consuming app's own build anyway — that was tried and disproven, see the Drift cross-package pattern above. Don't add this dependency "to fix" a cross-package Drift issue; it doesn't.
2. **`ThemeRow` name collision.** This package's `db/theme_repository.dart` defines a plain `ThemeRow` data class. Every consuming app's Drift setup also generates its *own* `ThemeRow` (from the `Themes` table, in that app's `database.g.dart`). These are different types with the same name. Consuming code that needs both must import one with a prefix or `hide` clause — don't rename either to "fix" this, the collision is inherent to the design (see the Drift pattern section).
3. **No `sqlite3_flutter_libs` dependency here, deliberately.** This package only touches Drift's `Migrator`/`TableInfo`/`GeneratedColumn` abstractions and the `sqlite3.Database` type (a transitive dependency via `drift`) — it never opens a real database file. Bundling native sqlite3 binaries is an app-level concern (each app's own `sqlite3_flutter_libs` dependency); don't add it here "to be safe."
4. **Windows notifications reuse one native string for both `NotificationResponse.actionId` and `.payload`.** Unlike Android, where the action id and the notification payload travel separately, `flutter_local_notifications`'s Windows implementation surfaces a single "invoked args" string as *both* fields — tapping an action button overwrites both with that button's `arguments` string. `NotificationService`'s Windows path works around this by embedding the action id inside the payload JSON itself (`kWindowsActionKey`); consuming code must unwrap that key before treating the rest of the payload as the real notification data. If you change the payload shape, keep this embedding intact or Windows action buttons will silently lose their payload.
5. **CI/build patterns (Flutter version pin, the Windows-Developer-Mode-enable step, the debug-keystore signing pattern) are documented, not shared, here.** A Flutter *package* has no `android/`/`windows/` runner folders of its own, so none of this is literally shareable code — see `docs/templates/build.yml.example` for a copyable starting point each new app's own CI workflow should be based on, and re-derive the debug-keystore pattern per-app (never share one keystore file across apps — that's a real signing/security anti-pattern, not just inconvenient).

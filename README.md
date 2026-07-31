# MercilithAppTemplate

Shared Flutter infrastructure for Mercilith's apps: theming, backup/restore,
DB connection hardening, a handful of generic widgets, and a cross-platform
notification mechanism. No shared runtime state or cross-app sync — this is
code-sharing only, so consuming apps can stay consistent in design and
behavior without copy-pasting.

See [CLAUDE.md](CLAUDE.md) for architecture, the Drift cross-package table
pattern, and toolchain notes.

## Consuming this package

Add to a Flutter app's `pubspec.yaml`:

```yaml
dependencies:
  mercilith_app_template:
    git:
      url: https://github.com/Mercilith/MercilithAppTemplate.git
      ref: main
```

(During local development against an unpushed checkout, use
`path: ../MercilithAppTemplate` instead.)

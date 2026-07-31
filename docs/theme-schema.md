# Theme File Format

Themes are stored and shared as a small, open JSON document. The format is
intentionally simple and app-agnostic so other apps can read or produce it:
it is just a **brightness** plus a map of **Material color roles** to colors.

## Example

```json
{
  "schemaVersion": 1,
  "name": "Indigo Light",
  "brightness": "light",
  "colors": {
    "primary": "#FF5C6BC0",
    "onPrimary": "#FFFFFFFF",
    "secondary": "#FF5C5E71",
    "tertiary": "#FF77536C",
    "error": "#FFBA1A1A",
    "surface": "#FFFBF8FF",
    "onSurface": "#FF1B1B21",
    "surfaceContainerHighest": "#FFE3E1EC"
  }
}
```

## Fields

| Field           | Type   | Required | Notes |
|-----------------|--------|----------|-------|
| `schemaVersion` | int    | yes      | Format version. Current: `1`. A reader should refuse files with a higher version than it understands. |
| `name`          | string | yes      | Human-readable theme name. |
| `brightness`    | string | yes      | `"light"` or `"dark"`. Any other value is treated as `"light"`. |
| `colors`        | object | yes      | Map of role name → color string. Must include at least `primary`. |

## Colors

Each value is a hex color string, case-insensitive, with an optional leading
`#`:

- `#AARRGGBB` — 8 digits, alpha first.
- `#RRGGBB` — 6 digits; alpha is assumed to be `FF` (opaque).

## Roles

The full set of roles this schema writes (and reads) mirrors the Material 3
`ColorScheme`:

```
primary, onPrimary, primaryContainer, onPrimaryContainer,
secondary, onSecondary, secondaryContainer, onSecondaryContainer,
tertiary, onTertiary, tertiaryContainer, onTertiaryContainer,
error, onError, errorContainer, onErrorContainer,
surface, onSurface, surfaceContainerHighest, onSurfaceVariant,
outline, outlineVariant, inverseSurface, onInverseSurface,
inversePrimary, shadow, scrim, surfaceTint
```

Any role may be omitted. Missing roles are filled in by deriving a complete
scheme from `primary` (and `brightness`), so a minimal file with only `primary`
still produces a valid, complete theme. This makes the format forgiving for
hand-authored or cross-app files.

## Forward compatibility

- Unknown keys inside `colors` are ignored.
- Increasing `schemaVersion` is reserved for changes that older readers could
  not safely interpret; additive, ignorable changes keep the same version.

---
name: check-colors
description: >
  Scan Flutter Dart files for hardcoded color literals that should be
  AppTheme/AppIcons tokens. Catches Color(0xFF...), Colors.red/blue/green etc.,
  raw hex values, and direct withOpacity/withAlpha calls that bypass the
  design-token system. Use after any UI change to ensure theme-consistency.
  Invoke: /check-colors [path]
argument-hint: "[path | file | all]"
allowed-tools: Grep, Glob, Read
---

# Hardcoded Color Scanner

You are a design-token auditor for a Flutter codebase. Your job is to find
every hardcoded color that bypasses `AppTheme` or `AppIcons` tokens and report
them as violations. **Never skip a check.**

Scope: `$ARGUMENTS` (default: `FrontEnd/lib`)

---

## Rules — what counts as a violation

### BANNED in screens, providers, widgets, and any file that is NOT `theme.dart`, `design_tokens.dart`, or `app_icons.dart`:

| Pattern | Why |
|---------|-----|
| `Color(0xFF......)` | Raw hex — must be a named token in AppTheme |
| `Colors.red`, `Colors.blue`, `Colors.green`, `Colors.orange`, `Colors.purple`, `Colors.pink`, `Colors.amber`, `Colors.yellow`, `Colors.teal`, `Colors.cyan`, `Colors.indigo`, `Colors.lime`, `Colors.brown`, `Colors.grey` (bare, non-alpha) | Named Material colors — use AppTheme semantic color instead |
| `Colors.black87`, `Colors.black54`, `Colors.black45`, `Colors.black38`, `Colors.black26`, `Colors.black12` | Non-frosted hardcoded alpha blacks — use `AppTheme.frostedFg` / `AppTheme.textPrimaryOf` |
| `.withOpacity(...)` anywhere | Deprecated API — use `.withValues(alpha: ...)` |
| `.shade100`–`.shade900` on any `Colors.*` | Material shade lookup — use a named AppTheme token |

### ALLOWED everywhere (not violations):
- `Colors.white` and `Colors.black` **only** inside `AppTheme` itself (theme.dart)
- `Colors.transparent`
- `Colors.white` / `Colors.black` passed through `AppTheme.frostedBg/frostedFg/onColor` helpers
- Any `Color` reference inside `theme.dart`, `design_tokens.dart`, `app_icons.dart`

---

## How to scan

1. Determine the scan path from `$ARGUMENTS`. Default: `FrontEnd/lib`.
2. Exclude `FrontEnd/lib/config/theme.dart`, `FrontEnd/lib/config/design_tokens.dart`,
   `FrontEnd/lib/config/app_icons.dart` from all checks.
3. Run these Grep searches (use `output_mode: content` with line numbers):

   a. Raw hex colors:
      Pattern: `Color\(0x[A-Fa-f0-9]+\)`

   b. Named Material colors (non-white/black/transparent):
      Pattern: `Colors\.(red|blue|green|orange|purple|pink|amber|yellow|teal|cyan|indigo|lime|brown|grey|deepOrange|deepPurple|lightBlue|lightGreen)\b`

   c. Hardcoded alpha blacks/whites (outside theme files):
      Pattern: `Colors\.(black|white)\d+`

   d. Deprecated withOpacity:
      Pattern: `\.withOpacity\(`

   e. Material shade lookups:
      Pattern: `Colors\.\w+\.shade\d+`

4. For each match, record: file path, line number, the offending snippet,
   and the suggested AppTheme/AppIcons replacement.

---

## Output format

```
## Color Audit — <scope>

### Violations found: N

#### 1. <file>:<line>
  Code:       <offending snippet>
  Type:       <Raw hex | Named color | Deprecated API | Shade lookup>
  Fix:        <suggested AppTheme.* or AppIcons.* replacement>

...

### Summary
- Raw hex literals:     N
- Named Material colors: N
- Deprecated withOpacity: N
- Shade lookups:        N

### Files with most violations
1. path/to/file.dart — N violations
```

If no violations are found, output:
```
✅ No hardcoded color violations found in <scope>.
```

---

## Replacement guide

| Hardcoded | Replace with |
|-----------|-------------|
| `Color(0xFF276EF1)` | `AppTheme.accentColor` |
| `Color(0xFFE11900)` | `AppTheme.errorColor` |
| `Color(0xFF05944F)` | `AppTheme.secondaryColor` |
| `Color(0xFFFFC043)` | `AppTheme.warningColor` |
| `Color(0xFF9333EA)` | `AppTheme.purpleColor` |
| `Color(0xFFFF8C00)` | `AppTheme.orangeColor` |
| `Color(0xFFC026D3)` | `AppTheme.magentaColor` |
| `Color(0xFF0891B2)` | `AppTheme.cyanColor` |
| `Color(0xFF0D9488)` | `AppTheme.tealColor` |
| `Colors.white` on a colored background | `AppTheme.onColor(bgColor)` |
| `Colors.black87` / `Colors.white` for neutral UI | `AppTheme.frostedFg(isDark)` |
| Semi-transparent white/black bg | `AppTheme.frostedBg(isDark)` |
| Secondary neutral text | `AppTheme.frostedFgSub(isDark)` |
| `.withOpacity(x)` | `.withValues(alpha: x)` |

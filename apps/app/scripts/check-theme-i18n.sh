#!/usr/bin/env bash
# check-theme-i18n.sh
#
# Industrial-grade static guard for the Dingit app theme + i18n systems.
#
# Enforces three invariants on apps/app/lib/**:
#   1. No hex color literals outside the theme token layer.
#      → all colors must live in lib/app/theme/tokens/ and be surfaced
#        through ColorScheme / DingitPalette.
#   2. No references to the removed `AppColors` static class.
#      → migrate to `context.colors` / `context.palette`.
#   3. No hard-coded Chinese text outside lib/l10n/**.
#      → every localized string must go through `context.l10n.*`.
#
# Exit code 0 means all three invariants hold. Non-zero means the run
# found violations; the offending lines are printed to stderr.
#
# The script is meant to be cheap enough for a pre-commit hook and
# strict enough for CI — any violation fails the build.

set -euo pipefail

# Locate the app/lib directory regardless of where the script is invoked
# from (repo root, apps/app, or the scripts dir).
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="$(cd "$SCRIPT_DIR/../lib" && pwd)"

if [[ ! -d "$LIB_DIR" ]]; then
  echo "check-theme-i18n: could not locate $LIB_DIR" >&2
  exit 2
fi

fail=0

echo "[check-theme-i18n] lib dir: $LIB_DIR"

# ── Rule 1: hex literals outside tokens ──────────────────────────────────
# Matches `Color(0x...)`. Excluded paths:
#   - lib/app/theme/tokens/**  (the sanctioned home of raw hex)
#   - lib/l10n/gen/**          (generated localization files)
if grep -RInE --include='*.dart' \
     --exclude-dir=gen \
     'Color\(0x' "$LIB_DIR" \
     | grep -v '/app/theme/tokens/' \
     > /tmp/theme_i18n_rule1.$$ 2>/dev/null; then
  echo "[check-theme-i18n] ❌ Rule 1: hex color literal outside tokens" >&2
  cat /tmp/theme_i18n_rule1.$$ >&2
  fail=1
fi
rm -f /tmp/theme_i18n_rule1.$$

# ── Rule 2: no references to the deleted `AppColors` class ───────────────
if grep -RInE --include='*.dart' \
     --exclude-dir=gen \
     'AppColors' "$LIB_DIR" \
     > /tmp/theme_i18n_rule2.$$ 2>/dev/null; then
  echo "[check-theme-i18n] ❌ Rule 2: AppColors reference (should use context.colors / context.palette)" >&2
  cat /tmp/theme_i18n_rule2.$$ >&2
  fail=1
fi
rm -f /tmp/theme_i18n_rule2.$$

# ── Rule 3: no Chinese literals outside l10n ─────────────────────────────
# Perl is used for the Unicode character class because BSD grep's
# understanding of \p{...} is unreliable.
if find "$LIB_DIR" -type f -name '*.dart' \
      ! -path '*/l10n/*' -print0 \
      | xargs -0 perl -nle '
          next if /^\s*\/\//;
          next if /^\s*\*/;
          if (/[\x{4e00}-\x{9fff}]/) {
            print "$ARGV:$.: $_";
          }
        ' \
      > /tmp/theme_i18n_rule3.$$ 2>/dev/null; then
  :
fi

if [[ -s /tmp/theme_i18n_rule3.$$ ]]; then
  echo "[check-theme-i18n] ❌ Rule 3: hard-coded Chinese literal outside lib/l10n" >&2
  cat /tmp/theme_i18n_rule3.$$ >&2
  fail=1
fi
rm -f /tmp/theme_i18n_rule3.$$

if [[ $fail -ne 0 ]]; then
  echo "[check-theme-i18n] FAIL" >&2
  exit 1
fi

echo "[check-theme-i18n] OK — theme & i18n invariants hold"

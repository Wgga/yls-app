#!/usr/bin/env bash
set -euo pipefail

RESOURCES_DIR="/Applications/Codex.app/Contents/Resources"
CODEX_APP="/Applications/Codex.app"
ASAR_FILE="$RESOURCES_DIR/app.asar"
BACKUP_FILE="$RESOURCES_DIR/app.asar.bak"

usage() {
  cat <<'EOF'
Usage:
  ./scripts/codex_fast_patch_macos.sh status
  ./scripts/codex_fast_patch_macos.sh backup
  ./scripts/codex_fast_patch_macos.sh patch --yes
  ./scripts/codex_fast_patch_macos.sh rollback --yes

Commands:
  status      Show Codex app resource status.
  backup      Create app.asar.bak if it does not already exist.
  patch       Backup, extract app.asar, patch JS bundles, disable Electron fuses, re-sign.
  rollback    Restore app.asar from app.asar.bak or app.asar1, remove extracted app/, re-sign.

Notes:
  - patch and rollback intentionally require --yes.
  - This modifies /Applications/Codex.app.
  - Re-run backup/status before patching after Codex updates.
EOF
}

require_codex_app() {
  if [[ ! -d "$RESOURCES_DIR" ]]; then
    echo "Codex resources directory not found: $RESOURCES_DIR" >&2
    exit 1
  fi
}

require_yes() {
  if [[ "${2:-}" != "--yes" ]]; then
    echo "Refusing to modify Codex.app without explicit --yes." >&2
    echo "Run: $0 $1 --yes" >&2
    exit 2
  fi
}

status() {
  require_codex_app
  echo "Codex resources: $RESOURCES_DIR"
  [[ -f "$ASAR_FILE" ]] && ls -lh "$ASAR_FILE" || echo "Missing: $ASAR_FILE"
  [[ -f "$BACKUP_FILE" ]] && ls -lh "$BACKUP_FILE" || echo "Missing: $BACKUP_FILE"
  [[ -f "$RESOURCES_DIR/app.asar1" ]] && ls -lh "$RESOURCES_DIR/app.asar1" || echo "Missing: $RESOURCES_DIR/app.asar1"
  [[ -d "$RESOURCES_DIR/app" ]] && echo "Extracted app/ exists" || echo "Extracted app/ missing"
}

backup() {
  require_codex_app
  if [[ ! -f "$ASAR_FILE" ]]; then
    echo "Cannot backup because app.asar is missing: $ASAR_FILE" >&2
    exit 1
  fi
  if [[ -f "$BACKUP_FILE" ]]; then
    echo "Backup already exists:"
    ls -lh "$BACKUP_FILE"
    return
  fi
  cp "$ASAR_FILE" "$BACKUP_FILE"
  echo "Backed up app.asar -> app.asar.bak"
  ls -lh "$BACKUP_FILE"
}

rollback() {
  require_codex_app
  require_yes rollback "${1:-}"

  cd "$RESOURCES_DIR"

  if [[ ! -f app.asar.bak && ! -f app.asar1 ]]; then
    echo "No rollback source found. Missing both app.asar.bak and app.asar1." >&2
    exit 1
  fi

  rm -rf app
  [[ -f app.asar1 ]] && mv app.asar1 app.asar
  [[ -f app.asar.bak ]] && cp app.asar.bak app.asar
  codesign --force --deep --sign - "$CODEX_APP"
  echo "Rolled back to original"
}

patch_js_bundles() {
  python3 <<'PYTHON'
import glob
import os
import re
import sys

base = '/Applications/Codex.app/Contents/Resources/app/webview/assets'
patched_count = 0

FAST_AUTH_PATTERNS = [
    'return!(r?.authMethod!==\x60chatgpt\x60||i?.requirements?.featureRequirements?.fast_mode===!1)',
    'return!(r?.authMethod!==`chatgpt`||i?.requirements?.featureRequirements?.fast_mode===!1)',
]

FAST_MODELS_PATTERNS = [
    'l?.modelsByType.models.some(F)??!1',
    'l?.modelsByType.models.some(F)??false',
]

for f in glob.glob(os.path.join(base, 'permissions-mode-helpers-*.js')):
    with open(f, 'r', encoding='utf-8') as fh:
        content = fh.read()
    original = content

    for pat in FAST_AUTH_PATTERNS:
        if pat in content:
            content = content.replace(pat, 'return true')
            print(f'[PATCHED] {os.path.basename(f)}: fast auth check -> return true')
            break
    else:
        content, count = re.subn(
            r'return!\([^)]*?\.authMethod!==`chatgpt`\|\|[A-Za-z_$][\w$]*\)',
            'return true',
            content,
            count=1,
        )
        if count:
            print(f'[PATCHED] {os.path.basename(f)}: fast auth check -> return true (regex)')
        elif 'authMethod' in content and 'fast_mode' in content:
            print(f'[WARN] {os.path.basename(f)}: has authMethod+fast_mode but pattern changed.')

    for pat in FAST_MODELS_PATTERNS:
        if pat in content:
            content = content.replace(pat, 'true')
            print(f'[PATCHED] {os.path.basename(f)}: models.some(F) -> true')
            break
    else:
        content, count = re.subn(
            r'[A-Za-z_$][\w$]*\?\.models\.some\([A-Za-z_$][\w$]*\)\?\?(?:!1|false)',
            'true',
            content,
            count=1,
        )
        if count:
            print(f'[PATCHED] {os.path.basename(f)}: models.some(...) -> true (regex)')
        elif 'modelsByType.models.some' in content or '.models.some' in content:
            print(f'[WARN] {os.path.basename(f)}: has model availability check but pattern changed.')

    content, count = re.subn(
        r'if\([^)]*?\.authMethod!==`chatgpt`\|\|[A-Za-z_$][\w$]*\)\{',
        'if(false){',
        content,
        count=1,
    )
    if count:
        print(f'[PATCHED] {os.path.basename(f)}: fast-mode runtime auth branch -> if(false)')

    if content != original:
        with open(f, 'w', encoding='utf-8') as fh:
            fh.write(content)
        patched_count += 1

for f in glob.glob(os.path.join(base, '*.js')):
    with open(f, 'r', encoding='utf-8') as fh:
        content = fh.read()
    original = content

    full_pat = 'D?(0,$.jsx)(Sl,{tooltipContent:(0,$.jsx)(Y,{id:\x60sidebarElectron.pluginsDisabledTooltip\x60'
    if full_pat in content:
        content = content.replace(full_pat, full_pat.replace('D?', '0?', 1), 1)
        print(f'[PATCHED] {os.path.basename(f)}: plugins D? -> 0?')
    elif 'pluginsDisabledTooltip' in content:
        idx = content.find('pluginsDisabledTooltip')
        before = content[max(0, idx - 200):idx]
        match = re.search(r'([A-Z])\?\(0,\$\.jsx\)\(Sl,\{tooltipContent', before + content[idx:idx+100])
        if match:
            gate_var = match.group(1)
            old_str = f'{gate_var}?(0,$.jsx)(Sl,{{tooltipContent'
            new_str = '0?(0,$.jsx)(Sl,{tooltipContent'
            if old_str in content:
                content = content.replace(old_str, new_str, 1)
                print(f'[PATCHED] {os.path.basename(f)}: plugins {gate_var}? -> 0?')
        if content == original:
            content, count = re.subn(
                r'([A-Za-z_$][\w$]*)\?\(0,\$\.jsx\)\(([A-Za-z_$][\w$]*),\{tooltipContent:\(0,\$\.jsx\)\(([A-Za-z_$][\w$]*),\{id:`sidebarElectron\.pluginsDisabledTooltip`',
                r'0?(0,$.jsx)(\2,{tooltipContent:(0,$.jsx)(\3,{id:`sidebarElectron.pluginsDisabledTooltip`',
                content,
                count=1,
            )
            if count:
                print(f'[PATCHED] {os.path.basename(f)}: plugins disabled gate -> 0? (regex)')
        if content == original:
            print(f'[WARN] {os.path.basename(f)}: pluginsDisabledTooltip found but gate pattern changed.')

    if content != original:
        with open(f, 'w', encoding='utf-8') as fh:
            fh.write(content)
        patched_count += 1

APIKEY_GATE_PATTERNS = [
    'function e(e){return e===`apikey`}',
    'function e(e){return e===\x60apikey\x60}',
    'function e(e){return e!==`chatgpt`}',
    'function e(e){return e!==\x60chatgpt\x60}',
]

for f in glob.glob(os.path.join(base, 'gradient-*.js')):
    with open(f, 'r', encoding='utf-8') as fh:
        content = fh.read()
    original = content

    for pat in APIKEY_GATE_PATTERNS:
        if pat in content:
            content = content.replace(pat, 'function e(e){return false}')
            print(f'[PATCHED] {os.path.basename(f)}: apikey gate -> return false')
            break
    else:
        if 'apikey' in content or 'chatgpt' in content:
            print(f'[WARN] {os.path.basename(f)}: has auth gate refs but pattern changed.')

    if content != original:
        with open(f, 'w', encoding='utf-8') as fh:
            fh.write(content)
        patched_count += 1

CONNECTOR_PATTERNS = [
    ('(i=`connector-unavailable`)', 'false&&(i=`connector-unavailable`)'),
    ('(i=\x60connector-unavailable\x60)', 'false&&(i=\x60connector-unavailable\x60)'),
]

for f in glob.glob(os.path.join(base, '*.js')):
    with open(f, 'r', encoding='utf-8') as fh:
        content = fh.read()
    original = content

    for old_pat, new_pat in CONNECTOR_PATTERNS:
        if old_pat in content:
            idx = content.find(old_pat)
            before = content[max(0, idx - 20):idx]
            if 'false&&' not in before:
                content = content.replace(old_pat, new_pat, 1)
                print(f'[PATCHED] {os.path.basename(f)}: connector gate -> false&&(...)')
                break

    if content != original:
        with open(f, 'w', encoding='utf-8') as fh:
            fh.write(content)
        patched_count += 1

if patched_count == 0:
    print('[ERROR] No patches applied. Codex bundle patterns may have changed.')
    print('Check app/webview/assets for authMethod, fast_mode, pluginsDisabledTooltip, apikey, connector-unavailable.')
    sys.exit(1)

print(f'\nAll {patched_count} patch(es) applied successfully.')
PYTHON
}

patch_app() {
  require_codex_app
  require_yes patch "${1:-}"

  command -v npx >/dev/null || { echo "Missing npx. Install Node.js first." >&2; exit 1; }
  command -v python3 >/dev/null || { echo "Missing python3." >&2; exit 1; }
  command -v codesign >/dev/null || { echo "Missing codesign." >&2; exit 1; }

  pkill -x Codex 2>/dev/null || true
  sleep 1

  cd "$RESOURCES_DIR"

  if [[ -f "$ASAR_FILE" ]]; then
    backup
    rm -rf app
    npx @electron/asar e ./app.asar app
    mv ./app.asar ./app.asar1
  elif [[ -f app.asar1 && -d app ]]; then
    echo "Continuing from existing extracted app/ and app.asar1."
  elif [[ -f app.asar1 ]]; then
    echo "app.asar is already renamed to app.asar1; extracting from app.asar1."
    rm -rf app
    npx @electron/asar e ./app.asar1 app
  else
    echo "Cannot patch because neither app.asar nor app.asar1 is available." >&2
    exit 1
  fi

  patch_js_bundles

  npx @electron/fuses write --app "$CODEX_APP" OnlyLoadAppFromAsar=off
  npx @electron/fuses write --app "$CODEX_APP" EnableEmbeddedAsarIntegrityValidation=off
  npx @electron/fuses write --app "$CODEX_APP" GrantFileProtocolExtraPrivileges=off
  npx @electron/fuses write --app "$CODEX_APP" EnableCookieEncryption=off

  codesign --force --deep --sign - "$CODEX_APP"

  echo ""
  echo "Patch complete."
  echo "Fast/Speed mode and Plugins should be enabled for API key mode."
  echo "If Codex does not launch, run:"
  echo "  $0 rollback --yes"
}

cmd="${1:-}"
case "$cmd" in
  status)
    status
    ;;
  backup)
    backup
    ;;
  patch)
    patch_app "${2:-}"
    ;;
  rollback)
    rollback "${2:-}"
    ;;
  ""|-h|--help|help)
    usage
    ;;
  *)
    echo "Unknown command: $cmd" >&2
    usage >&2
    exit 2
    ;;
esac

#!/bin/sh
# Reads GOOGLE_REVERSED_CLIENT_ID from --dart-define and patches it into the
# built Info.plist. Runs as a build phase after "Copy Bundle Resources".
set -euo pipefail

PLIST="${TARGET_BUILD_DIR}/${INFOPLIST_PATH}"
GOOGLE_REVERSED_CLIENT_ID=""

IFS=',' read -ra ITEMS <<< "${DART_DEFINES:-}"
for item in "${ITEMS[@]}"; do
  decoded=$(printf '%s' "$item" | base64 --decode 2>/dev/null || true)
  case "$decoded" in
    GOOGLE_REVERSED_CLIENT_ID=*)
      GOOGLE_REVERSED_CLIENT_ID="${decoded#GOOGLE_REVERSED_CLIENT_ID=}"
      ;;
  esac
done

if [ -z "$GOOGLE_REVERSED_CLIENT_ID" ]; then
  echo "warning: GOOGLE_REVERSED_CLIENT_ID not provided via --dart-define; Google OAuth URL scheme not injected"
  exit 0
fi

python3 - "$PLIST" "$GOOGLE_REVERSED_CLIENT_ID" <<'PYEOF'
import plistlib, sys

path, scheme = sys.argv[1], sys.argv[2]
with open(path, 'rb') as f:
    plist = plistlib.load(f)

for url_type in plist.get('CFBundleURLTypes', []):
    schemes = url_type.get('CFBundleURLSchemes', [])
    for i, s in enumerate(schemes):
        if 'googleusercontent' in s or s == '$(GOOGLE_REVERSED_CLIENT_ID)':
            schemes[i] = scheme
            break

with open(path, 'wb') as f:
    plistlib.dump(plist, f)

print('Injected Google URL scheme:', scheme)
PYEOF

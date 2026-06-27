#!/usr/bin/env bash
#
# build-pass.sh — package a .pkpass bundle from a .pass source directory.
#
# Signs ONLY if a real Apple Pass Type ID certificate is supplied; otherwise emits an
# UNSIGNED bundle that is structurally complete and "ready to sign later" (the only
# missing piece is the `signature` file).
#
# Usage:
#   ./build-pass.sh <pass_src_dir> <output.pkpass>
#   ./build-pass.sh <pass_src_dir> <output.pkpass> <cert.pem> <key.pem> <wwdr.pem> [key_password]
#
# Facts encoded here (verified against the iOS 26 toolchain):
#   * manifest.json maps each payload file -> its hex-encoded SHA-1 (NOT SHA-256).
#   * `signature` is a DETACHED PKCS#7/CMS blob over manifest.json.
#   * all files live at the ARCHIVE ROOT (zip from inside the staging dir, -X strips macOS extras).
#   * a self-signed cert produces a structurally valid signature but Wallet still rejects it
#     (PassKit pins the Apple WWDR PKI) — even on the Simulator. A real Pass Type ID cert is required.
#
set -euo pipefail

SRC="${1:?pass source dir (contains pass.json + images)}"
OUT="${2:?output .pkpass path}"
CERT="${3:-}"; KEY="${4:-}"; WWDR="${5:-}"; KEYPASS="${6:-}"
OPENSSL="${OPENSSL:-/usr/bin/openssl}"   # system LibreSSL works; override for brew openssl@3

[ -f "$SRC/pass.json" ] || { echo "ERROR: $SRC/pass.json missing" >&2; exit 1; }

STAGE="$(mktemp -d)"; trap 'rm -rf "$STAGE"' EXIT

# Copy the pass payload (everything except generated/secret files) into a clean staging dir.
( cd "$SRC" && for f in *; do
    case "$f" in manifest.json|signature|*.pem|.DS_Store) continue;; esac
    [ -f "$f" ] && cp "$f" "$STAGE/$f"
  done )

# 1) manifest.json = SHA-1 hex of every payload file.
( cd "$STAGE"
  printf '{\n'
  first=1
  for f in $(find . -type f ! -name manifest.json ! -name signature | sed 's|^\./||' | sort); do
    h=$(shasum -a 1 "$f" | awk '{print $1}')
    [ $first -eq 0 ] && printf ',\n'
    printf '  "%s" : "%s"' "$f" "$h"
    first=0
  done
  printf '\n}\n'
) > "$STAGE/manifest.json"

# 2) signature = detached PKCS#7/CMS over manifest.json (only with a REAL Apple cert).
if [ -n "$CERT" ] && [ -n "$KEY" ] && [ -n "$WWDR" ]; then
  "$OPENSSL" smime -binary -sign \
    -signer "$CERT" -inkey "$KEY" -certfile "$WWDR" \
    ${KEYPASS:+-passin pass:"$KEYPASS"} \
    -in "$STAGE/manifest.json" -out "$STAGE/signature" -outform DER
  echo "Signed with the provided Pass Type ID certificate."
else
  echo "No cert provided -> UNSIGNED bundle (structurally complete, ready to sign later)."
fi

# 3) zip with files at the ARCHIVE ROOT.
mkdir -p "$(dirname "$OUT")"
OUT="$(cd "$(dirname "$OUT")" && pwd)/$(basename "$OUT")"   # absolutize: the cd below must not break a relative path
rm -f "$OUT"
( cd "$STAGE" && zip -r -X "$OUT" . ) >/dev/null
echo "Wrote: $OUT"
unzip -l "$OUT"

#!/bin/bash
# assembleRelease の APK から「新署名版」と「ZipSigner版」を作り、署名証明書を照合して out/ に置く。
# 引数 = 本体ソースのディレクトリ。手順は本体の release.ps1 と同じ。
#
# ★取り違えると利用者が上書きインストールできない(アンインストール=データ全消しになる)。
#   Variables NEW_SIGNER_CERT_SHA256 / ZIPSIGNER_CERT_SHA256 と一致しなければ止める。
set -euo pipefail

source_dir=${1:?本体ソースのディレクトリを指定してください}

release_dir="$source_dir/app/build/outputs/apk/release"
apk="$release_dir/app-release.apk"
test -f "$apk" || { echo "::error::app-release.apk がありません"; exit 1; }

# versionName は「3.0.2β FixPatch20」「3.0.2β old-ui-18-12」の形。末尾の語をファイル名に使う。
version_name=$(python3 -c 'import json, sys; print(json.load(open(sys.argv[1], encoding="utf-8"))["elements"][0]["versionName"])' \
    "$release_dir/output-metadata.json")
label=${version_name##* }
if ! [[ "$label" =~ ^[0-9A-Za-z][0-9A-Za-z.-]*$ ]]; then
    echo "::error::versionName の形式が想定外です: $version_name"
    exit 1
fi

apksigner="$ANDROID_HOME/build-tools/35.0.0/apksigner"
mkdir -p out
new_apk="out/FutabaViewer-${label}-new-signature.apk"
zip_apk="out/FutabaViewer-${label}-zipsigner.apk"
cp "$apk" "$new_apk"

if [ -z "${ZIPSIGNER_PK8_BASE64:-}" ] || [ -z "${ZIPSIGNER_CERT_BASE64:-}" ]; then
    echo "::error::Secret ZIPSIGNER_PK8_BASE64 / ZIPSIGNER_CERT_BASE64 がありません(docs/SECRETS.md)"
    exit 1
fi
key_dir=$(mktemp -d "${RUNNER_TEMP:-/tmp}/zipsigner.XXXXXX")
trap 'rm -rf "$key_dir"' EXIT
printf '%s' "$ZIPSIGNER_PK8_BASE64" | base64 --decode > "$key_dir/key.pk8"
printf '%s' "$ZIPSIGNER_CERT_BASE64" | base64 --decode > "$key_dir/cert.pem"
"$apksigner" sign --key "$key_dir/key.pk8" --cert "$key_dir/cert.pem" --out "$zip_apk" "$apk"
rm -f "$zip_apk.idsig"

normalize() { tr 'A-F' 'a-f' | tr -d ': \n'; }

verify() {
    local file=$1 expected=$2 name=$3 actual
    actual=$("$apksigner" verify --print-certs "$file" \
        | sed -n 's/^Signer #1 certificate SHA-256 digest: //p' | head -n 1 | normalize)
    echo "$name の証明書 SHA-256: $actual"
    if [ -z "$expected" ]; then
        echo "::warning::$name の期待値(Variables)が未設定なので照合を省きました"
        return
    fi
    if [ "$actual" != "$(printf '%s' "$expected" | normalize)" ]; then
        echo "::error::$name の署名証明書が期待と違います。鍵の Secret を確かめてください"
        exit 1
    fi
}

verify "$new_apk" "${NEW_SIGNER_CERT_SHA256:-}" "新署名版"
verify "$zip_apk" "${ZIPSIGNER_CERT_SHA256:-}" "ZipSigner版"

(cd out && sha256sum -- *.apk)

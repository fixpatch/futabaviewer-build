#!/bin/bash
# Android のリリースビルドの前準備。引数 = 本体ソースのディレクトリ、系統(master / old-ui)。
#
# - SDK / NDK / CMake: NDK は同梱 .so の strip に要る(無いと本体の build.gradle が release を止める)。
#   master は :runtime のネイティブ部品のために CMake も要る。
# - testkey.keystore: 新署名版の鍵(本体の app/build.gradle が参照する)。
# - runtime_material.inc(master だけ): キャッシュ API の App トークンを署名証明書に縛って暗号化した素材。
#   無いと :runtime の CMake が FATAL_ERROR で止まる。
#
# ★公開リポジトリのログに出るので、秘密の値や復号結果を echo しないこと。
set -euo pipefail

source_dir=${1:?本体ソースのディレクトリを指定してください}
line=${2:?系統(master / old-ui)を指定してください}

sdkmanager="$ANDROID_HOME/cmdline-tools/latest/bin/sdkmanager"
packages=("ndk;27.0.12077973" "build-tools;35.0.0")
case "$line" in
    master) packages+=("cmake;3.22.1" "platforms;android-37.0") ;;
    old-ui) packages+=("platforms;android-35") ;;
    *) echo "::error::系統は master か old-ui です: $line"; exit 1 ;;
esac
# `yes` はパイプが閉じると SIGPIPE で終わるので、pipefail で失敗扱いにならないよう包む。
{ yes || true; } | "$sdkmanager" --install "${packages[@]}" > /dev/null

if [ -z "${ANDROID_KEYSTORE_BASE64:-}" ]; then
    echo "::error::Secret ANDROID_KEYSTORE_BASE64 がありません(docs/SECRETS.md)"
    exit 1
fi
printf '%s' "$ANDROID_KEYSTORE_BASE64" | base64 --decode > "$source_dir/testkey.keystore"

if [ "$line" = master ]; then
    if [ -z "${ANDROID_RUNTIME_MATERIAL_BASE64:-}" ]; then
        echo "::error::Secret ANDROID_RUNTIME_MATERIAL_BASE64 がありません(docs/SECRETS.md)"
        exit 1
    fi
    printf '%s' "$ANDROID_RUNTIME_MATERIAL_BASE64" | base64 --decode \
        > "$source_dir/runtime/src/main/cpp/runtime_material.inc"
fi

echo "準備できました(系統: $line)"

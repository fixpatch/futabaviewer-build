#!/bin/bash
# iOS ビルドの前準備。引数 = 本体ソースのディレクトリ。
#
# - local.properties: 配布ビルド用の入力を本体の生成処理へ渡す。
# - Android SDK の compileSdk プラットフォーム: iOS のビルドでも Gradle の構成時に Android モジュールを読むため。
# - Google Drive 同期の OAuth plist: Secrets にあれば本体の memo/google_oauth/ へ置く(無くてもビルドは通る)。
#
# ★公開リポジトリのログに出るので、秘密の値を echo しないこと。
set -euo pipefail

source_dir=${1:?本体ソースのディレクトリを指定してください}

token=${CACHE_SERVER_APP_TOKEN_NEW:-}
if ! [[ "$token" =~ ^[0-9a-f]{64}$ ]]; then
    echo "::error::配布ビルド用の入力が無いか、形式が不正です"
    exit 1
fi
printf 'cacheServerAppTokenNew=%s\n' "$token" > "$source_dir/local.properties"
unset token

if [ -n "${ANDROID_HOME:-}" ] && [ -x "$ANDROID_HOME/cmdline-tools/latest/bin/sdkmanager" ]; then
    # `yes` はパイプが閉じると SIGPIPE で終わるので、pipefail で失敗扱いにならないよう包む。
    { yes || true; } | "$ANDROID_HOME/cmdline-tools/latest/bin/sdkmanager" "platforms;android-37.0" > /dev/null \
        || echo "::warning::Android SDK platform 37 を入れられませんでした(既にあるなら問題なし)"
else
    echo "::warning::ANDROID_HOME の sdkmanager が見つかりません"
fi

if [ -n "${GOOGLE_OAUTH_IOS_PLIST_BASE64:-}" ]; then
    mkdir -p "$source_dir/memo/google_oauth"
    printf '%s' "$GOOGLE_OAUTH_IOS_PLIST_BASE64" | base64 --decode > "$source_dir/memo/google_oauth/client_ci.plist"
    if /usr/libexec/PlistBuddy -c "Print :CLIENT_ID" "$source_dir/memo/google_oauth/client_ci.plist" > /dev/null 2>&1; then
        echo "Google Drive 同期の OAuth 設定を置きました"
    else
        rm -f "$source_dir/memo/google_oauth/client_ci.plist"
        echo "::error::GOOGLE_OAUTH_IOS_PLIST_BASE64 が plist として読めません(Base64 の貼り間違い?)"
        exit 1
    fi
else
    echo "::warning::GOOGLE_OAUTH_IOS_PLIST_BASE64 が無いので Google Drive 同期の設定なしでビルドします"
fi

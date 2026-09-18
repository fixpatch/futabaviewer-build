#!/bin/bash
# 本体の app-ios/dist/FutabaViewer.ipa を「版入りの名前」でコピーし、GitHub Actions の出力へ渡す。
# 名前は Windows(FutabaViewer-Windows-<版>.exe)と揃えて FutabaViewer-iOS-<版>.ipa。Debug のときだけ -Debug を付ける。
# 引数 = 本体ソースのディレクトリ、構成(Release / Debug)。
set -euo pipefail

source_dir=${1:?本体ソースのディレクトリを指定してください}
configuration=${2:?構成を指定してください}

ipa="$source_dir/app-ios/dist/FutabaViewer.ipa"
test -f "$ipa" || { echo "::error::IPA がありません: $ipa"; exit 1; }

# 版は iOS の表示名(AppServicesIos.kt)の最後の語(例: "3.0.2β FixPatch20" → FixPatch20)。
# ★「β」など英数字以外を名前に入れない。GitHub の Release に上げると「.」に置き換えられる。
version_name=$(sed -n 's/^private const val IOS_VERSION_NAME = "\(.*\)"$/\1/p' \
    "$source_dir/data/src/iosMain/kotlin/jp/andosan/futabaviewer/data/AppServicesIos.kt")
label=${version_name##* }
if ! [[ "$label" =~ ^[0-9A-Za-z][0-9A-Za-z.-]*$ ]]; then
    echo "::error::表示名の形式が想定外です: ${version_name:-(空)}"
    exit 1
fi

case "$configuration" in
    Release) file="FutabaViewer-iOS-${label}.ipa" ;;
    *) file="FutabaViewer-iOS-${label}-${configuration}.ipa" ;;
esac

mkdir -p out
cp "$ipa" "out/$file"
shasum -a 256 "out/$file"

{
    echo "file=$file"
    echo "path=out/$file"
} >> "$GITHUB_OUTPUT"

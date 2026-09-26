#!/bin/bash
# 本体の app-ios/dist/FutabaViewer.ipa を「版入りの名前」でコピーし、GitHub Actions の出力へ渡す。
# 名前は Windows(FutabaViewer-Windows-<版>.exe)と揃えて FutabaViewer-iOS-<版>.ipa。Debug のときだけ -Debug を付ける。
# 引数 = 本体ソースのディレクトリ、構成(Release / Debug)。
set -euo pipefail

source_dir=${1:?本体ソースのディレクトリを指定してください}
configuration=${2:?構成を指定してください}

ipa="$source_dir/app-ios/dist/FutabaViewer.ipa"
test -f "$ipa" || { echo "::error::IPA がありません: $ipa"; exit 1; }
# キャッシュ API の App トークンの材料が入っているか。無いと standalone の過去スレ検索が 404 になる
# (FixPatch20-3 はこれが無いまま出ていた)。材料は本体の fvruntime.c がアプリ本体のバイナリの
# __DATA,__fvx0〜2 セクションへ置く(材料が無いビルドではセクション自体ができない)。中身は見ない。
binary=$(mktemp)
unzip -p "$ipa" 'Payload/FutabaViewer.app/FutabaViewer' > "$binary"
# 一覧は変数へ取ってから探す(`otool | grep -q` だと grep が先に抜けて pipefail で失敗扱いになり得る)。
load_commands=$(otool -l "$binary")
rm -f "$binary"
if ! grep -q 'sectname __fvx0' <<< "$load_commands"; then
    echo "::error::IPA に App トークンの材料がありません(CACHE_SERVER_APP_TOKEN_NEW と本体の setup-runtime-component.sh)"
    exit 1
fi

# 版は表示名の最後の語(例: "3.0.2β FixPatch20" → FixPatch20)。表示名は本体の version.properties の versionName。
# version.properties が無い古いタグ(FixPatch20-1 まで)は AppServicesIos.kt の定数から読む。
# ★「β」など英数字以外を名前に入れない。GitHub の Release に上げると「.」に置き換えられる。
if [ -f "$source_dir/version.properties" ]; then
    version_name=$(sed -n 's/^versionName=//p' "$source_dir/version.properties" | tr -d '\r')
else
    version_name=$(sed -n 's/^private const val IOS_VERSION_NAME = "\(.*\)"$/\1/p' \
        "$source_dir/data/src/iosMain/kotlin/jp/andosan/futabaviewer/data/AppServicesIos.kt")
fi
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

# SideStore / LiveContainer のソース(source.json)に載せるアイコン。IPA の中のアイコンは Xcode が
# 独自形式に圧縮していて普通の PNG として読めないので、本体の元画像を使う。
icon="$source_dir/app-ios/FutabaViewer/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png"
icon_path=
if [ "$configuration" = Release ] && [ -f "$icon" ]; then
    cp "$icon" out/FutabaViewer-iOS-icon.png
    icon_path=out/FutabaViewer-iOS-icon.png
fi

{
    echo "file=$file"
    echo "path<<EOF"
    echo "out/$file"
    [ -z "$icon_path" ] || echo "$icon_path"
    echo "EOF"
} >> "$GITHUB_OUTPUT"

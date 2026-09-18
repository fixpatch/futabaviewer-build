#!/usr/bin/env python3
"""SideStore / AltStore / LiveContainer に登録するソース(source.json)を作る。

publish で dist/ の IPA から版を読み、Release に添付する。Latest は master 系(FixPatch)に固定しているので、
登録する URL は常に最新を指す:
    https://github.com/<このリポジトリ>/releases/latest/download/source.json

更新の見分けは IPA の CFBundleShortVersionString(version)と CFBundleVersion(buildVersion)。
buildVersion は本体の version.properties の versionCode で、リリースごとに増える。

引数: dist ディレクトリ、タグ、出力先。環境変数 GITHUB_REPOSITORY を使う。
"""
import datetime
import glob
import json
import os
import plistlib
import sys
import zipfile

dist, tag, output = sys.argv[1:4]
repository = os.environ["GITHUB_REPOSITORY"]
download = f"https://github.com/{repository}/releases/download/{tag}"

ipas = [p for p in glob.glob(os.path.join(dist, "FutabaViewer-iOS-*.ipa")) if not p.endswith("-Debug.ipa")]
if len(ipas) != 1:
    sys.exit(f"::error::IPA がちょうど1つではありません: {ipas}")
ipa = ipas[0]

with zipfile.ZipFile(ipa) as archive:
    names = [n for n in archive.namelist() if n.startswith("Payload/") and n.count("/") == 2 and n.endswith(".app/Info.plist")]
    if len(names) != 1:
        sys.exit(f"::error::IPA の Info.plist が見つかりません: {names}")
    info = plistlib.loads(archive.read(names[0]))

version = info["CFBundleShortVersionString"]
build = info["CFBundleVersion"]
size = os.path.getsize(ipa)
date = datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
ipa_url = f"{download}/{os.path.basename(ipa)}"
icon_url = f"{download}/FutabaViewer-iOS-icon.png" if os.path.exists(os.path.join(dist, "FutabaViewer-iOS-icon.png")) else None
description = f"{tag}(変更点はアプリ内の「更新履歴」を参照)"

app = {
    "name": "ふたばビューア改",
    "bundleIdentifier": info["CFBundleIdentifier"],
    "developerName": "FixPatch",
    "subtitle": "ふたば☆ちゃんねる ビューア",
    "localizedDescription": "ふたばビューア改の iOS 版(未署名 IPA)。",
    "tintColor": "#2E7D32",
    "versions": [
        {
            "version": version,
            "buildVersion": build,
            "date": date,
            "localizedDescription": description,
            "downloadURL": ipa_url,
            "size": size,
            "minOSVersion": info.get("MinimumOSVersion", "16.2"),
        }
    ],
    # 旧形式(versions を読まないクライアント向け)。
    "version": version,
    "versionDate": date,
    "versionDescription": description,
    "downloadURL": ipa_url,
    "size": size,
    "appPermissions": {"entitlements": [], "privacy": {}},
    "screenshotURLs": [],
}
if icon_url:
    app["iconURL"] = icon_url

source = {
    "name": "ふたばビューア改",
    "identifier": f"io.github.{repository.replace('/', '.').lower()}",
    "sourceURL": f"https://github.com/{repository}/releases/latest/download/source.json",
    "website": f"https://github.com/{repository}",
    "apps": [app],
    "news": [],
}
if icon_url:
    source["iconURL"] = icon_url

with open(output, "w", encoding="utf-8") as f:
    json.dump(source, f, ensure_ascii=False, indent=2)
    f.write("\n")
print(f"{output}: {info['CFBundleIdentifier']} {version} ({build}) {size} bytes")

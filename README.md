# futabaviewer-build

Build infrastructure for FutabaViewer.
Application source is maintained in a private repository.

This repository holds the CI/CD workflows, CI helper scripts, and build documentation
used to produce FutabaViewer release artifacts (Android APK, Windows installer, iOS IPA).
It does not contain application source code.

---

## 日本語

ふたばビューア改のビルド基盤(CI の workflow・CI 用スクリプト・ビルド手順)を置くリポジトリ。
アプリのソースは非公開リポジトリ(場所は Secret `SOURCE_REPOSITORY` で渡す)にあり、workflow が読み取り専用トークンで取得してビルドする。

### ダウンロード

#### FixPatch(master 系)

[![Release](https://img.shields.io/github/v/release/fixpatch/futabaviewer-build?filter=FixPatch*&label=Release)](https://github.com/fixpatch/futabaviewer-build/releases/latest) [![Build](https://img.shields.io/github/actions/workflow/status/fixpatch/futabaviewer-build/release-fixpatch.yml?branch=main&label=Build)](https://github.com/fixpatch/futabaviewer-build/actions/workflows/release-fixpatch.yml)

**Android**

[![Get it on Obtainium](https://img.shields.io/badge/GET_IT_ON-Obtainium-7F57C2?style=for-the-badge&logo=obtainium&logoColor=white)](https://fixpatch.github.io/futabaviewer-build/get/?app=obtainium&line=FixPatch) [![Download APK](https://img.shields.io/badge/DOWNLOAD-APK-3DDC84?style=for-the-badge&logo=android&logoColor=white)](https://fixpatch.github.io/futabaviewer-build/get/?line=FixPatch&file=apk)

**iOS**

[![Get it on LiveContainer](https://img.shields.io/badge/GET_IT_ON-LiveContainer-0A84FF?style=for-the-badge&logo=apple&logoColor=white)](https://fixpatch.github.io/futabaviewer-build/get/?app=livecontainer) [![Get it on SideStore](https://img.shields.io/badge/GET_IT_ON-SideStore-8E44AD?style=for-the-badge&logo=apple&logoColor=white)](https://fixpatch.github.io/futabaviewer-build/get/?app=sidestore) [![Download IPA](https://img.shields.io/badge/DOWNLOAD-IPA-555555?style=for-the-badge&logo=apple&logoColor=white)](https://fixpatch.github.io/futabaviewer-build/get/?line=FixPatch&file=ipa)

**Windows**

[![Download Installer](https://img.shields.io/badge/DOWNLOAD-Installer-0078D4?style=for-the-badge&logo=data%3Aimage%2Fsvg%2Bxml%3Bbase64%2CPHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIHZpZXdCb3g9IjAgMCAyNCAyNCIgZmlsbD0id2hpdGUiPjxwYXRoIGQ9Ik0wIDBoMTEuNHYxMS40SDB6TTEyLjYgMEgyNHYxMS40SDEyLjZ6TTAgMTIuNmgxMS40VjI0SDB6TTEyLjYgMTIuNkgyNFYyNEgxMi42eiIvPjwvc3ZnPg%3D%3D&logoColor=white)](https://fixpatch.github.io/futabaviewer-build/get/?line=FixPatch&file=exe)

#### old-ui

[![Release](https://img.shields.io/github/v/release/fixpatch/futabaviewer-build?filter=old-ui*&label=Release)](https://github.com/fixpatch/futabaviewer-build/releases?q=old-ui&expanded=true) [![Build](https://img.shields.io/github/actions/workflow/status/fixpatch/futabaviewer-build/release-old-ui.yml?branch=main&label=Build)](https://github.com/fixpatch/futabaviewer-build/actions/workflows/release-old-ui.yml)

**Android**

[![Get it on Obtainium](https://img.shields.io/badge/GET_IT_ON-Obtainium-7F57C2?style=for-the-badge&logo=obtainium&logoColor=white)](https://fixpatch.github.io/futabaviewer-build/get/?app=obtainium&line=old-ui) [![Download APK](https://img.shields.io/badge/DOWNLOAD-APK-3DDC84?style=for-the-badge&logo=android&logoColor=white)](https://fixpatch.github.io/futabaviewer-build/get/?line=old-ui&file=apk)

- ボタンは [GitHub Pages の中継ページ](docs/get/index.html)を通る。README には http(s) のリンクしか置けず(`obtainium://` などは消される)、
  配布物のファイル名には版が入るので、中継ページが「その系統の最新 Release」を引いて本物へ飛ばす。
- Obtainium は Release の名前(`^FixPatch` / `^old-ui`)で系統だけを絞る。APK は絞らないので、更新の時に新署名版 / ZipSigner版のどちらを入れるか選ぶ画面が出る。
- iOS のソース: `https://github.com/fixpatch/futabaviewer-build/releases/latest/download/source.json`(LiveContainer / SideStore / AltStore)。
- Windows 版はアプリの起動時に新しい版を確かめ、タイトルバーに「更新あり」を出す(押すとインストーラーを落として入れ替える)。
- GitHub の「Latest」は1つしか付けられないので、master 系に固定している(old-ui を出しても Latest は移らない)。

| workflow | 起動 | 成果物 |
|---|---|---|
| [Release FixPatch](.github/workflows/release-fixpatch.yml) / [Release old-ui](.github/workflows/release-old-ui.yml)(中身は [_release.yml](.github/workflows/_release.yml)) | 本体で `FixPatch〇〇` / `old-ui〇〇` のタグを push(または手動) | Release に APK(新署名版・ZipSigner版)、master 系は Windows インストーラーと iOS IPA も |
| [iOS IPA](.github/workflows/ios-ipa.yml) | 手動 | iOS 未署名 IPA(Artifacts のみ・試し用) |

- 使い方と構成: [docs/CI.md](docs/CI.md)
- 秘密の設定: [docs/SECRETS.md](docs/SECRETS.md)

### 公開リポジトリであることの注意

- **ビルドログ・Artifacts・Releases は誰でも見られる。** ログに秘密を出さないこと。
- workflow を実行できるのは、このリポジトリに書き込み権限のある人だけ(`workflow_dispatch` のみ。PR からは動かない)。
- Secrets はフォークからの実行には渡らない。ただし書き込み権限のある人は workflow を書き換えて取り出せるので、協力者を足すときは注意する。

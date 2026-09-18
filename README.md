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

| 系統 | 最新 |
|---|---|
| master 系(FixPatch〇〇)| [releases/latest](https://github.com/fixpatch/futabaviewer-build/releases/latest) |
| old-ui 系(old-ui〇〇)| [old-ui の Release 一覧(新しい順)](https://github.com/fixpatch/futabaviewer-build/releases?q=old-ui&expanded=true) |

GitHub の「Latest」は1つしか付けられないので、master 系に固定している(old-ui を出しても Latest は移らない)。

自動アップデート: Android は Obtainium、iOS は LiveContainer / SideStore にソース `https://github.com/fixpatch/futabaviewer-build/releases/latest/download/source.json` を登録する(手順は Wiki の「自動アップデート」)。

| workflow | 起動 | 成果物 |
|---|---|---|
| [Release](.github/workflows/release.yml) | 本体で `FixPatch〇〇` / `old-ui〇〇` のタグを push(または手動) | Release に APK(新署名版・ZipSigner版)、master 系は Windows インストーラーと iOS IPA も |
| [iOS IPA](.github/workflows/ios-ipa.yml) | 手動 | iOS 未署名 IPA(Artifacts のみ・試し用) |

- 使い方と構成: [docs/CI.md](docs/CI.md)
- 秘密の設定: [docs/SECRETS.md](docs/SECRETS.md)

### 公開リポジトリであることの注意

- **ビルドログ・Artifacts・Releases は誰でも見られる。** ログに秘密を出さないこと。
- workflow を実行できるのは、このリポジトリに書き込み権限のある人だけ(`workflow_dispatch` のみ。PR からは動かない)。
- Secrets はフォークからの実行には渡らない。ただし書き込み権限のある人は workflow を書き換えて取り出せるので、協力者を足すときは注意する。

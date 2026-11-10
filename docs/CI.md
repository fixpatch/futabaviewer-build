# CI の構成と使い方

## 全体の流れ

```
本体 futabaviewer(非公開)                   futabaviewer-build(公開・このリポジトリ)
                                                 
 git tag FixPatch21 / old-ui-18-13               
 git push origin <タグ>                          
   └─ dispatch-build.yml(数秒)──起動──→  release-fixpatch.yml / release-old-ui.yml(タグの頭で選ぶ)
                                                 └─ _release.yml(tag = そのタグ)
                                                   ├─ resolve  … タグと系統が合っているかの確認
                                                   ├─ _android.yml(ubuntu)      … 新署名版 + ZipSigner版 APK
                                                   ├─ _windows.yml(windows)     … .exe / .msi   ※master 系のみ
                                                   ├─ _ios.yml(macos-26-intel)  … 未署名 IPA    ※master 系のみ
                                                   └─ publish … 全部そろったら Release <タグ> に添付
```

- ビルドはこのリポジトリの GitHub-hosted runner で行う。本体側で動くのは起動用の数秒だけ。
- 本体のソースは読み取り専用トークンで**タグの時点**を取得する。old-ui のタグは old-ui ブランチのコミットに付いているので、
  特別な指定なしに old-ui のソースになる。
- `dispatch-build.yml` は **master と old-ui の両方のブランチ**に置く(タグの付いたコミットに無いと動かない)。
- 呼び口を系統ごとに分けているのは README の Build バッジのため(バッジは workflow ファイル単位でしか取れない)。
  中身は `_release.yml` 1本。

## リリースの手順

1. 本体で版表記と更新履歴を確定してコミット・push(今まで通り)
2. タグを打って push:

   ```powershell
   git tag FixPatch21
   git push origin FixPatch21
   ```

   old-ui は old-ui のワークツリーで:

   ```powershell
   git tag old-ui-18-13
   git push origin old-ui-18-13
   ```

3. futabaviewer-build の **Actions → Release FixPatch / Release old-ui** で進み具合を見る。終わると **Releases** にタグ名で添付される。
4. APK は今まで通り **実機で確認してから**告知する(R8 由来の不具合は CI では分からない)。

### 手動で動かす / やり直す

- **Release**: Actions → Release → Run workflow → `tag` にタグ名。途中で落ちたときのやり直しもこれ(Release は同じタグ名へ上書き添付)。
- **iOS IPA だけ試す**: Actions → iOS IPA → Run workflow(ブランチ/コミットと構成を選ぶ。Release には置かず Artifacts のみ)。

### 旧版 Stable の手動リリース

「old-futabaviewerをリリースして」という指示は、特に指定がなければ以下の**手動公開（Release ラベル None）**を意味する。通常の CI は使わず、Latest・Pre-releaseは付けない。
通常の本体タグ `FixPatch*` / `old-ui*` は上記の CI 起動用。`Stable*` はその経路に流さない。

1. 18-7dXはReleaseビルドの**新署名APKだけ**を作成する。ZipSigner版は作成もアップロードもしない。ユーザー確認済みのAPKがあればそのまま使い、再ビルド・再署名しない。`SHA256SUMS.txt`には配布する新署名APKのハッシュだけを記載し、既存の一覧にZipSigner版があればその記載だけを除く。
2. **この公開ビルドリポジトリの `main`** で README の Stable 項目を最終版名と正規リンク `https://github.com/fixpatch/futabaviewer-build/releases/tag/Stable-FixPatch18-7dN` に更新し、コミット・push する。そのコミットに公開タグ `Stable-FixPatch18-7dN` を作成・push する。本体ソース側のタグではない。
3. 次の英語名の2ファイルを添付し、公開リリースを作る。`N` は対象の版番号に置き換える。コマンドはこのリポジトリで、成果物を参照できる場所から実行する。

   ```powershell
   gh release create Stable-FixPatch18-7dN `
     FutabaViewer-FixPatch18-7dN-new-signature.apk `
     SHA256SUMS.txt `
     --repo fixpatch/futabaviewer-build `
     --title "FixPatch18-7dN" `
     --notes "確認済みの旧版 Stable APK（新署名版のみ）と SHA-256。" `
     --latest=false --verify-tag
   ```

4. 設定は **`draft=false`、`prerelease=false`、`make_latest=false`（Release ラベル None）** とする。`--draft`・`--prerelease`は付けない。Noneは下書きではなく、Latest・Pre-releaseの表示ラベルを付けない公開リリースを意味する。

下書き（Draft）はユーザーが明示指定した場合だけ使う。「手順だけ訂正」の依頼では、既存リリースの公開・下書き状態や既存タグを変更しない。

## Release に置くファイル

| ファイル | 内容 |
|---|---|
| `FutabaViewer-<ラベル>-new-signature.apk` | 新署名版(`testkey.keystore`)。`release.ps1` の「新署名版」と同じ |
| `FutabaViewer-<ラベル>-zipsigner.apk` | FixPatch・old-uiのみ。ZipSigner版(旧鍵で署名し直し)。18-7dXでは作成・添付しない |
| `FutabaViewer-Windows-<ラベル>.exe` / `.msi` | Windows インストーラー(master 系のみ) |
| `FutabaViewer-<版>-Release-<コミット>.ipa` | iOS 未署名 IPA(master 系のみ) |
| `SHA256SUMS.txt` | 上の全ファイルの SHA-256 |

`<ラベル>` は versionName の末尾の語(`3.0.2β FixPatch21` → `FixPatch21`)。GitHub の添付ファイル名は日本語が化けるので英語名にしている。

## 安全装置

- APK の署名証明書を Variables(`NEW_SIGNER_CERT_SHA256` / `ZIPSIGNER_CERT_SHA256`)と照合し、違えば止める。
- master 系は Android・Windows・iOS の**3つ全部が成功したときだけ** Release を作る(欠けた Release を出さない)。
- 鍵・素材のファイルは各ジョブの最後に消す(ホスト型ランナーは使い捨てだが念のため)。

## 時間とキャッシュ

- iOS の初回は Kotlin/Native・LLVM・MobileVLCKit・VOICEVOX の取得で 60〜90 分ほど。以降はキャッシュが効く。
- Android は 15〜25 分、Windows は 20〜30 分ほどの見込み(初回は NDK・WiX の取得がある)。

## 公開リポジトリとしての注意

- **ビルドログと Artifacts / 公開済み Releases は誰でも見られる。** Release の下書きは一般公開されず、公開すると添付ファイルも一般公開になる。
- GitHub-hosted runner の利用条件(このリポジトリに関係するソフトウェアのビルド・テスト・配布に使うこと)に沿うよう、
  このリポジトリは FutabaViewer の正式なビルド基盤として workflow・スクリプト・手順を管理する。
- workflow は `workflow_dispatch` だけ。PR やフォークからは動かない。

## 失敗したとき

| 症状 | 見るところ |
|---|---|
| checkout で `Repository not found` | `FUTABAVIEWER_SOURCE_TOKEN` の期限切れ/対象リポジトリの選び忘れ/Contents 権限なし |
| 本体でタグを push しても Release が動かない | 本体の Actions で dispatch-build が赤なら `BUILD_REPO_DISPATCH_TOKEN`。そもそも動いていなければ、タグのコミットに `dispatch-build.yml` が無い |
| `の署名証明書が期待と違います` | 鍵の Secret と照合値の Variables の組み合わせ |
| iOS の `Kotlin/Native` のリンクで Killed / OutOfMemoryError | `IOS_RUNNER` が Intel(14GB)か。だめなら `IOS_GRADLE_JVMARGS` を下げる |
| iOS の Xcode の版が合わない | 本体の LastUpgradeCheck は 2600 = Xcode 26。`IOS_RUNNER` / `IOS_XCODE_VERSION` |
| iOS の `verify-ipa.py` の Forbidden text | 個人情報の文字列が IPA に入っている。どのファイルかがログに出る |

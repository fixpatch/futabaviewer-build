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

## Release に置くファイル

| ファイル | 内容 |
|---|---|
| `FutabaViewer-<ラベル>-new-signature.apk` | 新署名版(`testkey.keystore`)。`release.ps1` の「新署名版」と同じ |
| `FutabaViewer-<ラベル>-zipsigner.apk` | ZipSigner 版(旧鍵で署名し直し)。`release.ps1` の「ZipSigner版」と同じ |
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

- **ビルドログと Artifacts / Releases は誰でも見られる。** Release に置いた物は一般公開になる。
- GitHub-hosted runner の利用条件(このリポジトリに関係するソフトウェアのビルド・テスト・配布に使うこと)に沿うよう、
  このリポジトリは FutabaViewer の正式なビルド基盤として workflow・スクリプト・手順を管理する。
- workflow は `workflow_dispatch` だけ。PR やフォークからは動かない。

## 失敗したとき

| 症状 | 見るところ |
|---|---|
| checkout で `Repository not found` | `FUTABAVIEWER_SOURCE_TOKEN` の期限切れ/対象リポジトリの選び忘れ/Contents 権限なし |
| 本体でタグを push しても Release が動かない | 本体の Actions で dispatch-build が赤なら `BUILD_REPO_DISPATCH_TOKEN`。そもそも動いていなければ、タグのコミットに `dispatch-build.yml` が無い |
| `runtime_material.inc is missing` | `ANDROID_RUNTIME_MATERIAL_BASE64` |
| `の署名証明書が期待と違います` | 鍵の Secret と照合値の Variables の組み合わせ |
| Windows の `cacheServerAppTokenNew must be 64 lowercase hexadecimal` | `CACHE_SERVER_APP_TOKEN_NEW` |
| iOS の `CACHE_SERVER_APP_TOKEN_NEW が無いか` / `IPA に runtime_material.json がありません` | `CACHE_SERVER_APP_TOKEN_NEW` |
| iOS の `Kotlin/Native` のリンクで Killed / OutOfMemoryError | `IOS_RUNNER` が Intel(14GB)か。だめなら `IOS_GRADLE_JVMARGS` を下げる |
| iOS の Xcode の版が合わない | 本体の LastUpgradeCheck は 2600 = Xcode 26。`IOS_RUNNER` / `IOS_XCODE_VERSION` |
| iOS の `verify-ipa.py` の Forbidden text | 個人情報の文字列が IPA に入っている。どのファイルかがログに出る |

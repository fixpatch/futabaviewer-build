# Secrets / Variables の設定

置き場所は2か所。

| リポジトリ | 何を置くか |
|---|---|
| **futabaviewer-build**(公開・このリポジトリ) | ビルドと署名に使う秘密(下の 1〜6)と Variables |
| **futabaviewer**(非公開・本体) | タグ push でこちらを起動するためのトークン(下の 7)だけ |

登録画面はどちらも **Settings → Secrets and variables → Actions**。「Secrets」タブは値が見えなくなる秘密、
「Variables」タブは見えてよい設定。

> 公開リポジトリでも Secrets の値はログに出ない(自動で `***` に伏せられる)。ただし workflow やスクリプトで
> 加工した値(Base64 を解いた中身など)は伏せられないので、**加工した値を echo しないこと**。
> また、このリポジトリに**書き込み権限を持つ人は workflow を書き換えて秘密を取り出せる**。協力者を足すときは注意する。

以下のコマンドは **Windows の PowerShell**(本体は `K:\dev\local_repository\futabaviewer`)で、
`gh auth login` 済みの前提。`gh secret set` はパイプで受けた値をそのまま登録し、画面には出さない。

---

## futabaviewer-build に置く Secrets

### 1. `FUTABAVIEWER_SOURCE_TOKEN`(必須)

非公開の本体を読むためのトークン。**読み取り専用・本体だけ**に絞った fine-grained personal access token。

1. GitHub 右上のアイコン → **Settings** → **Developer settings** → **Personal access tokens** → **Fine-grained tokens** → **Generate new token**
2. 設定:
   - **Token name**: `futabaviewer-build source read`
   - **Expiration**: 90日など(切れたら作り直して Secret を更新)
   - **Resource owner**: `<本体の owner>`(本体を持つアカウントでログインして作る)
   - **Repository access**: **Only select repositories** → `<本体の owner>/futabaviewer`
   - **Repository permissions → Contents**: **Read-only**(Metadata: Read-only は自動。他は付けない)
3. **Generate token** → 表示された `github_pat_…` をコピー(閉じると二度と見えない)
4. 登録(貼り付けを求められるので、そこで貼る):

```powershell
gh secret set FUTABAVIEWER_SOURCE_TOKEN --repo fixpatch/futabaviewer-build
```

### `SOURCE_REPOSITORY`(必須)

本体の場所(`<owner>/<名前>`)。公開リポジトリに名前を書かないため Secret にしている(Actions のログでも `***` になる)。

```powershell
gh secret set SOURCE_REPOSITORY --repo fixpatch/futabaviewer-build --body "<本体の owner>/futabaviewer"
```

### 2. `ANDROID_KEYSTORE_BASE64`(必須)

新署名版の鍵 `testkey.keystore`(本体の `app/build.gradle` がパスワード `testkey` で参照)。

```powershell
[Convert]::ToBase64String([IO.File]::ReadAllBytes('K:\dev\local_repository\futabaviewer\testkey.keystore')) | gh secret set ANDROID_KEYSTORE_BASE64 --repo fixpatch/futabaviewer-build
```

### 3. `ANDROID_RUNTIME_MATERIAL_BASE64`(必須・master 系のみで使用)

`runtime/src/main/cpp/runtime_material.inc`。キャッシュ API の App トークンを**新署名版の証明書に縛って**暗号化した素材。
無いと `:runtime` の CMake が止まる。トークンや鍵を変えたら `tools/configure-runtime-component.ps1 -SkipCloudflare` で作り直して更新する。

```powershell
[Convert]::ToBase64String([IO.File]::ReadAllBytes('K:\dev\local_repository\futabaviewer\runtime\src\main\cpp\runtime_material.inc')) | gh secret set ANDROID_RUNTIME_MATERIAL_BASE64 --repo fixpatch/futabaviewer-build
```

### 4. `ZIPSIGNER_PK8_BASE64` / 5. `ZIPSIGNER_CERT_BASE64`(必須)

ZipSigner 版(旧署名)の鍵と証明書。`release.ps1` と同じ `K:\APK-Multi-Tool\other` のもの。

```powershell
[Convert]::ToBase64String([IO.File]::ReadAllBytes('K:\APK-Multi-Tool\other\zipsigner.testkey.pk8')) | gh secret set ZIPSIGNER_PK8_BASE64 --repo fixpatch/futabaviewer-build
[Convert]::ToBase64String([IO.File]::ReadAllBytes('K:\APK-Multi-Tool\other\zipsigner.testkey.x509.pem')) | gh secret set ZIPSIGNER_CERT_BASE64 --repo fixpatch/futabaviewer-build
```

### 6. `CACHE_SERVER_APP_TOKEN_NEW`(必須・Windows と iOS で使用)

`local.properties` の `cacheServerAppTokenNew`(64桁の小文字16進)として置く。

- Windows: `fvruntime.dll` の素材生成が読む。
- iOS: 本体 `app-ios/setup-runtime-component.sh` が IPA の `runtime_material.json` を作る。未署名 IPA では
  チームIDではなく元のバンドルIDに縛るので、SideStore / LiveContainer が署名し直しても復号できる。
  無いと standalone の過去スレ検索(`/api/search`)が 404 になる(FixPatch20-3 で発生)。
  `scripts/ios/stage-ipa.sh` が IPA に材料が無ければ止める。

```powershell
(Select-String -LiteralPath 'K:\dev\local_repository\futabaviewer\local.properties' -Pattern '^cacheServerAppTokenNew=(.+)$').Matches[0].Groups[1].Value.Trim() | gh secret set CACHE_SERVER_APP_TOKEN_NEW --repo fixpatch/futabaviewer-build
```

### `GOOGLE_OAUTH_IOS_PLIST_BASE64`(任意・iOS で使用)

Google Drive 同期の iOS 用 OAuth クライアント。**無くてもビルドは通り**、Google Drive 同期が「設定がありません」になるだけ。
plist は **Mac の `~/Developer/futabaviewer/memo/google_oauth/`** にしか無い。Mac のターミナルで:

```bash
cd ~/Developer/futabaviewer && base64 -i "$(ls memo/google_oauth/client_*.plist | head -n 1)" | tr -d '\n' | gh secret set GOOGLE_OAUTH_IOS_PLIST_BASE64 --repo fixpatch/futabaviewer-build
```

(Mac で gh を使わない場合は `| pbcopy` にしてブラウザの New repository secret へ貼る)

---

## futabaviewer-build に置く Variables

**証明書の照合値は必ず入れる**(取り違えた APK を公開しないための安全装置。未設定だと照合を省いて警告だけになる)。

```powershell
gh variable set NEW_SIGNER_CERT_SHA256 --repo fixpatch/futabaviewer-build --body "0e549823560a32d86743e96d564081bd3b9a1684906f80b344203db2a93d6b98"
gh variable set ZIPSIGNER_CERT_SHA256 --repo fixpatch/futabaviewer-build --body "a40da80a59d170caa950cf15c18c454d47a39b26989d8b640ecd745ba71bf5dc"
```

照合値の出し方(値を確かめ直したいとき):

```powershell
keytool -list -v -keystore K:\dev\local_repository\futabaviewer\testkey.keystore -storepass testkey -alias testkey | Select-String SHA256
keytool -printcert -file K:\APK-Multi-Tool\other\zipsigner.testkey.x509.pem | Select-String SHA256
```

その他(任意・既定で動く):

| 名前 | 既定 | 変えるとき |
|---|---|---|
| `IOS_RUNNER` | `macos-26-intel` | 別のイメージを使う(例 `macos-15-intel`)。Xcode 26 が必要 |
| `IOS_XCODE_VERSION` | `latest-stable` | Xcode の版を固定したい(例 `26.0`) |
| `IOS_GRADLE_JVMARGS` | 空(= 本体の既定 `-Xmx6g …`) | メモリ不足で落ちるとき `-Xmx5g -Dfile.encoding=UTF-8 -XX:MaxMetaspaceSize=1024m` |
| `ARTIFACT_RETENTION_DAYS` | `7` | Artifacts を置いておく日数(公開なので短め。Release の添付は消えない) |

---

## futabaviewer(本体)に置く Secret

### 7. `BUILD_REPO_DISPATCH_TOKEN`(必須)

本体でタグを push したとき、`dispatch-build.yml` が futabaviewer-build の Release を起動するためのトークン。

1. Fine-grained tokens → **Generate new token**
   - **Token name**: `futabaviewer release dispatch`
   - **Resource owner**: `fixpatch`
   - **Repository access**: **Only select repositories** → `fixpatch/futabaviewer-build`
   - **Repository permissions → Actions**: **Read and write**(他は付けない)
2. 登録:

```powershell
gh secret set BUILD_REPO_DISPATCH_TOKEN --repo <本体の owner>/futabaviewer
```

---

## 登録しないもの

- **iOS 用に別のトークン**: 上の `CACHE_SERVER_APP_TOKEN_NEW` を共用する。
- **Apple の証明書・プロビジョニング**: 未署名 IPA なので不要。

## 確認

```powershell
gh secret list --repo fixpatch/futabaviewer-build
gh variable list --repo fixpatch/futabaviewer-build
gh secret list --repo <本体の owner>/futabaviewer
```

(Secret は名前と更新日時だけが出る。値は見えない)

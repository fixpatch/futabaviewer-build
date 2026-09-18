# Windows インストーラーのビルドの前準備。
#
# - local.properties: fvruntime.dll の素材生成(本体 tools/configure-desktop-runtime-component.ps1)が
#   cacheServerAppTokenNew を読む。無いと Gradle の入力ファイル不足で止まる。
# - Android SDK: Gradle の構成時に Android モジュールも読むので compileSdk のプラットフォームを入れておく。
#
# ★公開リポジトリのログに出るので、秘密の値を出力しないこと。
param(
    [Parameter(Mandatory = $true)][string]$SourceDir
)

$ErrorActionPreference = 'Stop'

$token = [string]$env:CACHE_SERVER_APP_TOKEN_NEW
if ($token -notmatch '^[0-9a-f]{64}$') {
    throw 'Secret CACHE_SERVER_APP_TOKEN_NEW が無いか、64桁の小文字16進ではありません(docs/SECRETS.md)'
}
[IO.File]::WriteAllText((Join-Path $SourceDir 'local.properties'), "cacheServerAppTokenNew=$token`n", [Text.Encoding]::ASCII)
Remove-Variable token

$sdkmanager = Join-Path $env:ANDROID_HOME 'cmdline-tools\latest\bin\sdkmanager.bat'
if (Test-Path -LiteralPath $sdkmanager) {
    cmd /c "echo y| `"$sdkmanager`" `"platforms;android-37.0`" > NUL"
    if ($LASTEXITCODE -ne 0) { Write-Host '::warning::Android SDK platform 37 を入れられませんでした(既にあるなら問題なし)' }
} else {
    Write-Host '::warning::ANDROID_HOME の sdkmanager が見つかりません'
}

Write-Host '準備できました'

# 作ったインストーラーを「版入りの名前」で out/ に置く。
# インストーラー自体の版(packageVersion)は本体の build.gradle.kts が決める。名前は表示名の最後の語から取る。
# 表示名は本体の version.properties の versionName。それが無い古いタグ(FixPatch20-1 まで)は Main.kt の定数から読む。
param(
    [Parameter(Mandatory = $true)][string]$SourceDir
)

$ErrorActionPreference = 'Stop'

$properties = Join-Path $SourceDir 'version.properties'
if (Test-Path -LiteralPath $properties) {
    $match = Select-String -LiteralPath $properties -Encoding utf8 -Pattern '^versionName=(.*)$' | Select-Object -First 1
} else {
    $main = Join-Path $SourceDir 'app-desktop/src/desktopMain/kotlin/jp/andosan/futabaviewer/desktop/Main.kt'
    $match = Select-String -LiteralPath $main -Pattern '^private const val APP_VERSION_NAME = "(.*)"$' | Select-Object -First 1
}
$label = if ($match) { ($match.Matches[0].Groups[1].Value.Trim() -split ' ')[-1] } else { 'unknown' }
if ($label -notmatch '^[0-9A-Za-z][0-9A-Za-z.-]*$') { throw "表示名の形式が想定外です: $label" }

$binaries = Join-Path $SourceDir 'app-desktop/build/compose/binaries/main'
$installers = @(Get-ChildItem -Path (Join-Path $binaries 'exe/*.exe'), (Join-Path $binaries 'msi/*.msi') -File)
if (-not ($installers | Where-Object Extension -eq '.exe')) { throw 'exe インストーラーが作られていません' }

New-Item -ItemType Directory -Force -Path out | Out-Null
foreach ($installer in $installers) {
    $destination = Join-Path out ("FutabaViewer-Windows-$label" + $installer.Extension)
    Copy-Item -LiteralPath $installer.FullName -Destination $destination -Force
    $hash = (Get-FileHash -LiteralPath $destination -Algorithm SHA256).Hash.ToLowerInvariant()
    Write-Host "$hash  $(Split-Path $destination -Leaf)"
}

# Установка готового APK лаунчера CleanYourTV на ТВ (без сборки, без JDK/Android SDK).
# Логика повторяет launcher\build-and-install.ps1 из репо, но берёт уже собранный APK.
# Запуск из папки cleanyourtv-main:
#   powershell -ExecutionPolicy Bypass -File .\install-launcher.ps1 -TvHost 192.168.0.6 -Apk .\tvhome-2.5.0.apk
# Откат (вернуть штатный лаунчер):
#   powershell -ExecutionPolicy Bypass -File .\install-launcher.ps1 -TvHost 192.168.0.6 -Undo
param(
    [string]$TvHost = $env:TV_HOST,
    [string]$Apk = '.\tvhome-2.5.0.apk',
    [switch]$Undo
)
$ErrorActionPreference = 'Stop'
$OutputEncoding = New-Object System.Text.UTF8Encoding $false
if (-not $TvHost) { throw 'pass -TvHost <tv ip>' }
$env:TV_HOST = $TvHost
$py = '.\tools\venv\Scripts\python.exe'
if (-not (Test-Path $py)) { throw 'run from cleanyourtv-main (tools\venv not found)' }
$stock = 'com.google.android.tvlauncher'
$new = 'com.gathin.tvhome'

if ($Undo) {
    @(
        "pm enable --user 0 $stock",
        "cmd package set-home-activity --user 0 $stock/.MainActivity",
        "pm uninstall --user 0 $new",
        'cmd package resolve-activity --brief -a android.intent.action.MAIN -c android.intent.category.HOME'
    ) | & $py -I .\tools\tv.py --batch
    Write-Host 'Stock launcher restored. Press Home.'
    exit 0
}

if (-not (Test-Path $Apk)) { throw "APK not found: $Apk" }
$Apk = (Resolve-Path $Apk).Path

# 1. Кто сейчас владеет Home — должен быть штатный лаунчер
$homePkg = (& $py -I .\tools\tv.py 'cmd package resolve-activity --brief -a android.intent.action.MAIN -c android.intent.category.HOME' | Select-Object -Last 1)
$homePkg = "$homePkg".Trim().Split('/')[0]
Write-Host "HOME before: $homePkg"
if ($homePkg -ne $stock -and $homePkg -ne $new) { throw "Home resolves to '$homePkg', expected $stock. Stop." }

# 2. Залить и установить APK
& $py -I .\tools\b64push.py $Apk /data/local/tmp/tvhome.apk
if ($LASTEXITCODE -ne 0) { throw 'APK upload failed' }
$out = & $py -I .\tools\tv.py 'pm install -r /data/local/tmp/tvhome.apk; rm -f /data/local/tmp/tvhome.apk'
Write-Host $out
if ("$out" -notmatch 'Success') { throw 'pm install failed; stock launcher untouched' }

# 3. Назначить домашним и запустить — ДО отключения штатного
$out = & $py -I .\tools\tv.py "cmd package set-home-activity --user 0 $new/.MainActivity"
Write-Host $out
if ("$out" -match 'Error') { throw 'could not set home; stock launcher untouched' }
$start = (& $py -I .\tools\tv.py "am start -W -n $new/.MainActivity") -join "`n"
Write-Host $start
if ($start -notmatch 'Status: ok' -or $start -match '(?m)^Error') { throw 'new launcher did not start; stock launcher untouched' }

# 4. Скомпилировать лаунчер, отключить штатный, закрепить выбор
@(
    "cmd package compile -m speed -f $new",
    "pm disable-user --user 0 $stock",
    "cmd package set-home-activity --user 0 $new/.MainActivity",
    "settings put secure screensaver_components $new/.ClockDream",
    'settings put secure screensaver_enabled 1'
) | & $py -I .\tools\tv.py --batch

# 5. Проверка: если Home не у нового — вернуть штатный
$homeNow = (& $py -I .\tools\tv.py 'cmd package resolve-activity --brief -a android.intent.action.MAIN -c android.intent.category.HOME' | Select-Object -Last 1).Trim()
if ($homeNow -notlike "$new/*") {
    & $py -I .\tools\tv.py "pm enable --user 0 $stock" | Out-Null
    & $py -I .\tools\tv.py "cmd package set-home-activity --user 0 $stock/.MainActivity" | Out-Null
    throw "Home resolves to '$homeNow'; stock launcher re-enabled."
}
Write-Host "Home now resolves to $homeNow. Press Home on the remote."

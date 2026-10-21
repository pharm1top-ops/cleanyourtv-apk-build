# Xiaomi MiTV-MOOQ0 (192.168.0.6) — что сделано и как откатить

Все команды — в PowerShell из папки `C:\Users\Aru\cleanyourtv-main`.
Перед командами через `tv.py` один раз на сессию: `$env:TV_HOST = '192.168.0.6'`
(`disable.ps1` / `restore.ps1` / `install-launcher.ps1` берут адрес из `-TvHost` сами).

Записи отката: `C:\Users\Aru\.cleanyourtv\recovery-*.json` (копии — в этой папке `backup/`).
ТВ: Android TV 10, 1,8 ГБ RAM, прошивка QTG3.200305.006.xxxx.

## Что сделано 21.10.2026

| # | Что | Список | Запись отката | Откат |
|---|---|---|---|---|
| 1 | Отключено 20 пакетов: PatchWall, рекламные ряды, Mi-аналитика, TV Manager, Alexa, Mi Gallery/Music, Play Games, заставки, демо-режим, рекомендации Google | `examples\xiaomi-mitv-mooq0\debloat.txt` | `recovery-…-c21cd84f.json` | `restore.ps1 … debloat.txt` |
| 2 | Отключён сервис обновлений прошивки `com.xiaomi.mitv.updateservice` | `extra.txt` | `recovery-…-db1e6f54.json` | `restore.ps1 … extra.txt` |
| 3 | Отключены Mi Cast, Miracast, SmartShare, Mi TV+, Play Movies, YT Music, Mi-плеер | `extra2.txt` | `recovery-…-3f14d7c9.json` | `restore.ps1 … extra2.txt` |
| 4 | Анимации 0.5 (было 1.0 / не задано) | — | — | три `settings put … 1.0` |
| 5 | Лаунчер CleanYourTV 2.5.0 (`com.gathin.tvhome`) вместо Google TV; `com.google.android.tvlauncher` отключён; заставка — часы лаунчера | `tvhome-2.5.0.apk` | — | `install-launcher.ps1 -Undo` |

Всего отключено 29 пакетов (28 + штатный лаунчер). Ничего не удалено.

## Команды отката

Вернуть штатный лаунчер (сначала это, если откатываешь всё):
```powershell
powershell -ExecutionPolicy Bypass -File .\install-launcher.ps1 -TvHost 192.168.0.6 -Undo
```

Вернуть анимации:
```powershell
$env:TV_HOST = '192.168.0.6'
@('settings put global window_animation_scale 1.0','settings put global transition_animation_scale 1.0','settings put global animator_duration_scale 1.0') | tools\venv\Scripts\python.exe -I tools\tv.py --batch
```

Вернуть пакеты (любой список по отдельности):
```powershell
powershell -ExecutionPolicy Bypass -File .\tools\restore.ps1 -TvHost 192.168.0.6 .\extra2.txt
powershell -ExecutionPolicy Bypass -File .\tools\restore.ps1 -TvHost 192.168.0.6 .\extra.txt
powershell -ExecutionPolicy Bypass -File .\tools\restore.ps1 -TvHost 192.168.0.6 .\examples\xiaomi-mitv-mooq0\debloat.txt
```

Полный откат «как было»: лаунчер → анимации → extra2 → extra → debloat → перезагрузка ТВ.

## Повторная установка лаунчера (новый ноут / после сброса)
```powershell
Invoke-WebRequest https://github.com/pharm1top-ops/cleanyourtv-apk-build/releases/download/v2.5.0/tvhome-2.5.0.apk -OutFile tvhome-2.5.0.apk
Invoke-WebRequest https://raw.githubusercontent.com/pharm1top-ops/cleanyourtv-apk-build/backup/backup/install-launcher.ps1 -OutFile install-launcher.ps1
powershell -ExecutionPolicy Bypass -File .\install-launcher.ps1 -TvHost 192.168.0.6
```

## Если ТВ не отвечает по ADB
На ТВ: Настройки → Параметры разработчика → «Отладка по сети» включена; IP — Настройки → Сеть.
Если папка `.cleanyourtv` потеряна — скопировать `backup/recovery-*.json` обратно в `C:\Users\Aru\.cleanyourtv\`.
Если ноут новый — Python 3.13, ZIP репо cleanyourtv, `py -m venv tools\venv`, `pip install -r tools\requirements.txt` (см. README cleanyourtv).

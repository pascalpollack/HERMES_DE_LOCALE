@echo off
setlocal enabledelayedexpansion
chcp 65001 >nul
title Hermes Desktop - Deutsch installieren

rem ---------------------------------------------------------------
rem  Hermes Desktop: deutsche Oberflaeche einspielen.
rem  Gebaut am 12.09.2026 fuer Hermes 0.17.2.
rem
rem  Spielt fertige Dateien ein. Auf dem Zielrechner werden WEDER
rem  Node NOCH ein Quellbaum gebraucht.
rem
rem  Warum volle Pfade nach %SystemRoot%: auf fremden Rechnern kann
rem  der PATH ein anderes find.exe vorne haben, Git Bash bringt
rem  eines mit. Am 12.09.2026 genau so schiefgegangen.
rem ---------------------------------------------------------------

set "SYS=%SystemRoot%\System32"
set "PAKET=%~dp0paket"
set "ZIEL=%LOCALAPPDATA%\hermes\hermes-agent\apps\desktop\release\win-unpacked"
set "SICHERUNG=%ZIEL%.vor-deutsch"

echo.
echo ===============================================================
echo   Hermes Desktop - deutsche Oberflaeche installieren
echo ===============================================================
echo.

if not exist "%PAKET%\Hermes.exe" (
  echo [FEHLER] Der Ordner "paket" fehlt oder ist unvollstaendig.
  echo          Erwartet wurde: %PAKET%\Hermes.exe
  echo.
  echo Bitte den kompletten entpackten Ordner verwenden, nicht nur
  echo diese Batchdatei.
  goto :ende_fehler
)

if not exist "%ZIEL%\Hermes.exe" (
  echo [FEHLER] Hermes wurde nicht gefunden unter:
  echo          %ZIEL%
  echo.
  echo Ist Hermes Desktop auf diesem Rechner installiert?
  goto :ende_fehler
)
echo Installation gefunden:
echo   %ZIEL%
echo.

if exist "%PAKET%\VERSION.txt" (
  set /p PAKETVERSION=<"%PAKET%\VERSION.txt"
  echo Dieses Paket wurde gebaut fuer Hermes-Version: !PAKETVERSION!
  echo.
  echo   HINWEIS: Passt die Version nicht zur installierten, kann die
  echo   App danach nicht mehr starten. Zum Zuruecknehmen gibt es
  echo   Deutsch_zuruecknehmen.bat
  echo.
)

"%SYS%\tasklist.exe" /FI "IMAGENAME eq Hermes.exe" 2>nul | "%SYS%\find.exe" /I "Hermes.exe" >nul
if not errorlevel 1 (
  echo [ACHTUNG] Hermes laeuft gerade und muss beendet werden.
  echo.
  "%SYS%\choice.exe" /C JN /M "Jetzt beenden und fortfahren"
  if errorlevel 2 goto :abbruch
  echo Beende Hermes...
  "%SYS%\taskkill.exe" /IM Hermes.exe /F >nul 2>&1
  "%SYS%\timeout.exe" /t 3 /nobreak >nul
  "%SYS%\tasklist.exe" /FI "IMAGENAME eq Hermes.exe" 2>nul | "%SYS%\find.exe" /I "Hermes.exe" >nul
  if not errorlevel 1 (
    echo [FEHLER] Hermes laesst sich nicht beenden. Bitte von Hand
    echo          schliessen und den Batch erneut starten.
    goto :ende_fehler
  )
  echo Hermes beendet.
  echo.
)

if exist "%SICHERUNG%\Hermes.exe" (
  echo Eine Sicherung liegt bereits vor, sie bleibt unveraendert:
  echo   %SICHERUNG%
  echo   ^(so bleibt der urspruengliche englische Stand erhalten,
  echo    auch wenn dieser Batch mehrfach laeuft^)
  echo.
  goto :einspielen
)

echo Lege Sicherung an. Das dauert einen Moment, rund 400 MB...
"%SYS%\robocopy.exe" "%ZIEL%" "%SICHERUNG%" /MIR /NFL /NDL /NJH /NJS /NP /R:1 /W:1 >nul
call :pruefe_robocopy
if "%FEHLER%"=="1" (
  echo [FEHLER] Die Sicherung ist fehlgeschlagen. Es wurde nichts
  echo          veraendert.
  goto :ende_fehler
)
echo Sicherung angelegt:
echo   %SICHERUNG%
echo.

:einspielen
echo Spiele deutsche Fassung ein...
"%SYS%\robocopy.exe" "%PAKET%\resources" "%ZIEL%\resources" /MIR /NFL /NDL /NJH /NJS /NP /R:2 /W:2 >nul
call :pruefe_robocopy
if "%FEHLER%"=="1" (
  echo [FEHLER] Das Einspielen der Programmdateien ist fehlgeschlagen.
  goto :ruecknahme_anbieten
)

rem  Hermes.exe traegt die Pruefsumme des Programmpakets in sich.
rem  Sie muss mitgetauscht werden: nur app.asar zu ersetzen laesst
rem  die App an ihrer eigenen Integritaetspruefung scheitern.
copy /Y "%PAKET%\Hermes.exe" "%ZIEL%\Hermes.exe" >nul
if errorlevel 1 (
  echo [FEHLER] Hermes.exe konnte nicht ersetzt werden.
  goto :ruecknahme_anbieten
)

echo.
echo ===============================================================
echo   Fertig. Die deutsche Oberflaeche ist eingespielt.
echo ===============================================================
echo.
echo   Beim naechsten Start steht unter Einstellungen - Sprache
echo   "Deutsch" zur Auswahl.
echo.
echo   Rueckgaengig machen:  Deutsch_zuruecknehmen.bat
echo.
echo   Ein Hermes-Update ueberschreibt die deutsche Fassung. Danach
echo   diesen Batch einfach erneut starten.
echo.
"%SYS%\choice.exe" /C JN /M "Hermes jetzt starten"
if errorlevel 2 goto :ende_ok
start "" "%ZIEL%\Hermes.exe"
goto :ende_ok

rem --- robocopy meldet 0 bis 7 als Erfolg, erst ab 8 ist es ein
rem     Fehler. In einem Klammerblock waere %ERRORLEVEL% schon zur
rem     Parsezeit ersetzt, deshalb steht die Pruefung in einem
rem     eigenen Unterprogramm.
:pruefe_robocopy
set "FEHLER=0"
if %ERRORLEVEL% GEQ 8 set "FEHLER=1"
exit /b 0

:ruecknahme_anbieten
echo.
echo Der Vorgang wurde abgebrochen. Der vorherige Stand liegt in:
echo   %SICHERUNG%
echo Zum Wiederherstellen: Deutsch_zuruecknehmen.bat
goto :ende_fehler

:abbruch
echo.
echo Abgebrochen. Es wurde nichts veraendert.
goto :ende_ok

:ende_ok
echo.
pause
exit /b 0

:ende_fehler
echo.
pause
exit /b 1

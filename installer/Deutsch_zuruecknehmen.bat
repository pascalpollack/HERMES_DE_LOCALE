@echo off
setlocal
chcp 65001 >nul
title Hermes Desktop - Deutsch zuruecknehmen

rem ---------------------------------------------------------------
rem  Stellt den Stand wieder her, der vor Deutsch_installieren.bat
rem  galt. Braucht den Ordner ...win-unpacked.vor-deutsch
rem ---------------------------------------------------------------

set "SYS=%SystemRoot%\System32"
set "ZIEL=%LOCALAPPDATA%\hermes\hermes-agent\apps\desktop\release\win-unpacked"
set "SICHERUNG=%ZIEL%.vor-deutsch"

echo.
echo ===============================================================
echo   Hermes Desktop - deutsche Oberflaeche zuruecknehmen
echo ===============================================================
echo.

if not exist "%SICHERUNG%\Hermes.exe" (
  echo [FEHLER] Keine Sicherung gefunden unter:
  echo          %SICHERUNG%
  echo.
  echo Ohne Sicherung kann dieser Batch nichts wiederherstellen.
  echo Hermes laesst sich in dem Fall neu installieren.
  goto :ende_fehler
)

echo Sicherung gefunden:
echo   %SICHERUNG%
echo.
echo Der jetzige Stand wird damit ueberschrieben. Die deutsche
echo Fassung ist danach weg.
echo.
"%SYS%\choice.exe" /C JN /M "Wirklich zuruecknehmen"
if errorlevel 2 goto :abbruch

"%SYS%\tasklist.exe" /FI "IMAGENAME eq Hermes.exe" 2>nul | "%SYS%\find.exe" /I "Hermes.exe" >nul
if not errorlevel 1 (
  echo Beende Hermes...
  "%SYS%\taskkill.exe" /IM Hermes.exe /F >nul 2>&1
  "%SYS%\timeout.exe" /t 3 /nobreak >nul
  "%SYS%\tasklist.exe" /FI "IMAGENAME eq Hermes.exe" 2>nul | "%SYS%\find.exe" /I "Hermes.exe" >nul
  if not errorlevel 1 (
    echo [FEHLER] Hermes laesst sich nicht beenden. Bitte von Hand
    echo          schliessen und erneut starten.
    goto :ende_fehler
  )
)

echo Stelle den vorherigen Stand wieder her...
"%SYS%\robocopy.exe" "%SICHERUNG%" "%ZIEL%" /MIR /NFL /NDL /NJH /NJS /NP /R:2 /W:2 >nul
call :pruefe_robocopy
if "%FEHLER%"=="1" (
  echo [FEHLER] Das Wiederherstellen ist fehlgeschlagen.
  echo          Die Sicherung ist noch da und unveraendert:
  echo          %SICHERUNG%
  goto :ende_fehler
)

echo.
echo ===============================================================
echo   Fertig. Der vorherige Stand ist wiederhergestellt.
echo ===============================================================
echo.
echo   Die Sicherung bleibt liegen. Wer Platz braucht, kann sie
echo   von Hand loeschen:
echo   %SICHERUNG%
echo.
"%SYS%\choice.exe" /C JN /M "Hermes jetzt starten"
if errorlevel 2 goto :ende_ok
start "" "%ZIEL%\Hermes.exe"
goto :ende_ok

rem --- robocopy meldet 0 bis 7 als Erfolg, erst ab 8 ist es ein
rem     Fehler. Eigenes Unterprogramm, weil %ERRORLEVEL% in einem
rem     Klammerblock schon zur Parsezeit ersetzt wuerde.
:pruefe_robocopy
set "FEHLER=0"
if %ERRORLEVEL% GEQ 8 set "FEHLER=1"
exit /b 0

:abbruch
echo.
echo Abgebrochen. Es wurde nichts veraendert.

:ende_ok
echo.
pause
exit /b 0

:ende_fehler
echo.
pause
exit /b 1

@echo off
chcp 65001 >nul
title Hermes Desktop - Deutsch nachziehen

rem ---------------------------------------------------------------
rem  Einstieg fuer die Aufgabenplanung und fuer den Start von Hand.
rem
rem  Laeuft bei der Anmeldung, nicht im Stundentakt: ein Build muss
rem  Hermes beenden. Bei der Anmeldung kostet das nichts, mitten in
rem  der Arbeit waere es ein Uebergriff.
rem
rem  Voller Pfad zu Python: die PATH-Reihenfolge ist auf diesem
rem  Rechner nicht verlaesslich, und nur C:\Python314 hat die Pakete.
rem ---------------------------------------------------------------

set "PY=C:\Python314\python.exe"
set "SKRIPT=%~dp0deutsch_nachziehen.py"

if not exist "%PY%" (
  echo [FEHLER] Python nicht gefunden: %PY%
  pause
  exit /b 1
)

rem  --still gehoert dem Batch, nicht dem Skript: es darf nicht
rem  durchgereicht werden, argparse kennt es nicht.
set "STILL="
if "%1"=="--still" (
  set "STILL=1"
  shift
)

"%PY%" "%SKRIPT%" %1 %2 %3
set "CODE=%ERRORLEVEL%"

rem  Ohne Fenster (Aufgabenplanung) nicht auf eine Taste warten.
if defined STILL exit /b %CODE%
echo.
pause
exit /b %CODE%

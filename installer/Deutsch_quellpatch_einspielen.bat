@echo off
setlocal
rem Quellpatch. Kopiert kein Hermes.exe, kein resources und kein paket.
rem Braucht Git for Windows und einen Checkout von Hermes Desktop 0.17.6.

if "%~1"=="" (
  echo Aufruf: Deutsch_quellpatch_einspielen.bat PFAD\zum\hermes-agent
  exit /b 2
)

set "BASH="
if exist "%ProgramFiles%\Git\bin\bash.exe" set "BASH=%ProgramFiles%\Git\bin\bash.exe"
if not defined BASH if exist "%ProgramFiles(x86)%\Git\bin\bash.exe" set "BASH=%ProgramFiles(x86)%\Git\bin\bash.exe"
if not defined BASH (
  echo Git Bash wurde nicht gefunden.
  echo In einer offenen Git Bash denselben Patch so einspielen:
  echo   bash installer/Deutsch_installieren.sh PFAD/zum/hermes-agent
  exit /b 2
)

"%BASH%" "%~dp0Deutsch_installieren.sh" "%~1"
exit /b %ERRORLEVEL%

@echo off
setlocal
rem Nimmt nur den Quellpatch zurück. Stellt keine Programmdateien her
rem und löscht kein Profil.

if "%~1"=="" (
  echo Aufruf: Deutsch_quellpatch_zuruecknehmen.bat PFAD\zum\hermes-agent
  exit /b 2
)

set "BASH="
if exist "%ProgramFiles%\Git\bin\bash.exe" set "BASH=%ProgramFiles%\Git\bin\bash.exe"
if not defined BASH if exist "%ProgramFiles(x86)%\Git\bin\bash.exe" set "BASH=%ProgramFiles(x86)%\Git\bin\bash.exe"
if not defined BASH (
  echo Git Bash wurde nicht gefunden.
  echo In einer offenen Git Bash:
  echo   bash installer/Deutsch_zuruecknehmen.sh PFAD/zum/hermes-agent
  exit /b 2
)

"%BASH%" "%~dp0Deutsch_zuruecknehmen.sh" "%~1"
exit /b %ERRORLEVEL%

@echo off
rem cmd shim: runs claude-statusline.sh under Git for Windows bash (per-user install first, then machine-wide).
set "GITBASH=%LOCALAPPDATA%\Programs\Git\bin\bash.exe"
if not exist "%GITBASH%" set "GITBASH=%ProgramFiles%\Git\bin\bash.exe"
if not exist "%GITBASH%" ( echo Git for Windows bash.exe not found 1>&2 & exit /b 1 )
"%GITBASH%" "%~dp0..\claude-statusline.sh" %*

@echo off
setlocal
set "RIVERBANK_GODOT=%USERPROFILE%\Godot\4.7.2\Godot_v4.7.2-stable_win64.exe"
if not exist "%RIVERBANK_GODOT%" (
  echo Godot 4.7.2 was not found in %USERPROFILE%\Godot\4.7.2
  echo Open scenes/tools/riverbank_playtest.tscn in Godot and press F6.
  pause
  exit /b 1
)
if not exist "%~dp0ztest\profile\riverbank" mkdir "%~dp0ztest\profile\riverbank"
set "APPDATA=%~dp0ztest\profile\riverbank"
start "" "%RIVERBANK_GODOT%" --path "%~dp0." res://scenes/tools/riverbank_playtest.tscn
endlocal

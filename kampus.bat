@echo off
rem Sorf - kampus modunu Godot 4.7.2 ile baslatir
set GODOT=C:\tools\godot\Godot_v4.7.2-stable_win64.exe
if not exist "%GODOT%" (
  echo Godot bulunamadi: %GODOT%
  echo https://github.com/godotengine/godot/releases/tag/4.7.2-stable adresinden indirip C:\tools\godot icine acin.
  pause
  exit /b 1
)
rem .godot onbellegi git disidir; yoksa once uretilir.
if not exist "%~dp0.godot\global_script_class_cache.cfg" (
  echo Ilk acilis: onbellek uretiliyor...
  "%GODOT%" --headless --path "%~dp0." --import
)
"%GODOT%" --path "%~dp0." --resolution 1600x900 -- --kampus

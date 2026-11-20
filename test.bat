@echo off
rem Sorf - bot testi: rampada kayip hizlanmali. Cikis kodu 0 = gecti.
set GODOT=C:\tools\godot\Godot_v4.7.2-stable_win64_console.exe
if not exist "%~dp0.godot\global_script_class_cache.cfg" (
  "%GODOT%" --headless --path "%~dp0." --import
)
"%GODOT%" --path "%~dp0." --resolution 1280x720 -- --test
exit /b %ERRORLEVEL%

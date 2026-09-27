@echo off
rem ======================================================================
rem  Build lua5.1.dll, lua51.dll (proxy), lua.exe, luac.exe and the demos
rem  (demo_dll.exe uses lua5.1.dll, demo_static.exe has Lua built in) with Delphi
rem  (tested target: Delphi 10.2 Tokyo, dcc32 / dcc64).
rem
rem  Run from the "RAD Studio Command Prompt", or call rsvars.bat first:
rem    call "C:\Program Files (x86)\Embarcadero\Studio\19.0\bin\rsvars.bat"
rem
rem  usage:  build.bat            build Win32 and Win64
rem          build.bat win32      build one platform
rem          build.bat win64 ucrt UCRT-style number formatting (see README)
rem  Output: build\delphi\win32\*  and  build\delphi\win64\*
rem ======================================================================
setlocal
set PLATS=%1
if "%PLATS%"=="" set PLATS=win32 win64
set EXTRA=
if /i "%2"=="ucrt" set EXTRA=-DLUA_UCRT

for %%P in (%PLATS%) do (
  call :build %%P
  if errorlevel 1 exit /b 1
)
echo.
echo Build OK.
exit /b 0

:build
if /i "%1"=="win32" (set DCC=dcc32) else (set DCC=dcc64)
set OUT=build\delphi\%1
if not exist %OUT%\dcu mkdir %OUT%\dcu
where %DCC% >nul 2>&1
if errorlevel 1 (
  echo %DCC% not found - run from the RAD Studio Command Prompt or call rsvars.bat
  exit /b 1
)
set COMMON=-B -Q -$O+ -$D- -$L- -$Y- -NU%OUT%\dcu -NSSystem;Winapi %EXTRA%
set FLAGS=%COMMON% -E%OUT%
set HFLAGS=%COMMON% -E%OUT%\hybrid
echo === %1: lua5.1.dll
%DCC% %FLAGS% lua5.dpr
if errorlevel 1 exit /b 1
rem  {$LIBSUFFIX '.1'} in lua5.dpr makes the output lua5.1.dll; fall back
rem  to a rename in case the compiler ignored it.
if exist %OUT%\lua5.dll (
  if exist %OUT%\lua5.1.dll del %OUT%\lua5.1.dll
  ren %OUT%\lua5.dll lua5.1.dll
)
echo === %1: lua51.dll (proxy)
%DCC% %FLAGS% lua51.dpr
if errorlevel 1 exit /b 1
echo === %1: lua.exe
%DCC% %FLAGS% lua.dpr
if errorlevel 1 exit /b 1
echo === %1: luac.exe
%DCC% %FLAGS% luac.dpr
if errorlevel 1 exit /b 1
echo === %1: demo_dll.exe / demo_static.exe
%DCC% %FLAGS% -Usrc -Isrc demo\demo_dll.dpr
if errorlevel 1 exit /b 1
rem  demo_static: project-wide define LUA_STATIC and its own dcu folder, so
rem  the shared unit demo\DemoApp.pas is compiled separately for each demo
if not exist %OUT%\dcu_static mkdir %OUT%\dcu_static
%DCC% %FLAGS% -DLUA_STATIC -NU%OUT%\dcu_static -Usrc -Isrc demo\demo_static.dpr
if errorlevel 1 exit /b 1
rem  hybrid: Lua linked into demo_hybrid.exe + shim lua5.1.dll for C modules,
rem  in its own folder so the shim does not replace the real lua5.1.dll
echo === %1: hybrid\lua5.1.dll (shim) / hybrid\demo_hybrid.exe
if not exist %OUT%\hybrid mkdir %OUT%\hybrid
%DCC% %HFLAGS% -Isrc hybrid\lua5.dpr
if errorlevel 1 exit /b 1
if exist %OUT%\hybrid\lua5.dll (
  if exist %OUT%\hybrid\lua5.1.dll del %OUT%\hybrid\lua5.1.dll
  ren %OUT%\hybrid\lua5.dll lua5.1.dll
)
%DCC% %HFLAGS% -Usrc -Isrc demo\demo_hybrid.dpr
if errorlevel 1 exit /b 1
copy /y %OUT%\lua51.dll %OUT%\hybrid\ >nul
copy /y demo\prebuilt\%1\hello.dll %OUT%\hybrid\ >nul
exit /b 0

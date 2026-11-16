@echo off
setlocal enabledelayedexpansion

echo ============================================================
echo   Universal Installer - Build Script
echo ============================================================

set "ROOT_DIR=%~dp0"
set "CONFIG=Release"
set "NO_PAUSE=0"
set "PUBLISH=1"

for %%A in (%*) do (
    if /I "%%~A"=="/nopause" set "NO_PAUSE=1"
    if /I "%%~A"=="--nopause" set "NO_PAUSE=1"
    if /I "%%~A"=="--no-publish" set "PUBLISH=0"
    if /I "%%~A"=="debug" set "CONFIG=Debug"
    if /I "%%~A"=="release" set "CONFIG=Release"
)

:: Check dotnet CLI
where dotnet >nul 2>nul
if %ERRORLEVEL% neq 0 (
    echo [ERROR] dotnet CLI not found! Please install .NET SDK.
    if !NO_PAUSE! equ 0 pause
    exit /b 1
)

echo.
echo [1/2] Compiling Installer project [%CONFIG%]...
dotnet build "%ROOT_DIR%Installer\Installer.csproj" -c %CONFIG%
if %ERRORLEVEL% neq 0 (
    echo [ERROR] Installer compilation failed!
    if !NO_PAUSE! equ 0 pause
    exit /b %ERRORLEVEL%
)

if !PUBLISH! equ 1 (
    echo.
    echo [2/2] Publishing standalone single-file Installer.exe [%CONFIG%]...
    dotnet publish "%ROOT_DIR%Installer\Installer.csproj" -c %CONFIG%
    if !ERRORLEVEL! neq 0 (
        echo [ERROR] Installer publish failed!
        if !NO_PAUSE! equ 0 pause
        exit /b !ERRORLEVEL!
    )

    set "EXE_PATH=%ROOT_DIR%Installer\bin\%CONFIG%\net9.0\win-x64\publish\Installer.exe"
    if exist "!EXE_PATH!" (
        echo.
        echo [SUCCESS] Standalone executable published:
        echo   !EXE_PATH!
        copy /Y "!EXE_PATH!" "%ROOT_DIR%Installer.exe" >nul
        echo   Copied to project root: %ROOT_DIR%Installer.exe
    )
)

echo.
echo ============================================================
echo   Installer build completed successfully!
echo ============================================================
if !NO_PAUSE! equ 0 pause
exit /b 0

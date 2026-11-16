@echo off
setlocal enabledelayedexpansion

echo ============================================================
echo   BepInExPlugin - Build Script
echo ============================================================

set "ROOT_DIR=%~dp0"
set "CONFIG=Release"
set "EFT_PATH=J:\SteamLibrary\steamapps\common\Escape from Tarkov"
set "NO_PAUSE=0"

for %%A in (%*) do (
    if /I "%%~A"=="/nopause" set "NO_PAUSE=1"
    if /I "%%~A"=="--nopause" set "NO_PAUSE=1"
    if /I "%%~A"=="debug" set "CONFIG=Debug"
    if /I "%%~A"=="release" set "CONFIG=Release"
    if /I not "%%~A"=="/nopause" if /I not "%%~A"=="--nopause" if /I not "%%~A"=="debug" if /I not "%%~A"=="release" (
        if not "%%~A"=="" set "EFT_PATH=%%~A"
    )
)

:: Check dotnet CLI
where dotnet >nul 2>nul
if %ERRORLEVEL% neq 0 (
    echo [ERROR] dotnet CLI not found! Please install .NET SDK.
    if !NO_PAUSE! equ 0 pause
    exit /b 1
)

echo.
echo [1/2] Building BepInExPlugin and NLog.EFT.Trainer (%CONFIG%)...
dotnet build "%ROOT_DIR%BepInExPlugin\BepInExPlugin.csproj" -c %CONFIG%
if %ERRORLEVEL% neq 0 (
    echo [ERROR] Build failed!
    if !NO_PAUSE! equ 0 pause
    exit /b %ERRORLEVEL%
)

echo.
echo [2/2] Deploying BepInEx plugin to EFT: "%EFT_PATH%"...
if not exist "%EFT_PATH%" (
    echo [WARNING] EFT path "%EFT_PATH%" not found. Skipping game deployment.
) else (
    if not exist "%EFT_PATH%\BepInEx\plugins" mkdir "%EFT_PATH%\BepInEx\plugins"
    if not exist "%EFT_PATH%\EscapeFromTarkov_Data\Managed" mkdir "%EFT_PATH%\EscapeFromTarkov_Data\Managed"

    echo Copying spt-efttrainer.dll to BepInEx\plugins...
    copy /Y "%ROOT_DIR%BepInExPlugin\bin\%CONFIG%\spt-efttrainer.dll" "%EFT_PATH%\BepInEx\plugins\" >nul

    echo Copying NLog.EFT.Trainer.dll to BepInEx\plugins and Managed...
    copy /Y "%ROOT_DIR%bin\%CONFIG%\NLog.EFT.Trainer.dll" "%EFT_PATH%\BepInEx\plugins\" >nul
    copy /Y "%ROOT_DIR%bin\%CONFIG%\NLog.EFT.Trainer.dll" "%EFT_PATH%\EscapeFromTarkov_Data\Managed\" >nul

    if exist "%ROOT_DIR%Files\outline" (
        echo Copying outline shader to EscapeFromTarkov_Data\outline...
        copy /Y "%ROOT_DIR%Files\outline" "%EFT_PATH%\EscapeFromTarkov_Data\outline" >nul
    )

    echo [SUCCESS] BepInExPlugin files successfully deployed to EFT!
)

echo.
echo ============================================================
echo   BepInExPlugin build completed successfully!
echo ============================================================
if !NO_PAUSE! equ 0 pause
exit /b 0


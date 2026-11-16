@echo off
setlocal enabledelayedexpansion

echo ============================================================
echo   EscapeFromTarkov-Trainer - Build Script
echo ============================================================

set "CONFIG=Release"
set "EFT_PATH=J:\SteamLibrary\steamapps\common\Escape from Tarkov"
set "NO_PAUSE=0"

for %%A in (%*) do (
    if /I "%%~A"=="/nopause" set "NO_PAUSE=1"
    if /I "%%~A"=="--nopause" set "NO_PAUSE=1"
    if /I not "%%~A"=="/nopause" if /I not "%%~A"=="--nopause" (
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
echo [1/3] Building NLog.EFT.Trainer and BepInExPlugin (%CONFIG%)...
dotnet build BepInExPlugin/BepInExPlugin.csproj -c %CONFIG%
if %ERRORLEVEL% neq 0 (
    echo [ERROR] BepInExPlugin build failed!
    if !NO_PAUSE! equ 0 pause
    exit /b %ERRORLEVEL%
)

echo.
echo [2/3] Building Universal Installer (%CONFIG%)...
dotnet build Installer/Installer.csproj -c %CONFIG%
if %ERRORLEVEL% neq 0 (
    echo [ERROR] Installer build failed!
    if !NO_PAUSE! equ 0 pause
    exit /b %ERRORLEVEL%
)

echo.
echo [3/3] Deploying to EFT installation: "%EFT_PATH%"...
if not exist "%EFT_PATH%" (
    echo [WARNING] EFT path not found at "%EFT_PATH%". Skipping game deployment.
) else (
    :: Ensure target directories exist
    if not exist "%EFT_PATH%\BepInEx\plugins" mkdir "%EFT_PATH%\BepInEx\plugins"
    if not exist "%EFT_PATH%\EscapeFromTarkov_Data\Managed" mkdir "%EFT_PATH%\EscapeFromTarkov_Data\Managed"

    :: Copy plugin and trainer DLLs
    echo Copying spt-efttrainer.dll to BepInEx\plugins...
    copy /Y "BepInExPlugin\bin\%CONFIG%\spt-efttrainer.dll" "%EFT_PATH%\BepInEx\plugins\" >nul

    echo Copying NLog.EFT.Trainer.dll to BepInEx\plugins and Managed...
    copy /Y "bin\%CONFIG%\NLog.EFT.Trainer.dll" "%EFT_PATH%\BepInEx\plugins\" >nul
    copy /Y "bin\%CONFIG%\NLog.EFT.Trainer.dll" "%EFT_PATH%\EscapeFromTarkov_Data\Managed\" >nul

    :: Copy outline shader asset
    if exist "Files\outline" (
        echo Copying outline shader to EscapeFromTarkov_Data\outline...
        copy /Y "Files\outline" "%EFT_PATH%\EscapeFromTarkov_Data\outline" >nul
    )

    echo [SUCCESS] Files successfully deployed to EFT!
)

echo.
echo ============================================================
echo   Build completed successfully!
echo ============================================================
if !NO_PAUSE! equ 0 pause
exit /b 0

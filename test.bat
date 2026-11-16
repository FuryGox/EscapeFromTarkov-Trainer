@echo off
setlocal enabledelayedexpansion

echo ============================================================
echo   EscapeFromTarkov-Trainer - Test Script
echo ============================================================

set "CONFIG=Release"
set "EFT_PATH=J:\SteamLibrary\steamapps\common\Escape from Tarkov"
set "NO_PAUSE=0"
set "TESTS_PASSED=0"
set "TESTS_FAILED=0"

for %%A in (%*) do (
    if /I "%%~A"=="/nopause" set "NO_PAUSE=1"
    if /I "%%~A"=="--nopause" set "NO_PAUSE=1"
    if /I not "%%~A"=="/nopause" if /I not "%%~A"=="--nopause" (
        if not "%%~A"=="" set "EFT_PATH=%%~A"
    )
)

:: 1. Check dotnet CLI
echo.
echo [TEST 1] Checking .NET SDK environment...
dotnet --version >nul 2>nul
if %ERRORLEVEL% equ 0 (
    for /f "tokens=*" %%v in ('dotnet --version') do echo [PASS] .NET SDK installed: %%v
    set /a TESTS_PASSED+=1
) else (
    echo [FAIL] .NET SDK not found!
    set /a TESTS_FAILED+=1
)

:: 2. Test Build BepInExPlugin & Trainer
echo.
echo [TEST 2] Testing build of NLog.EFT.Trainer and BepInExPlugin...
dotnet build BepInExPlugin/BepInExPlugin.csproj -c %CONFIG% --nologo -v q
if %ERRORLEVEL% equ 0 (
    echo [PASS] BepInExPlugin compiled successfully.
    set /a TESTS_PASSED+=1
) else (
    echo [FAIL] BepInExPlugin compilation failed!
    set /a TESTS_FAILED+=1
)

:: 3. Test Build Installer
echo.
echo [TEST 3] Testing build of Universal Installer...
dotnet build Installer/Installer.csproj -c %CONFIG% --nologo -v q
if %ERRORLEVEL% equ 0 (
    echo [PASS] Universal Installer compiled successfully.
    set /a TESTS_PASSED+=1
) else (
    echo [FAIL] Universal Installer compilation failed!
    set /a TESTS_FAILED+=1
)

:: 4. Verify Built Artifacts
echo.
echo [TEST 4] Verifying generated build artifacts...
set "MISSING_ARTIFACTS=0"

if exist "bin\%CONFIG%\NLog.EFT.Trainer.dll" (
    echo [PASS] Found bin\%CONFIG%\NLog.EFT.Trainer.dll
) else (
    echo [FAIL] Missing bin\%CONFIG%\NLog.EFT.Trainer.dll
    set "MISSING_ARTIFACTS=1"
)

if exist "BepInExPlugin\bin\%CONFIG%\spt-efttrainer.dll" (
    echo [PASS] Found BepInExPlugin\bin\%CONFIG%\spt-efttrainer.dll
) else (
    echo [FAIL] Missing BepInExPlugin\bin\%CONFIG%\spt-efttrainer.dll
    set "MISSING_ARTIFACTS=1"
)

if exist "Installer\bin\%CONFIG%\net9.0\win-x64\Installer.dll" (
    echo [PASS] Found Installer\bin\%CONFIG%\net9.0\win-x64\Installer.dll
) else (
    echo [FAIL] Missing Installer\bin\%CONFIG%\net9.0\win-x64\Installer.dll
    set "MISSING_ARTIFACTS=1"
)

if !MISSING_ARTIFACTS! equ 0 (
    set /a TESTS_PASSED+=1
) else (
    set /a TESTS_FAILED+=1
)

:: 5. Test Installer CLI execution
echo.
echo [TEST 5] Testing Installer CLI health (--help)...
dotnet "Installer\bin\%CONFIG%\net9.0\win-x64\Installer.dll" --help >nul 2>nul
if %ERRORLEVEL% equ 0 (
    echo [PASS] Installer CLI executed cleanly with exit code 0.
    set /a TESTS_PASSED+=1
) else (
    echo [FAIL] Installer CLI returned error code %ERRORLEVEL%!
    set /a TESTS_FAILED+=1
)

:: 6. Verify Game Deployment
echo.
echo [TEST 6] Checking EFT installation deployment...
if exist "%EFT_PATH%" (
    echo [INFO] EFT installation detected at "%EFT_PATH%".
    set "DEPLOY_OK=1"
    
    if exist "%EFT_PATH%\BepInEx\plugins\spt-efttrainer.dll" (
        echo [PASS] spt-efttrainer.dll is present in BepInEx\plugins
    ) else (
        echo [WARN] spt-efttrainer.dll not in BepInEx\plugins
        set "DEPLOY_OK=0"
    )

    if exist "%EFT_PATH%\EscapeFromTarkov_Data\Managed\NLog.EFT.Trainer.dll" (
        echo [PASS] NLog.EFT.Trainer.dll is present in Managed folder
    ) else (
        echo [WARN] NLog.EFT.Trainer.dll not in Managed folder
        set "DEPLOY_OK=0"
    )

    if exist "%EFT_PATH%\EscapeFromTarkov_Data\outline" (
        echo [PASS] outline shader is present in EscapeFromTarkov_Data
    ) else (
        echo [WARN] outline shader not in EscapeFromTarkov_Data
        set "DEPLOY_OK=0"
    )

    if !DEPLOY_OK! equ 1 (
        echo [PASS] Game deployment verified.
        set /a TESTS_PASSED+=1
    ) else (
        echo [WARN] Game deployment incomplete. Run build.bat to deploy.
        set /a TESTS_FAILED+=1
    )
) else (
    echo [SKIP] EFT installation path not found at "%EFT_PATH%".
)

:: Summary
echo.
echo ============================================================
echo   Test Summary: %TESTS_PASSED% Passed, %TESTS_FAILED% Failed
echo ============================================================
if %TESTS_FAILED% equ 0 (
    echo [ALL TESTS PASSED]
) else (
    echo [SOME TESTS FAILED]
)

if !NO_PAUSE! equ 0 pause
exit /b %TESTS_FAILED%

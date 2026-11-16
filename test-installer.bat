@echo off
setlocal enabledelayedexpansion

echo ============================================================
echo   Universal Installer - Test Script
echo ============================================================

set "ROOT_DIR=%~dp0"
set "CONFIG=Release"
set "NO_PAUSE=0"
set "TESTS_PASSED=0"
set "TESTS_FAILED=0"

for %%A in (%*) do (
    if /I "%%~A"=="/nopause" set "NO_PAUSE=1"
    if /I "%%~A"=="--nopause" set "NO_PAUSE=1"
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

:: 2. Test Build Installer
echo.
echo [TEST 2] Testing compilation of Installer.csproj...
dotnet build "%ROOT_DIR%Installer\Installer.csproj" -c %CONFIG% --nologo -v q
if %ERRORLEVEL% equ 0 (
    echo [PASS] Installer compiled successfully.
    set /a TESTS_PASSED+=1
) else (
    echo [FAIL] Installer compilation failed!
    set /a TESTS_FAILED+=1
)

:: 3. Verify Built Artifacts
echo.
echo [TEST 3] Verifying generated Installer binaries...
set "DLL_PATH=%ROOT_DIR%Installer\bin\%CONFIG%\net9.0\win-x64\Installer.dll"
set "EXE_PATH=%ROOT_DIR%Installer\bin\%CONFIG%\net9.0\win-x64\publish\Installer.exe"
set "MISSING=0"

if exist "%DLL_PATH%" (
    echo [PASS] Found %DLL_PATH%
) else (
    echo [FAIL] Missing %DLL_PATH%
    set "MISSING=1"
)

if exist "%EXE_PATH%" (
    echo [PASS] Found standalone %EXE_PATH%
) else (
    echo [WARN] Standalone Installer.exe not found. (Run build-installer.bat to publish)
)

if !MISSING! equ 0 (
    set /a TESTS_PASSED+=1
) else (
    set /a TESTS_FAILED+=1
)

:: 4. Test Installer CLI execution (--help)
echo.
echo [TEST 4] Testing Installer CLI health (--help)...
if exist "%EXE_PATH%" (
    "%EXE_PATH%" --help >nul 2>nul
    if !ERRORLEVEL! equ 0 (
        echo [PASS] Standalone Installer.exe executed cleanly with exit code 0.
        set /a TESTS_PASSED+=1
    ) else (
        echo [FAIL] Installer.exe returned error code !ERRORLEVEL!!
        set /a TESTS_FAILED+=1
    )
) else (
    dotnet "%DLL_PATH%" --help >nul 2>nul
    if !ERRORLEVEL! equ 0 (
        echo [PASS] dotnet Installer.dll executed cleanly with exit code 0.
        set /a TESTS_PASSED+=1
    ) else (
        echo [FAIL] dotnet Installer.dll returned error code !ERRORLEVEL!!
        set /a TESTS_FAILED+=1
    )
)

:: 5. Test CLI command options
echo.
echo [TEST 5] Testing Installer CLI commands validation...
set "HELP_OUTPUT="
for /f "tokens=*" %%O in ('dotnet "%DLL_PATH%" --help') do (
    echo %%O | findstr /I "install uninstall" >nul
    if !ERRORLEVEL! equ 0 set "CMD_OK=1"
)

if "!CMD_OK!"=="1" (
    echo [PASS] Found expected commands [install, uninstall] in Installer help output.
    set /a TESTS_PASSED+=1
) else (
    echo [FAIL] Installer help output missing expected commands!
    set /a TESTS_FAILED+=1
)

:: Summary
echo.
echo ============================================================
echo   Installer Test Summary: %TESTS_PASSED% Passed, %TESTS_FAILED% Failed
echo ============================================================
if %TESTS_FAILED% equ 0 (
    echo [ALL TESTS PASSED]
) else (
    echo [SOME TESTS FAILED]
)

if !NO_PAUSE! equ 0 pause
exit /b %TESTS_FAILED%


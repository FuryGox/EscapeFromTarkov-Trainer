@echo off
setlocal

echo ============================================================
echo   Running Build and Test Pipeline
echo ============================================================

call "%~dp0build.bat" %*
if %ERRORLEVEL% neq 0 (
    echo [ERROR] Build step failed with exit code %ERRORLEVEL%
    exit /b %ERRORLEVEL%
)

call "%~dp0test.bat" %*
if %ERRORLEVEL% neq 0 (
    echo [ERROR] Test step failed with exit code %ERRORLEVEL%
    exit /b %ERRORLEVEL%
)

exit /b 0


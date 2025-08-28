@echo off
setlocal enabledelayedexpansion

echo ===================================================
echo Building Windows Installer for ShiPlus Flutter App
echo ===================================================

:: Check if Flutter is installed
where flutter >nul 2>&1
if %ERRORLEVEL% neq 0 (
    echo Flutter not found. Please install Flutter and add it to your PATH.
    exit /b 1
)

:: Set variables
set "APP_NAME=ShiPlus"
set "OUTPUT_DIR=build\windows\installer"
set "BUILD_DIR=build\windows\runner\Release"

:: Create output directory if it doesn't exist
if not exist "%OUTPUT_DIR%" mkdir "%OUTPUT_DIR%"

:: Build the Flutter Windows app in release mode
echo Building Flutter Windows application...
flutter build windows --release
if %ERRORLEVEL% neq 0 (
    echo Flutter build failed.
    exit /b 1
)

:: Copy necessary binary files to the build directory
echo Copying binary files...
if not exist "%BUILD_DIR%\assets\bin" mkdir "%BUILD_DIR%\assets\bin"
copy /Y "assets\bin\ffmpeg.exe" "%BUILD_DIR%\assets\bin\" 2>nul
copy /Y "assets\bin\N_m3u8DL-RE.exe" "%BUILD_DIR%\assets\bin\" 2>nul

:: Check for NSIS installation
set "NSIS_FOUND=0"
set "NSIS_PATH="

if exist "C:\Program Files (x86)\NSIS\makensis.exe" (
    set "NSIS_PATH=C:\Program Files (x86)\NSIS\makensis.exe"
    set "NSIS_FOUND=1"
)

if %NSIS_FOUND% EQU 0 (
    if exist "C:\Program Files\NSIS\makensis.exe" (
        set "NSIS_PATH=C:\Program Files\NSIS\makensis.exe"
        set "NSIS_FOUND=1"
    )
)

:: Try to build the installer if NSIS is found
if %NSIS_FOUND% EQU 1 (
    echo NSIS found at %NSIS_PATH%
    echo Building NSIS installer...
    "%NSIS_PATH%" "scripts\shiplus_installer.nsi"
    
    if %ERRORLEVEL% EQU 0 (
        echo.
        echo NSIS Installer created successfully at %OUTPUT_DIR%\%APP_NAME%_Setup.exe
        echo.
    ) else (
        echo.
        echo NSIS compilation failed.
        echo.
    )
) else (
    echo.
    echo NSIS not found. To create the installer:
    echo 1. Install NSIS from https://nsis.sourceforge.io/Download
    echo 2. Run: "C:\Program Files (x86)\NSIS\makensis.exe" "scripts\shiplus_installer.nsi"
    echo.
    echo The Flutter Windows application has been built at %BUILD_DIR%
    echo.
)

endlocal
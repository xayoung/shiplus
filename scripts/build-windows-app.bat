@echo off
setlocal enabledelayedexpansion

echo ===================================================
echo Building ShiPlus Flutter Windows Application
echo ===================================================

:: Check if Flutter is installed
where flutter >nul 2>&1
if %ERRORLEVEL% neq 0 (
    echo Flutter not found. Please install Flutter and add it to your PATH.
    exit /b 1
)

:: Set variables
set "BUILD_DIR=build\windows\x64\runner\Release"

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

echo.
echo Flutter Windows application built successfully at %BUILD_DIR%
echo.

endlocal
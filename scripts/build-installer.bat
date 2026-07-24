@echo off
setlocal enabledelayedexpansion

echo ===================================================
echo ShiPlus Windows Installer Builder
echo ===================================================

:: Configuration
set "APP_NAME=ShiPlus"
set "BUILD_DIR=build\windows\x64\runner\Release"
set "OUTPUT_DIR=build\windows\installer"
set "NSIS_SCRIPT=scripts\shiplus_installer.nsi"

:: Command-line options
set "BUILD_APP=0"
set "INSTALL_NSIS=0"

if "%1"=="--help" (
    echo Usage: build-installer.bat [options]
    echo Options:
    echo   --build-app    Build the Flutter Windows application first
    echo   --install-nsis Install NSIS when it is not available
    echo   --help         Show this help message
    exit /b 0
)

:parse_args
if "%1"=="--build-app" (
    set "BUILD_APP=1"
    shift
    goto parse_args
)
if "%1"=="--install-nsis" (
    set "INSTALL_NSIS=1"
    shift
    goto parse_args
)

:: Build the Flutter Windows application when requested.
if %BUILD_APP% EQU 1 (
    echo Building the Flutter Windows application...

    where flutter >nul 2>&1
    if %ERRORLEVEL% neq 0 (
        echo Error: Flutter was not found. Install Flutter and add it to PATH.
        exit /b 1
    )

    flutter build windows --release
    if %ERRORLEVEL% neq 0 (
        echo Flutter build failed.
        exit /b 1
    )

    echo Flutter Windows application built successfully.
    echo.
)

:: Verify the Flutter build output.
if not exist "%BUILD_DIR%" (
    echo Error: Flutter build directory does not exist: %BUILD_DIR%
    echo Run this command first: build-installer.bat --build-app
    exit /b 1
)

if not exist "%BUILD_DIR%\shiplus.exe" (
    echo Error: Flutter executable does not exist: %BUILD_DIR%\shiplus.exe
    echo Run this command first: build-installer.bat --build-app
    exit /b 1
)

:: Locate NSIS.
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

:: Install NSIS when requested and not already available.
if %NSIS_FOUND% EQU 0 (
    if %INSTALL_NSIS% EQU 1 (
        echo NSIS is not installed. Installing it now...

        powershell -ExecutionPolicy Bypass -Command "& {$nsisUrl = 'https://sourceforge.net/projects/nsis/files/NSIS%%203/3.08/nsis-3.08-setup.exe/download'; $nsisInstaller = Join-Path $env:TEMP 'nsis-setup.exe'; [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12; Invoke-WebRequest -Uri $nsisUrl -OutFile $nsisInstaller; Start-Process -FilePath $nsisInstaller -ArgumentList '/S' -Wait; if (Test-Path 'C:\Program Files (x86)\NSIS\makensis.exe') { Write-Host 'NSIS installed successfully' } else { Write-Host 'NSIS installation failed' }}"

        if exist "C:\Program Files (x86)\NSIS\makensis.exe" (
            set "NSIS_PATH=C:\Program Files (x86)\NSIS\makensis.exe"
            set "NSIS_FOUND=1"
            echo NSIS installed successfully.
        ) else (
            echo NSIS installation failed.
            echo Install NSIS manually from https://nsis.sourceforge.io/Download.
            exit /b 1
        )
    ) else (
        echo NSIS was not found.
        echo Install NSIS or use --install-nsis:
        echo   build-installer.bat --install-nsis
        echo Alternatively, install it from https://nsis.sourceforge.io/Download.
        exit /b 1
    )
)

:: Create the output directory.
if not exist "%OUTPUT_DIR%" mkdir "%OUTPUT_DIR%"

:: Build the NSIS installer.
echo Creating the installer with NSIS...
cd scripts
"%NSIS_PATH%" shiplus_installer.nsi
cd ..

:: Report the build result.
if %ERRORLEVEL% EQU 0 (
    if exist "%OUTPUT_DIR%\%APP_NAME%_Setup.exe" (
        echo.
        echo NSIS installer created: %OUTPUT_DIR%\%APP_NAME%_Setup.exe
        echo File size: !%OUTPUT_DIR%\%APP_NAME%_Setup.exe:~0,10! MB
        echo.
    ) else (
        echo.
        echo NSIS reported success, but the installer file was not found.
        echo.
    )
) else (
    echo.
    echo NSIS build failed with exit code: %ERRORLEVEL%
    echo.
)

endlocal

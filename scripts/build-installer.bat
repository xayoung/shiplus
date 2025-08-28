@echo off
setlocal enabledelayedexpansion

echo ===================================================
echo ShiPlus Windows Installer Builder
echo ===================================================

:: 设置变量
set "APP_NAME=ShiPlus"
set "BUILD_DIR=build\windows\x64\runner\Release"
set "OUTPUT_DIR=build\windows\installer"
set "NSIS_SCRIPT=scripts\shiplus_installer.nsi"

:: 检查参数
set "BUILD_APP=0"
set "INSTALL_NSIS=0"

if "%1"=="--help" (
    echo 用法: build-installer.bat [选项]
    echo 选项:
    echo   --build-app    首先构建Flutter Windows应用
    echo   --install-nsis 如果需要，安装NSIS
    echo   --help         显示此帮助信息
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

:: 如果需要，构建Flutter Windows应用
if %BUILD_APP% EQU 1 (
    echo 正在构建Flutter Windows应用...
    
    where flutter >nul 2>&1
    if %ERRORLEVEL% neq 0 (
        echo 错误: 找不到Flutter。请安装Flutter并将其添加到PATH中。
        exit /b 1
    )
    
    flutter build windows --release
    if %ERRORLEVEL% neq 0 (
        echo Flutter构建失败。
        exit /b 1
    )
    
    echo Flutter Windows应用构建成功。
    echo.
)

:: 检查Flutter构建目录是否存在
if not exist "%BUILD_DIR%" (
    echo 错误: Flutter构建目录不存在: %BUILD_DIR%
    echo 请先运行: build-installer.bat --build-app
    exit /b 1
)

:: 检查Flutter构建目录中的主程序是否存在
if not exist "%BUILD_DIR%\shiplus.exe" (
    echo 错误: Flutter应用程序可执行文件不存在: %BUILD_DIR%\shiplus.exe
    echo 请先运行: build-installer.bat --build-app
    exit /b 1
)

:: 检查NSIS是否已安装
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

:: 如果NSIS未安装且用户请求安装，则安装NSIS
if %NSIS_FOUND% EQU 0 (
    if %INSTALL_NSIS% EQU 1 (
        echo NSIS未安装，正在自动安装...
        
        powershell -ExecutionPolicy Bypass -Command "& {$nsisUrl = 'https://sourceforge.net/projects/nsis/files/NSIS%%203/3.08/nsis-3.08-setup.exe/download'; $nsisInstaller = Join-Path $env:TEMP 'nsis-setup.exe'; [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12; Invoke-WebRequest -Uri $nsisUrl -OutFile $nsisInstaller; Start-Process -FilePath $nsisInstaller -ArgumentList '/S' -Wait; if (Test-Path 'C:\Program Files (x86)\NSIS\makensis.exe') { Write-Host 'NSIS安装成功' } else { Write-Host 'NSIS安装失败' }}"
        
        if exist "C:\Program Files (x86)\NSIS\makensis.exe" (
            set "NSIS_PATH=C:\Program Files (x86)\NSIS\makensis.exe"
            set "NSIS_FOUND=1"
            echo NSIS安装成功。
        ) else (
            echo NSIS安装失败。
            echo 请从 https://nsis.sourceforge.io/Download 手动安装NSIS。
            exit /b 1
        )
    ) else (
        echo 未找到NSIS。
        echo 请安装NSIS或使用 --install-nsis 参数自动安装:
        echo   build-installer.bat --install-nsis
        echo 或从 https://nsis.sourceforge.io/Download 手动安装NSIS。
        exit /b 1
    )
)

:: 创建输出目录
if not exist "%OUTPUT_DIR%" mkdir "%OUTPUT_DIR%"

:: 运行NSIS编译器
echo 正在使用NSIS创建安装程序...
cd scripts
"%NSIS_PATH%" shiplus_installer.nsi
cd ..

:: 检查编译结果
if %ERRORLEVEL% EQU 0 (
    if exist "%OUTPUT_DIR%\%APP_NAME%_Setup.exe" (
        echo.
        echo NSIS安装程序创建成功: %OUTPUT_DIR%\%APP_NAME%_Setup.exe
        echo 文件大小: !%OUTPUT_DIR%\%APP_NAME%_Setup.exe:~0,10! MB
        echo.
    ) else (
        echo.
        echo NSIS编译报告成功，但找不到安装程序文件。
        echo.
    )
) else (
    echo.
    echo NSIS编译失败，错误代码: %ERRORLEVEL%
    echo.
)

endlocal
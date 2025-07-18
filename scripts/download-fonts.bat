@echo off
setlocal enabledelayedexpansion

REM 下载 Titillium Web 字体文件脚本 (Windows)

echo 🔤 下载 Titillium Web 字体文件

REM 创建字体目录
set FONTS_DIR=assets\fonts
if not exist "%FONTS_DIR%" (
    mkdir "%FONTS_DIR%"
    echo ✅ 创建字体目录: %FONTS_DIR%
)

REM 字体文件 URL（从 Google Fonts GitHub 仓库）
set BASE_URL=https://raw.githubusercontent.com/google/fonts/main/ofl/titilliumweb

REM 需要下载的字体文件
set FONT_FILES=TitilliumWeb-Light.ttf TitilliumWeb-Regular.ttf TitilliumWeb-SemiBold.ttf TitilliumWeb-Bold.ttf

echo 📥 开始下载字体文件...

for %%f in (%FONT_FILES%) do (
    set local_path=%FONTS_DIR%\%%f
    
    if exist "!local_path!" (
        echo ⚠️  %%f 已存在，跳过下载
    ) else (
        echo 📥 下载 %%f...
        
        REM 使用 PowerShell 下载文件
        powershell -Command "try { Invoke-WebRequest -Uri '%BASE_URL%/%%f' -OutFile '!local_path!' -ErrorAction Stop; Write-Host '✅ %%f 下载完成' } catch { Write-Host '❌ %%f 下载失败'; exit 1 }"
        
        if errorlevel 1 (
            echo ❌ 下载失败，退出
            exit /b 1
        )
    )
)

echo 🎉 所有字体文件下载完成！

REM 验证字体文件
echo 🔍 验证字体文件...

for %%f in (%FONT_FILES%) do (
    set local_path=%FONTS_DIR%\%%f
    if exist "!local_path!" (
        for %%A in ("!local_path!") do (
            echo    %%f: %%~zA bytes
        )
    ) else (
        echo ❌ %%f 不存在
    )
)

REM 检查 pubspec.yaml 配置
echo 🔧 检查 pubspec.yaml 配置...

findstr /C:"family: Titillium Web" pubspec.yaml >nul
if %errorlevel% equ 0 (
    echo ✅ pubspec.yaml 中已配置 Titillium Web 字体
) else (
    echo ⚠️  pubspec.yaml 中未找到 Titillium Web 字体配置
    echo    请确保在 pubspec.yaml 中添加了字体配置
)

echo 📋 下一步操作:
echo    1. 运行 flutter pub get
echo    2. 运行 flutter clean
echo    3. 重新构建应用程序
echo    4. 字体将自动应用到整个应用程序

echo ✨ 字体下载和配置完成！

pause

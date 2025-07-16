@echo off
setlocal enabledelayedexpansion

REM 验证平台特定资源文件的脚本 (Windows)
REM 用于检查构建产物是否只包含对应平台的可执行文件

if "%1"=="" (
    echo 错误: 请提供平台参数
    echo 使用方法: %0 ^<platform^>
    echo 支持的平台: windows, macos, linux
    exit /b 1
)

set PLATFORM=%1
set ASSETS_DIR=assets\bin

echo 🔍 验证平台特定资源文件
echo 📋 检查平台: %PLATFORM%

REM 检查 assets 目录是否存在
if not exist "%ASSETS_DIR%" (
    echo ❌ assets\bin 目录不存在
    exit /b 1
)

REM 列出当前文件
echo 📁 当前 assets\bin 目录内容:
dir "%ASSETS_DIR%"

REM 根据平台检查文件
if /i "%PLATFORM%"=="windows" (
    echo 🪟 验证 Windows 平台资源...
    
    REM 检查应该存在的文件
    if exist "%ASSETS_DIR%\N_m3u8DL-RE.exe" (
        echo ✅ N_m3u8DL-RE.exe 存在
    ) else (
        echo ❌ N_m3u8DL-RE.exe 不存在
        exit /b 1
    )
    
    if exist "%ASSETS_DIR%\ffmpeg.exe" (
        echo ✅ ffmpeg.exe 存在
    ) else (
        echo ❌ ffmpeg.exe 不存在
        exit /b 1
    )
    
    REM 检查不应该存在的文件
    if exist "%ASSETS_DIR%\N_m3u8DL-RE" (
        echo ❌ N_m3u8DL-RE 不应该存在（非 Windows 文件）
        exit /b 1
    ) else (
        echo ✅ N_m3u8DL-RE 已正确移除
    )
    
    if exist "%ASSETS_DIR%\ffmpeg" (
        echo ❌ ffmpeg 不应该存在（非 Windows 文件）
        exit /b 1
    ) else (
        echo ✅ ffmpeg 已正确移除
    )
    
) else if /i "%PLATFORM%"=="macos" (
    echo 🍎 验证 macOS 平台资源...
    
    REM 检查应该存在的文件
    if exist "%ASSETS_DIR%\N_m3u8DL-RE" (
        echo ✅ N_m3u8DL-RE 存在
    ) else (
        echo ❌ N_m3u8DL-RE 不存在
        exit /b 1
    )
    
    if exist "%ASSETS_DIR%\ffmpeg" (
        echo ✅ ffmpeg 存在
    ) else (
        echo ❌ ffmpeg 不存在
        exit /b 1
    )
    
    REM 检查不应该存在的文件
    if exist "%ASSETS_DIR%\N_m3u8DL-RE.exe" (
        echo ❌ N_m3u8DL-RE.exe 不应该存在（Windows 文件）
        exit /b 1
    ) else (
        echo ✅ N_m3u8DL-RE.exe 已正确移除
    )
    
    if exist "%ASSETS_DIR%\ffmpeg.exe" (
        echo ❌ ffmpeg.exe 不应该存在（Windows 文件）
        exit /b 1
    ) else (
        echo ✅ ffmpeg.exe 已正确移除
    )
    
) else if /i "%PLATFORM%"=="linux" (
    echo 🐧 验证 Linux 平台资源...
    
    REM 检查应该存在的文件
    if exist "%ASSETS_DIR%\N_m3u8DL-RE" (
        echo ✅ N_m3u8DL-RE 存在
    ) else (
        echo ❌ N_m3u8DL-RE 不存在
        exit /b 1
    )
    
    if exist "%ASSETS_DIR%\ffmpeg" (
        echo ✅ ffmpeg 存在
    ) else (
        echo ❌ ffmpeg 不存在
        exit /b 1
    )
    
    REM 检查不应该存在的文件
    if exist "%ASSETS_DIR%\N_m3u8DL-RE.exe" (
        echo ❌ N_m3u8DL-RE.exe 不应该存在（Windows 文件）
        exit /b 1
    ) else (
        echo ✅ N_m3u8DL-RE.exe 已正确移除
    )
    
    if exist "%ASSETS_DIR%\ffmpeg.exe" (
        echo ❌ ffmpeg.exe 不应该存在（Windows 文件）
        exit /b 1
    ) else (
        echo ✅ ffmpeg.exe 已正确移除
    )
    
) else (
    echo ❌ 不支持的平台: %PLATFORM%
    echo 支持的平台: windows, macos, linux
    exit /b 1
)

echo 🎉 平台资源验证通过！

REM 统计信息
for /f %%i in ('dir /b "%ASSETS_DIR%" ^| find /c /v ""') do set FILE_COUNT=%%i
echo 📊 统计信息:
echo    文件总数: %FILE_COUNT%

pause

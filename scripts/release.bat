@echo off
setlocal enabledelayedexpansion

REM Shiplus 版本发布脚本 (Windows)
REM 使用方法: scripts\release.bat 1.0.0

if "%1"=="" (
    echo 错误: 请提供版本号
    echo 使用方法: %0 ^<version^>
    echo 示例: %0 1.0.0
    exit /b 1
)

set VERSION=%1
set TAG=v%VERSION%

echo 🚀 开始发布 Shiplus %VERSION%

REM 检查是否在 git 仓库中
git rev-parse --git-dir >nul 2>&1
if errorlevel 1 (
    echo 错误: 当前目录不是 git 仓库
    exit /b 1
)

REM 检查工作目录是否干净
git diff-index --quiet HEAD --
if errorlevel 1 (
    echo 错误: 工作目录有未提交的更改
    echo 请先提交或暂存所有更改
    exit /b 1
)

REM 获取当前分支
for /f "tokens=*" %%i in ('git branch --show-current') do set CURRENT_BRANCH=%%i

REM 检查是否在主分支
if not "%CURRENT_BRANCH%"=="main" if not "%CURRENT_BRANCH%"=="master" (
    echo 警告: 当前不在主分支 ^(当前: %CURRENT_BRANCH%^)
    set /p REPLY="是否继续? (y/N): "
    if /i not "!REPLY!"=="y" (
        echo 发布已取消
        exit /b 1
    )
)

REM 检查标签是否已存在
git tag -l | findstr /x "%TAG%" >nul
if not errorlevel 1 (
    echo 错误: 标签 %TAG% 已存在
    exit /b 1
)

REM 更新 pubspec.yaml 中的版本号
echo 📝 更新 pubspec.yaml 版本号...
powershell -Command "(Get-Content pubspec.yaml) -replace '^version: .*', 'version: %VERSION%+1' | Set-Content pubspec.yaml"

REM 检查 Flutter 项目
echo 🔍 检查 Flutter 项目...
flutter pub get
flutter analyze
if errorlevel 1 (
    echo 错误: Flutter 分析失败
    exit /b 1
)

REM 运行测试
echo 🧪 运行测试...
flutter test
if errorlevel 1 (
    echo 错误: 测试失败
    exit /b 1
)

REM 提交版本更新
echo 📦 提交版本更新...
git add pubspec.yaml
git commit -m "chore: bump version to %VERSION%"

REM 创建标签
echo 🏷️ 创建标签 %TAG%...
git tag -a "%TAG%" -m "Release %VERSION%"

REM 推送到远程仓库
echo ⬆️ 推送到远程仓库...
git push origin %CURRENT_BRANCH%
git push origin %TAG%

echo ✅ 发布完成!
echo 📋 接下来的步骤:
echo    1. 前往 GitHub Actions 查看构建进度
echo    2. 构建完成后，在 Releases 页面查看发布版本
echo    3. 下载并测试构建产物
echo.
echo 🔗 有用的链接:
for /f "tokens=*" %%i in ('git config --get remote.origin.url') do set REPO_URL=%%i
set REPO_URL=%REPO_URL:https://github.com/=%
set REPO_URL=%REPO_URL:.git=%
echo    • Actions: https://github.com/%REPO_URL%/actions
echo    • Releases: https://github.com/%REPO_URL%/releases

pause

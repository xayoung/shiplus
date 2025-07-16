#!/bin/bash

# Flutter macOS DMG 打包脚本
# 使用方法: ./build_dmg.sh

set -e

echo "开始构建 Flutter macOS 应用..."

# 清理之前的构建
echo "清理之前的构建文件..."
flutter clean
flutter pub get

# 构建 macOS 应用
echo "构建 macOS Release 版本..."
flutter build macos --release

# 检查构建是否成功
if [ ! -d "build/macos/Build/Products/Release/shiplus.app" ]; then
    echo "错误: 构建失败，找不到应用文件"
    exit 1
fi

echo "构建成功！"

# 创建临时目录
echo "准备打包 DMG..."
rm -rf dmg_temp
mkdir -p dmg_temp

# 复制应用到临时目录
cp -R "build/macos/Build/Products/Release/shiplus.app" dmg_temp/

# 创建 Applications 文件夹的符号链接
ln -s /Applications dmg_temp/Applications

# 删除旧的 DMG 文件
rm -f shiplus_flutter_installer.dmg

# 创建 DMG
echo "创建 DMG 文件..."
hdiutil create -volname "ShiPlus Flutter" -srcfolder dmg_temp -ov -format UDZO shiplus_flutter_installer.dmg

# 清理临时文件
rm -rf dmg_temp

echo "✅ DMG 文件创建成功: shiplus_flutter_installer.dmg"
echo "文件大小: $(du -h shiplus_flutter_installer.dmg | cut -f1)"
echo ""
echo "安装说明:"
echo "1. 双击 shiplus_flutter_installer.dmg 打开"
echo "2. 将 shiplus_flutter.app 拖拽到 Applications 文件夹"
echo "3. 从 Applications 文件夹启动应用"
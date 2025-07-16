#!/bin/bash

# 验证平台特定资源文件的脚本
# 用于检查构建产物是否只包含对应平台的可执行文件

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}🔍 验证平台特定资源文件${NC}"

# 检查参数
if [ $# -eq 0 ]; then
    echo -e "${RED}错误: 请提供平台参数${NC}"
    echo -e "${YELLOW}使用方法: $0 <platform>${NC}"
    echo -e "${YELLOW}支持的平台: windows, macos, linux${NC}"
    exit 1
fi

PLATFORM=$1
ASSETS_DIR="assets/bin"

echo -e "${BLUE}📋 检查平台: $PLATFORM${NC}"

# 检查 assets 目录是否存在
if [ ! -d "$ASSETS_DIR" ]; then
    echo -e "${RED}❌ assets/bin 目录不存在${NC}"
    exit 1
fi

# 列出当前文件
echo -e "${BLUE}📁 当前 assets/bin 目录内容:${NC}"
ls -la "$ASSETS_DIR"

# 根据平台检查文件
case $PLATFORM in
    "windows")
        echo -e "${BLUE}🪟 验证 Windows 平台资源...${NC}"
        
        # 应该存在的文件
        EXPECTED_FILES=("N_m3u8DL-RE.exe" "ffmpeg.exe")
        # 不应该存在的文件
        UNEXPECTED_FILES=("N_m3u8DL-RE" "ffmpeg")
        
        for file in "${EXPECTED_FILES[@]}"; do
            if [ -f "$ASSETS_DIR/$file" ]; then
                echo -e "${GREEN}✅ $file 存在${NC}"
            else
                echo -e "${RED}❌ $file 不存在${NC}"
                exit 1
            fi
        done
        
        for file in "${UNEXPECTED_FILES[@]}"; do
            if [ -f "$ASSETS_DIR/$file" ]; then
                echo -e "${RED}❌ $file 不应该存在（非 Windows 文件）${NC}"
                exit 1
            else
                echo -e "${GREEN}✅ $file 已正确移除${NC}"
            fi
        done
        ;;
        
    "macos"|"linux")
        echo -e "${BLUE}🍎 验证 $PLATFORM 平台资源...${NC}"
        
        # 应该存在的文件
        EXPECTED_FILES=("N_m3u8DL-RE" "ffmpeg")
        # 不应该存在的文件
        UNEXPECTED_FILES=("N_m3u8DL-RE.exe" "ffmpeg.exe")
        
        for file in "${EXPECTED_FILES[@]}"; do
            if [ -f "$ASSETS_DIR/$file" ]; then
                echo -e "${GREEN}✅ $file 存在${NC}"
            else
                echo -e "${RED}❌ $file 不存在${NC}"
                exit 1
            fi
        done
        
        for file in "${UNEXPECTED_FILES[@]}"; do
            if [ -f "$ASSETS_DIR/$file" ]; then
                echo -e "${RED}❌ $file 不应该存在（Windows 文件）${NC}"
                exit 1
            else
                echo -e "${GREEN}✅ $file 已正确移除${NC}"
            fi
        done
        ;;
        
    *)
        echo -e "${RED}❌ 不支持的平台: $PLATFORM${NC}"
        echo -e "${YELLOW}支持的平台: windows, macos, linux${NC}"
        exit 1
        ;;
esac

echo -e "${GREEN}🎉 平台资源验证通过！${NC}"
echo -e "${BLUE}📊 统计信息:${NC}"
echo -e "   文件总数: $(ls -1 "$ASSETS_DIR" | wc -l)"
echo -e "   目录大小: $(du -sh "$ASSETS_DIR" | cut -f1)"

# 显示文件权限（Unix 平台）
if [ "$PLATFORM" != "windows" ]; then
    echo -e "${BLUE}🔐 文件权限:${NC}"
    for file in "$ASSETS_DIR"/*; do
        if [ -f "$file" ]; then
            echo -e "   $(basename "$file"): $(stat -c '%A' "$file" 2>/dev/null || stat -f '%Sp' "$file")"
        fi
    done
fi

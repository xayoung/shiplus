#!/bin/bash

# 下载 Titillium Web 字体文件脚本

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}🔤 下载 Titillium Web 字体文件${NC}"

# 创建字体目录
FONTS_DIR="assets/fonts"
if [ ! -d "$FONTS_DIR" ]; then
    mkdir -p "$FONTS_DIR"
    echo -e "${GREEN}✅ 创建字体目录: $FONTS_DIR${NC}"
fi

# 字体文件 URL（从 Google Fonts GitHub 仓库）
BASE_URL="https://raw.githubusercontent.com/google/fonts/main/ofl/titilliumweb"

# 需要下载的字体文件
declare -a FONT_FILES=(
    "TitilliumWeb-Light.ttf"
    "TitilliumWeb-Regular.ttf"
    "TitilliumWeb-SemiBold.ttf"
    "TitilliumWeb-Bold.ttf"
)

# 下载字体文件
echo -e "${BLUE}📥 开始下载字体文件...${NC}"

for font_file in "${FONT_FILES[@]}"; do
    local_path="$FONTS_DIR/$font_file"
    
    if [ -f "$local_path" ]; then
        echo -e "${YELLOW}⚠️  $font_file 已存在，跳过下载${NC}"
        continue
    fi
    
    echo -e "${BLUE}📥 下载 $font_file...${NC}"
    
    if command -v curl >/dev/null 2>&1; then
        curl -L -o "$local_path" "$BASE_URL/$font_file"
    elif command -v wget >/dev/null 2>&1; then
        wget -O "$local_path" "$BASE_URL/$font_file"
    else
        echo -e "${RED}❌ 错误: 需要 curl 或 wget 来下载文件${NC}"
        exit 1
    fi
    
    if [ -f "$local_path" ]; then
        echo -e "${GREEN}✅ $font_file 下载完成${NC}"
    else
        echo -e "${RED}❌ $font_file 下载失败${NC}"
        exit 1
    fi
done

echo -e "${GREEN}🎉 所有字体文件下载完成！${NC}"

# 验证字体文件
echo -e "${BLUE}🔍 验证字体文件...${NC}"

total_size=0
for font_file in "${FONT_FILES[@]}"; do
    local_path="$FONTS_DIR/$font_file"
    if [ -f "$local_path" ]; then
        file_size=$(stat -c%s "$local_path" 2>/dev/null || stat -f%z "$local_path" 2>/dev/null || echo "0")
        total_size=$((total_size + file_size))
        echo -e "   $font_file: $(numfmt --to=iec $file_size 2>/dev/null || echo "${file_size} bytes")"
    else
        echo -e "${RED}❌ $font_file 不存在${NC}"
    fi
done

echo -e "${GREEN}📊 总大小: $(numfmt --to=iec $total_size 2>/dev/null || echo "${total_size} bytes")${NC}"

# 检查 pubspec.yaml 配置
echo -e "${BLUE}🔧 检查 pubspec.yaml 配置...${NC}"

if grep -q "family: Titillium Web" pubspec.yaml; then
    echo -e "${GREEN}✅ pubspec.yaml 中已配置 Titillium Web 字体${NC}"
else
    echo -e "${YELLOW}⚠️  pubspec.yaml 中未找到 Titillium Web 字体配置${NC}"
    echo -e "${YELLOW}   请确保在 pubspec.yaml 中添加了字体配置${NC}"
fi

echo -e "${BLUE}📋 下一步操作:${NC}"
echo -e "   1. 运行 ${YELLOW}flutter pub get${NC}"
echo -e "   2. 运行 ${YELLOW}flutter clean${NC}"
echo -e "   3. 重新构建应用程序"
echo -e "   4. 字体将自动应用到整个应用程序"

echo -e "${GREEN}✨ 字体下载和配置完成！${NC}"

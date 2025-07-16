#!/bin/bash

# Shiplus 版本发布脚本
# 使用方法: ./scripts/release.sh 1.0.0

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 检查参数
if [ $# -eq 0 ]; then
    echo -e "${RED}错误: 请提供版本号${NC}"
    echo -e "${YELLOW}使用方法: $0 <version>${NC}"
    echo -e "${YELLOW}示例: $0 1.0.0${NC}"
    exit 1
fi

VERSION=$1
TAG="v$VERSION"

echo -e "${BLUE}🚀 开始发布 Shiplus $VERSION${NC}"

# 检查是否在 git 仓库中
if ! git rev-parse --git-dir > /dev/null 2>&1; then
    echo -e "${RED}错误: 当前目录不是 git 仓库${NC}"
    exit 1
fi

# 检查工作目录是否干净
if ! git diff-index --quiet HEAD --; then
    echo -e "${RED}错误: 工作目录有未提交的更改${NC}"
    echo -e "${YELLOW}请先提交或暂存所有更改${NC}"
    exit 1
fi

# 检查是否在主分支
CURRENT_BRANCH=$(git branch --show-current)
if [ "$CURRENT_BRANCH" != "main" ] && [ "$CURRENT_BRANCH" != "master" ]; then
    echo -e "${YELLOW}警告: 当前不在主分支 (当前: $CURRENT_BRANCH)${NC}"
    read -p "是否继续? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo -e "${RED}发布已取消${NC}"
        exit 1
    fi
fi

# 检查标签是否已存在
if git tag -l | grep -q "^$TAG$"; then
    echo -e "${RED}错误: 标签 $TAG 已存在${NC}"
    exit 1
fi

# 更新 pubspec.yaml 中的版本号
echo -e "${BLUE}📝 更新 pubspec.yaml 版本号...${NC}"
if [[ "$OSTYPE" == "darwin"* ]]; then
    # macOS
    sed -i '' "s/^version: .*/version: $VERSION+1/" pubspec.yaml
else
    # Linux
    sed -i "s/^version: .*/version: $VERSION+1/" pubspec.yaml
fi

# 检查 Flutter 项目
echo -e "${BLUE}🔍 检查 Flutter 项目...${NC}"
flutter pub get
flutter analyze

# 运行测试
echo -e "${BLUE}🧪 运行测试...${NC}"
if ! flutter test; then
    echo -e "${RED}错误: 测试失败${NC}"
    exit 1
fi

# 提交版本更新
echo -e "${BLUE}📦 提交版本更新...${NC}"
git add pubspec.yaml
git commit -m "chore: bump version to $VERSION"

# 创建标签
echo -e "${BLUE}🏷️  创建标签 $TAG...${NC}"
git tag -a "$TAG" -m "Release $VERSION"

# 推送到远程仓库
echo -e "${BLUE}⬆️  推送到远程仓库...${NC}"
git push origin "$CURRENT_BRANCH"
git push origin "$TAG"

echo -e "${GREEN}✅ 发布完成!${NC}"
echo -e "${GREEN}📋 接下来的步骤:${NC}"
echo -e "   1. 前往 GitHub Actions 查看构建进度"
echo -e "   2. 构建完成后，在 Releases 页面查看发布版本"
echo -e "   3. 下载并测试构建产物"
echo ""
echo -e "${BLUE}🔗 有用的链接:${NC}"
echo -e "   • Actions: https://github.com/$(git config --get remote.origin.url | sed 's/.*github.com[:/]\([^.]*\).*/\1/')/actions"
echo -e "   • Releases: https://github.com/$(git config --get remote.origin.url | sed 's/.*github.com[:/]\([^.]*\).*/\1/')/releases"

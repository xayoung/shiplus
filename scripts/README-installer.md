# ShiPlus Windows 安装程序指南

本文档提供了使用NSIS创建ShiPlus Windows安装程序的详细说明。

## 前提条件

1. 安装Flutter SDK并配置Windows开发环境
2. 安装NSIS (Nullsoft Scriptable Install System)

## 快速开始

### 一键构建（推荐）

如果你想一次性完成所有步骤（构建Flutter应用并创建安装程序），请运行：

```batch
scripts\build-installer.bat --build-app --install-nsis
```

这个命令会：
1. 如果需要，自动安装NSIS
2. 构建Flutter Windows应用
3. 创建NSIS安装程序

### 分步构建

如果你想分步骤进行：

1. **构建Flutter Windows应用**
   ```batch
   scripts\build-installer.bat --build-app
   ```

2. **创建NSIS安装程序**（假设Flutter应用已构建）
   ```batch
   scripts\build-installer.bat
   ```

## 命令行参数

`build-installer.bat` 支持以下参数：

- `--build-app`: 首先构建Flutter Windows应用
- `--install-nsis`: 如果需要，自动安装NSIS
- `--help`: 显示帮助信息

## 文件说明

- `scripts/shiplus_installer.nsi`: NSIS安装程序脚本
- `scripts/build-installer.bat`: 主构建脚本
- `build/windows/installer/ShiPlus_Setup.exe`: 生成的安装程序

## 常见问题

### 找不到NSIS

确保NSIS已正确安装，或使用 `--install-nsis` 参数自动安装。

### 构建失败

检查Flutter Windows应用是否已成功构建。确保 `build\windows\x64\runner\Release` 目录中包含所有必要的文件。

### 自定义安装程序

如果需要自定义安装程序，可以编辑 `scripts\shiplus_installer.nsi` 文件。
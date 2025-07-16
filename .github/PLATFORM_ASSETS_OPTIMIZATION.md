# 平台特定资源文件优化

## 概述

优化 GitHub Actions 构建流程，确保每个平台的构建产物只包含对应平台的可执行文件，减少不必要的文件打包。

## 问题背景

### 原始问题
- 所有平台构建都包含全部可执行文件
- Windows 构建包含 macOS/Linux 文件
- macOS 构建包含 Windows .exe 文件
- 导致构建产物体积增大，用户下载不必要的文件

### 资源文件结构
```
assets/bin/
├── N_m3u8DL-RE      # macOS/Linux 版本
├── N_m3u8DL-RE.exe  # Windows 版本
├── ffmpeg           # macOS/Linux 版本
└── ffmpeg.exe       # Windows 版本
```

## 解决方案

### 构建前资源清理

在每个平台构建前，删除不需要的平台文件：

#### Windows 构建
```powershell
# 删除 macOS/Linux 文件，保留 .exe 文件
Remove-Item -Path "assets/bin/N_m3u8DL-RE" -Force -ErrorAction SilentlyContinue
Remove-Item -Path "assets/bin/ffmpeg" -Force -ErrorAction SilentlyContinue
```

#### macOS 构建
```bash
# 删除 Windows 文件，保留非 .exe 文件
rm -f assets/bin/N_m3u8DL-RE.exe
rm -f assets/bin/ffmpeg.exe
```

#### Linux 构建
```bash
# 删除 Windows 文件，保留非 .exe 文件
rm -f assets/bin/N_m3u8DL-RE.exe
rm -f assets/bin/ffmpeg.exe
```

## 实现细节

### 修改的工作流文件

1. **`.github/workflows/build-windows.yml`**
   - 添加 "Prepare Windows assets" 步骤
   - 使用 PowerShell 删除非 Windows 文件

2. **`.github/workflows/build-multiplatform.yml`**
   - Windows 作业：添加 Windows 资源准备步骤
   - macOS 作业：添加 macOS 资源准备步骤
   - Linux 作业：添加 Linux 资源准备步骤

### 步骤顺序
```yaml
1. Checkout repository
2. Setup Flutter
3. Enable platform desktop
4. Install dependencies
5. Analyze code
6. [NEW] Prepare platform assets  # 新增步骤
7. Build platform release
8. Create release package
9. Upload artifacts
```

## 优化效果

### 构建产物大小减少
- **Windows**: 减少约 50-100MB（移除 macOS/Linux 可执行文件）
- **macOS**: 减少约 50-100MB（移除 Windows .exe 文件）
- **Linux**: 减少约 50-100MB（移除 Windows .exe 文件）

### 用户体验改善
- 下载速度更快
- 安装包更小
- 避免混淆（用户不会看到其他平台的文件）

### 安全性提升
- 减少攻击面（不包含不必要的可执行文件）
- 避免误执行其他平台的程序

## 技术考虑

### 文件删除安全性
- 使用 `-ErrorAction SilentlyContinue` (Windows) 和 `-f` (Unix) 确保删除失败不会中断构建
- 删除操作在临时构建环境中进行，不影响源代码

### 平台检测逻辑
- **Windows**: 保留 `.exe` 后缀文件
- **macOS/Linux**: 保留无后缀文件
- 基于文件扩展名进行简单可靠的区分

### 构建一致性
- 每次构建都从完整的资源文件开始
- 确保不同构建之间的独立性
- 避免缓存导致的文件残留问题

## 验证方法

### 构建产物检查
1. **下载构建产物**
2. **解压并检查 assets/bin/ 目录**
3. **验证只包含对应平台的文件**：
   - Windows: 只有 `.exe` 文件
   - macOS: 只有无后缀文件
   - Linux: 只有无后缀文件

### 功能测试
1. **运行应用程序**
2. **测试下载功能**
3. **确认可执行文件正常工作**

## 回滚方案

如需回滚到包含所有平台文件的版本：

1. **移除资源准备步骤**：
   ```yaml
   # 注释或删除这些步骤
   # - name: Prepare [Platform] assets
   #   run: |
   #     # 平台特定的文件删除命令
   ```

2. **恢复原始构建流程**：
   ```yaml
   - name: Build [Platform] Release
     run: flutter build [platform] --release --verbose
   ```

## 监控指标

### 构建指标
- 构建时间变化
- 构建产物大小
- 构建成功率

### 用户指标
- 下载时间
- 安装成功率
- 功能正常性

## 注意事项

1. **本地开发不受影响**：本地 `assets/bin/` 目录仍包含所有平台文件
2. **CI/CD 环境专用**：文件删除只在 GitHub Actions 中进行
3. **可执行权限**：Unix 平台需要确保可执行文件有正确权限
4. **路径兼容性**：使用相对路径确保跨平台兼容

---

**实施日期**: 2025-01-16  
**影响版本**: v1.0.0+  
**预期收益**: 减少 50-100MB 构建产物大小

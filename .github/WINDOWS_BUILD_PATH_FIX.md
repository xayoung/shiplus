# Windows 构建路径问题修复

## 问题描述

GitHub Actions Windows 构建在打包步骤失败：

```
Building Windows application...                                    62.1s
√  Built build\windows\x64\runner\Release\shiplus.exe (0.1MB).
0s
Run cd build/windows/runner/Release
Set-Location: D:\a\_temp\340023b8-9665-4bc6-9de4-caee0030358c.ps1:2
Line |
   2 |  cd build/windows/runner/Release
     |  ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
     | Cannot find path 'D:\a\shiplus_flutter\shiplus_flutter\build\windows\runner\Release' because it does not exist.
Error: Process completed with exit code 1.
```

## 根本原因

1. **Flutter 构建成功**：成功生成了 `shiplus.exe` 文件
2. **路径不匹配**：实际构建输出路径与脚本中的预期路径不一致
3. **硬编码路径**：使用了固定的 `build/windows/runner/Release` 路径

## 分析

### 构建输出信息
```
√  Built build\windows\x64\runner\Release\shiplus.exe (0.1MB).
```

这表明实际路径可能是：
- `build\windows\x64\runner\Release\` 而不是 `build\windows\runner\Release\`
- 或者目录结构在不同的 Flutter 版本中有所变化

### 问题根源
- 硬编码的目录路径不够灵活
- 没有验证目录是否存在就直接切换
- 缺乏错误处理和备用方案

## 解决方案

### 1. 动态查找可执行文件

使用 PowerShell 动态查找 `shiplus.exe` 文件：

```powershell
$exeFile = Get-ChildItem -Path "build" -Recurse -Filter "shiplus.exe" | Select-Object -First 1
```

### 2. 基于文件位置确定目录

```powershell
if ($exeFile) {
  $releaseDir = $exeFile.Directory.FullName
  Write-Host "Release directory: $releaseDir"
}
```

### 3. 添加调试信息

```powershell
- name: Debug - List Windows build directory structure
  run: |
    Write-Host "Listing build directory structure:"
    if (Test-Path "build") {
      Get-ChildItem -Path "build" -Recurse -Directory | Select-Object FullName
      Write-Host "Looking for executable files:"
      Get-ChildItem -Path "build" -Recurse -Filter "*.exe" | Select-Object FullName
    }
```

### 4. 改进的打包脚本

```powershell
- name: Create Windows release package
  run: |
    # Find the exe file and its directory
    $exeFile = Get-ChildItem -Path "build" -Recurse -Filter "shiplus.exe" | Select-Object -First 1
    if ($exeFile) {
      Write-Host "Found exe at: $($exeFile.FullName)"
      $releaseDir = $exeFile.Directory.FullName
      Write-Host "Release directory: $releaseDir"
      
      # Create archive from the directory containing the exe
      Set-Location $releaseDir
      $archivePath = Join-Path $env:GITHUB_WORKSPACE "shiplus-windows-x64.zip"
      7z a -tzip $archivePath *
      Write-Host "Created archive: $archivePath"
    } else {
      Write-Host "ERROR: Could not find shiplus.exe"
      exit 1
    }
  shell: powershell
```

## 修复优势

### 1. 灵活性
- 不依赖固定的目录结构
- 适应不同 Flutter 版本的输出路径变化
- 自动查找实际的构建产物位置

### 2. 可靠性
- 添加了错误检查和处理
- 提供详细的调试信息
- 失败时给出明确的错误消息

### 3. 可维护性
- 减少硬编码路径
- 更容易调试和排错
- 适应未来的 Flutter 版本变化

## 实施步骤

### 修改的文件
1. `.github/workflows/build-windows.yml`
2. `.github/workflows/build-multiplatform.yml`

### 新增功能
1. **调试步骤**：显示完整的构建目录结构
2. **动态路径查找**：基于文件搜索而非固定路径
3. **改进的错误处理**：更好的错误消息和退出处理

## 验证方法

### 1. 检查调试输出
查看 "Debug - List Windows build directory structure" 步骤的输出，确认：
- 构建目录结构
- 可执行文件的实际位置

### 2. 验证打包过程
查看 "Create Windows release package" 步骤的输出，确认：
- 找到了 `shiplus.exe` 文件
- 正确识别了 Release 目录
- 成功创建了压缩包

### 3. 检查构建产物
- 下载生成的 `shiplus-windows-x64.zip`
- 验证包含所有必要的文件
- 确认只包含 Windows 平台的可执行文件

## 可能的目录结构

根据不同的 Flutter 版本，可能的目录结构包括：

```
# 可能的结构 1
build/windows/runner/Release/
├── shiplus.exe
├── flutter_windows.dll
└── data/

# 可能的结构 2
build/windows/x64/runner/Release/
├── shiplus.exe
├── flutter_windows.dll
└── data/

# 可能的结构 3
build/windows/Release/
├── shiplus.exe
├── flutter_windows.dll
└── data/
```

新的脚本能够自动适应所有这些结构。

## 回滚方案

如果新的脚本出现问题，可以回滚到固定路径：

```yaml
- name: Create Windows release package
  run: |
    cd build/windows/runner/Release
    7z a -tzip ../../../../shiplus-windows-x64.zip *
```

但建议先尝试修复路径问题而不是回滚。

## 监控指标

- 构建成功率
- 打包步骤成功率
- 构建产物完整性
- 用户下载和使用反馈

---

**修复日期**: 2025-01-16  
**影响版本**: 所有 Windows 构建  
**预期效果**: 解决路径不匹配导致的打包失败

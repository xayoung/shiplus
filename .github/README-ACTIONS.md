# GitHub Actions 自动构建说明

本项目配置了 GitHub Actions 来自动构建多平台版本的应用程序。

## 🚀 自动构建触发条件

### 自动触发
- **推送到主分支**: 当代码推送到 `main` 或 `master` 分支时
- **创建标签**: 当创建以 `v` 开头的标签时（如 `v1.0.0`）
- **Pull Request**: 当创建或更新 PR 时

### 手动触发
1. 进入 GitHub 仓库页面
2. 点击 "Actions" 标签
3. 选择 "Build Multi-Platform Release" 工作流
4. 点击 "Run workflow" 按钮
5. 选择要构建的平台并运行

## 📦 构建产物

### Windows 版本
- **文件名**: `shiplus-windows-x64.zip`
- **包含内容**:
  - `shiplus.exe` - 主程序
  - `flutter_windows.dll` - Flutter 运行时
  - `data/` - 应用资源文件
- **系统要求**: Windows 10+ (x64)

### macOS 版本
- **文件名**: `shiplus-macos-universal.zip`
- **包含内容**:
  - `shiplus.app` - macOS 应用包
- **系统要求**: macOS 10.14+

## 🏷️ 创建发布版本

要创建正式发布版本：

1. **创建标签**:
   ```bash
   git tag v1.0.0
   git push origin v1.0.0
   ```

2. **自动发布**: GitHub Actions 会自动：
   - 构建所有平台版本
   - 创建 GitHub Release
   - 上传构建产物
   - 生成发布说明

## 📋 工作流文件说明

### `build-windows.yml`
- 专门用于构建 Windows 版本
- 包含代码分析和测试
- 适合快速 Windows 构建

### `build-multiplatform.yml`
- 支持多平台构建（Windows、macOS、Linux）
- 可选择性构建特定平台
- 自动创建 GitHub Release

## 🔧 自定义配置

### 修改 Flutter 版本
在工作流文件中修改：
```yaml
flutter-version: '3.19.4'  # 改为你需要的版本
```

### 添加构建选项
在构建命令中添加参数：
```yaml
run: flutter build windows --release --obfuscate --split-debug-info=symbols
```

### 修改发布内容
编辑工作流文件中的 `body` 部分来自定义发布说明。

## 📊 查看构建状态

1. 进入 GitHub 仓库
2. 点击 "Actions" 标签
3. 查看最近的工作流运行状态
4. 点击具体的运行记录查看详细日志

## 📥 下载构建产物

### 从 Actions 页面下载
1. 进入 "Actions" 页面
2. 点击成功的工作流运行
3. 在 "Artifacts" 部分下载对应的文件

### 从 Releases 页面下载
1. 进入 "Releases" 页面
2. 下载最新版本的构建产物

## ⚠️ 注意事项

- 构建时间约 10-15 分钟
- 免费账户每月有 2000 分钟的 Actions 使用时间
- 私有仓库的 Actions 使用时间会消耗配额
- 构建产物保留 30 天后自动删除

## 🐛 故障排除

### 构建失败
1. 检查 Actions 日志中的错误信息
2. 确保 `pubspec.yaml` 中的依赖版本正确
3. 检查代码是否通过 `flutter analyze`

### 无法下载构建产物
1. 确保你有仓库的访问权限
2. 检查构建是否成功完成
3. 确认构建产物未过期（30天）

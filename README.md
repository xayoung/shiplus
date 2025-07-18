# Shiplus Flutter

一个基于 Flutter 的跨平台桌面应用程序。

## 🚀 快速开始

### 开发环境要求
- Flutter 3.19.4+
- Dart 3.3.2+
- 对应平台的开发工具（见下方平台特定要求）

### 安装依赖
```bash
flutter pub get
```

### 运行应用
```bash
# 调试模式
flutter run -d windows  # Windows
flutter run -d macos    # macOS
flutter run -d linux    # Linux

# 发布模式
flutter run --release -d windows
```

## 📦 构建发布版本

### 🤖 自动构建（推荐）

本项目配置了 GitHub Actions 自动构建，支持：
- ✅ Windows (x64) - 仅包含 .exe 可执行文件
- ✅ macOS (Apple Silicon) - 仅包含 macOS 可执行文件
- ⚠️ Linux (可选) - 仅包含 Linux 可执行文件

> 💡 **优化说明**: 每个平台的构建产物只包含对应平台的可执行文件，减少下载大小约 50-100MB

#### 创建发布版本

**方法一：使用发布脚本**
```bash
# macOS/Linux
./scripts/release.sh 1.0.0

# Windows
scripts\release.bat 1.0.0
```

**方法二：手动创建标签**
```bash
git tag v1.0.0
git push origin v1.0.0
```

#### 下载构建产物
1. 前往 [Actions](../../actions) 页面查看构建进度
2. 构建完成后，在 [Releases](../../releases) 页面下载对应平台的文件

### 🔧 本地构建

#### Windows
```bash
# 启用 Windows 桌面支持
flutter config --enable-windows-desktop

# 构建
flutter build windows --release
```
构建产物位于: `build\windows\runner\Release\`

#### macOS
```bash
# 启用 macOS 桌面支持
flutter config --enable-macos-desktop

# 构建
flutter build macos --release
```
构建产物位于: `build/macos/Build/Products/Release/`

#### Linux
```bash
# 安装依赖
sudo apt-get install clang cmake ninja-build pkg-config libgtk-3-dev liblzma-dev

# 启用 Linux 桌面支持
flutter config --enable-linux-desktop

# 构建
flutter build linux --release
```
构建产物位于: `build/linux/x64/release/bundle/`

## 📋 系统要求

### Windows
- Windows 10 或更高版本
- x64 架构

### macOS
- macOS 11.0 或更高版本
- Apple Silicon (M1/M2/M3 芯片)

### Linux
- Ubuntu 18.04+ 或等效发行版
- GTK 3.0+

## 🛠️ 开发

### 代码分析
```bash
flutter analyze
```

### 运行测试
```bash
flutter test
```

### 格式化代码
```bash
dart format .
```

## 🔧 故障排除

### Windows 平台问题

#### "N_m3u8DL-RE可执行文件不存在"
**原因**: 应用程序无法找到可执行文件
**解决方案**:
1. 确保 `assets/bin/N_m3u8DL-RE.exe` 文件存在
2. 重新安装应用程序
3. 检查防病毒软件是否阻止了文件提取

#### 首次运行缓慢
**原因**: 应用程序需要从 assets 提取可执行文件
**解决方案**: 等待几秒钟，后续运行会更快

#### 配置不生效
**原因**: 配置可能未正确保存
**解决方案**:
1. 重新打开 Settings 页面检查配置
2. 点击 "重置默认" 后重新配置
3. 重启应用程序

## ⚙️ 配置选项

### N_m3u8DL-RE 下载配置
在 Settings 页面可以配置下载参数：

#### 输出格式
- **MP4** (默认): 兼容性最好，适合大多数播放器
- **MKV**: 支持更多编解码器和字幕格式

#### 视频质量
- **分辨率选择**: 480p, 720p, 1080p, 1440p, 4K 等
- **动态范围**: SDR (标准) / HLG (高动态范围)

#### 字幕处理
- **跳过字幕** (默认开启): 不下载字幕文件，减少下载时间
- **包含字幕**: 下载所有可用的字幕文件

### 配置方法
1. 打开 Settings 页面
2. 在 "下载配置" 部分调整设置
3. 点击 "保存配置" 应用更改
4. 新的下载任务将使用新配置

## 🎨 设计特性

### 字体
- **全局字体**: Titillium Web Sans-serif
- **字重支持**: Light (300), Regular (400), SemiBold (600), Bold (700)
- **特点**: 现代、简洁、易读的无衬线字体

### 字体安装
```bash
# 自动下载字体文件
./scripts/download-fonts.sh      # Unix/macOS/Linux
scripts\download-fonts.bat       # Windows

# 应用字体配置
flutter pub get
flutter clean
```

## 📚 项目结构

```
lib/
├── main.dart              # 应用入口
├── widgets/               # UI 组件
│   ├── home_page.dart
│   ├── season_page.dart
│   ├── weekend_page.dart
│   └── ...
├── utils/                 # 工具类
│   └── dio_helper.dart
└── ...

assets/
├── fonts/                 # Titillium Web 字体文件
│   ├── TitilliumWeb-Light.ttf
│   ├── TitilliumWeb-Regular.ttf
│   ├── TitilliumWeb-SemiBold.ttf
│   └── TitilliumWeb-Bold.ttf
└── bin/                   # 可执行文件
    ├── N_m3u8DL-RE(.exe)
    └── ffmpeg(.exe)

.github/
├── workflows/             # GitHub Actions 工作流
│   ├── build-windows.yml
│   └── build-multiplatform.yml
└── README-ACTIONS.md      # Actions 使用说明

scripts/
├── release.sh             # 发布脚本 (Unix)
└── release.bat            # 发布脚本 (Windows)
```

## 🤝 贡献

1. Fork 本仓库
2. 创建特性分支 (`git checkout -b feature/AmazingFeature`)
3. 提交更改 (`git commit -m 'Add some AmazingFeature'`)
4. 推送到分支 (`git push origin feature/AmazingFeature`)
5. 创建 Pull Request

## 📄 许可证

本项目采用 MIT 许可证 - 查看 [LICENSE](LICENSE) 文件了解详情。

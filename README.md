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
- ✅ Windows (x64)
- ✅ macOS (Apple Silicon)
- ⚠️ Linux (可选)

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

# Titillium Web 字体文件

本项目使用 Titillium Web 作为全局字体。

## 字体文件获取

### 方法一：从 Google Fonts 下载
1. 访问 [Google Fonts - Titillium Web](https://fonts.google.com/specimen/Titillium+Web)
2. 点击 "Download family" 下载字体包
3. 解压后将以下文件复制到 `assets/fonts/` 目录：
   - `TitilliumWeb-Regular.ttf`
   - `TitilliumWeb-Bold.ttf`
   - `TitilliumWeb-Light.ttf`
   - `TitilliumWeb-SemiBold.ttf`

### 方法二：从 GitHub 下载
1. 访问 [Titillium Web GitHub](https://github.com/google/fonts/tree/main/ofl/titilliumweb)
2. 下载所需的 .ttf 文件

## 需要的字体文件

将以下文件放置在 `assets/fonts/` 目录中：

```
assets/fonts/
├── TitilliumWeb-Regular.ttf     # 常规字重
├── TitilliumWeb-Bold.ttf        # 粗体
├── TitilliumWeb-Light.ttf       # 细体
├── TitilliumWeb-SemiBold.ttf    # 半粗体
├── TitilliumWeb-Italic.ttf      # 斜体 (可选)
└── TitilliumWeb-BoldItalic.ttf  # 粗斜体 (可选)
```

## 字体配置

字体已在 `pubspec.yaml` 中配置：

```yaml
flutter:
  fonts:
    - family: Titillium Web
      fonts:
        - asset: assets/fonts/TitilliumWeb-Regular.ttf
          weight: 400
        - asset: assets/fonts/TitilliumWeb-Light.ttf
          weight: 300
        - asset: assets/fonts/TitilliumWeb-SemiBold.ttf
          weight: 600
        - asset: assets/fonts/TitilliumWeb-Bold.ttf
          weight: 700
```

## 字体特性

Titillium Web 是一款现代的无衬线字体，具有以下特点：

- **设计风格**：现代、简洁、易读
- **字符支持**：拉丁字符、数字、标点符号
- **字重范围**：200-900
- **开源许可**：SIL Open Font License

## 使用说明

字体配置完成后，应用程序将自动使用 Titillium Web 作为默认字体。如果系统中没有安装该字体，Flutter 会使用内置的字体文件。

### 在代码中使用

```dart
// 全局字体已配置，无需额外设置
Text('Hello World')

// 指定特定字重
Text(
  'Bold Text',
  style: TextStyle(
    fontWeight: FontWeight.bold,
    fontFamily: 'Titillium Web',
  ),
)
```

## 备用字体

如果 Titillium Web 字体文件不可用，系统将回退到以下字体：

1. **Windows**: Segoe UI
2. **macOS**: San Francisco
3. **Linux**: Ubuntu / Roboto
4. **通用**: sans-serif

## 许可证

Titillium Web 字体采用 SIL Open Font License 1.1 许可证，允许免费使用、修改和分发。

## 故障排除

### 字体未生效
1. 确认字体文件已正确放置在 `assets/fonts/` 目录
2. 检查 `pubspec.yaml` 中的字体配置
3. 运行 `flutter clean && flutter pub get`
4. 重新构建应用程序

### 字体文件缺失
如果某些字重的字体文件缺失，Flutter 会自动使用最接近的可用字重。

### 构建错误
如果出现字体相关的构建错误：
1. 检查字体文件路径是否正确
2. 确认字体文件格式为 .ttf
3. 验证 pubspec.yaml 语法是否正确

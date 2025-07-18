# 全局字体更换为 Titillium Web Sans-Serif

## 概述

本项目已将全局字体更换为 **Titillium Web**，这是一款现代、简洁的无衬线字体，提供更好的阅读体验和视觉效果。

## 字体特性

### Titillium Web 特点
- **设计风格**: 现代、简洁、几何化
- **字体类型**: Sans-serif (无衬线)
- **字符支持**: 拉丁字符、数字、标点符号
- **字重范围**: 300-700 (Light, Regular, SemiBold, Bold)
- **开源许可**: SIL Open Font License 1.1

### 视觉优势
- 🔤 **更好的可读性**: 在各种屏幕尺寸上都清晰易读
- 🎨 **现代美感**: 简洁的几何设计符合现代 UI 趋势
- 📱 **跨平台一致性**: 在不同操作系统上保持一致的外观
- ⚡ **性能优化**: 优化的字体文件，加载速度快

## 实施详情

### 1. 字体文件配置

#### 下载的字体文件
```
assets/fonts/
├── TitilliumWeb-Light.ttf      # 300 weight
├── TitilliumWeb-Regular.ttf    # 400 weight (默认)
├── TitilliumWeb-SemiBold.ttf   # 600 weight
└── TitilliumWeb-Bold.ttf       # 700 weight
```

#### pubspec.yaml 配置
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

### 2. 应用程序配置

#### main.dart 主题设置
```dart
MaterialApp(
  theme: ThemeData(
    colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
    useMaterial3: true,
    fontFamily: 'Titillium Web',
    textTheme: const TextTheme().apply(
      fontFamily: 'Titillium Web',
    ),
  ),
)
```

### 3. 自动化脚本

#### Unix/macOS/Linux
```bash
./scripts/download-fonts.sh
```

#### Windows
```cmd
scripts\download-fonts.bat
```

## 使用方法

### 自动应用
字体配置完成后，整个应用程序将自动使用 Titillium Web 字体，无需额外代码修改。

### 手动指定字重
```dart
// 使用不同字重
Text(
  'Light Text',
  style: TextStyle(
    fontWeight: FontWeight.w300,  // Light
    fontFamily: 'Titillium Web',
  ),
)

Text(
  'Regular Text',
  style: TextStyle(
    fontWeight: FontWeight.w400,  // Regular (默认)
    fontFamily: 'Titillium Web',
  ),
)

Text(
  'SemiBold Text',
  style: TextStyle(
    fontWeight: FontWeight.w600,  // SemiBold
    fontFamily: 'Titillium Web',
  ),
)

Text(
  'Bold Text',
  style: TextStyle(
    fontWeight: FontWeight.w700,  // Bold
    fontFamily: 'Titillium Web',
  ),
)
```

## 安装和配置

### 首次设置
1. **下载字体文件**:
   ```bash
   # Unix/macOS/Linux
   ./scripts/download-fonts.sh
   
   # Windows
   scripts\download-fonts.bat
   ```

2. **安装依赖**:
   ```bash
   flutter pub get
   ```

3. **清理缓存**:
   ```bash
   flutter clean
   ```

4. **重新构建**:
   ```bash
   flutter run
   ```

### 验证安装
运行应用程序后，所有文本应该显示为 Titillium Web 字体。可以通过以下方式验证：

1. **视觉检查**: 文本应该显示为现代的无衬线字体
2. **开发者工具**: 在调试模式下检查字体渲染
3. **不同字重**: 测试粗体、细体等不同字重的显示效果

## 备用字体策略

如果 Titillium Web 字体不可用，系统将按以下顺序回退：

1. **Titillium Web** (首选)
2. **系统默认 Sans-serif**:
   - Windows: Segoe UI
   - macOS: San Francisco
   - Linux: Ubuntu/Roboto
3. **通用 sans-serif**

## 性能影响

### 字体文件大小
- **总大小**: ~250KB (4个字重文件)
- **单个文件**: 60-64KB 平均
- **加载时间**: 首次加载 <1秒

### 内存使用
- **运行时内存**: 增加约 1-2MB
- **缓存策略**: Flutter 自动缓存已加载的字体
- **性能优化**: 只加载实际使用的字重

## 故障排除

### 字体未生效
1. **检查文件路径**: 确认字体文件在 `assets/fonts/` 目录
2. **验证配置**: 检查 `pubspec.yaml` 中的字体配置
3. **重新构建**: 运行 `flutter clean && flutter pub get`
4. **重启应用**: 完全重启应用程序

### 字体文件缺失
```bash
# 重新下载字体文件
./scripts/download-fonts.sh  # Unix/macOS/Linux
scripts\download-fonts.bat   # Windows
```

### 构建错误
1. **语法检查**: 验证 `pubspec.yaml` 缩进和语法
2. **文件格式**: 确认字体文件为 `.ttf` 格式
3. **路径检查**: 验证 asset 路径是否正确

## 自定义和扩展

### 添加更多字重
如需添加更多字重（如 ExtraLight, Black 等）：

1. **下载字体文件**: 从 Google Fonts 获取
2. **更新 pubspec.yaml**: 添加新的字重配置
3. **重新构建**: 运行 `flutter pub get`

### 字体回退配置
```dart
TextStyle(
  fontFamily: 'Titillium Web',
  fontFamilyFallback: ['Roboto', 'Arial', 'sans-serif'],
)
```

## 许可证信息

Titillium Web 字体采用 **SIL Open Font License 1.1**，允许：
- ✅ 免费使用
- ✅ 商业使用
- ✅ 修改和分发
- ✅ 嵌入到应用程序中

## 相关资源

- [Google Fonts - Titillium Web](https://fonts.google.com/specimen/Titillium+Web)
- [SIL Open Font License](https://scripts.sil.org/OFL)
- [Flutter 自定义字体文档](https://docs.flutter.dev/cookbook/design/fonts)

---

**实施日期**: 2025-01-16  
**字体版本**: Titillium Web (Google Fonts)  
**影响范围**: 全局应用程序字体

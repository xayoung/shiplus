# Windows 可执行文件路径修复

## 问题描述

Windows 平台打包后运行时提示：
```
N_m3u8DL-RE可执行文件不存在
```

## 根本原因

### 代码分析

在 `lib/ffi/n_m3u8dl_re.dart` 中，`_execPath` 方法对 Windows 平台的处理有问题：

#### 原始代码（有问题）
```dart
static Future<String> get _execPath async {
  if (Platform.isWindows) {
    return 'N_m3u8DL-RE.exe';  // ❌ 只返回文件名，不是完整路径
  }
  
  // macOS/Linux 的处理逻辑...
}
```

#### 问题分析
1. **Windows 特殊处理**：代码直接返回 `'N_m3u8DL-RE.exe'`，这只是文件名
2. **缺少路径解析**：没有从 assets 中提取到应用程序目录
3. **不一致的逻辑**：macOS/Linux 有完整的 assets 提取逻辑，但 Windows 没有

### 实际需求

Windows 应用程序需要：
1. 从 `assets/bin/N_m3u8DL-RE.exe` 提取可执行文件
2. 保存到应用程序支持目录
3. 返回完整的文件路径

## 解决方案

### 1. 统一平台处理逻辑

将 Windows 平台纳入统一的 assets 提取流程：

```dart
static Future<String> get _execPath async {
  // 获取应用程序的支持目录
  final appSupportDir = await getApplicationSupportDirectory();
  if (!appSupportDir.existsSync()) {
    appSupportDir.createSync(recursive: true);
  }

  // 确定可执行文件名和路径
  final execName = Platform.isWindows ? 'N_m3u8DL-RE.exe' : 'N_m3u8DL-RE';
  final execInAppSupport = File('${appSupportDir.path}/$execName');
  
  // 统一的 assets 提取逻辑...
}
```

### 2. 修复 ffmpeg 路径问题

`_ffmpegPath` 方法也有同样的问题，需要同样的修复：

```dart
static Future<String> get _ffmpegPath async {
  // 获取应用程序的支持目录
  final appSupportDir = await getApplicationSupportDirectory();
  if (!appSupportDir.existsSync()) {
    appSupportDir.createSync(recursive: true);
  }

  // 确定ffmpeg可执行文件名和路径
  final ffmpegName = Platform.isWindows ? 'ffmpeg.exe' : 'ffmpeg';
  final ffmpegInAppSupport = File('${appSupportDir.path}/$ffmpegName');
  
  // 统一的 assets 提取逻辑...
}
```

## 修复效果

### 修复前的行为
1. ❌ Windows: 返回 `'N_m3u8DL-RE.exe'`（相对路径）
2. ✅ macOS/Linux: 返回完整路径，如 `/path/to/app/support/N_m3u8DL-RE`

### 修复后的行为
1. ✅ Windows: 返回完整路径，如 `C:\Users\...\AppData\Local\shiplus\N_m3u8DL-RE.exe`
2. ✅ macOS/Linux: 保持原有行为不变

## 技术细节

### Assets 提取流程

1. **检查目标文件是否存在**
   ```dart
   if (!execInAppSupport.existsSync()) {
   ```

2. **从 assets 加载文件数据**
   ```dart
   final ByteData data = await rootBundle.load(assetPath);
   final Uint8List bytes = data.buffer.asUint8List();
   ```

3. **写入到应用程序支持目录**
   ```dart
   await execInAppSupport.writeAsBytes(bytes);
   ```

4. **设置可执行权限**（仅 Unix 平台）
   ```dart
   if (Platform.isMacOS || Platform.isLinux) {
     await Process.run('chmod', ['755', execInAppSupport.path]);
   }
   ```

### 平台特定处理

#### Windows
- 文件名：`N_m3u8DL-RE.exe`, `ffmpeg.exe`
- 不需要设置可执行权限
- 使用 Windows 路径分隔符

#### macOS/Linux
- 文件名：`N_m3u8DL-RE`, `ffmpeg`
- 需要设置可执行权限 (755)
- 使用 Unix 路径分隔符

## 验证方法

### 1. 本地测试
```dart
// 在 Windows 上测试
final execPath = await N_m3u8DL_RE._execPath;
print('Executable path: $execPath');
// 应该输出类似：C:\Users\...\AppData\Local\shiplus\N_m3u8DL-RE.exe

final ffmpegPath = await N_m3u8DL_RE._ffmpegPath;
print('FFmpeg path: $ffmpegPath');
// 应该输出类似：C:\Users\...\AppData\Local\shiplus\ffmpeg.exe
```

### 2. 文件存在性检查
```dart
final execFile = File(execPath);
assert(execFile.existsSync(), 'Executable file should exist');

final ffmpegFile = File(ffmpegPath);
assert(ffmpegFile.existsSync(), 'FFmpeg file should exist');
```

### 3. 下载功能测试
- 启动应用程序
- 尝试下载视频
- 确认不再出现"可执行文件不存在"错误

## 相关文件

### 修改的文件
- `lib/ffi/n_m3u8dl_re.dart` - 主要修复文件

### 依赖的 Assets
- `assets/bin/N_m3u8DL-RE.exe` - Windows 版本的 N_m3u8DL-RE
- `assets/bin/ffmpeg.exe` - Windows 版本的 FFmpeg
- `assets/bin/N_m3u8DL-RE` - macOS/Linux 版本的 N_m3u8DL-RE
- `assets/bin/ffmpeg` - macOS/Linux 版本的 FFmpeg

## 注意事项

### 1. 首次运行
- 应用程序首次运行时会从 assets 提取可执行文件
- 这个过程可能需要几秒钟时间
- 后续运行会直接使用已提取的文件

### 2. 权限问题
- Windows 通常不需要特殊的可执行权限
- macOS/Linux 需要设置 755 权限
- 某些安全软件可能会阻止可执行文件的提取

### 3. 存储位置
- 文件存储在应用程序支持目录
- Windows: `%LOCALAPPDATA%\shiplus\`
- macOS: `~/Library/Application Support/shiplus/`
- Linux: `~/.local/share/shiplus/`

## 回滚方案

如果修复导致其他问题，可以临时回滚：

```dart
static Future<String> get _execPath async {
  if (Platform.isWindows) {
    return 'N_m3u8DL-RE.exe';
  }
  // 保持原有的 macOS/Linux 逻辑
}
```

但这只是临时方案，根本问题仍然存在。

---

**修复日期**: 2025-01-16  
**影响平台**: Windows  
**预期效果**: 解决 Windows 平台可执行文件路径问题

# N_m3u8DL-RE 配置功能实现

## 功能概述

实现了 N_m3u8DL-RE 下载服务的可配置参数功能，用户可以在 Settings 页面中配置输出格式和字幕处理选项。

## 实现的配置项

### 1. 输出格式 (format)
- **可选值**: `mp4`, `mkv`
- **默认值**: `mp4`
- **说明**: 设置下载视频的输出容器格式

### 2. 跳过字幕 (skip_sub)
- **可选值**: `true`, `false`
- **默认值**: `true`
- **说明**: 是否跳过字幕文件的下载

## 技术实现

### 1. 配置服务 (`N_m3u8dlConfigService`)

#### 核心方法
```dart
// 获取/设置输出格式
static Future<String> getFormat()
static Future<void> setFormat(String format)

// 获取/设置跳过字幕选项
static Future<bool> getSkipSub()
static Future<void> setSkipSub(bool skipSub)

// 生成完整的 -M 参数
static Future<String> getMuxerParameter()

// 重置为默认配置
static Future<void> resetToDefaults()
```

#### 参数生成逻辑
```dart
// 默认配置生成: "format=mp4:muxer=ffmpeg:skip_sub=true"
// 自定义配置示例: "format=mkv:muxer=ffmpeg" (skip_sub=false时)
```

### 2. Settings 页面集成

#### UI 组件
- **格式选择**: 下拉菜单选择 MP4 或 MKV
- **字幕开关**: Switch 组件控制是否跳过字幕
- **保存按钮**: 保存当前配置到本地存储
- **重置按钮**: 恢复默认配置

#### 配置持久化
使用 `SharedPreferences` 存储用户配置，应用重启后配置保持不变。

### 3. 下载服务集成

#### 参数应用
```dart
// 在 n_m3u8dl_re.dart 中
final muxerParameter = await N_m3u8dlConfigService.getMuxerParameter();

final arguments = [
  // ... 其他参数
  '-M', muxerParameter,  // 应用用户配置
  // ... 其他参数
];
```

## 文件结构

### 新增文件
```
lib/services/n_m3u8dl_config_service.dart  # 配置服务
test/n_m3u8dl_config_test.dart             # 配置测试
.github/N_M3U8DL_CONFIG_FEATURE.md         # 功能文档
```

### 修改文件
```
lib/ffi/n_m3u8dl_re.dart                   # 集成配置服务
lib/widgets/settings_page.dart             # 添加配置UI
pubspec.yaml                               # 添加 shared_preferences 依赖
```

## 用户使用流程

### 1. 配置设置
1. 打开应用程序
2. 导航到 "Settings" 页面
3. 在 "下载配置" 卡片中调整设置：
   - 选择输出格式 (MP4/MKV)
   - 开启/关闭跳过字幕
4. 点击 "保存配置" 按钮

### 2. 配置应用
1. 配置保存后，所有新的下载任务将使用新配置
2. 正在进行的下载任务不受影响
3. 配置在应用重启后保持有效

### 3. 重置配置
1. 在 Settings 页面点击 "重置默认" 按钮
2. 配置将恢复为默认值 (MP4, 跳过字幕)

## 配置效果对比

### 默认配置
```bash
N_m3u8DL-RE.exe [url] -M "format=mp4:muxer=ffmpeg:skip_sub=true"
```
- 输出: MP4 格式
- 字幕: 跳过下载

### 自定义配置示例
```bash
# 配置: format=mkv, skip_sub=false
N_m3u8DL-RE.exe [url] -M "format=mkv:muxer=ffmpeg"
```
- 输出: MKV 格式
- 字幕: 包含下载

## 测试覆盖

### 单元测试
- ✅ 默认值获取测试
- ✅ 配置保存和读取测试
- ✅ 参数生成测试
- ✅ 配置重置测试
- ✅ 格式验证测试
- ✅ 完整配置获取测试

### 测试运行
```bash
flutter test test/n_m3u8dl_config_test.dart
```

## 错误处理

### 配置加载失败
- 显示错误提示
- 使用默认配置作为回退

### 配置保存失败
- 显示错误提示
- 保持当前UI状态

### 无效格式处理
- 格式验证确保只接受支持的格式
- 下拉菜单限制用户选择

## 性能考虑

### 配置读取
- 配置在应用启动时加载一次
- 下载时异步获取，不阻塞UI

### 存储开销
- 配置数据很小 (<1KB)
- 使用 SharedPreferences 高效存储

## 扩展性

### 添加新配置项
1. 在 `N_m3u8dlConfigService` 中添加新的 getter/setter
2. 更新 `getMuxerParameter()` 方法
3. 在 Settings 页面添加对应的UI组件
4. 添加相应的测试

### 支持更多格式
1. 更新 `getSupportedFormats()` 方法
2. 更新格式验证逻辑
3. 测试新格式的兼容性

## 已知限制

1. **格式支持**: 目前只支持 MP4 和 MKV 格式
2. **参数范围**: 只配置了 format 和 skip_sub 参数
3. **实时应用**: 配置更改不影响正在进行的下载

## 未来改进

1. **更多格式**: 支持 AVI, MOV 等格式
2. **高级参数**: 添加视频质量、音频质量等配置
3. **配置模板**: 预设多种配置模板供用户选择
4. **导入导出**: 支持配置的导入和导出功能

---

**实施日期**: 2025-01-16  
**版本**: v1.0.0  
**测试状态**: ✅ 通过  
**文档状态**: ✅ 完整

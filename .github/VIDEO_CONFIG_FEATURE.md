# 视频配置功能实现

## 功能概述

为 N_m3u8DL-RE 下载配置新增了两个重要功能：视频分辨率选择和动态范围选择，用户可以在 Settings 页面中配置这些参数来控制视频下载质量。

## 新增配置项

### 1. 视频分辨率 (Resolution)
- **可选值**: `480`, `512`, `640`, `960`, `1280`, `1920`, `2560`, `3840`
- **默认值**: `3840` (4K)
- **说明**: 设置下载视频的最大分辨率
- **UI显示**: 下拉菜单显示为 "480p", "1920p", "3840p" 等

### 2. 动态范围 (Range)
- **可选值**: `SDR`, `HLG`
- **默认值**: `SDR`
- **说明**: 设置视频的动态范围类型
  - **SDR**: Standard Dynamic Range (标准动态范围)
  - **HLG**: Hybrid Log-Gamma (混合对数伽马)

## 技术实现

### 1. 配置服务扩展 (`N_m3u8dlConfigService`)

#### 新增配置字段
```dart
// 默认值
static const String defaultResolution = '3840';
static const String defaultRange = 'SDR';

// 内存存储
static String _resolution = defaultResolution;
static String _range = defaultRange;
```

#### 核心方法
```dart
// 分辨率配置
static Future<String> getResolution() async
static Future<void> setResolution(String resolution) async

// 动态范围配置
static Future<String> getRange() async
static Future<void> setRange(String range) async

// 视频选择参数生成
static Future<String> getVideoSelectParameter() async
```

#### 参数生成逻辑
```dart
/// 生成 -sv 参数：res="分辨率*":range=动态范围:for=best
static Future<String> getVideoSelectParameter() async {
  final resolution = await getResolution();
  final range = await getRange();
  
  return 'res="$resolution*":range=$range:for=best';
}
```

### 2. 下载服务集成

#### 参数应用
```dart
// 在 n_m3u8dl_re.dart 中
final videoSelectParameter = await N_m3u8dlConfigService.getVideoSelectParameter();
final skipSub = await N_m3u8dlConfigService.getSkipSub();

final fullArgs = [
  // ... 其他参数
  '-sv', videoSelectParameter,  // 应用视频选择配置
  '-sa', 'best',
];

// 只有当不跳过字幕时才添加字幕选择参数
if (!skipSub) {
  fullArgs.add('-ss');
  fullArgs.add('all');
}
```

### 3. Settings 页面集成

#### UI 组件
- **分辨率选择**: 下拉菜单选择分辨率
- **动态范围选择**: 下拉菜单选择 SDR 或 HLG
- **保存按钮**: 保存所有配置到内存
- **重置按钮**: 恢复所有默认配置

#### 配置持久化
使用内存存储，配置在当前会话中保持有效。

## 参数效果对比

### 默认配置
```bash
N_m3u8DL-RE.exe [url] -sv "res=\"3840*\":range=SDR:for=best"
```
- 分辨率: 最高 4K (3840p)
- 动态范围: 标准动态范围 (SDR)

### 自定义配置示例
```bash
# 配置: resolution=1920, range=HLG
N_m3u8DL-RE.exe [url] -sv "res=\"1920*\":range=HLG:for=best"
```
- 分辨率: 最高 1080p (1920p)
- 动态范围: 混合对数伽马 (HLG)

### 低分辨率配置
```bash
# 配置: resolution=480, range=SDR
N_m3u8DL-RE.exe [url] -sv "res=\"480*\":range=SDR:for=best"
```
- 分辨率: 最高 480p
- 动态范围: 标准动态范围 (SDR)

## 用户使用流程

### 1. 配置设置
1. 打开应用程序
2. 导航到 "Settings" 页面
3. 在 "下载配置" 部分调整设置：
   - 选择视频分辨率 (480p-3840p)
   - 选择动态范围 (SDR/HLG)
   - 设置其他选项 (格式、字幕)
4. 点击 "保存配置" 应用更改

### 2. 配置应用
1. 配置保存后，所有新的下载任务将使用新配置
2. 正在进行的下载任务不受影响
3. 配置在应用重启后重置为默认值

### 3. 重置配置
1. 在 Settings 页面点击 "重置默认" 按钮
2. 所有配置将恢复为默认值

## 分辨率选择指南

### 分辨率对比
| 分辨率 | 像素 | 常用名称 | 适用场景 |
|--------|------|----------|----------|
| 480 | 854×480 | 480p/SD | 低带宽、快速下载 |
| 512 | 910×512 | - | 特殊格式 |
| 640 | 1138×640 | - | 特殊格式 |
| 960 | 1706×960 | - | 特殊格式 |
| 1280 | 1280×720 | 720p/HD | 标清高质量 |
| 1920 | 1920×1080 | 1080p/FHD | 全高清 |
| 2560 | 2560×1440 | 1440p/QHD | 2K 高清 |
| 3840 | 3840×2160 | 2160p/4K | 超高清 |

### 选择建议
- **快速下载**: 选择 480p 或 720p
- **平衡质量**: 选择 1080p
- **最佳质量**: 选择 4K (如果源支持)
- **存储空间有限**: 选择较低分辨率

## 动态范围说明

### SDR (Standard Dynamic Range)
- **特点**: 标准动态范围，兼容性最好
- **适用**: 大多数设备和播放器
- **推荐**: 一般用户的默认选择

### HLG (Hybrid Log-Gamma)
- **特点**: 高动态范围，更好的色彩和对比度
- **适用**: 支持 HDR 的现代设备
- **推荐**: 有 HDR 显示设备的用户

## 测试覆盖

### 单元测试
- ✅ 分辨率配置保存和读取测试
- ✅ 动态范围配置保存和读取测试
- ✅ 视频选择参数生成测试
- ✅ 配置重置测试
- ✅ 支持列表验证测试

### 参数生成测试
```dart
// 默认配置测试
expect(parameter, equals('res="3840*":range=SDR:for=best'));

// 自定义配置测试
expect(parameter, equals('res="1920*":range=HLG:for=best'));
```

### 测试运行结果
```
00:01 +15: All tests passed!
```

## 性能考虑

### 配置读取
- 配置在内存中存储，读取速度极快
- 下载时异步获取，不阻塞UI

### 存储开销
- 新增配置数据很小 (<100 bytes)
- 使用内存存储，无 I/O 开销

### 下载性能
- 分辨率选择直接影响下载文件大小
- 较低分辨率可显著减少下载时间和存储空间

## 扩展性

### 添加新分辨率
1. 在 `getSupportedResolutions()` 方法中添加新值
2. 更新 UI 下拉菜单
3. 添加相应的测试

### 添加新动态范围
1. 在 `getSupportedRanges()` 方法中添加新值
2. 更新 UI 下拉菜单
3. 验证 N_m3u8DL-RE 支持

### 高级参数
未来可以考虑添加：
- 视频编码器选择
- 音频质量设置
- 帧率限制
- 色彩空间选择

## 已知限制

1. **分辨率支持**: 实际可用分辨率取决于视频源
2. **动态范围**: HLG 需要源和播放设备都支持
3. **配置持久化**: 配置在应用重启后重置
4. **实时应用**: 配置更改不影响正在进行的下载

## 未来改进

1. **智能分辨率**: 根据网络速度自动选择最佳分辨率
2. **预设模板**: 提供"快速下载"、"高质量"等预设
3. **配置持久化**: 添加可选的配置文件保存
4. **高级选项**: 支持更多 N_m3u8DL-RE 参数

---

**实施日期**: 2025-01-16  
**版本**: v2.0.0  
**测试状态**: ✅ 通过  
**文档状态**: ✅ 完整

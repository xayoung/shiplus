# 取消并删除下载任务功能实现

## 功能改进

将原来的"取消下载任务"功能改进为"取消并删除下载任务"，用户点击取消按钮后，不仅会中断下载进程，还会直接从任务列表中删除该任务。

## 实现详情

### 1. 修改 GlobalDownloadManager.cancelDownload 方法

#### 原来的实现
```dart
/// 取消下载任务
void cancelDownload(String taskId) {
  final taskIndex = _downloadTasks.indexWhere((task) => task.id == taskId);
  if (taskIndex == -1) return;

  // 尝试取消正在运行的进程
  final processKilled = N_m3u8DL_RE.cancelDownload(taskId);

  _downloadTasks[taskIndex] = _downloadTasks[taskIndex].copyWith(
    status: DownloadStatus.cancelled,
  );
  notifyListeners();

  if (processKilled) {
    _logControllers[taskId]?.add('⏹️ 下载进程已中断');
  } else {
    _logControllers[taskId]?.add('⏹️ 下载已标记为取消');
  }
}
```

#### 新的实现
```dart
/// 取消下载任务并删除
void cancelDownload(String taskId) {
  final taskIndex = _downloadTasks.indexWhere((task) => task.id == taskId);
  if (taskIndex == -1) return;

  // 尝试取消正在运行的进程
  final processKilled = N_m3u8DL_RE.cancelDownload(taskId);

  // 记录取消日志
  if (processKilled) {
    _logControllers[taskId]?.add('⏹️ 下载进程已中断，任务已删除');
  } else {
    _logControllers[taskId]?.add('⏹️ 下载已取消，任务已删除');
  }

  // 直接删除任务而不是更改状态
  removeDownloadTask(taskId);
}
```

### 2. 更新 UI 提示信息

#### 下载管理页面
- **按钮提示**: 从 "取消" 改为 "取消并删除"
- **成功消息**: 从 "已取消下载" 改为 "已取消并删除下载"
- **日志消息**: 明确说明任务已被删除

```dart
if (task.canCancel)
  IconButton(
    icon: const Icon(Icons.stop, size: 20),
    onPressed: () {
      GlobalDownloadManager().cancelDownload(task.id);
      _showSuccessSnackBar('已取消并删除下载: ${task.title}');
    },
    tooltip: '取消并删除',
  ),
```

## 功能对比

### 原来的行为
1. 用户点击取消按钮
2. 中断下载进程
3. 任务状态变为 `cancelled`
4. 任务仍然保留在列表中
5. 用户需要手动点击删除按钮来移除任务

### 新的行为
1. 用户点击取消按钮
2. 中断下载进程
3. 任务直接从列表中删除
4. 清理所有相关资源（日志流、进度流等）
5. 一步完成取消和删除操作

## 用户体验改进

### 1. 操作简化
- **原来**: 取消 → 删除（两步操作）
- **现在**: 取消并删除（一步操作）

### 2. 界面清洁
- 不会在列表中留下已取消的任务
- 减少界面混乱
- 用户不需要额外的清理操作

### 3. 资源管理
- 立即释放任务相关的内存资源
- 自动清理日志和进度流
- 避免无用数据积累

## 技术实现

### 1. 进程管理
```dart
// 中断正在运行的 n_m3u8dl_re 进程
final processKilled = N_m3u8DL_RE.cancelDownload(taskId);
```

### 2. 资源清理
```dart
// removeDownloadTask 方法会自动清理：
// - 从任务列表中移除任务
// - 关闭日志流控制器
// - 关闭进度流控制器
// - 清理相关的 Map 条目
removeDownloadTask(taskId);
```

### 3. 状态通知
```dart
// removeDownloadTask 内部会调用 notifyListeners()
// 确保 UI 立即更新
```

## 边界情况处理

### 1. 任务不存在
```dart
final taskIndex = _downloadTasks.indexWhere((task) => task.id == taskId);
if (taskIndex == -1) return; // 安全退出
```

### 2. 进程已结束
- 即使进程已经结束，任务仍会被删除
- 日志会显示相应的状态信息

### 3. 重复操作
- 由于任务被删除，重复点击不会有副作用
- UI 状态会立即更新，按钮消失

## 与其他功能的关系

### 1. 重试功能
- 取消并删除的任务无法重试
- 这是合理的，因为任务已经不存在

### 2. 清理完成任务功能
- 不再需要清理已取消的任务
- 因为它们已经被自动删除

### 3. 删除按钮
- 删除按钮仍然保留
- 用于删除已完成或失败的任务
- 取消按钮和删除按钮功能互补

## 安全性考虑

### 1. 数据一致性
- 确保进程中断和任务删除的原子性
- 避免出现进程已停止但任务仍存在的情况

### 2. 资源泄漏防护
- 自动清理所有相关资源
- 防止内存泄漏
- 确保流控制器正确关闭

### 3. 用户确认
- 当前实现是直接删除
- 如果需要，可以添加确认对话框
- 但考虑到用户意图明确，直接删除更符合预期

## 测试场景

### 1. 正常取消
1. 开始一个下载任务
2. 在下载过程中点击取消按钮
3. 验证：
   - 进程被中断
   - 任务从列表中消失
   - 显示成功消息
   - 相关资源被清理

### 2. 快速操作
1. 开始下载后立即取消
2. 验证操作的响应性和正确性

### 3. 多任务场景
1. 同时运行多个下载任务
2. 取消其中一个
3. 验证其他任务不受影响

## 总结

这个改进显著提升了用户体验：

✅ **操作简化**: 一键完成取消和删除
✅ **界面清洁**: 不留下无用的已取消任务
✅ **资源优化**: 立即释放相关资源
✅ **逻辑清晰**: 取消即删除，符合用户直觉
✅ **实现安全**: 完善的错误处理和资源清理

用户现在可以通过一次点击就完成取消下载并删除任务的操作，无需额外的清理步骤。

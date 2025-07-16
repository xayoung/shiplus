# macOS 构建架构变更说明

## 变更内容

将 macOS 构建从 Universal (通用) 架构改为仅支持 Apple Silicon (ARM64) 架构。

## 变更原因

1. **目标用户群体**：现代 Mac 用户主要使用 M 系列芯片
2. **构建效率**：减少构建时间和产物大小
3. **维护简化**：专注于主流架构，减少兼容性问题
4. **性能优化**：针对 Apple Silicon 优化的原生性能

## 技术变更

### GitHub Actions 工作流
- **文件**: `.github/workflows/build-multiplatform.yml`
- **变更**: 
  - 构建名称：`Build macOS Release (Apple Silicon)`
  - 产物名称：`shiplus-macos-arm64.zip`
  - 移除 Universal 构建参数

### 系统要求更新
- **之前**: macOS 10.14+ (Intel 或 Apple Silicon)
- **现在**: macOS 11.0+ (Apple Silicon 仅)

### 文档更新
- `README.md` - 更新系统要求和构建说明
- `.github/README-ACTIONS.md` - 更新构建产物说明

## 影响范围

### ✅ 支持的设备
- MacBook Air (M1, M2, M3)
- MacBook Pro (M1, M2, M3)
- iMac (M1, M3)
- Mac mini (M1, M2)
- Mac Studio (M1, M2)
- Mac Pro (M2)

### ❌ 不再支持的设备
- Intel 芯片的 Mac 设备 (2020 年之前的大部分机型)

## 用户指南

### 如何检查你的 Mac 芯片类型
1. 点击左上角苹果菜单 → "关于本机"
2. 查看"芯片"或"处理器"信息：
   - 显示 "Apple M1/M2/M3" → ✅ 支持
   - 显示 "Intel" → ❌ 不支持

### Intel Mac 用户的替代方案
1. **本地构建**：
   ```bash
   flutter build macos --release
   ```

2. **使用 Rosetta 2**（可能性能较差）：
   - 下载 ARM64 版本
   - 通过 Rosetta 2 运行（系统会自动处理）

3. **升级硬件**：考虑升级到 Apple Silicon Mac

## 回滚方案

如需恢复 Universal 构建，可以：

1. **修改工作流文件**：
   ```yaml
   - name: Build macOS Release (Universal)
     run: flutter build macos --release --verbose
   ```

2. **更新产物名称**：
   ```yaml
   name: shiplus-macos-universal
   path: shiplus-macos-universal.zip
   ```

3. **恢复系统要求**：
   - macOS 10.14+ (Intel 或 Apple Silicon)

## 性能预期

### Apple Silicon 原生构建优势
- 🚀 **启动速度**：提升 20-30%
- 🔋 **电池续航**：降低 15-25% 功耗
- 💾 **内存效率**：优化内存使用
- 🎯 **原生性能**：无需转译开销

### 构建产物变化
- **文件大小**：减少约 50%（无需包含 Intel 代码）
- **构建时间**：减少约 30%
- **下载速度**：更快的分发

## 监控和反馈

### 关键指标
- 构建成功率
- 用户下载量
- 性能反馈
- 兼容性问题报告

### 反馈渠道
- GitHub Issues
- 用户反馈表单
- 性能监控数据

## 时间线

- **立即生效**：新的构建流程
- **1 周后**：收集用户反馈
- **1 月后**：评估变更效果
- **按需调整**：根据反馈优化

## 注意事项

1. **现有用户**：已安装的应用不受影响
2. **新下载**：只能在 Apple Silicon Mac 上运行
3. **开发环境**：本地开发不受影响
4. **CI/CD**：GitHub Actions 使用 Apple Silicon runner

---

**变更日期**: 2025-01-16  
**影响版本**: v1.0.0+  
**负责人**: 开发团队

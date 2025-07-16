# 全局 Dio 配置与 Cookie 管理

## 功能概述

已成功为项目新增全局 Dio 配置，并集成了 Cookie 管理功能。所有网络请求现在都使用统一的配置，支持自动 Cookie 管理、请求重试、日志记录等功能。

## 主要特性

### 1. 全局 Dio 实例
- **单例模式**: 确保整个应用使用同一个 Dio 实例
- **统一配置**: 所有网络请求共享相同的基础配置
- **自动初始化**: 应用启动时自动初始化 HTTP 服务

### 2. Cookie 管理
- **自动 Cookie 管理**: `dio.interceptors.add(CookieManager(CookieJar()))`
- **持久化存储**: Cookie 自动保存到本地文件系统
- **跨请求共享**: 所有请求自动携带相关 Cookie
- **域名隔离**: 不同域名的 Cookie 自动隔离管理

### 3. 请求拦截器
- **日志记录**: 自动记录请求和响应信息
- **错误处理**: 统一的错误处理和日志记录
- **自动重试**: 网络超时时自动重试（最多3次）

## 技术实现

### 依赖配置
```yaml
dependencies:
  dio: ^5.4.0
  dio_cookie_manager: ^3.1.1
  cookie_jar: ^4.0.8
```

### 核心文件

#### 1. HttpService (`lib/services/http_service.dart`)
- 全局 HTTP 服务管理类
- 提供统一的 Dio 实例
- 集成 Cookie 管理功能
- 包含请求拦截器和错误处理

#### 2. 应用初始化 (`lib/main.dart`)
```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // 初始化HTTP服务
  await HttpService.init();
  
  runApp(const MyApp());
}
```

### Cookie 管理配置

```dart
// 创建持久化Cookie Jar
_cookieJar = PersistCookieJar(
  storage: FileStorage('${cookieDir.path}/'),
);

// 添加Cookie管理器到Dio
_dio!.interceptors.add(CookieManager(_cookieJar!));
```

### 基础配置

```dart
_dio!.options = BaseOptions(
  connectTimeout: const Duration(seconds: 30),
  receiveTimeout: const Duration(seconds: 30),
  sendTimeout: const Duration(seconds: 30),
  headers: {
    'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
    'Accept': 'application/json, text/plain, */*',
    'Accept-Language': 'en-US,en;q=0.9,zh-CN;q=0.8,zh;q=0.7',
    'Accept-Encoding': 'gzip, deflate, br',
    'Connection': 'keep-alive',
  },
);
```

## 使用方法

### 1. 基本使用
```dart
// 使用全局 Dio 实例
final response = await HttpService.dio.get('https://api.example.com/data');

// 或使用便捷方法
final response = await Http.get('https://api.example.com/data');
```

### 2. POST 请求
```dart
final response = await HttpService.dio.post(
  'https://api.example.com/login',
  data: {
    'username': 'user',
    'password': 'pass',
  },
);
```

### 3. Cookie 管理
```dart
// 获取指定域名的 Cookie
final cookies = await HttpService.getCookies('https://example.com');

// 清除所有 Cookie
await HttpService.clearCookies();

// 设置 Cookie
await HttpService.setCookies('https://example.com', [cookie]);
```

## 已更新的文件

### 网络请求文件
1. **play_detail_page.dart**: 更新为使用全局 Dio 实例
2. **weekend_page.dart**: 更新为使用全局 Dio 实例
3. **archive_page.dart**: 更新为使用全局 Dio 实例
4. **season_page.dart**: 更新为使用全局 Dio 实例

### 配置文件
1. **pubspec.yaml**: 添加 Cookie 管理相关依赖
2. **main.dart**: 添加 HTTP 服务初始化

## 功能优势

### 1. 统一管理
- 所有网络请求使用相同的配置
- 便于维护和调试
- 统一的错误处理机制

### 2. Cookie 自动管理
- 登录状态自动保持
- 会话信息自动携带
- 跨页面状态共享

### 3. 性能优化
- 连接复用
- 自动重试机制
- 请求日志记录

### 4. 开发体验
- 统一的 API 接口
- 详细的日志输出
- 便捷的工具方法

## 日志输出示例

```
🚀 Request: GET https://api.example.com/data
📋 Request Headers: {User-Agent: Mozilla/5.0...}
✅ Response: 200 https://api.example.com/data
📥 Response Data Length: 1234
Cookie manager initialized with storage: /path/to/cookies
```

## 错误处理

```
❌ Error: Connection timeout
🔗 Request: GET https://api.example.com/data
🔄 Retrying request (1/3): https://api.example.com/data
```

## 注意事项

1. **初始化顺序**: 确保在使用前调用 `HttpService.init()`
2. **Cookie 存储**: Cookie 存储在应用文档目录下的 `cookies` 文件夹
3. **网络权限**: 确保应用有网络访问权限
4. **错误处理**: 建议在业务代码中添加适当的错误处理

## 后续扩展

1. **请求缓存**: 可以添加请求缓存机制
2. **请求签名**: 可以添加 API 签名验证
3. **请求限流**: 可以添加请求频率限制
4. **多环境配置**: 可以支持开发/测试/生产环境切换

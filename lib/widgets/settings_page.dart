import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../services/download_service.dart';
import '../services/n_m3u8dl_config_service.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final _pathController = TextEditingController();
  String _currentPath = '';

  // N_m3u8DL-RE 配置
  String _selectedFormat = 'mp4';
  bool _skipSub = true;
  String _selectedResolution = 'best';
  String _selectedRange = 'SDR';
  String _selectedAudioLang = 'eng';

  @override
  void initState() {
    super.initState();
    _loadCurrentPath();
    _loadDownloadConfig();
  }

  Future<void> _loadCurrentPath() async {
    try {
      final path = await DownloadService.getDownloadPath();
      setState(() {
        _currentPath = path;
      });
    } catch (e) {
      _showErrorSnackBar('获取下载路径失败: $e');
    }
  }

  Future<void> _loadDownloadConfig() async {
    try {
      final format = await N_m3u8dlConfigService.getFormat();
      final skipSub = await N_m3u8dlConfigService.getSkipSub();
      final resolution = await N_m3u8dlConfigService.getResolution();
      final range = await N_m3u8dlConfigService.getRange();
      final audioLang = await N_m3u8dlConfigService.getAudioLang();
      setState(() {
        _selectedFormat = format;
        _skipSub = skipSub;
        _selectedResolution = resolution;
        _selectedRange = range;
        _selectedAudioLang = audioLang;
      });
    } catch (e) {
      _showErrorSnackBar('获取下载配置失败: $e');
    }
  }

  Future<void> _saveDownloadConfig() async {
    try {
      await N_m3u8dlConfigService.setFormat(_selectedFormat);
      await N_m3u8dlConfigService.setSkipSub(_skipSub);
      await N_m3u8dlConfigService.setResolution(_selectedResolution);
      await N_m3u8dlConfigService.setRange(_selectedRange);
      await N_m3u8dlConfigService.setAudioLang(_selectedAudioLang);
      _showSuccessSnackBar('下载配置已保存');
    } catch (e) {
      print('保存配置错误详情: $e');
      _showErrorSnackBar('保存下载配置失败: ${e.toString()}');
    }
  }

  Future<void> _resetDownloadConfig() async {
    try {
      await N_m3u8dlConfigService.resetToDefaults();
      await _loadDownloadConfig();
      _showSuccessSnackBar('下载配置已重置为默认值');
    } catch (e) {
      print('重置配置错误详情: $e');

      // 即使重置失败，也尝试更新UI到默认值
      setState(() {
        _selectedFormat = N_m3u8dlConfigService.defaultFormat;
        _skipSub = N_m3u8dlConfigService.defaultSkipSub;
        _selectedResolution = N_m3u8dlConfigService.defaultResolution;
        _selectedRange = N_m3u8dlConfigService.defaultRange;
        _selectedAudioLang = N_m3u8dlConfigService.defaultAudioLang;
      });

      _showErrorSnackBar('重置下载配置失败: ${e.toString()}');
    }
  }

  void _updateDownloadPath() {
    final newPath = _pathController.text.trim();
    if (newPath.isNotEmpty) {
      DownloadService.setDownloadPath(newPath);
      _loadCurrentPath();
      _showSuccessSnackBar('下载路径已更新');
      _pathController.clear();
    } else {
      _showErrorSnackBar('请输入有效的路径');
    }
  }

  Future<void> _selectDownloadPath() async {
    try {
      String? selectedDirectory = await FilePicker.platform.getDirectoryPath();

      if (selectedDirectory != null) {
        DownloadService.setDownloadPath(selectedDirectory);
        _loadCurrentPath();
        _showSuccessSnackBar('下载路径已更新');
        _pathController.clear();
      }
    } catch (e) {
      _showErrorSnackBar('选择文件夹失败: $e');
    }
  }

  void _clearCustomPath() {
    DownloadService.clearCustomDownloadPath();
    _loadCurrentPath();
    _pathController.clear();
    _showSuccessSnackBar('已恢复默认下载路径');
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 页面标题
            const Text(
              '设置',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1E1E1E),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '配置应用程序设置和偏好',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 32),

            // 下载路径设置卡片
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.folder,
                          color: Theme.of(context).primaryColor,
                          size: 24,
                        ),
                        const SizedBox(width: 12),
                        const Text(
                          '下载路径设置',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      '当前下载路径:',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.grey[50],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey[300]!),
                      ),
                      child: Text(
                        _currentPath.isEmpty ? '加载中...' : _currentPath,
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 13,
                          color: Color(0xFF333333),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    // 文件夹选择按钮
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _selectDownloadPath,
                        icon: const Icon(Icons.folder_open, size: 20),
                        label: const Text('选择下载文件夹'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Theme.of(context).primaryColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    // 分割线
                    Row(
                      children: [
                        const Expanded(child: Divider()),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Text(
                            '或手动输入路径',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 12,
                            ),
                          ),
                        ),
                        const Expanded(child: Divider()),
                      ],
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _pathController,
                      decoration: InputDecoration(
                        labelText: '自定义下载路径',
                        hintText: '输入新的下载路径，留空使用默认路径',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        prefixIcon: const Icon(Icons.edit_location),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _updateDownloadPath,
                            icon: const Icon(Icons.save, size: 18),
                            label: const Text('保存路径'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _clearCustomPath,
                            icon: const Icon(Icons.refresh, size: 18),
                            label: const Text('恢复默认'),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // N_m3u8DL-RE 下载配置卡片
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.settings,
                          color: Theme.of(context).primaryColor,
                          size: 24,
                        ),
                        const SizedBox(width: 12),
                        const Text(
                          '下载配置',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      '配置 N_m3u8DL-RE 下载参数',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 20),

                    // 输出格式选择
                    Text(
                      '输出格式',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[800],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey[300]!),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _selectedFormat,
                          items: N_m3u8dlConfigService.getSupportedFormats()
                              .map((format) => DropdownMenuItem(
                                    value: format,
                                    child: Text(format.toUpperCase()),
                                  ))
                              .toList(),
                          onChanged: (value) {
                            if (value != null) {
                              setState(() {
                                _selectedFormat = value;
                              });
                            }
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // 跳过字幕开关
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '跳过字幕',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey[800],
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '启用后将不下载字幕文件',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ),
                        Switch(
                          value: _skipSub,
                          onChanged: (value) {
                            setState(() {
                              _skipSub = value;
                            });
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // 视频分辨率选择
                    Text(
                      '视频分辨率',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[800],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey[300]!),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _selectedResolution,
                          items: N_m3u8dlConfigService
                                  .getSupportedResolutionsTitle()
                              .map((resolution) => DropdownMenuItem(
                                    value: resolution['value'],
                                    child: Text(resolution['name']!),
                                  ))
                              .toList(),
                          onChanged: (value) {
                            if (value != null) {
                              setState(() {
                                _selectedResolution = value;
                              });
                            }
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // 动态范围选择
                    Text(
                      '动态范围',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[800],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey[300]!),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _selectedRange,
                          items: N_m3u8dlConfigService.getSupportedRanges()
                              .map((range) => DropdownMenuItem(
                                    value: range['value'],
                                    child: Text(range['name']!),
                                  ))
                              .toList(),
                          onChanged: (value) {
                            if (value != null) {
                              setState(() {
                                _selectedRange = value;
                              });
                            }
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // 音频语言选择
                    Text(
                      '音频语言',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[800],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey[300]!),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _selectedAudioLang,
                          items:
                              N_m3u8dlConfigService.getSupportedAudioLanguages()
                                  .map((audioLang) => DropdownMenuItem(
                                        value: audioLang['value'],
                                        child: Text(audioLang['name']!),
                                      ))
                                  .toList(),
                          onChanged: (value) {
                            if (value != null) {
                              setState(() {
                                _selectedAudioLang = value;
                              });
                            }
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // 保存和重置按钮
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _saveDownloadConfig,
                            icon: const Icon(Icons.save, size: 18),
                            label: const Text('保存配置'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _resetDownloadConfig,
                            icon: const Icon(Icons.refresh, size: 18),
                            label: const Text('重置默认'),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // 其他设置卡片
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.tune,
                          color: Theme.of(context).primaryColor,
                          size: 24,
                        ),
                        const SizedBox(width: 12),
                        const Text(
                          '其他设置',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    ListTile(
                      leading: const Icon(Icons.info_outline),
                      title: const Text('关于应用'),
                      subtitle: const Text('版本信息和开发者信息'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () {
                        // TODO: 显示关于对话框
                        showDialog(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: const Text('关于 M3U8下载器'),
                            content: const Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('版本: 1.0.0'),
                                SizedBox(height: 8),
                                Text('一个简单易用的M3U8视频下载工具'),
                              ],
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.of(context).pop(),
                                child: const Text('确定'),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                    const Divider(),
                    ListTile(
                      leading: const Icon(Icons.help_outline),
                      title: const Text('使用帮助'),
                      subtitle: const Text('查看使用说明和常见问题'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () {
                        // TODO: 显示帮助信息
                        showDialog(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: const Text('使用帮助'),
                            content: const SingleChildScrollView(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('1. 在Home页面输入M3U8视频链接'),
                                  SizedBox(height: 4),
                                  Text('2. 设置文件名（不含扩展名）'),
                                  SizedBox(height: 4),
                                  Text('3. 可选择配置额外参数'),
                                  SizedBox(height: 4),
                                  Text('4. 点击开始下载按钮'),
                                  SizedBox(height: 4),
                                  Text('5. 在Settings页面可以设置下载路径'),
                                ],
                              ),
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.of(context).pop(),
                                child: const Text('确定'),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _pathController.dispose();
    super.dispose();
  }
}

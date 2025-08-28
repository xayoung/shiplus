import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/download_service.dart';
import '../services/n_m3u8dl_config_service.dart';
import '../services/formula1_service.dart';
import 'package:intl/intl.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final _pathController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  String _currentPath = '';
  
  // Formula 1 data
  String? _reese84Token;
  Map<String, dynamic>? _formula1UserData;
  bool _isLoadingF1Data = false;

  // N_m3u8DL-RE configuration
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
    _loadFormula1Data();
  }
  
  // Get subscription type
  String _getSubscriptionType() {
    if (_formula1UserData == null || _formula1UserData!['SubscriptionInfo'] == null) {
      return 'Unknown';
    }
    
    final subscriptionInfo = _formula1UserData!['SubscriptionInfo'];
    if (subscriptionInfo['SubscriptionName'] != null) {
      return subscriptionInfo['SubscriptionName'];
    } else if (subscriptionInfo['SubscriptionType'] != null) {
      return subscriptionInfo['SubscriptionType'];
    } else {
      return 'F1 TV';
    }
  }
  
  String _getSubscriptionStatus() {
    if (_formula1UserData == null) {
      return 'Unknown';
    }
    
    if (_formula1UserData!['Status'] != null) {
      final status = _formula1UserData!['Status'].toString().toLowerCase();
      if (status == 'active') {
        return 'Active';
      } else if (status == 'inactive') {
        return 'Inactive';
      } else {
        return status.substring(0, 1).toUpperCase() + status.substring(1);
      }
    }
    
    return 'Unknown';
  }
  
  String _getExpiryDate() {
    if (_formula1UserData == null || _formula1UserData!['SubscriptionInfo'] == null) {
      return 'Unknown';
    }
    
    final subscriptionInfo = _formula1UserData!['SubscriptionInfo'];
    if (subscriptionInfo['ExpiryDate'] != null) {
      try {
        final expiryDateValue = subscriptionInfo['ExpiryDate'];
        DateTime expiryDate;

        if (expiryDateValue is String) {
          if (expiryDateValue.contains('T')) {
            expiryDate = DateTime.parse(expiryDateValue);
          } else if (expiryDateValue.contains('-')) {
            expiryDate = DateTime.parse(expiryDateValue);
          } else if (int.tryParse(expiryDateValue) != null) {
            final timestamp = int.parse(expiryDateValue);
            expiryDate = DateTime.fromMillisecondsSinceEpoch(
              timestamp > 9999999999 ? timestamp : timestamp * 1000
            );
          } else {
            throw FormatException('fail');
          }
        } else if (expiryDateValue is int) {
          expiryDate = DateTime.fromMillisecondsSinceEpoch(
            expiryDateValue > 9999999999 ? expiryDateValue : expiryDateValue * 1000
          );
        } else if (expiryDateValue is double) {
          final timestamp = expiryDateValue.toInt();
          expiryDate = DateTime.fromMillisecondsSinceEpoch(
            timestamp > 9999999999 ? timestamp : timestamp * 1000
          );
        } else {
          throw FormatException('fail');
        }
        
        return '${expiryDate.year}-${expiryDate.month.toString().padLeft(2, '0')}-${expiryDate.day.toString().padLeft(2, '0')}';
      } catch (e) {
        return subscriptionInfo['ExpiryDate'].toString();
      }
    }
    
    return 'Unknown';
  }
  
  List<Widget> _buildEntitlementsList() {
    if (_formula1UserData == null || _formula1UserData!['Entitlements'] == null) {
      return [];
    }
    
    final entitlements = _formula1UserData!['Entitlements'] as List;
    return entitlements.map((entitlement) {
      String name = 'Unknown';
      String country = '';
      
      if (entitlement is Map) {
        if (entitlement['Name'] != null) {
          name = entitlement['Name'];
        } else if (entitlement['ent'] != null) {
          name = entitlement['ent'];
        }
        
        if (entitlement['Country'] != null) {
          country = entitlement['Country'];
        } else if (entitlement['country'] != null) {
          country = entitlement['country'];
        }
      } else if (entitlement is String) {
        name = entitlement;
      }
  
      switch (name.toUpperCase()) {
        case 'PREMIUM':
          name = 'F1 TV Premium';
          break;
        case 'REG':
          name = 'F1 TV Access';
          break;
        case 'PRO':
          name = 'F1 TV Pro';
          break;
      }
      
      return Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Row(
          children: [
            const Icon(Icons.check_circle, size: 16, color: Colors.green),
            const SizedBox(width: 8),
            Expanded(
              child: country.isNotEmpty 
                ? Text('$name ($country)') 
                : Text(name),
            ),
          ],
        ),
      );
    }).toList();
  }
  
  Future<void> _loadFormula1Data() async {
    try {
      setState(() {
        _isLoadingF1Data = true;
      });

      _reese84Token = await Formula1Service.getSavedReese84Token();
      

      _formula1UserData = await Formula1Service.getSavedUserData();
      
      setState(() {
        _isLoadingF1Data = false;
      });
    } catch (e) {
      print('Error loading Formula 1 data: $e');
      setState(() {
        _isLoadingF1Data = false;
      });
    }
  }

  Future<void> _loadCurrentPath() async {
    try {
      final path = await DownloadService.getDownloadPath();
      setState(() {
        _currentPath = path;
      });
    } catch (e) {
      _showErrorSnackBar('Failed to get download path: $e');
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
      _showErrorSnackBar('Failed to get download configuration: $e');
    }
  }

  Future<void> _saveDownloadConfig() async {
    try {
      await N_m3u8dlConfigService.setFormat(_selectedFormat);
      await N_m3u8dlConfigService.setSkipSub(_skipSub);
      await N_m3u8dlConfigService.setResolution(_selectedResolution);
      await N_m3u8dlConfigService.setRange(_selectedRange);
      await N_m3u8dlConfigService.setAudioLang(_selectedAudioLang);
      _showSuccessSnackBar('Download configuration saved');
    } catch (e) {
      print('Save configuration error details: $e');
      _showErrorSnackBar('Failed to save download configuration: ${e.toString()}');
    }
  }

  Future<void> _resetDownloadConfig() async {
    try {
      await N_m3u8dlConfigService.resetToDefaults();
      await _loadDownloadConfig();
      _showSuccessSnackBar('Download configuration reset to defaults');
    } catch (e) {
      setState(() {
        _selectedFormat = N_m3u8dlConfigService.defaultFormat;
        _skipSub = N_m3u8dlConfigService.defaultSkipSub;
        _selectedResolution = N_m3u8dlConfigService.defaultResolution;
        _selectedRange = N_m3u8dlConfigService.defaultRange;
        _selectedAudioLang = N_m3u8dlConfigService.defaultAudioLang;
      });

      _showErrorSnackBar('Failed to reset download configuration: ${e.toString()}');
    }
  }

  void _updateDownloadPath() {
    final newPath = _pathController.text.trim();
    if (newPath.isNotEmpty) {
      DownloadService.setDownloadPath(newPath);
      _loadCurrentPath();
      _showSuccessSnackBar('Download path updated');
      _pathController.clear();
    } else {
      _showErrorSnackBar('Please enter a valid path');
    }
  }

  Future<void> _selectDownloadPath() async {
    try {
      String? selectedDirectory = await FilePicker.platform.getDirectoryPath();

      if (selectedDirectory != null) {
        DownloadService.setDownloadPath(selectedDirectory);
        _loadCurrentPath();
        _showSuccessSnackBar('Download path updated');
        _pathController.clear();
      }
    } catch (e) {
      _showErrorSnackBar('Failed to select folder: $e');
    }
  }

  void _clearCustomPath() {
    DownloadService.clearCustomDownloadPath();
    _loadCurrentPath();
    _pathController.clear();
    _showSuccessSnackBar('Default download path restored');
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
  
  void _showLoginDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Formula 1 Account'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Enter your Formula 1 account credentials:'),
                const SizedBox(height: 16),
                TextField(
                  controller: _emailController,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    hintText: 'Enter email',
                    prefixIcon: Icon(Icons.email),
                  ),
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _passwordController,
                  decoration: const InputDecoration(
                    labelText: 'Password',
                    hintText: 'Enter password',
                    prefixIcon: Icon(Icons.lock),
                  ),
                  obscureText: true,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (_emailController.text.isEmpty || _passwordController.text.isEmpty) {
                  _showErrorSnackBar('Please enter both email and password');
                  return;
                }

                Navigator.of(dialogContext).pop();
                setState(() {
                  _isLoadingF1Data = true;
                });
                
                BuildContext? loadingDialogContext;
                showDialog(
                  context: context,
                  barrierDismissible: false,
                  builder: (BuildContext ctx) {
                    loadingDialogContext = ctx;
                    return WillPopScope(
                      onWillPop: () async => false,
                      child: const AlertDialog(
                        content: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircularProgressIndicator(),
                            SizedBox(height: 16),
                            Text('Logging in to Formula 1...'),
                          ],
                        ),
                      ),
                    );
                  },
                );
                
                try {
                  final userData = await Formula1Service.login(
                    _emailController.text,
                    _passwordController.text,
                  );
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (loadingDialogContext != null && Navigator.canPop(loadingDialogContext!)) {
                      Navigator.of(loadingDialogContext!).pop();
                    }

                    setState(() {
                      _isLoadingF1Data = false;
                      if (userData != null) {
                        _formula1UserData = userData;
                        _showSuccessSnackBar('Successfully logged in to Formula 1');
                      } else {
                        _showErrorSnackBar('Failed to login. Please check your credentials.');
                      }
                    });
                  });
                } catch (e) {

                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (loadingDialogContext != null && Navigator.canPop(loadingDialogContext!)) {
                      Navigator.of(loadingDialogContext!).pop();
                    }
                    
                    setState(() {
                      _isLoadingF1Data = false;
                    });
                    
                    _showErrorSnackBar('Login error: $e');
                  });
                }
              },
              child: const Text('Login'),
            ),
          ],
        );
      },
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
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [const Text(
              'Settings',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1E1E1E),
              ),
            ),
              InkWell(
                onTap: () {
                  try {
                    final Uri url = Uri.parse('https://github.com/xayoung/shiplus');
                    launchUrl(url, mode: LaunchMode.externalApplication);
                  } catch (e) {
                    print('无法打开URL: $e');
                  }
                },
                child: const Icon(
                          FontAwesomeIcons.github,
                          size: 30,
                        ),
              ),
            ],
            ),
            const SizedBox(height: 8),
            Text(
              'Configure application settings and preferences',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 24),
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
                          Icons.sports_motorsports,
                          color: Theme.of(context).primaryColor,
                          size: 24,
                        ),
                        const SizedBox(width: 12),
                        const Text(
                          'Formula 1 Account',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    if (_formula1UserData != null) ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.grey[50],
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey[300]!),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.person, size: 16, color: Colors.blue),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Email: ${_formula1UserData!['Email'] ?? 'Unknown'}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            if (_formula1UserData!['FirstName'] != null && _formula1UserData!['LastName'] != null) ...[
                              Row(
                                children: [
                                  const Icon(Icons.badge, size: 16, color: Colors.blue),
                                  const SizedBox(width: 8),
                                  Text('Name: ${_formula1UserData!['FirstName']} ${_formula1UserData!['LastName']}'),
                                ],
                              ),
                              const SizedBox(height: 4),
                            ],
                            Row(
                              children: [
                                const Icon(Icons.numbers, size: 16, color: Colors.blue),
                                const SizedBox(width: 8),
                                Text('User ID: ${_formula1UserData!['SubscriberId'] ?? 'Unknown'}'),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                const Icon(Icons.public, size: 16, color: Colors.blue),
                                const SizedBox(width: 8),
                                Text('Country: ${_formula1UserData!['HomeCountry'] ?? 'Unknown'}'),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Icon(
                                  _getSubscriptionStatus().toLowerCase() == 'active' 
                                      ? Icons.check_circle 
                                      : Icons.cancel,
                                  size: 16,
                                  color: _getSubscriptionStatus().toLowerCase() == 'active'
                                      ? Colors.green
                                      : Colors.red,
                                ),
                                const SizedBox(width: 8),
                                Text('Status: ${_getSubscriptionStatus()}'),
                              ],
                            ),
                            const SizedBox(height: 4),
                            if (_formula1UserData!['SubscriptionInfo'] != null) ...[
                              const Divider(height: 16),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  const Icon(Icons.card_membership, size: 16, color: Colors.blue),
                                  const SizedBox(width: 8),
                                  const Text(
                                    'Subscription Information:',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Padding(
                                padding: const EdgeInsets.only(left: 24),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Type: ${_getSubscriptionType()}'),
                                    if (_formula1UserData!['SubscriptionInfo']['IsAutoRenewing'] != null)
                                      Text('Auto-renewing: ${_formula1UserData!['SubscriptionInfo']['IsAutoRenewing'] ? 'Yes' : 'No'}'),
                                  ],
                                ),
                              ),
                            ],
                            if (_formula1UserData!['Entitlements'] != null && 
                                _formula1UserData!['Entitlements'] is List && 
                                (_formula1UserData!['Entitlements'] as List).isNotEmpty) ...[
                              const Divider(height: 16),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  const Icon(Icons.verified_user, size: 16, color: Colors.blue),
                                  const SizedBox(width: 8),
                                  const Text(
                                    'Entitlements:',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Padding(
                                padding: const EdgeInsets.only(left: 24),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: _buildEntitlementsList(),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () async {
                                setState(() {
                                  _isLoadingF1Data = true;
                                });
                                BuildContext? dialogContext;
                                showDialog(
                                  context: context,
                                  barrierDismissible: false,
                                  builder: (BuildContext ctx) {
                                    dialogContext = ctx;
                                    return const AlertDialog(
                                      content: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          CircularProgressIndicator(),
                                          SizedBox(height: 16),
                                          Text('Refreshing token...'),
                                        ],
                                      ),
                                    );
                                  },
                                );
                                
                                try {
                                  final refreshedData = await Formula1Service.refreshToken();
                                  if (dialogContext != null && Navigator.canPop(dialogContext!)) {
                                    Navigator.of(dialogContext!).pop();
                                  }
                                  
                                  setState(() {
                                    _isLoadingF1Data = false;
                                    if (refreshedData != null) {
                                      _formula1UserData = refreshedData;
                                      _showSuccessSnackBar('Token refreshed successfully');
                                    } else {
                                      _showErrorSnackBar('Failed to refresh token');
                                    }
                                  });
                                } catch (e) {
                                  if (dialogContext != null && Navigator.canPop(dialogContext!)) {
                                    Navigator.of(dialogContext!).pop();
                                  }
                                  
                                  setState(() {
                                    _isLoadingF1Data = false;
                                  });
                                  
                                  _showErrorSnackBar('Error refreshing token: $e');
                                }
                              },
                              icon: const Icon(Icons.refresh, size: 18),
                              label: const Text('Refresh Token'),
                              style: OutlinedButton.styleFrom(
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
                              onPressed: () async {
                                await Formula1Service.clearAllData();
                                setState(() {
                                  _reese84Token = null;
                                  _formula1UserData = null;
                                });
                                _showSuccessSnackBar('Formula 1 login data cleared');
                              },
                              icon: const Icon(Icons.logout, size: 18),
                              label: const Text('Logout'),
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
                    ] else ...[
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _isLoadingF1Data 
                              ? null 
                              : () async {
                                  BuildContext? dialogContext;
                                  showDialog(
                                    context: context,
                                    barrierDismissible: false,
                                    builder: (BuildContext ctx) {
                                      dialogContext = ctx;
                                      return const AlertDialog(
                                        content: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            CircularProgressIndicator(),
                                            SizedBox(height: 16),
                                            Text('Getting authentication token...'),
                                          ],
                                        ),
                                      );
                                    },
                                  );
                                  
                                  setState(() {
                                    _isLoadingF1Data = true;
                                  });
                                  
                                  try {
                                    final token = await Formula1Service.getReese84Token(context);
                    
                                    if (dialogContext != null && Navigator.canPop(dialogContext!)) {
                                      Navigator.of(dialogContext!).pop();
                                    }
                                    
                                    if (token != null) {
                                      _reese84Token = token;
                                      _showLoginDialog();
                                    } else {
                                      _showErrorSnackBar('Failed to get authentication token');
                                    }
                                  } catch (e) {
                                    if (dialogContext != null && Navigator.canPop(dialogContext!)) {
                                      Navigator.of(dialogContext!).pop();
                                    }
                                    _showErrorSnackBar('Error: $e');
                                  } finally {
                                    setState(() {
                                      _isLoadingF1Data = false;
                                    });
                                  }
                                },
                          icon: _isLoadingF1Data 
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                  ),
                                )
                              : const Icon(Icons.login, size: 20),
                          label: Text(_isLoadingF1Data ? 'Loading...' : 'Login to F1TV'),
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
                    ],
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 24),
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
                          'Download Path Settings',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Current Download Path:',
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
                        _currentPath.isEmpty ? 'Loading...' : _currentPath,
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 13,
                          color: Color(0xFF333333),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _selectDownloadPath,
                        icon: const Icon(Icons.folder_open, size: 20),
                        label: const Text('Select Download Folder'),
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
                    Row(
                      children: [
                        const Expanded(child: Divider()),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Text(
                            'or manually enter path',
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
                        labelText: 'Custom Download Path',
                        hintText: 'Enter new download path, leave empty to use default',
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
                            label: const Text('Save Path'),
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
                            label: const Text('Restore Default'),
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
                    
                    ListTile(
                      leading: const Icon(Icons.info_outline),
                      title: const Text('About'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () {
                        showDialog(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: const Text('About shiplus'),
                            content: const Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Version: 1.0.0'),
                                SizedBox(height: 8),
                                SizedBox(
                                  width: 400, // Fixed width in logical pixels
                                  child: Text('This app is a free and open source project for downloading F1TV race replays.'),
                                ),
                                SizedBox(height: 8),
                                SizedBox(
                                  width: 400, // Fixed width in logical pixels
                                  child: Text('This app is unofficial and is not associated in any way with the Formula 1 companies. F1, FORMULA ONE, FORMULA 1, FIA FORMULA ONE WORLD CHAMPIONSHIP, GRAND PRIX and related marks are trade marks of Formula One Licensing B.V.'),
                                )]),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.of(context).pop(),
                                child: const Text('OK'),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                    const Divider(),
                    ListTile(
                      leading: const Icon(FontAwesomeIcons.github),
                      title: const Text('Github'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () {
                        try {
                          final Uri url = Uri.parse('https://github.com/xayoung/shiplus');
                          launchUrl(url, mode: LaunchMode.externalApplication);
                        } catch (e) {
                          print('无法打开URL: $e');
                        }
                      },
                    ),
                    const Divider(),
                    ListTile(
                      leading: const Icon(Icons.help_outline),
                      title: const Text('Help'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () {
                        showDialog(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: const Text('Help'),
                            content: SingleChildScrollView(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('1. To use shiplus, you need an F1 TV subscription. Which one may depend on your specific needs, and availability in your country.'),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      Text(
                                          '2. See availability and exact delays.'),
                                      const SizedBox(width: 10),
                                      InkWell(
                                        onTap: () {
                                          try {
                                            final Uri url = Uri.parse('https://support.formula1.com/s/article/2023-Location-Availability?language=en_US');
                                            launchUrl(url, mode: LaunchMode.externalApplication);
                                          } catch (e) {
                                            print('无法打开URL: $e');
                                          }
                                        },
                                        child: const Text(
                                          'Click',
                                          style: TextStyle(
                                            color: Colors.blue,
                                            decoration: TextDecoration.underline,
                                          ),
                                        ),
                                      ),
                                    ]
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      Text(
                                          '3. Having trouble? Submit an issue on GitHub.'),
                                      const SizedBox(width: 10),
                                      InkWell(
                                        onTap: () {
                                          try {
                                            final Uri url = Uri.parse('https://support.formula1.com/s/article/2023-Location-Availability?language=en_US');
                                            launchUrl(url, mode: LaunchMode.externalApplication);
                                          } catch (e) {
                                            print('无法打开URL: $e');
                                          }
                                        },
                                        child: const Text(
                                          'Click',
                                          style: TextStyle(
                                            color: Colors.blue,
                                            decoration: TextDecoration.underline,
                                          ),
                                        ),
                                      ),
                                    ]
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      Text(
                                          '4. Donate/Support this project.'),
                                      const SizedBox(width: 10),
                                      InkWell(
                                        onTap: () {
                                          try {
                                            final Uri url = Uri.parse('https://github.com/sponsors/xayoung');
                                            launchUrl(url, mode: LaunchMode.externalApplication);
                                          } catch (e) {
                                            print('无法打开URL: $e');
                                          }
                                        },
                                        child: const Text(
                                          'Github',
                                          style: TextStyle(
                                            color: Colors.blue,
                                            decoration: TextDecoration.underline,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 5),
                                      InkWell(
                                        onTap: () {
                                          try {
                                            final Uri url = Uri.parse('https://ko-fi.com/xayoung');
                                            launchUrl(url, mode: LaunchMode.externalApplication);
                                          } catch (e) {
                                            print('无法打开URL: $e');
                                          }
                                        },
                                        child: const Text(
                                          'Ko-fi',
                                          style: TextStyle(
                                            color: Colors.blue,
                                            decoration: TextDecoration.underline,
                                          ),
                                        ),
                                      ),
                                    ]
                                  )
                                ],
                              ),
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.of(context).pop(),
                                child: const Text('OK'),
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
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }
}

import 'dart:async';
import 'dart:collection';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/app_notification_service.dart';
import '../services/formula1_service.dart';

typedef DeviceSignInStarter = Future<DeviceAuthorization> Function();
typedef DeviceSignInCompleter =
    Future<Map<String, dynamic>> Function(
      DeviceAuthorization authorization, {
      required bool browserApproved,
      Future<void> Function(Duration)? wait,
      bool Function()? isCancelled,
    });
typedef ExternalUrlLauncher = Future<bool> Function(Uri url);

class F1LoginDialog extends StatefulWidget {
  const F1LoginDialog({
    super.key,
    this.beginSignIn,
    this.completeSignIn,
    this.launchExternalUrl,
    this.completionFallbackDelay = const Duration(seconds: 60),
    this.forceExternalBrowser = false,
  });

  final DeviceSignInStarter? beginSignIn;
  final DeviceSignInCompleter? completeSignIn;
  final ExternalUrlLauncher? launchExternalUrl;
  final Duration completionFallbackDelay;
  final bool forceExternalBrowser;

  @override
  State<F1LoginDialog> createState() => _F1LoginDialogState();
}

class _F1LoginDialogState extends State<F1LoginDialog> {
  static WebViewEnvironment? _windowsWebViewEnvironment;
  static bool _windowsWebViewUnavailable = false;

  int _attemptEpoch = 0;
  bool _isPreparing = true;
  bool _isCompleting = false;
  bool _isWebViewLoading = false;
  bool _useExternalBrowser = false;
  bool _pollingActive = false;
  bool _completionTriggered = false;

  DeviceAuthorization? _authorization;
  WebViewEnvironment? _webViewEnvironment;
  String? _errorMessage;
  String _currentHost = 'account.formula1.com';
  int _remainingSeconds = 0;

  Timer? _countdownTimer;
  Timer? _fallbackPollingTimer;
  Completer<void>? _activeWaitCompleter;

  @override
  void initState() {
    super.initState();
    _useExternalBrowser = widget.forceExternalBrowser;
    _startSignIn();
  }

  @override
  void dispose() {
    _cancelActiveAttempt();
    super.dispose();
  }

  void _cancelActiveAttempt() {
    _attemptEpoch++;
    _countdownTimer?.cancel();
    _countdownTimer = null;
    _fallbackPollingTimer?.cancel();
    _fallbackPollingTimer = null;
    _wakeWaiter();
    _pollingActive = false;
    _completionTriggered = false;
  }

  void _wakeWaiter() {
    final waiter = _activeWaitCompleter;
    if (waiter != null && !waiter.isCompleted) {
      waiter.complete();
    }
    _activeWaitCompleter = null;
  }

  Future<void> _cancellableWait(Duration duration, int epoch) {
    if (!mounted || epoch != _attemptEpoch) {
      return Future<void>.value();
    }
    final completer = Completer<void>();
    _activeWaitCompleter = completer;
    final timer = Timer(duration, () {
      if (!completer.isCompleted) {
        completer.complete();
      }
    });
    return completer.future.whenComplete(() {
      timer.cancel();
      if (identical(_activeWaitCompleter, completer)) {
        _activeWaitCompleter = null;
      }
    });
  }

  Future<bool> _prepareWebViewSupport() async {
    if (widget.forceExternalBrowser) return false;
    if (!Platform.isWindows) return true;
    if (_windowsWebViewUnavailable) return false;
    if (_windowsWebViewEnvironment != null) {
      _webViewEnvironment = _windowsWebViewEnvironment;
      return true;
    }

    try {
      final version = await WebViewEnvironment.getAvailableVersion();
      if (version == null || version.isEmpty) {
        _windowsWebViewUnavailable = true;
        return false;
      }
      final supportDir = await getApplicationSupportDirectory();
      final udfDir = Directory(p.join(supportDir.path, 'webview2_auth'));
      if (!udfDir.existsSync()) {
        await udfDir.create(recursive: true);
      }
      final env = await WebViewEnvironment.create(
        settings: WebViewEnvironmentSettings(userDataFolder: udfDir.path),
      );
      _windowsWebViewEnvironment = env;
      _webViewEnvironment = env;
      return true;
    } catch (_) {
      _windowsWebViewUnavailable = true;
      return false;
    }
  }

  Future<void> _startSignIn({bool preferExternalBrowser = false}) async {
    _cancelActiveAttempt();
    final epoch = _attemptEpoch;

    setState(() {
      _isPreparing = true;
      _isCompleting = false;
      _isWebViewLoading = false;
      _errorMessage = null;
      _authorization = null;
      _remainingSeconds = 0;
      _currentHost = 'id.formula1.com';
      if (preferExternalBrowser) {
        _useExternalBrowser = true;
      }
    });

    try {
      final begin =
          widget.beginSignIn ?? (() => Formula1Service.beginDeviceSignIn());
      final authFuture = begin();
      final webViewFuture = preferExternalBrowser || widget.forceExternalBrowser
          ? Future<bool>.value(false)
          : _prepareWebViewSupport();

      final auth = await authFuture;
      final canUseWebView = await webViewFuture;

      if (!mounted || epoch != _attemptEpoch) return;

      final useExternal =
          preferExternalBrowser || widget.forceExternalBrowser || !canUseWebView;

      setState(() {
        _authorization = auth;
        _isPreparing = false;
        _useExternalBrowser = useExternal;
        _isWebViewLoading = !useExternal;
        _currentHost = auth.verificationUriComplete.host;
        _remainingSeconds = _computeRemainingSeconds(auth.expiresAt);
      });

      _startCountdown(auth, epoch);

      if (useExternal) {
        _startPolling(auth, epoch, browserApproved: false);
      } else {
        _fallbackPollingTimer = Timer(widget.completionFallbackDelay, () {
          if (!mounted || epoch != _attemptEpoch) return;
          _startPolling(auth, epoch, browserApproved: false);
        });
      }
    } catch (e) {
      if (!mounted || epoch != _attemptEpoch) return;
      setState(() {
        _isPreparing = false;
        _isCompleting = false;
        _errorMessage = e.toString();
      });
    }
  }

  int _computeRemainingSeconds(DateTime expiresAt) {
    final seconds = expiresAt.difference(DateTime.now().toUtc()).inSeconds;
    return seconds < 0 ? 0 : seconds;
  }

  void _startCountdown(DeviceAuthorization auth, int epoch) {
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted || epoch != _attemptEpoch) {
        timer.cancel();
        return;
      }
      final remaining = _computeRemainingSeconds(auth.expiresAt);
      setState(() {
        _remainingSeconds = remaining;
      });
      if (remaining <= 0) {
        timer.cancel();
      }
    });
  }

  void _startPolling(
    DeviceAuthorization auth,
    int epoch, {
    required bool browserApproved,
  }) {
    if (!mounted || epoch != _attemptEpoch) return;
    if (_pollingActive) {
      if (browserApproved) {
        _wakeWaiter();
      }
      return;
    }

    _pollingActive = true;
    final completerFn =
        widget.completeSignIn ??
        ((
          DeviceAuthorization a, {
          required bool browserApproved,
          Future<void> Function(Duration)? wait,
          bool Function()? isCancelled,
        }) => Formula1Service.completeDeviceSignIn(
          a,
          browserApproved: browserApproved,
          wait: wait,
          isCancelled: isCancelled,
        ));

    completerFn(
          auth,
          browserApproved: browserApproved,
          wait: (duration) => _cancellableWait(duration, epoch),
          isCancelled: () => !mounted || epoch != _attemptEpoch,
        )
        .then((userData) {
          if (!mounted || epoch != _attemptEpoch) return;
          _cancelActiveAttempt();
          Navigator.of(context).pop(userData);
        })
        .catchError((Object error) {
          if (!mounted || epoch != _attemptEpoch) return;
          if (error is DeviceSignInException &&
              error.type == DeviceSignInErrorType.cancelled) {
            return;
          }
          _pollingActive = false;
          _fallbackPollingTimer?.cancel();
          _fallbackPollingTimer = null;
          setState(() {
            _isCompleting = false;
            _errorMessage = error.toString();
          });
        });
  }

  void _handleObservedUrl(Uri? uri, int epoch) {
    if (!mounted || epoch != _attemptEpoch || uri == null) return;
    if (uri.host.isNotEmpty && uri.host != _currentHost) {
      setState(() {
        _currentHost = uri.host;
      });
    }
    if (_completionTriggered) return;
    if (!Formula1Service.isBrowserCompletionUrl(uri)) return;

    final auth = _authorization;
    if (auth == null) return;

    _completionTriggered = true;
    _fallbackPollingTimer?.cancel();
    _fallbackPollingTimer = null;

    setState(() {
      _isCompleting = true;
      _isWebViewLoading = false;
      _errorMessage = null;
    });

    _startPolling(auth, epoch, browserApproved: true);
  }

  Future<void> _openInExternalBrowser() async {
    final auth = _authorization;
    if (auth == null) return;
    final epoch = _attemptEpoch;

    _fallbackPollingTimer?.cancel();
    _fallbackPollingTimer = null;

    setState(() {
      _useExternalBrowser = true;
      _isWebViewLoading = false;
      _errorMessage = null;
    });

    _startPolling(auth, epoch, browserApproved: false);

    try {
      final launcher =
          widget.launchExternalUrl ??
          ((Uri url) => launchUrl(url, mode: LaunchMode.externalApplication));
      final launched = await launcher(auth.verificationUriComplete);
      if (!launched && mounted && epoch == _attemptEpoch) {
        setState(() {
          _errorMessage =
              'Could not open your browser automatically. Copy the link below to open it manually.';
        });
      }
    } catch (_) {
      if (mounted && epoch == _attemptEpoch) {
        setState(() {
          _errorMessage =
              'Could not open your browser automatically. Copy the link below to open it manually.';
        });
      }
    }
  }

  Future<void> _copyText(String value, String label) async {
    await Clipboard.setData(ClipboardData(text: value));
    if (!mounted) return;
    if (AppNotificationService.instance.hasHost) {
      AppNotificationService.instance.showSuccess(
        id: 'clipboard_copy',
        title: '$label copied to clipboard',
        duration: const Duration(seconds: 2),
      );
      return;
    }
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      SnackBar(
        content: Text('$label copied to clipboard'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  String _formatCountdown(int totalSeconds) {
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    final size = MediaQuery.sizeOf(context);
    final dialogWidth = (size.width - 48).clamp(480.0, 820.0);
    final dialogHeight = (size.height - 48).clamp(440.0, 720.0);

    return Dialog(
      insetPadding: const EdgeInsets.all(24),
      backgroundColor: theme.colorScheme.card,
      shape: RoundedRectangleBorder(
        borderRadius: theme.radius,
        side: BorderSide(color: theme.colorScheme.border),
      ),
      child: SizedBox(
        width: dialogWidth,
        height: dialogHeight,
        child: Column(
          children: [
            _buildHeader(theme),
            Divider(height: 1, color: theme.colorScheme.border),
            if (_errorMessage != null && _authorization != null)
              _buildErrorBanner(theme),
            Expanded(child: _buildBody(theme)),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(ShadThemeData theme) {
    final auth = _authorization;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Icon(
            LucideIcons.lock,
            size: 18,
            color: theme.colorScheme.mutedForeground,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Sign in to F1TV', style: theme.textTheme.small),
                const SizedBox(height: 2),
                Text(
                  auth == null
                      ? 'Connecting to Formula 1...'
                      : '$_currentHost · Code ${auth.userCode} · Expires in ${_formatCountdown(_remainingSeconds)}',
                  style: theme.textTheme.muted.copyWith(fontSize: 12),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (auth != null && !_isCompleting && !_useExternalBrowser)
            ShadButton.outline(
              size: ShadButtonSize.sm,
              onPressed: _openInExternalBrowser,
              leading: const Icon(LucideIcons.externalLink, size: 14),
              child: const Text('Open in Browser'),
            ),
          if (auth != null && !_isCompleting && !_useExternalBrowser)
            const SizedBox(width: 6),
          ShadButton.outline(
            size: ShadButtonSize.sm,
            enabled: !_isPreparing,
            onPressed: () => _startSignIn(
              preferExternalBrowser:
                  _useExternalBrowser && !widget.forceExternalBrowser
                  ? false
                  : _useExternalBrowser,
            ),
            leading: const Icon(LucideIcons.refreshCw, size: 14),
            child: const Text('New Code'),
          ),
          const SizedBox(width: 6),
          ShadButton.ghost(
            size: ShadButtonSize.sm,
            onPressed: () {
              _cancelActiveAttempt();
              Navigator.of(context).pop(null);
            },
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorBanner(ShadThemeData theme) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: theme.colorScheme.destructive.withValues(alpha: 0.1),
        border: Border(bottom: BorderSide(color: theme.colorScheme.border)),
      ),
      child: Row(
        children: [
          Icon(
            LucideIcons.circleAlert,
            size: 16,
            color: theme.colorScheme.destructive,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _errorMessage!,
              style: theme.textTheme.small.copyWith(
                color: theme.colorScheme.destructive,
              ),
            ),
          ),
          const SizedBox(width: 8),
          if (_authorization != null && !_useExternalBrowser)
            ShadButton.outline(
              size: ShadButtonSize.sm,
              onPressed: _openInExternalBrowser,
              child: const Text('Use External Browser'),
            ),
          const SizedBox(width: 6),
          ShadButton.outline(
            size: ShadButtonSize.sm,
            onPressed: () => _startSignIn(
              preferExternalBrowser: _useExternalBrowser,
            ),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(ShadThemeData theme) {
    if (_isPreparing) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text('Preparing Formula 1 sign-in...', style: theme.textTheme.muted),
          ],
        ),
      );
    }

    final auth = _authorization;
    if (auth == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                LucideIcons.circleAlert,
                size: 40,
                color: theme.colorScheme.destructive,
              ),
              const SizedBox(height: 12),
              Text(
                'Could not start Formula 1 sign-in',
                style: theme.textTheme.h4,
              ),
              const SizedBox(height: 8),
              Text(
                _errorMessage ?? 'Please check your network or proxy settings.',
                style: theme.textTheme.muted,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ShadButton(
                onPressed: () => _startSignIn(),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (_isCompleting) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text('Completing sign-in...', style: theme.textTheme.h4),
            const SizedBox(height: 6),
            Text(
              'Retrieving your F1TV session and subscription details.',
              style: theme.textTheme.muted,
            ),
          ],
        ),
      );
    }

    if (_useExternalBrowser) {
      return _buildExternalBrowserPanel(theme, auth);
    }

    return _buildEmbeddedWebView(theme, auth);
  }

  Widget _buildExternalBrowserPanel(
    ShadThemeData theme,
    DeviceAuthorization auth,
  ) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Complete sign-in in your browser',
                style: theme.textTheme.h4,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Open the Formula 1 verification link in your browser, sign in to your F1TV account, and confirm the pairing code below.',
                style: theme.textTheme.muted,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 16,
                ),
                decoration: BoxDecoration(
                  color: theme.colorScheme.muted,
                  borderRadius: theme.radius,
                  border: Border.all(color: theme.colorScheme.border),
                ),
                child: Column(
                  children: [
                    Text(
                      'Pairing Code',
                      style: theme.textTheme.muted.copyWith(fontSize: 12),
                    ),
                    const SizedBox(height: 6),
                    SelectableText(
                      auth.userCode,
                      style: theme.textTheme.h2.copyWith(
                        fontFamily: 'monospace',
                        letterSpacing: 3,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Expires in ${_formatCountdown(_remainingSeconds)}',
                      style: theme.textTheme.muted.copyWith(fontSize: 12),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: ShadButton(
                      onPressed: _openInExternalBrowser,
                      leading: const Icon(LucideIcons.externalLink, size: 16),
                      child: const Text('Open F1 Sign-In Page'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: ShadButton.outline(
                      onPressed: () => _copyText(auth.userCode, 'Pairing code'),
                      leading: const Icon(LucideIcons.copy, size: 15),
                      child: const Text('Copy Code'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ShadButton.outline(
                      onPressed: () => _copyText(
                        auth.verificationUriComplete.toString(),
                        'Sign-in link',
                      ),
                      leading: const Icon(LucideIcons.link, size: 15),
                      child: const Text('Copy Link'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Waiting for browser confirmation...',
                    style: theme.textTheme.muted,
                  ),
                ],
              ),
              if (!widget.forceExternalBrowser && !_windowsWebViewUnavailable) ...[
                const SizedBox(height: 14),
                Center(
                  child: ShadButton.ghost(
                    size: ShadButtonSize.sm,
                    onPressed: () => _startSignIn(preferExternalBrowser: false),
                    child: const Text('Use in-app browser instead'),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmbeddedWebView(ShadThemeData theme, DeviceAuthorization auth) {
    final epoch = _attemptEpoch;
    final userScripts = UnmodifiableListView<UserScript>([
      UserScript(
        source: Formula1Service.buildWebsiteLanguageScript(),
        injectionTime: UserScriptInjectionTime.AT_DOCUMENT_START,
        forMainFrameOnly: true,
      ),
      UserScript(
        source: Formula1Service.buildCompletionWatcherScript(),
        injectionTime: UserScriptInjectionTime.AT_DOCUMENT_START,
        forMainFrameOnly: true,
      ),
      if (auth.hasPrefilledUserCode)
        UserScript(
          source: Formula1Service.buildVerificationScript(auth.userCode),
          injectionTime: UserScriptInjectionTime.AT_DOCUMENT_END,
          forMainFrameOnly: true,
        ),
    ]);

    return Stack(
      children: [
        InAppWebView(
          key: ValueKey('f1-login-webview-${auth.attemptId}'),
          webViewEnvironment: _webViewEnvironment,
          initialUrlRequest: URLRequest(
            url: WebUri(auth.verificationUriComplete.toString()),
          ),
          initialUserScripts: userScripts,
          initialSettings: InAppWebViewSettings(
            javaScriptEnabled: true,
            incognito: true,
            javaScriptCanOpenWindowsAutomatically: true,
          ),
          onWebViewCreated: (controller) {
            controller.addJavaScriptHandler(
              handlerName: 'f1Completion',
              callback: (args) {
                if (args.isNotEmpty && args.first is String) {
                  _handleObservedUrl(Uri.tryParse(args.first as String), epoch);
                }
                return null;
              },
            );
          },
          onLoadStart: (controller, url) {
            if (!mounted || epoch != _attemptEpoch) return;
            setState(() {
              _isWebViewLoading = true;
              _errorMessage = null;
              if (url != null && url.host.isNotEmpty) {
                _currentHost = url.host;
              }
            });
          },
          onLoadStop: (controller, url) {
            if (!mounted || epoch != _attemptEpoch) return;
            setState(() {
              _isWebViewLoading = false;
            });
            _handleObservedUrl(url, epoch);
          },
          onUpdateVisitedHistory: (controller, url, isReload) {
            _handleObservedUrl(url, epoch);
          },
          onCreateWindow: (controller, createWindowAction) async {
            final targetUrl = createWindowAction.request.url;
            if (targetUrl != null && targetUrl.scheme == 'https') {
              await controller.loadUrl(urlRequest: createWindowAction.request);
            }
            return false;
          },
          onReceivedError: (controller, request, error) {
            if (request.isForMainFrame != true) return;
            if (!mounted || epoch != _attemptEpoch) return;
            setState(() {
              _isWebViewLoading = false;
              _errorMessage =
                  'Failed to load the sign-in page (${error.description}). You can retry or open it in your external browser.';
            });
          },
        ),
        if (_isWebViewLoading)
          const Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: LinearProgressIndicator(minHeight: 2),
          ),
      ],
    );
  }
}

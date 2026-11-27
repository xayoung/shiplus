import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

enum AppNotificationType { info, loading, success, error }

class AppNotificationItem {
  const AppNotificationItem({
    required this.id,
    required this.type,
    required this.title,
    this.description,
    this.actionLabel,
    this.onAction,
    required this.duration,
    required this.revision,
    this.dismissOnAction = true,
  });

  final String id;
  final AppNotificationType type;
  final String title;
  final String? description;
  final String? actionLabel;
  final FutureOr<void> Function()? onAction;
  final Duration duration;
  final int revision;
  final bool dismissOnAction;
}

class AppNotificationService extends ChangeNotifier {
  AppNotificationService();

  static final AppNotificationService instance = AppNotificationService();

  static const int maxVisible = 3;
  static const Duration defaultInfoDuration = Duration(milliseconds: 2500);
  static const Duration defaultLoadingTimeout = Duration(seconds: 30);
  static const Duration defaultSuccessDuration = Duration(seconds: 4);
  static const Duration defaultErrorDuration = Duration(seconds: 5);

  final List<AppNotificationItem> _items = [];
  int _counter = 0;
  int _revision = 0;
  int _attachedHosts = 0;

  List<AppNotificationItem> get items => List.unmodifiable(_items);
  bool get hasHost => _attachedHosts > 0;

  void attachHost() {
    _attachedHosts++;
  }

  void detachHost() {
    if (_attachedHosts > 0) {
      _attachedHosts--;
    }
  }

  String show({
    String? id,
    required AppNotificationType type,
    required String title,
    String? description,
    String? actionLabel,
    FutureOr<void> Function()? onAction,
    Duration? duration,
    bool dismissOnAction = true,
  }) {
    final effectiveId = (id != null && id.isNotEmpty)
        ? id
        : 'notification_${++_counter}';
    final effectiveDuration = duration ?? _defaultDurationFor(type);
    final cleanTitle = title.trim().isEmpty ? 'Notification' : title.trim();
    final cleanDescription = description?.trim();

    final item = AppNotificationItem(
      id: effectiveId,
      type: type,
      title: cleanTitle,
      description:
          (cleanDescription != null && cleanDescription.isNotEmpty)
          ? cleanDescription
          : null,
      actionLabel:
          (actionLabel != null && actionLabel.trim().isNotEmpty && onAction != null)
          ? actionLabel.trim()
          : null,
      onAction: onAction,
      duration: effectiveDuration,
      revision: ++_revision,
      dismissOnAction: dismissOnAction,
    );

    final existingIndex = _items.indexWhere((element) => element.id == effectiveId);
    if (existingIndex != -1) {
      _items[existingIndex] = item;
    } else {
      while (_items.length >= maxVisible) {
        final evictIndex = _items.indexWhere(
          (element) =>
              element.type == AppNotificationType.info ||
              element.type == AppNotificationType.loading,
        );
        _items.removeAt(evictIndex != -1 ? evictIndex : 0);
      }
      _items.add(item);
    }

    notifyListeners();
    return effectiveId;
  }

  String showLoading({
    String? id,
    required String title,
    String? description,
    Duration? duration,
  }) {
    return show(
      id: id,
      type: AppNotificationType.loading,
      title: title,
      description: description,
      duration: duration ?? defaultLoadingTimeout,
    );
  }

  String showInfo({
    String? id,
    required String title,
    String? description,
    String? actionLabel,
    FutureOr<void> Function()? onAction,
    Duration? duration,
    bool dismissOnAction = true,
  }) {
    return show(
      id: id,
      type: AppNotificationType.info,
      title: title,
      description: description,
      actionLabel: actionLabel,
      onAction: onAction,
      duration: duration ?? defaultInfoDuration,
      dismissOnAction: dismissOnAction,
    );
  }

  String showSuccess({
    String? id,
    required String title,
    String? description,
    String? actionLabel,
    FutureOr<void> Function()? onAction,
    Duration? duration,
    bool dismissOnAction = true,
  }) {
    return show(
      id: id,
      type: AppNotificationType.success,
      title: title,
      description: description,
      actionLabel: actionLabel,
      onAction: onAction,
      duration: duration ?? defaultSuccessDuration,
      dismissOnAction: dismissOnAction,
    );
  }

  String showError({
    String? id,
    required String title,
    String? description,
    String? actionLabel,
    FutureOr<void> Function()? onAction,
    Duration? duration,
    bool dismissOnAction = true,
  }) {
    return show(
      id: id,
      type: AppNotificationType.error,
      title: title,
      description: description,
      actionLabel: actionLabel,
      onAction: onAction,
      duration: duration ?? defaultErrorDuration,
      dismissOnAction: dismissOnAction,
    );
  }

  void dismiss(String id) {
    final before = _items.length;
    _items.removeWhere((item) => item.id == id);
    if (_items.length != before) {
      notifyListeners();
    }
  }

  void clear() {
    if (_items.isEmpty) return;
    _items.clear();
    notifyListeners();
  }

  static Duration _defaultDurationFor(AppNotificationType type) {
    switch (type) {
      case AppNotificationType.info:
        return defaultInfoDuration;
      case AppNotificationType.loading:
        return defaultLoadingTimeout;
      case AppNotificationType.success:
        return defaultSuccessDuration;
      case AppNotificationType.error:
        return defaultErrorDuration;
    }
  }

  static String formatError(Object error) {
    if (error is DioException) {
      return _formatDioException(error);
    }
    if (error is FileSystemException) {
      final osMsg = error.osError?.message.trim();
      if (osMsg != null && osMsg.isNotEmpty) {
        return '${error.message} ($osMsg)';
      }
      return error.message;
    }
    return _cleanErrorText(error.toString());
  }

  static String _formatDioException(DioException error) {
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return 'Request timed out. Please check your network or proxy settings.';
      case DioExceptionType.connectionError:
        return 'Network connection failed. Please check your internet or proxy settings.';
      case DioExceptionType.cancel:
        return 'Request was cancelled.';
      case DioExceptionType.badCertificate:
        return 'SSL certificate verification failed.';
      case DioExceptionType.badResponse:
        final statusCode = error.response?.statusCode;
        final apiMessage = _extractResponseMessage(error.response?.data);
        if (statusCode == 401) {
          return 'Session expired (HTTP 401). Please sign in again in Settings.';
        }
        if (statusCode == 403) {
          return apiMessage != null
              ? 'Access denied (HTTP 403): $apiMessage'
              : 'Access denied (HTTP 403). Your account or region may not have access.';
        }
        if (statusCode == 404) {
          return 'Requested content was not found (HTTP 404).';
        }
        if (apiMessage != null) {
          return statusCode != null
              ? 'HTTP $statusCode: $apiMessage'
              : apiMessage;
        }
        return statusCode != null
            ? 'Server returned HTTP $statusCode.'
            : 'Server returned an invalid response.';
      case DioExceptionType.unknown:
        final underlying = error.error;
        if (underlying is SocketException) {
          return 'Network error: ${underlying.message}';
        }
        if (underlying != null) {
          return _cleanErrorText(underlying.toString());
        }
        final msg = error.message;
        if (msg != null && msg.trim().isNotEmpty) {
          return _cleanErrorText(msg);
        }
        return 'An unexpected network error occurred.';
    }
  }

  static String? _extractResponseMessage(dynamic data) {
    if (data is Map) {
      for (final key in const [
        'message',
        'errorDescription',
        'error_description',
        'error',
        'detail',
      ]) {
        final raw = data[key]?.toString().trim();
        if (raw != null &&
            raw.isNotEmpty &&
            raw.toLowerCase() != 'null' &&
            !_looksLikeHtml(raw)) {
          return _truncate(raw.replaceAll(RegExp(r'\s+'), ' '), 140);
        }
      }
      return null;
    }
    if (data is String) {
      final trimmed = data.trim();
      if (trimmed.isEmpty || _looksLikeHtml(trimmed)) {
        return null;
      }
      return _truncate(trimmed.replaceAll(RegExp(r'\s+'), ' '), 140);
    }
    return null;
  }

  static bool _looksLikeHtml(String value) {
    final lower = value.toLowerCase();
    return lower.contains('<!doctype') ||
        lower.contains('<html') ||
        lower.contains('<body');
  }

  static String _cleanErrorText(String raw) {
    var text = raw.trim();
    while (text.startsWith('Exception: ') || text.startsWith('Error: ')) {
      if (text.startsWith('Exception: ')) {
        text = text.substring('Exception: '.length).trim();
      } else if (text.startsWith('Error: ')) {
        text = text.substring('Error: '.length).trim();
      }
    }
    final readMoreIndex = text.indexOf('Read more at ');
    if (readMoreIndex > 0) {
      text = text.substring(0, readMoreIndex).trim();
    }
    text = text.replaceAll(RegExp(r'\s+'), ' ');
    if (text.isEmpty) {
      return 'An unexpected error occurred.';
    }
    return _truncate(text, 160);
  }

  static String _truncate(String value, int maxLength) {
    if (value.length <= maxLength) return value;
    return '${value.substring(0, maxLength - 3)}...';
  }
}

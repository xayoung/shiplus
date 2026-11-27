import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../services/app_notification_service.dart';

class AppNotificationOverlay extends StatefulWidget {
  const AppNotificationOverlay({
    super.key,
    required this.child,
    this.service,
  });

  final Widget child;
  final AppNotificationService? service;

  @override
  State<AppNotificationOverlay> createState() => _AppNotificationOverlayState();
}

class _AppNotificationOverlayState extends State<AppNotificationOverlay> {
  final Map<String, _NotificationTimerEntry> _timers = {};

  AppNotificationService get _service =>
      widget.service ?? AppNotificationService.instance;

  @override
  void initState() {
    super.initState();
    _service.attachHost();
    _service.addListener(_onServiceChanged);
    _syncTimers();
  }

  @override
  void didUpdateWidget(covariant AppNotificationOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    final oldService = oldWidget.service ?? AppNotificationService.instance;
    if (!identical(oldService, _service)) {
      oldService.removeListener(_onServiceChanged);
      oldService.detachHost();
      _cancelAllTimers();
      _service.attachHost();
      _service.addListener(_onServiceChanged);
      _syncTimers();
    }
  }

  @override
  void dispose() {
    _service.removeListener(_onServiceChanged);
    _service.detachHost();
    _cancelAllTimers();
    super.dispose();
  }

  void _onServiceChanged() {
    if (!mounted) return;
    _syncTimers();
    setState(() {});
  }

  void _syncTimers() {
    final activeIds = _service.items.map((item) => item.id).toSet();
    final staleIds = _timers.keys
        .where((id) => !activeIds.contains(id))
        .toList();
    for (final id in staleIds) {
      _timers.remove(id)?.cancel();
    }

    for (final item in _service.items) {
      final existing = _timers[item.id];
      if (existing == null || existing.revision != item.revision) {
        existing?.cancel();
        _timers[item.id] = _startTimerEntry(item);
      }
    }
  }

  _NotificationTimerEntry _startTimerEntry(AppNotificationItem item) {
    final entry = _NotificationTimerEntry(
      id: item.id,
      revision: item.revision,
      remaining: item.duration,
    );
    _scheduleEntry(entry);
    return entry;
  }

  void _scheduleEntry(_NotificationTimerEntry entry) {
    entry.cancel();
    entry.paused = false;
    entry.startedAt = DateTime.now();
    entry.timer = Timer(entry.remaining, () {
      if (!mounted) return;
      _service.dismiss(entry.id);
    });
  }

  void _pauseTimer(String id) {
    final entry = _timers[id];
    if (entry == null || entry.paused) return;
    entry.paused = true;
    final startedAt = entry.startedAt;
    if (startedAt != null) {
      final elapsed = DateTime.now().difference(startedAt);
      final remainingMs = math.max(
        800,
        entry.remaining.inMilliseconds - elapsed.inMilliseconds,
      );
      entry.remaining = Duration(milliseconds: remainingMs);
    }
    entry.cancel();
  }

  void _resumeTimer(String id) {
    final entry = _timers[id];
    if (entry == null || !entry.paused) return;
    _scheduleEntry(entry);
  }

  void _cancelAllTimers() {
    for (final entry in _timers.values) {
      entry.cancel();
    }
    _timers.clear();
  }

  @override
  Widget build(BuildContext context) {
    final items = _service.items;
    final isCompact = MediaQuery.sizeOf(context).width < 760;
    final bottomOffset =
        MediaQuery.viewPaddingOf(context).bottom + (isCompact ? 76.0 : 20.0);

    return Stack(
      children: [
        widget.child,
        if (items.isNotEmpty)
          Positioned(
            left: 0,
            right: 0,
            bottom: bottomOffset,
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 460),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (int i = 0; i < items.length; i++) ...[
                        if (i > 0) const SizedBox(height: 8),
                        _NotificationCard(
                          key: ValueKey('app-notification-${items[i].id}'),
                          item: items[i],
                          onDismiss: () => _service.dismiss(items[i].id),
                          onHoverEnter: () => _pauseTimer(items[i].id),
                          onHoverExit: () => _resumeTimer(items[i].id),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _NotificationTimerEntry {
  _NotificationTimerEntry({
    required this.id,
    required this.revision,
    required this.remaining,
  });

  final String id;
  final int revision;
  Duration remaining;
  DateTime? startedAt;
  Timer? timer;
  bool paused = false;

  void cancel() {
    timer?.cancel();
    timer = null;
  }
}

class _NotificationCard extends StatelessWidget {
  const _NotificationCard({
    super.key,
    required this.item,
    required this.onDismiss,
    required this.onHoverEnter,
    required this.onHoverExit,
  });

  final AppNotificationItem item;
  final VoidCallback onDismiss;
  final VoidCallback onHoverEnter;
  final VoidCallback onHoverExit;

  @override
  Widget build(BuildContext context) {
    final shad = ShadTheme.of(context);
    final isDark = shad.brightness == Brightness.dark;
    final palette = _resolvePalette(shad, isDark);

    return MouseRegion(
      onEnter: (_) => onHoverEnter(),
      onExit: (_) => onHoverExit(),
      child: Material(
        type: MaterialType.transparency,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: palette.backgroundColor,
            borderRadius: shad.radius,
            border: Border.all(color: palette.borderColor),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.45 : 0.14),
                blurRadius: 18,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                _buildLeadingIcon(palette),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: shad.textTheme.small.copyWith(
                          color: palette.titleColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (item.description != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          item.description!,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: shad.textTheme.muted.copyWith(
                            fontSize: 12,
                            color: palette.descriptionColor,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (item.actionLabel != null && item.onAction != null) ...[
                  const SizedBox(width: 8),
                  ShadButton.outline(
                    size: ShadButtonSize.sm,
                    onPressed: () async {
                      if (item.dismissOnAction) {
                        onDismiss();
                      }
                      try {
                        await item.onAction!();
                      } catch (e) {
                        AppNotificationService.instance.showError(
                          title: 'Action failed',
                          description: AppNotificationService.formatError(e),
                        );
                      }
                    },
                    child: Text(item.actionLabel!),
                  ),
                ],
                const SizedBox(width: 4),
                ShadIconButton.ghost(
                  key: ValueKey('app-notification-close-${item.id}'),
                  width: 26,
                  height: 26,
                  padding: EdgeInsets.zero,
                  foregroundColor: palette.descriptionColor,
                  onPressed: onDismiss,
                  icon: const Icon(LucideIcons.x, size: 15),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLeadingIcon(_NotificationPalette palette) {
    if (item.type == AppNotificationType.loading) {
      return SizedBox(
        width: 18,
        height: 18,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          valueColor: AlwaysStoppedAnimation<Color>(palette.iconColor),
        ),
      );
    }

    final iconData = switch (item.type) {
      AppNotificationType.success => LucideIcons.circleCheck,
      AppNotificationType.error => LucideIcons.circleAlert,
      AppNotificationType.info => LucideIcons.info,
      AppNotificationType.loading => LucideIcons.loader,
    };

    return Icon(iconData, size: 18, color: palette.iconColor);
  }

  _NotificationPalette _resolvePalette(ShadThemeData shad, bool isDark) {
    final scheme = shad.colorScheme;
    switch (item.type) {
      case AppNotificationType.success:
        final green = isDark
            ? const Color(0xFF34D399)
            : const Color(0xFF059669);
        return _NotificationPalette(
          backgroundColor: Color.alphaBlend(
            green.withValues(alpha: isDark ? 0.12 : 0.07),
            scheme.card,
          ),
          borderColor: green.withValues(alpha: 0.45),
          iconColor: green,
          titleColor: scheme.foreground,
          descriptionColor: scheme.mutedForeground,
        );
      case AppNotificationType.error:
        final red = scheme.destructive;
        return _NotificationPalette(
          backgroundColor: Color.alphaBlend(
            red.withValues(alpha: isDark ? 0.22 : 0.08),
            scheme.card,
          ),
          borderColor: red.withValues(alpha: 0.55),
          iconColor: isDark ? const Color(0xFFFCA5A5) : red,
          titleColor: isDark ? const Color(0xFFFECACA) : red,
          descriptionColor: scheme.foreground.withValues(alpha: 0.9),
        );
      case AppNotificationType.loading:
      case AppNotificationType.info:
        return _NotificationPalette(
          backgroundColor: scheme.card,
          borderColor: scheme.border,
          iconColor: scheme.primary,
          titleColor: scheme.foreground,
          descriptionColor: scheme.mutedForeground,
        );
    }
  }
}

class _NotificationPalette {
  const _NotificationPalette({
    required this.backgroundColor,
    required this.borderColor,
    required this.iconColor,
    required this.titleColor,
    required this.descriptionColor,
  });

  final Color backgroundColor;
  final Color borderColor;
  final Color iconColor;
  final Color titleColor;
  final Color descriptionColor;
}

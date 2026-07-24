import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

class ShiplusPageHeader extends StatelessWidget {
  const ShiplusPageHeader({
    super.key,
    required this.title,
    this.description,
    this.icon,
    this.actions = const [],
  });

  final String title;
  final String? description;
  final IconData? icon;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (icon != null) ...[
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: theme.colorScheme.accent,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              icon,
              size: 20,
              color: theme.colorScheme.accentForeground,
            ),
          ),
          const SizedBox(width: 12),
        ],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: theme.textTheme.h2),
              if (description != null) ...[
                const SizedBox(height: 4),
                Text(description!, style: theme.textTheme.muted),
              ],
            ],
          ),
        ),
        if (actions.isNotEmpty) ...[
          const SizedBox(width: 16),
          Wrap(spacing: 8, children: actions),
        ],
      ],
    );
  }
}

class ShiplusSectionCard extends StatelessWidget {
  const ShiplusSectionCard({
    super.key,
    this.title,
    this.description,
    this.leading,
    this.trailing,
    this.footer,
    required this.child,
    this.padding,
  });

  final Widget? title;
  final Widget? description;
  final Widget? leading;
  final Widget? trailing;
  final Widget? footer;
  final Widget child;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return ShadCard(
      width: double.infinity,
      title: title,
      description: description,
      leading: leading,
      trailing: trailing,
      footer: footer,
      padding: padding,
      child: child,
    );
  }
}

class ShiplusLoadingState extends StatelessWidget {
  const ShiplusLoadingState({super.key, this.label = 'Loading...'});

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 280),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const ShadProgress(minHeight: 6),
            const SizedBox(height: 14),
            Text(label, style: theme.textTheme.muted),
          ],
        ),
      ),
    );
  }
}

class ShiplusErrorState extends StatelessWidget {
  const ShiplusErrorState({
    super.key,
    required this.message,
    required this.onRetry,
    this.title = 'Something went wrong',
  });

  final String title;
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: ShadAlert.destructive(
          icon: const Icon(LucideIcons.circleAlert),
          title: Text(title),
          description: Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(message),
                const SizedBox(height: 14),
                ShadButton.outline(
                  leading: const Icon(LucideIcons.refreshCw, size: 16),
                  onPressed: onRetry,
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class ShiplusEmptyState extends StatelessWidget {
  const ShiplusEmptyState({
    super.key,
    required this.title,
    required this.description,
    this.icon = LucideIcons.inbox,
  });

  final String title;
  final String description;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: theme.colorScheme.muted,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: theme.colorScheme.mutedForeground),
          ),
          const SizedBox(height: 16),
          Text(title, style: theme.textTheme.h4),
          const SizedBox(height: 6),
          Text(description, style: theme.textTheme.muted),
        ],
      ),
    );
  }
}

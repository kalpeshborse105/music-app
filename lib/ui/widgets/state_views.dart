import 'package:flutter/material.dart';

import '../../core/errors/app_exception.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

/// Loading view with branded indicator.
class LoadingView extends StatelessWidget {
  final String? message;
  const LoadingView({super.key, this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const SizedBox(
            width: 32,
            height: 32,
            child: CircularProgressIndicator(
              strokeWidth: 2.8,
              color: AppColors.primary,
            ),
          ),
          if (message != null) ...<Widget>[
            const SizedBox(height: AppSpacing.lg),
            Text(
              message!,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondaryDark,
                  ),
            ),
          ],
        ],
      ),
    );
  }
}

/// A generic empty/error state with an icon, title, subtitle and optional retry.
class MessageView extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;

  const MessageView({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.actionLabel,
    this.onAction,
  });

  /// Build the right view for an error.
  factory MessageView.fromError(Object error, {VoidCallback? onRetry}) {
    final IconData icon;
    final String title;
    final String subtitle;

    if (error is AppException) {
      subtitle = error.message;
    } else {
      subtitle = 'Please check your connection and try again.';
    }

    if (error is OfflineException) {
      icon = Icons.wifi_off_rounded;
      title = 'You are offline';
    } else if (error is RateLimitException) {
      icon = Icons.hourglass_top_rounded;
      title = 'Service busy';
    } else if (error is AuthenticationException) {
      icon = Icons.key_off_rounded;
      title = 'Provider not configured';
    } else if (error is TimeoutException) {
      icon = Icons.timer_off_rounded;
      title = 'Connection timed out';
    } else if (error is NotFoundException || error is TrackUnavailableException) {
      icon = Icons.music_off_rounded;
      title = 'Not available';
    } else {
      icon = Icons.cloud_off_rounded;
      title = 'Something went wrong';
    }

    return MessageView(
      icon: icon,
      title: title,
      subtitle: subtitle,
      actionLabel: onRetry != null ? 'Try Again' : null,
      onAction: onRetry,
    );
  }

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerHigh.withValues(alpha: 0.6),
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.borderSubtle),
              ),
              child: Icon(icon, size: 36, color: AppColors.primaryLight),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              title,
              style: text.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              textAlign: TextAlign.center,
            ),
            if (subtitle != null) ...<Widget>[
              const SizedBox(height: AppSpacing.sm),
              Text(
                subtitle!,
                style: text.bodySmall?.copyWith(color: AppColors.textSecondaryDark),
                textAlign: TextAlign.center,
              ),
            ],
            if (actionLabel != null && onAction != null) ...<Widget>[
              const SizedBox(height: AppSpacing.xl),
              FilledButton(
                onPressed: onAction,
                child: Text(actionLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Section header with Stitch headline-sm typography and accent action button.
class SectionHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;
  final Widget? trailing;

  const SectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.actionLabel,
    this.onAction,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.xl,
        AppSpacing.lg,
        AppSpacing.sm,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  title,
                  style: const TextStyle(
                    fontFamily: 'Plus Jakarta Sans',
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.01,
                  ),
                ),
                if (subtitle != null) ...<Widget>[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 12,
                      color: AppColors.textSecondaryDark,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (trailing != null)
            trailing!
          else if (actionLabel != null && onAction != null)
            InkWell(
              onTap: onAction,
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Text(
                  actionLabel!,
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.secondary,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

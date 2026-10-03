import 'package:flutter/material.dart';

import '../theme/app_spacing.dart';

/// Small label showing which provider/source a track came from. Users get a
/// clear, honest signal of the source without ever seeing a raw stream URL
/// (spec §22/§29).
class SourceBadge extends StatelessWidget {
  final String label;
  final IconData icon;

  const SourceBadge({super.key, required this.label, this.icon = Icons.cloud_queue_rounded});

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: 3,
      ),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.6),
        borderRadius: AppSpacing.brPill,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 11, color: scheme.onSurfaceVariant),
          const SizedBox(width: 4),
          Text(
            label,
            style: Theme.of(context)
                .textTheme
                .labelSmall
                ?.copyWith(fontSize: 10, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

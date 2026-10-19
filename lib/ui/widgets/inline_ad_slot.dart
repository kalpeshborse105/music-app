import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../data/services/supabase_service.dart';
import '../../domain/models/advertisement.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

/// Compact inline ad that only takes space when an active placement exists.
/// Does not alter surrounding track/section layout when inactive.
class InlineAdSlot extends StatefulWidget {
  final String placement;
  final EdgeInsetsGeometry padding;

  const InlineAdSlot({
    super.key,
    required this.placement,
    this.padding = const EdgeInsets.fromLTRB(
      AppSpacing.lg,
      AppSpacing.sm,
      AppSpacing.lg,
      AppSpacing.sm,
    ),
  });

  @override
  State<InlineAdSlot> createState() => _InlineAdSlotState();
}

class _InlineAdSlotState extends State<InlineAdSlot> {
  Advertisement? _ad;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant InlineAdSlot oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.placement != widget.placement) {
      _load();
    }
  }

  Future<void> _load() async {
    try {
      final List<Advertisement> ads =
          await SupabaseService().fetchActiveAdvertisements(
        placement: widget.placement,
      );
      if (!mounted) return;
      setState(() => _ad = ads.isEmpty ? null : ads.first);
    } catch (_) {
      if (!mounted) return;
      setState(() => _ad = null);
    }
  }

  Future<void> _open() async {
    final String? url = _ad?.targetUrl?.trim();
    if (url == null || url.isEmpty) return;
    try {
      final Uri uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final Advertisement? ad = _ad;
    if (ad == null || ad.imageUrl.isEmpty) {
      return const SizedBox.shrink();
    }
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: widget.padding,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _open,
          borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
          child: Ink(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
              border: Border.all(
                color: isDark ? AppColors.borderSubtle : AppColors.lightBorder,
              ),
              color: isDark
                  ? AppColors.surfaceContainerHigh.withValues(alpha: 0.55)
                  : AppColors.lightElevatedSurface,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(AppSpacing.radiusLg),
                  ),
                  child: AspectRatio(
                    aspectRatio: 16 / 7,
                    child: CachedNetworkImage(
                      imageUrl: ad.imageUrl,
                      fit: BoxFit.cover,
                      placeholder: (_, __) => Container(
                        color: Colors.black26,
                        alignment: Alignment.center,
                        child: const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                      errorWidget: (_, __, ___) => Container(
                        color: Colors.black26,
                        alignment: Alignment.center,
                        child: const Icon(Icons.campaign_rounded),
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
                  child: Row(
                    children: <Widget>[
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.amber.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'AD',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: Colors.amber,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          ad.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: context.textPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

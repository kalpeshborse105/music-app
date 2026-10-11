import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../data/services/supabase_service.dart';
import '../../domain/models/advertisement.dart';
import '../theme/app_colors.dart';

/// Amazon Prime / Spotify style promotional popup dialog
/// Controlled exclusively via the Admin Dashboard.
class AdPopupDialog extends StatelessWidget {
  final Advertisement ad;

  const AdPopupDialog({
    super.key,
    required this.ad,
  });

  static bool _hasShownThisSession = false;

  /// Checks for any active admin-configured advertisements and displays
  /// the popup on app start if not already shown in the current session.
  static Future<void> showIfAvailable(BuildContext context) async {
    if (_hasShownThisSession) return;
    try {
      final List<Advertisement> activeAds =
          await SupabaseService().fetchActiveAdvertisements();
      if (activeAds.isEmpty) return;

      _hasShownThisSession = true;
      final Advertisement selectedAd = activeAds.first;

      if (!context.mounted) return;

      await showDialog<void>(
        context: context,
        barrierDismissible: true,
        barrierColor: Colors.black.withValues(alpha: 0.8),
        builder: (BuildContext ctx) => AdPopupDialog(ad: selectedAd),
      );
    } catch (e) {
      debugPrint('[AdPopupDialog] Error loading ad: $e');
    }
  }

  /// Forces displaying an ad (useful for Admin Preview mode)
  static Future<void> preview(BuildContext context, Advertisement ad) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black.withValues(alpha: 0.8),
      builder: (BuildContext ctx) => AdPopupDialog(ad: ad),
    );
  }

  Future<void> _handleAdClick(BuildContext context) async {
    final String? url = ad.targetUrl?.trim();
    if (url != null && url.isNotEmpty) {
      try {
        final Uri uri = Uri.parse(url);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        }
      } catch (e) {
        debugPrint('[AdPopupDialog] Failed to open URL: $e');
      }
    }
  }

  Widget _buildCloseButton(BuildContext context) {
    switch (ad.closeButtonType) {
      case 'text_and_cross':
        return Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => Navigator.of(context).pop(),
            borderRadius: BorderRadius.circular(20),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.25),
                  width: 1,
                ),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    'Close',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.3,
                    ),
                  ),
                  SizedBox(width: 5),
                  Icon(
                    Icons.close_rounded,
                    size: 16,
                    color: Colors.white,
                  ),
                ],
              ),
            ),
          ),
        );

      case 'text_only':
        return Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => Navigator.of(context).pop(),
            borderRadius: BorderRadius.circular(20),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.25),
                  width: 1,
                ),
              ),
              child: const Text(
                'Skip',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.3,
                ),
              ),
            ),
          ),
        );

      case 'icon':
      default:
        return Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => Navigator.of(context).pop(),
            borderRadius: BorderRadius.circular(22),
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.black.withValues(alpha: 0.75),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.3),
                  width: 1,
                ),
              ),
              child: const Icon(
                Icons.close_rounded,
                size: 20,
                color: Colors.white,
              ),
            ),
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final Size size = MediaQuery.of(context).size;
    final double maxDialogWidth = size.width > 500 ? 440 : size.width * 0.88;

    return Center(
      child: SingleChildScrollView(
        child: Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          child: Container(
            width: maxDialogWidth,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: <Color>[
                  Color(0xFF1E1E2E),
                  Color(0xFF0F0F1A),
                ],
              ),
              border: Border.all(
                color: AppColors.primary.withValues(alpha: 0.35),
                width: 1.5,
              ),
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.25),
                  blurRadius: 32,
                  spreadRadius: 2,
                  offset: const Offset(0, 10),
                ),
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.7),
                  blurRadius: 20,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: Stack(
                children: <Widget>[
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      // Promotional Banner Image
                      if (ad.imageUrl.isNotEmpty)
                        GestureDetector(
                          onTap: () => _handleAdClick(context),
                          child: Stack(
                            children: <Widget>[
                              AspectRatio(
                                aspectRatio: 16 / 9,
                                child: CachedNetworkImage(
                                  imageUrl: ad.imageUrl,
                                  fit: BoxFit.cover,
                                  placeholder: (BuildContext ctx, String url) => Container(
                                    color: const Color(0xFF181824),
                                    child: const Center(
                                      child: SizedBox(
                                        width: 28,
                                        height: 28,
                                        child: CircularProgressIndicator(strokeWidth: 2),
                                      ),
                                    ),
                                  ),
                                  errorWidget: (BuildContext ctx, String url, Object err) => Container(
                                    color: const Color(0xFF181824),
                                    child: const Center(
                                      child: Icon(
                                        Icons.image_not_supported_rounded,
                                        color: Colors.white54,
                                        size: 40,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              // Gradient Overlay at bottom of image
                              Positioned(
                                bottom: 0,
                                left: 0,
                                right: 0,
                                height: 60,
                                child: Container(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                      colors: <Color>[
                                        Colors.transparent,
                                        const Color(0xFF1E1E2E).withValues(alpha: 0.95),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                      // Text and Action Content
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: <Widget>[
                            // Sponsored Badge
                            Row(
                              children: <Widget>[
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: AppColors.primary.withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(
                                      color: AppColors.primary.withValues(alpha: 0.4),
                                      width: 0.8,
                                    ),
                                  ),
                                  child: const Text(
                                    'SPONSORED',
                                    style: TextStyle(
                                      color: AppColors.primary,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 0.8,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),

                            // Ad Title
                            Text(
                              ad.title,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                height: 1.25,
                              ),
                            ),

                            // Subtitle / Description
                            if (ad.subtitle != null && ad.subtitle!.isNotEmpty) ...<Widget>[
                              const SizedBox(height: 8),
                              Text(
                                ad.subtitle!,
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.75),
                                  fontSize: 13,
                                  height: 1.4,
                                ),
                              ),
                            ],

                            const SizedBox(height: 18),

                            // Call to Action Buttons
                            Row(
                              children: <Widget>[
                                if (ad.targetUrl != null && ad.targetUrl!.isNotEmpty)
                                  Expanded(
                                    child: ElevatedButton(
                                      onPressed: () => _handleAdClick(context),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AppColors.primary,
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(vertical: 13),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        elevation: 4,
                                      ),
                                      child: const Text(
                                        'Explore Now',
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                          letterSpacing: 0.3,
                                        ),
                                      ),
                                    ),
                                  ),
                                if (ad.targetUrl != null && ad.targetUrl!.isNotEmpty)
                                  const SizedBox(width: 10),
                                TextButton(
                                  onPressed: () => Navigator.of(context).pop(),
                                  style: TextButton.styleFrom(
                                    foregroundColor: Colors.white70,
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                                  ),
                                  child: const Text('Dismiss'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  // Admin-Controlled Close Button (Positioned top-right)
                  Positioned(
                    top: 12,
                    right: 12,
                    child: _buildCloseButton(context),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

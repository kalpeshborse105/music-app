import 'dart:convert';
import 'dart:typed_data';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../data/services/supabase_service.dart';
import '../../domain/models/advertisement.dart';

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

  Widget _buildPosterImage(String url) {
    if (url.startsWith('data:image')) {
      try {
        final int commaIdx = url.indexOf(',');
        if (commaIdx != -1) {
          final Uint8List bytes = base64Decode(url.substring(commaIdx + 1));
          return Image.memory(
            bytes,
            fit: BoxFit.contain,
          );
        }
      } catch (e) {
        debugPrint('[AdPopupDialog] Error decoding base64 image: $e');
      }
    }

    return CachedNetworkImage(
      imageUrl: url,
      fit: BoxFit.contain,
      placeholder: (BuildContext ctx, String u) => Container(
        height: 320,
        color: const Color(0xFF181824),
        child: const Center(
          child: SizedBox(
            width: 32,
            height: 32,
            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white70),
          ),
        ),
      ),
      errorWidget: (BuildContext ctx, String u, Object err) => Image.network(
        url,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => Container(
          height: 240,
          color: const Color(0xFF181824),
          child: const Center(
            child: Icon(Icons.broken_image_rounded, color: Colors.white54, size: 48),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final Size size = MediaQuery.of(context).size;
    final double maxDialogWidth = size.width > 520 ? 440 : size.width * 0.90;
    final double maxDialogHeight = size.height * 0.82;

    return Center(
      child: Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: maxDialogWidth,
            maxHeight: maxDialogHeight,
          ),
          child: Stack(
            alignment: Alignment.topRight,
            children: <Widget>[
              // Proper Clean Poster (Edge-to-Edge, no extra space or borders)
              GestureDetector(
                onTap: () => _handleAdClick(context),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: <BoxShadow>[
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.65),
                          blurRadius: 28,
                          spreadRadius: 2,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: _buildPosterImage(ad.imageUrl),
                  ),
                ),
              ),

              // Admin-Controlled Close Button Only
              Positioned(
                top: 10,
                right: 10,
                child: _buildCloseButton(context),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

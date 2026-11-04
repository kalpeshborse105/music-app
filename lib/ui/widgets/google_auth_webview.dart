import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../data/services/supabase_service.dart';
import '../theme/app_colors.dart';

/// In-app Google OAuth (MahaTicket-style): pick account in WebView, then return
/// to the app without leaving a stuck Chrome tab.
class GoogleAuthWebView extends StatefulWidget {
  final String authUrl;
  final VoidCallback onClose;
  final VoidCallback? onSuccess;
  final ValueChanged<String>? onError;

  const GoogleAuthWebView({
    super.key,
    required this.authUrl,
    required this.onClose,
    this.onSuccess,
    this.onError,
  });

  @override
  State<GoogleAuthWebView> createState() => _GoogleAuthWebViewState();
}

class _GoogleAuthWebViewState extends State<GoogleAuthWebView> {
  late final WebViewController _controller;
  bool _pageLoading = true;
  bool _completing = false;
  bool _handled = false;

  static const String _mobileUserAgent =
      'Mozilla/5.0 (Linux; Android 13) AppleWebKit/537.36 '
      '(KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36 '
      'KalpkrutBeats/1.0';

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0xFF0A0A14))
      ..setUserAgent(_mobileUserAgent)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) {
            if (mounted && !_completing) setState(() => _pageLoading = true);
          },
          onPageFinished: (_) {
            if (mounted && !_completing) setState(() => _pageLoading = false);
          },
          onWebResourceError: (WebResourceError error) {
            // Custom-scheme redirects often surface as load errors — ignore if handled.
            if (_handled) return;
            final String? url = error.url;
            if (url != null && _isOAuthCallback(url)) {
              _finishFromUrl(url);
            }
          },
          onNavigationRequest: (NavigationRequest request) {
            if (_isOAuthCallback(request.url)) {
              _finishFromUrl(request.url);
              return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.authUrl));
  }

  bool _isOAuthCallback(String url) {
    if (url.startsWith('com.kalpkrut.beats://')) return true;
    final Uri? uri = Uri.tryParse(url);
    if (uri == null) return false;
    final bool hasCode = (uri.queryParameters['code'] ?? '').isNotEmpty;
    final bool hasError = (uri.queryParameters['error'] ?? '').isNotEmpty;
    if (!hasCode && !hasError) return false;
    final String host = uri.host.toLowerCase();
    return host.contains('kalpkrutinfotech.com') ||
        host.contains('supabase.co') ||
        uri.scheme == 'com.kalpkrut.beats';
  }

  Future<void> _finishFromUrl(String url) async {
    if (_handled) return;
    _handled = true;
    if (mounted) {
      setState(() {
        _completing = true;
        _pageLoading = false;
      });
    }

    final Uri uri = Uri.parse(url);
    final String? err = uri.queryParameters['error'] ??
        uri.queryParameters['error_description'];
    if (err != null && err.isNotEmpty) {
      widget.onError?.call(
        err == 'access_denied'
            ? 'Google sign-in was cancelled.'
            : err.replaceAll('+', ' '),
      );
      return;
    }

    try {
      await SupabaseService().completeGoogleOAuthFromUrl(url);
      if (!mounted) return;
      // Parent closes the WebView and shows the success loader.
      widget.onSuccess?.call();
    } catch (e) {
      _handled = false;
      final String message = e.toString().contains('flow_state_already_used')
          ? 'Sign-in already completed. Please try again.'
          : 'Google sign-in failed. Please try again.';
      if (mounted) {
        setState(() => _completing = false);
      }
      widget.onError?.call(message);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.background,
      child: SafeArea(
        child: Column(
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
              child: Row(
                children: <Widget>[
                  IconButton(
                    tooltip: 'Close',
                    onPressed: _completing
                        ? null
                        : () {
                            if (widget.onError != null) {
                              widget.onError!(
                                'Google sign-in was cancelled.',
                              );
                            } else {
                              widget.onClose();
                            }
                          },
                    icon: const Icon(Icons.close_rounded, color: Colors.white),
                  ),
                  const Expanded(
                    child: Text(
                      'Google Sign-In',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 48),
                ],
              ),
            ),
            const Divider(height: 1, color: Color(0x22FFFFFF)),
            Expanded(
              child: Stack(
                children: <Widget>[
                  WebViewWidget(controller: _controller),
                  if (_pageLoading || _completing)
                    ColoredBox(
                      color: AppColors.background.withValues(
                        alpha: _completing ? 0.92 : 0.55,
                      ),
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            const CircularProgressIndicator(
                              color: AppColors.electricViolet,
                              strokeWidth: 3,
                            ),
                            const SizedBox(height: 18),
                            Text(
                              _completing
                                  ? 'Signing you in…'
                                  : 'Loading Google…',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.9),
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            if (_completing) ...<Widget>[
                              const SizedBox(height: 6),
                              Text(
                                'Please wait a moment',
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.5),
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

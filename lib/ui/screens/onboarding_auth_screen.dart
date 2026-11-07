import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/utils/auth_utils.dart';
import '../../data/services/supabase_service.dart';
import '../theme/app_colors.dart';
import '../widgets/glass_card.dart';
import '../widgets/google_auth_webview.dart';

/// Screen representing Stitch UI "Kalpkrut Beats - Onboarding & Auth"
/// (Screen ID: f44179deb8b14f2f84a5766edd493fc7)
/// Fully integrated with real Supabase authentication (Sign In, Sign Up,
/// Password Recovery, Session Persistence, and Guest Mode).
class OnboardingAuthScreen extends StatefulWidget {
  final VoidCallback onComplete;
  final bool initialShowAuthForm;
  final bool initialSignUp;

  const OnboardingAuthScreen({
    super.key,
    required this.onComplete,
    this.initialShowAuthForm = false,
    this.initialSignUp = false,
  });

  @override
  State<OnboardingAuthScreen> createState() => _OnboardingAuthScreenState();
}

class _OnboardingAuthScreenState extends State<OnboardingAuthScreen> {
  late bool _showAuthForm;
  late bool _isSignUp;
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _nameController = TextEditingController();
  String? _errorMessage;
  StreamSubscription<AuthState>? _authSub;
  bool _waitingForGoogleOAuth = false;
  bool _showGoogleWebView = false;
  String? _googleAuthUrl;
  bool _completingGoogle = false;

  @override
  void initState() {
    super.initState();
    _showAuthForm = widget.initialShowAuthForm;
    _isSignUp = widget.initialSignUp;

    // Reactively complete auth when session arrives (browser OAuth deep link).
    _authSub = SupabaseService().authStateChanges.listen((AuthState data) async {
      if (data.session == null || !mounted) return;
      // In-app WebView (if ever used) finishes via _onGoogleWebViewSuccess.
      if (_showGoogleWebView) return;
      final bool fromGoogle = _waitingForGoogleOAuth || _completingGoogle;
      _waitingForGoogleOAuth = false;
      final SupabaseService supabase = SupabaseService();
      try {
        await supabase.ensureProfile();
      } catch (_) {}
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _completingGoogle = false;
        _errorMessage = null;
      });
      if (fromGoogle) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Signed in with Google successfully'),
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: 2),
          ),
        );
      }
      widget.onComplete();
    });
  }

  @override
  void dispose() {
    _authSub?.cancel();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _handleGoogleSignIn() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _waitingForGoogleOAuth = true;
    });

    try {
      final SupabaseService supabase = SupabaseService();
      // Never carry a stale "reset password" flag into Google login.
      supabase.isPasswordRecovery = false;

      // Use the device browser / Chrome (existing Google accounts + cookies).
      // In-app WebView is isolated and forces a blank Google login form.
      final bool started = await supabase.signInWithGoogle();
      if (!mounted) return;
      if (supabase.isAuthenticated) {
        _waitingForGoogleOAuth = false;
        await supabase.ensureProfile();
        if (!mounted) return;
        setState(() {
          _isLoading = false;
          _completingGoogle = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Signed in with Google successfully'),
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: 2),
          ),
        );
        widget.onComplete();
        return;
      }
      setState(() {
        // Keep loader until deep link returns a session.
        _isLoading = started;
        _waitingForGoogleOAuth = started;
        _completingGoogle = started;
        _showGoogleWebView = false;
        _googleAuthUrl = null;
        if (!started) {
          _errorMessage = 'Google sign-in was cancelled.';
        }
      });
    } on AuthException catch (e) {
      _waitingForGoogleOAuth = false;
      if (mounted) {
        setState(() {
          _isLoading = false;
          _completingGoogle = false;
          _showGoogleWebView = false;
          _errorMessage = AuthUtils.getFriendlyErrorMessage(e);
        });
      }
    } catch (_) {
      _waitingForGoogleOAuth = false;
      if (mounted) {
        setState(() {
          _isLoading = false;
          _completingGoogle = false;
          _showGoogleWebView = false;
          _errorMessage =
              'Google sign-in was cancelled or encountered an error.';
        });
      }
    }
  }

  Future<void> _onGoogleWebViewSuccess() async {
    if (!mounted) return;
    setState(() {
      _showGoogleWebView = false;
      _googleAuthUrl = null;
      _completingGoogle = true;
      _isLoading = true;
      _waitingForGoogleOAuth = false;
      _errorMessage = null;
    });
    final SupabaseService supabase = SupabaseService();
    try {
      await supabase.ensureProfile();
    } catch (_) {}
    if (!mounted) return;
    setState(() {
      _completingGoogle = false;
      _isLoading = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Signed in with Google successfully'),
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: 2),
      ),
    );
    widget.onComplete();
  }

  void _onGoogleWebViewClosed({String? error}) {
    if (!mounted || _completingGoogle) return;
    setState(() {
      _showGoogleWebView = false;
      _googleAuthUrl = null;
      _isLoading = false;
      _waitingForGoogleOAuth = false;
      if (error != null && error.isNotEmpty) {
        _errorMessage = error;
      }
    });
  }

  Future<void> _handleAuthSubmit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final SupabaseService supabase = SupabaseService();
    try {
      if (_isSignUp) {
        final String name = _nameController.text.trim();
        final AuthResponse? response = await supabase.signUp(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
          displayName: name.isNotEmpty ? name : null,
        );

        if (response != null && response.user != null) {
          if (response.session != null) {
            // Immediate active session
            await supabase.ensureProfile(
              email: _emailController.text.trim(),
              displayName: name.isNotEmpty ? name : null,
            );
            if (mounted) {
              setState(() => _isLoading = false);
              widget.onComplete();
            }
          } else {
            // Email confirmation required by Supabase
            if (mounted) {
              setState(() {
                _isLoading = false;
                _isSignUp = false;
              });
              _showConfirmationSentDialog(_emailController.text.trim());
            }
          }
        } else {
          setState(() {
            _isLoading = false;
            _errorMessage =
                'Could not create account. Please check your credentials.';
          });
        }
      } else {
        final AuthResponse? response = await supabase.signInWithPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        );

        if (response != null && response.session != null) {
          if (mounted) {
            setState(() => _isLoading = false);
            widget.onComplete();
          }
        } else {
          setState(() {
            _isLoading = false;
            _errorMessage = 'Email or password is incorrect.';
          });
        }
      }
    } on AuthException catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = AuthUtils.getFriendlyErrorMessage(e);
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = AuthUtils.getFriendlyErrorMessage(e);
        });
      }
    }
  }

  void _showConfirmationSentDialog(String email) {
    showDialog<void>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceContainerHigh,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: <Widget>[
            Icon(Icons.mark_email_read_rounded, color: AppColors.neonCyan),
            SizedBox(width: 10),
            Text(
              'Check Your Inbox',
              style: TextStyle(color: Colors.white, fontSize: 18),
            ),
          ],
        ),
        content: Text(
          'An account confirmation link was sent to $email. Please check your email and verify your account to sign in.',
          style: const TextStyle(
            color: AppColors.onSurfaceVariant,
            fontSize: 13,
            height: 1.4,
          ),
        ),
        actions: <Widget>[
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.electricViolet,
            ),
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Got It'),
          ),
        ],
      ),
    );
  }

  void _showForgotPasswordDialog() {
    final TextEditingController resetEmailController = TextEditingController(
      text: _emailController.text.trim(),
    );
    bool isSending = false;

    showDialog<void>(
      context: context,
      builder: (BuildContext ctx) => StatefulBuilder(
        builder: (BuildContext dialogCtx, StateSetter setDialogState) => AlertDialog(
          backgroundColor: AppColors.surfaceContainerHigh,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Row(
            children: <Widget>[
              Icon(Icons.lock_reset_rounded, color: AppColors.neonCyan),
              SizedBox(width: 10),
              Text(
                'Reset Password',
                style: TextStyle(color: Colors.white, fontSize: 18),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const Text(
                'Enter your registered email address. A password recovery link will be sent to your inbox.',
                style: TextStyle(
                  color: AppColors.onSurfaceVariant,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: resetEmailController,
                keyboardType: TextInputType.emailAddress,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Email Address',
                  labelStyle: const TextStyle(color: AppColors.outline),
                  filled: true,
                  fillColor: AppColors.surfaceContainerLowest,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ],
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text(
                'Cancel',
                style: TextStyle(color: AppColors.onSurfaceVariant),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.electricViolet,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: isSending
                  ? null
                  : () async {
                      final String email = resetEmailController.text.trim();
                      if (!email.contains('@')) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Please enter a valid email address'),
                          ),
                        );
                        return;
                      }
                      setDialogState(() => isSending = true);
                      try {
                        await SupabaseService().resetPasswordForEmail(email);
                        if (dialogCtx.mounted) {
                          Navigator.pop(dialogCtx);
                        }
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Password reset instructions sent to $email',
                              ),
                              backgroundColor: AppColors.electricViolet,
                            ),
                          );
                        }
                      } catch (e) {
                        setDialogState(() => isSending = false);
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(AuthUtils.getFriendlyErrorMessage(e)),
                              backgroundColor: AppColors.error,
                            ),
                          );
                        }
                      }
                    },
              child: isSending
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text(
                      'Send Link',
                      style: TextStyle(color: Colors.white),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGoogleButton() {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: OutlinedButton(
        style: OutlinedButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: const Color(0xFF1F1F1F),
          side: BorderSide.none,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
          ),
          elevation: 2,
        ),
        onPressed: _isLoading ? null : _handleGoogleSignIn,
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            _OfficialGoogleGLogo(size: 20),
            SizedBox(width: 10),
            Text(
              'Continue with Google',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1F1F1F),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: <Widget>[
          // Background ambient glows (centered)
          Positioned.fill(
            child: Align(
              alignment: Alignment.topCenter,
              child: Transform.translate(
                offset: const Offset(0, -60),
                child: const EchoAmbientGlowOrb(
                  color: AppColors.electricViolet,
                  size: 420,
                  opacity: 0.20,
                ),
              ),
            ),
          ),
          Positioned(
            top: 280,
            right: -80,
            child: const EchoAmbientGlowOrb(
              color: AppColors.neonCyan,
              size: 300,
              opacity: 0.12,
            ),
          ),

          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Column(
                children: <Widget>[
                  if (Navigator.canPop(context))
                    Align(
                      alignment: Alignment.centerLeft,
                      child: IconButton(
                        icon: const Icon(
                          Icons.arrow_back_rounded,
                          color: Colors.white,
                        ),
                        tooltip: 'Back',
                        onPressed: () => Navigator.pop(context),
                      ),
                    ),
                  const SizedBox(height: 16),
                  // Centered Official Logo
                  Center(
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(22),
                        boxShadow: <BoxShadow>[
                          BoxShadow(
                            color: AppColors.electricViolet.withValues(alpha: 0.35),
                            blurRadius: 30,
                            spreadRadius: 4,
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(22),
                        child: Image.asset(
                          'assets/icon/app_icon.png',
                          width: 84,
                          height: 84,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            width: 84,
                            height: 84,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: <Color>[
                                  AppColors.electricViolet,
                                  AppColors.neonCyan,
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(22),
                            ),
                            child: const Icon(
                              Icons.graphic_eq_rounded,
                              size: 44,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),

                  const Text(
                    'Kalpkrut Beats',
                    style: TextStyle(
                      fontSize: 34,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: -0.8,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Discover music, playlists and radio. Developed by Kalpkrut Infotech',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.onSurfaceVariant,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 24),

                  if (!_showAuthForm) ...<Widget>[
                    // Progress indicator matching Stitch Step 3 of 4
                    // Row(
                    //   mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    //   children: <Widget>[
                    //     const Text(
                    //       'Personalize Your Experience',
                    //       style: TextStyle(
                    //         fontSize: 12,
                    //         fontWeight: FontWeight.w600,
                    //         color: AppColors.primaryFixedDim,
                    //       ),
                    //     ),
                    //     Text(
                    //       'High-Fidelity Audio',
                    //       style: TextStyle(
                    //         fontSize: 11,
                    //         color: Colors.white.withValues(alpha: 0.6),
                    //       ),
                    //     ),
                    //   ],
                    // ),
                    // const SizedBox(height: 6),
                    // ClipRRect(
                    //   borderRadius: BorderRadius.circular(4),
                    //   child: Container(
                    //     height: 5,
                    //     width: double.infinity,
                    //     color: AppColors.surfaceContainerHighest,
                    //     child: Align(
                    //       alignment: Alignment.centerLeft,
                    //       child: Container(
                    //         width: MediaQuery.of(context).size.width * 0.75,
                    //         decoration: const BoxDecoration(
                    //           gradient: LinearGradient(
                    //             colors: <Color>[AppColors.electricViolet, AppColors.neonCyan],
                    //           ),
                    //         ),
                    //       ),
                    //     ),
                    //   ),
                    // ),
                    // const SizedBox(height: 20),

                    // Feature highlights matching Stitch Bento Card
                    EchoGlassCard(
                      padding: const EdgeInsets.all(18),
                      borderRadius: 20,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: <Widget>[
                              const Row(
                                children: <Widget>[
                                  Icon(
                                    Icons.verified_user_rounded,
                                    color: AppColors.neonCyan,
                                    size: 20,
                                  ),
                                  SizedBox(width: 8),
                                  Text(
                                    'Curated Music Flow',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.neonCyan.withValues(
                                    alpha: 0.15,
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Text(
                                  '320KBPS HD',
                                  style: TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.neonCyan,
                                    letterSpacing: 0.8,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),

                          _buildFeatureRow(
                            icon: Icons.library_music_rounded,
                            iconColor: AppColors.electricViolet,
                            title: 'Unlimited Music Streaming',
                            desc:
                                'Stream your favorite tracks, trending hits, and curated playlists seamlessly.',
                          ),
                          const SizedBox(height: 12),
                          _buildFeatureRow(
                            icon: Icons.graphic_eq_rounded,
                            iconColor: AppColors.neonCyan,
                            title: 'High-Fidelity Audio',
                            desc:
                                'Crystal-clear sound quality with continuous background playback.',
                          ),
                          const SizedBox(height: 12),
                          _buildFeatureRow(
                            icon: Icons.folder_shared_rounded,
                            iconColor: AppColors.hyperMagenta,
                            title: 'Local Device Music Player',
                            desc:
                                'Instant zero-latency playback of your device audio files.',
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Action buttons
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          padding: EdgeInsets.zero,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                          elevation: 8,
                          shadowColor: AppColors.electricViolet.withValues(
                            alpha: 0.4,
                          ),
                        ),
                        onPressed: () => setState(() {
                          _showAuthForm = true;
                          _isSignUp = true;
                        }),
                        child: Ink(
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: <Color>[
                                AppColors.electricViolet,
                                Color(0xFFA078FF),
                              ],
                              begin: Alignment.centerLeft,
                              end: Alignment.centerRight,
                            ),
                            borderRadius: BorderRadius.circular(30),
                          ),
                          child: const Center(
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: <Widget>[
                                Text(
                                  'Create Free Account',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                ),
                                SizedBox(width: 8),
                                Icon(
                                  Icons.arrow_forward_rounded,
                                  color: Colors.white,
                                  size: 20,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),

                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          backgroundColor: AppColors.surfaceContainerHighest
                              .withValues(alpha: 0.6),
                          side: BorderSide(
                            color: Colors.white.withValues(alpha: 0.12),
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                        ),
                        onPressed: () {
                          setState(() {
                            _showAuthForm = true;
                            _isSignUp = false;
                          });
                        },
                        icon: const Icon(
                          Icons.lock_open_rounded,
                          color: AppColors.onSurfaceVariant,
                          size: 18,
                        ),
                        label: const Text(
                          'Sign In to Existing Account',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),

                    _buildGoogleButton(),
                    const SizedBox(height: 12),
                  ] else ...<Widget>[
                    // Interactive Auth Form Card
                    // Interactive Auth Form Card matching screenshot reference
                    EchoGlassCard(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 26,
                      ),
                      borderRadius: 28,
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: <Widget>[
                            // Top purple pill badge
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFF281C44),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: const Color(
                                    0xFF6B4EE6,
                                  ).withValues(alpha: 0.5),
                                  width: 1,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: const <Widget>[
                                  Icon(
                                    Icons.auto_awesome_rounded,
                                    color: Color(0xFFB488FF),
                                    size: 14,
                                  ),
                                  SizedBox(width: 6),
                                  Text(
                                    'KALPKRUT BEATS ACCOUNT',
                                    style: TextStyle(
                                      color: Color(0xFFD2B8FF),
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 0.8,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 18),

                            // Main Title
                            Text(
                              _isSignUp
                                  ? 'Create Kalpkrut Beats Account'
                                  : 'Sign In to Kalpkrut Beats',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                                letterSpacing: -0.5,
                              ),
                            ),
                            const SizedBox(height: 8),

                            // Subtitle
                            Text(
                              'Sync personalized playlists, offline downloads, and community favorites across all your devices.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.white.withValues(alpha: 0.65),
                                height: 1.4,
                              ),
                            ),
                            const SizedBox(height: 22),

                            // Continue with Google Button
                            _buildGoogleButton(),
                            const SizedBox(height: 18),

                            // OR EMAIL divider
                            Row(
                              children: <Widget>[
                                Expanded(
                                  child: Divider(
                                    color: Colors.white.withValues(alpha: 0.15),
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                  ),
                                  child: Text(
                                    'OR EMAIL',
                                    style: TextStyle(
                                      color: Colors.white.withValues(
                                        alpha: 0.4,
                                      ),
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      letterSpacing: 1.2,
                                    ),
                                  ),
                                ),
                                Expanded(
                                  child: Divider(
                                    color: Colors.white.withValues(alpha: 0.15),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 18),

                            // Fields
                            if (_isSignUp) ...<Widget>[
                              Align(
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  'Full Name',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white.withValues(alpha: 0.85),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 6),
                              TextFormField(
                                controller: _nameController,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                ),
                                validator: (String? val) {
                                  if (val == null || val.trim().isEmpty) {
                                    return 'Please enter your name';
                                  }
                                  if (val.trim().length < 2) {
                                    return 'Name must be at least 2 characters';
                                  }
                                  return null;
                                },
                                decoration: InputDecoration(
                                  hintText: 'Your name',
                                  hintStyle: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.3),
                                  ),
                                  prefixIcon: const Icon(
                                    Icons.person_outline_rounded,
                                    color: AppColors.onSurfaceVariant,
                                  ),
                                  filled: true,
                                  fillColor: const Color(0xFF14141E),
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 14,
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(
                                      color: Colors.white.withValues(
                                        alpha: 0.1,
                                      ),
                                    ),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(
                                      color: Colors.white.withValues(
                                        alpha: 0.1,
                                      ),
                                    ),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: const BorderSide(
                                      color: AppColors.electricViolet,
                                      width: 1.5,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 14),
                            ],

                            Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                'Email Address',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white.withValues(alpha: 0.85),
                                ),
                              ),
                            ),
                            const SizedBox(height: 6),
                            TextFormField(
                              controller: _emailController,
                              keyboardType: TextInputType.emailAddress,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                              ),
                              validator: (String? val) {
                                if (val == null || val.trim().isEmpty) {
                                  return 'Email is required';
                                }
                                if (!val.contains('@') || !val.contains('.')) {
                                  return 'Enter a valid email address';
                                }
                                return null;
                              },
                              decoration: InputDecoration(
                                hintText: 'name@example.com',
                                hintStyle: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.3),
                                ),
                                prefixIcon: const Icon(
                                  Icons.mail_outline_rounded,
                                  color: AppColors.onSurfaceVariant,
                                ),
                                filled: true,
                                fillColor: const Color(0xFF14141E),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 14,
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(
                                    color: Colors.white.withValues(alpha: 0.1),
                                  ),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(
                                    color: Colors.white.withValues(alpha: 0.1),
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(
                                    color: AppColors.electricViolet,
                                    width: 1.5,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 14),

                            Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                'Password',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white.withValues(alpha: 0.85),
                                ),
                              ),
                            ),
                            const SizedBox(height: 6),
                            TextFormField(
                              controller: _passwordController,
                              obscureText: _obscurePassword,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                              ),
                              validator: (String? val) {
                                if (val == null || val.length < 6) {
                                  return 'Password must be at least 6 characters';
                                }
                                return null;
                              },
                              decoration: InputDecoration(
                                hintText: '••••••••',
                                hintStyle: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.3),
                                ),
                                prefixIcon: const Icon(
                                  Icons.lock_outline_rounded,
                                  color: AppColors.onSurfaceVariant,
                                ),
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _obscurePassword ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                                    color: AppColors.onSurfaceVariant,
                                    size: 20,
                                  ),
                                  onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                                ),
                                filled: true,
                                fillColor: const Color(0xFF14141E),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 14,
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(
                                    color: Colors.white.withValues(alpha: 0.1),
                                  ),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(
                                    color: Colors.white.withValues(alpha: 0.1),
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(
                                    color: AppColors.electricViolet,
                                    width: 1.5,
                                  ),
                                ),
                              ),
                            ),

                            if (_isSignUp) ...<Widget>[
                              const SizedBox(height: 14),
                              Align(
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  'Confirm Password',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white.withValues(alpha: 0.85),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 6),
                              TextFormField(
                                controller: _confirmPasswordController,
                                obscureText: _obscureConfirmPassword,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                ),
                                validator: (String? val) {
                                  if (val == null || val.isEmpty) {
                                    return 'Please confirm your password';
                                  }
                                  if (val != _passwordController.text) {
                                    return 'Passwords do not match';
                                  }
                                  return null;
                                },
                                decoration: InputDecoration(
                                  hintText: '••••••••',
                                  hintStyle: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.3),
                                  ),
                                  prefixIcon: const Icon(
                                    Icons.lock_outline_rounded,
                                    color: AppColors.onSurfaceVariant,
                                  ),
                                  suffixIcon: IconButton(
                                    icon: Icon(
                                      _obscureConfirmPassword ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                                      color: AppColors.onSurfaceVariant,
                                      size: 20,
                                    ),
                                    onPressed: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
                                  ),
                                  filled: true,
                                  fillColor: const Color(0xFF14141E),
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 14,
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(
                                      color: Colors.white.withValues(
                                        alpha: 0.1,
                                      ),
                                    ),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(
                                      color: Colors.white.withValues(
                                        alpha: 0.1,
                                      ),
                                    ),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: const BorderSide(
                                      color: AppColors.electricViolet,
                                      width: 1.5,
                                    ),
                                  ),
                                ),
                              ),
                            ],

                            if (!_isSignUp)
                              Align(
                                alignment: Alignment.centerRight,
                                child: TextButton(
                                  onPressed: _showForgotPasswordDialog,
                                  child: const Text(
                                    'Forgot Password?',
                                    style: TextStyle(
                                      color: AppColors.neonCyan,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              )
                            else
                              const SizedBox(height: 14),

                            if (_errorMessage != null)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: AppColors.error.withValues(
                                      alpha: 0.15,
                                    ),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: AppColors.error.withValues(
                                        alpha: 0.3,
                                      ),
                                    ),
                                  ),
                                  child: Row(
                                    children: <Widget>[
                                      const Icon(
                                        Icons.error_outline_rounded,
                                        color: AppColors.error,
                                        size: 16,
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          _errorMessage!,
                                          style: const TextStyle(
                                            color: AppColors.error,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),

                            // Glowing Gradient CTA Button
                            SizedBox(
                              width: double.infinity,
                              height: 52,
                              child: Container(
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: <Color>[
                                      Color(0xFF6B4EE6),
                                      Color(0xFF00D2FF),
                                    ],
                                    begin: Alignment.centerLeft,
                                    end: Alignment.centerRight,
                                  ),
                                  borderRadius: BorderRadius.circular(30),
                                  boxShadow: <BoxShadow>[
                                    BoxShadow(
                                      color: const Color(
                                        0xFF6B4EE6,
                                      ).withValues(alpha: 0.35),
                                      blurRadius: 16,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.transparent,
                                    shadowColor: Colors.transparent,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(30),
                                    ),
                                  ),
                                  onPressed: _isLoading
                                      ? null
                                      : _handleAuthSubmit,
                                  child: _isLoading
                                      ? const SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.white,
                                          ),
                                        )
                                      : Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: <Widget>[
                                            Text(
                                              _isSignUp
                                                  ? 'Create Account'
                                                  : 'Sign In to Listen',
                                              style: const TextStyle(
                                                fontSize: 15,
                                                fontWeight: FontWeight.w700,
                                                color: Colors.white,
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            const Icon(
                                              Icons.arrow_forward_rounded,
                                              color: Colors.white,
                                              size: 18,
                                            ),
                                          ],
                                        ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),

                            // Footer: Sign In / Sign Up toggle only (no guest skip)
                            Align(
                              alignment: Alignment.centerLeft,
                              child: GestureDetector(
                                onTap: () {
                                  setState(() {
                                    _isSignUp = !_isSignUp;
                                    _errorMessage = null;
                                  });
                                },
                                child: Text(
                                  _isSignUp
                                      ? 'Already have an account? Sign In'
                                      : 'Need an account? Sign up',
                                  style: const TextStyle(
                                    color: Color(0xFFB488FF),
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 18),

                            // Security line
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: <Widget>[
                                const Icon(
                                  Icons.check_circle_outline_rounded,
                                  color: Color(0xFF00E676),
                                  size: 14,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'Secured via Supabase Real-Time Auth & Cloud Sync',
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.45),
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Footer Disclosures
                  const SizedBox(height: 16),
                  Text(
                    'Kalpkrut Infotech',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: AppColors.onSurfaceVariant.withValues(alpha: 0.7),
                      letterSpacing: 0.3,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text.rich(
                    TextSpan(
                      style: TextStyle(
                        fontSize: 10,
                        color: AppColors.onSurfaceVariant.withValues(alpha: 0.6),
                      ),
                      children: <InlineSpan>[
                        TextSpan(
                          text: 'Privacy Policy',
                          style: const TextStyle(
                            decoration: TextDecoration.underline,
                            color: AppColors.secondary,
                          ),
                          recognizer: TapGestureRecognizer()
                            ..onTap = () {
                              unawaited(
                                launchUrl(
                                  Uri.parse('https://kalpkrutinfotech.com/privacy'),
                                  mode: LaunchMode.externalApplication,
                                ),
                              );
                            },
                        ),
                        const TextSpan(text: ' • '),
                        TextSpan(
                          text: 'Terms of Service',
                          style: const TextStyle(
                            decoration: TextDecoration.underline,
                            color: AppColors.secondary,
                          ),
                          recognizer: TapGestureRecognizer()
                            ..onTap = () {
                              unawaited(
                                launchUrl(
                                  Uri.parse('https://kalpkrutinfotech.com/terms'),
                                  mode: LaunchMode.externalApplication,
                                ),
                              );
                            },
                        ),
                      ],
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),

          // Full-screen wait while profile sync finishes after Google WebView.
          if (_completingGoogle)
            Positioned.fill(
              child: ColoredBox(
                color: Colors.black.withValues(alpha: 0.72),
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
                        'Signing you in…',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.95),
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Almost done — please wait',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.55),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // MahaTicket-style in-app Google account picker.
          if (_showGoogleWebView &&
              _googleAuthUrl != null &&
              _googleAuthUrl!.isNotEmpty)
            Positioned.fill(
              child: GoogleAuthWebView(
                authUrl: _googleAuthUrl!,
                onClose: () => _onGoogleWebViewClosed(),
                onSuccess: () {
                  unawaited(_onGoogleWebViewSuccess());
                },
                onError: (String message) =>
                    _onGoogleWebViewClosed(error: message),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildFeatureRow({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String desc,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerHigh.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  desc,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.onSurfaceVariant,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _OfficialGoogleGLogo extends StatelessWidget {
  final double size;
  const _OfficialGoogleGLogo({this.size = 20});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _GoogleGPainter()),
    );
  }
}

class _GoogleGPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final double w = size.width;
    final double h = size.height;
    final Rect rect = Rect.fromLTWH(0, 0, w, h);
    final double strokeWidth = w * 0.22;

    final Paint paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.butt;

    final Rect arcRect = rect.deflate(strokeWidth / 2);

    // Red: 200° to 330°
    paint.color = const Color(0xFFEA4335);
    canvas.drawArc(arcRect, 3.49, 1.85, false, paint);

    // Yellow: 140° to 220°
    paint.color = const Color(0xFFFBBC05);
    canvas.drawArc(arcRect, 2.27, 1.40, false, paint);

    // Green: 45° to 145°
    paint.color = const Color(0xFF34A853);
    canvas.drawArc(arcRect, 0.70, 1.65, false, paint);

    // Blue: -15° to 45°
    paint.color = const Color(0xFF4285F4);
    canvas.drawArc(arcRect, -0.26, 1.05, false, paint);

    // Blue center horizontal bar
    final Paint barPaint = Paint()
      ..color = const Color(0xFF4285F4)
      ..style = PaintingStyle.fill;

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTRB(w * 0.44, h * 0.38, w * 0.98, h * 0.62),
        const Radius.circular(2),
      ),
      barPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

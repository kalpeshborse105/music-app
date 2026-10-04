import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../data/services/supabase_service.dart';
import '../theme/app_colors.dart';
import '../widgets/glass_card.dart';

/// Screen representing Stitch UI "EchoFlow Music - Onboarding & Auth"
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

  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _nameController = TextEditingController();
  String? _errorMessage;
  StreamSubscription<AuthState>? _authSub;

  @override
  void initState() {
    super.initState();
    _showAuthForm = widget.initialShowAuthForm;
    _isSignUp = widget.initialSignUp;

    // Reactively complete auth when returning from Google OAuth or deep link
    _authSub = SupabaseService().authStateChanges.listen((AuthState data) {
      if (data.session != null && mounted) {
        widget.onComplete();
      }
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
    });

    try {
      final SupabaseService supabase = SupabaseService();
      await supabase.signInWithGoogle();
      if (mounted && supabase.isAuthenticated) {
        await supabase.ensureProfile();
        setState(() => _isLoading = false);
        widget.onComplete();
      } else {
        if (mounted) setState(() => _isLoading = false);
      }
    } on AuthException catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = e.message;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Google sign-in was cancelled or encountered an error.';
        });
      }
    }
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
            _errorMessage = 'Could not create account. Please check your credentials.';
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
          final String msg = e.message.toLowerCase();
          if (msg.contains('invalid login credentials')) {
            _errorMessage = 'Email or password is incorrect.';
          } else if (msg.contains('email not confirmed')) {
            _errorMessage = 'Please verify your email address before signing in.';
          } else if (msg.contains('user already registered')) {
            _errorMessage = 'This email is already registered. Please sign in instead.';
          } else {
            _errorMessage = e.message;
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Connection unavailable. Check your internet connection.';
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
            Text('Check Your Inbox', style: TextStyle(color: Colors.white, fontSize: 18)),
          ],
        ),
        content: Text(
          'An account confirmation link was sent to $email. Please check your email and verify your account to sign in.',
          style: const TextStyle(color: AppColors.onSurfaceVariant, fontSize: 13, height: 1.4),
        ),
        actions: <Widget>[
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.electricViolet),
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Got It'),
          ),
        ],
      ),
    );
  }

  void _showForgotPasswordDialog() {
    final TextEditingController resetEmailController =
        TextEditingController(text: _emailController.text.trim());
    bool isSending = false;

    showDialog<void>(
      context: context,
      builder: (BuildContext ctx) => StatefulBuilder(
        builder: (BuildContext dialogCtx, StateSetter setDialogState) => AlertDialog(
          backgroundColor: AppColors.surfaceContainerHigh,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(
            children: <Widget>[
              Icon(Icons.lock_reset_rounded, color: AppColors.neonCyan),
              SizedBox(width: 10),
              Text('Reset Password', style: TextStyle(color: Colors.white, fontSize: 18)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const Text(
                'Enter your registered email address. A password recovery link will be sent to your inbox.',
                style: TextStyle(color: AppColors.onSurfaceVariant, fontSize: 13),
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
              child: const Text('Cancel', style: TextStyle(color: AppColors.onSurfaceVariant)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.electricViolet,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: isSending
                  ? null
                  : () async {
                      final String email = resetEmailController.text.trim();
                      if (!email.contains('@')) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Please enter a valid email address')),
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
                              content: Text('Password reset instructions sent to $email'),
                              backgroundColor: AppColors.electricViolet,
                            ),
                          );
                        }
                      } catch (e) {
                        setDialogState(() => isSending = false);
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Could not send reset link: $e')),
                          );
                        }
                      }
                    },
              child: isSending
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Send Link', style: TextStyle(color: Colors.white)),
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
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
          elevation: 2,
        ),
        onPressed: _isLoading ? null : _handleGoogleSignIn,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Image.network(
              'https://lh3.googleusercontent.com/COxitqgJr1sJnIDe8-jiKhxDx1FrYbtRHKJ9zOIoGJ2cEWKLoceukqh4BQ8wzsWCmAgg=w64',
              width: 18,
              height: 18,
              errorBuilder: (_, __, ___) => const Icon(
                Icons.g_mobiledata_rounded,
                color: Color(0xFF4285F4),
                size: 24,
              ),
            ),
            const SizedBox(width: 10),
            const Text(
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
          // Background ambient glows
          Positioned(
            top: -60,
            left: MediaQuery.of(context).size.width * 0.2,
            child: const EchoAmbientGlowOrb(
              color: AppColors.electricViolet,
              size: 320,
              opacity: 0.20,
            ),
          ),
          Positioned(
            top: 280,
            right: -80,
            child: const EchoAmbientGlowOrb(
              color: AppColors.neonCyan,
              size: 300,
              opacity: 0.15,
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
                        icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                        tooltip: 'Back',
                        onPressed: () => Navigator.pop(context),
                      ),
                    ),
                  const SizedBox(height: 12),
                  // Header Logo & Glow Brand
                  Center(
                    child: Stack(
                      alignment: Alignment.center,
                      children: <Widget>[
                        Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            boxShadow: <BoxShadow>[
                              BoxShadow(
                                color: AppColors.electricViolet.withValues(alpha: 0.4),
                                blurRadius: 36,
                                spreadRadius: 8,
                              ),
                            ],
                          ),
                        ),
                        Container(
                          width: 72,
                          height: 72,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: <Color>[AppColors.electricViolet, AppColors.neonCyan],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Icon(
                            Icons.graphic_eq_rounded,
                            size: 40,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Verified pure hi-res badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceContainerHighest.withValues(alpha: 0.8),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: AppColors.neonCyan.withValues(alpha: 0.4),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Container(
                          width: 7,
                          height: 7,
                          decoration: const BoxDecoration(
                            color: AppColors.neonCyan,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'VERIFIED PURE HI-RES STREAM',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.2,
                            color: AppColors.neonCyan,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  const Text(
                    'EchoFlow',
                    style: TextStyle(
                      fontSize: 34,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: -0.8,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Pure Sound. Infinite Flow. Legal Hi-Res Audio by Kalpkrut Infotech',
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
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: <Widget>[
                        const Text(
                          'Personalize & Legal Catalog',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primaryFixedDim,
                          ),
                        ),
                        Text(
                          '100% Free & Legal',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.white.withValues(alpha: 0.6),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: Container(
                        height: 5,
                        width: double.infinity,
                        color: AppColors.surfaceContainerHighest,
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Container(
                            width: MediaQuery.of(context).size.width * 0.75,
                            decoration: const BoxDecoration(
                              gradient: LinearGradient(
                                colors: <Color>[AppColors.electricViolet, AppColors.neonCyan],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

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
                                  Icon(Icons.verified_user_rounded, color: AppColors.neonCyan, size: 20),
                                  SizedBox(width: 8),
                                  Text(
                                    'Curated Architecture',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: AppColors.neonCyan.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Text(
                                  'LOSSLESS 24-BIT',
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
                            title: '100% Legal & Independent',
                            desc: 'Licensed catalog powered by Jamendo, Free Music Archive, and ccMixter.',
                          ),
                          const SizedBox(height: 12),
                          _buildFeatureRow(
                            icon: Icons.graphic_eq_rounded,
                            iconColor: AppColors.neonCyan,
                            title: '24-Bit / 96kHz Fidelity',
                            desc: 'Uncompressed streaming with continuous background session engine.',
                          ),
                          const SizedBox(height: 12),
                          _buildFeatureRow(
                            icon: Icons.folder_shared_rounded,
                            iconColor: AppColors.hyperMagenta,
                            title: 'Local Device Music Player',
                            desc: 'Instant zero-latency playback of your device FLAC & MP3 storage.',
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
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                          elevation: 8,
                          shadowColor: AppColors.electricViolet.withValues(alpha: 0.4),
                        ),
                        onPressed: () => setState(() {
                          _showAuthForm = true;
                          _isSignUp = true;
                        }),
                        child: Ink(
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: <Color>[AppColors.electricViolet, Color(0xFFA078FF)],
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
                                Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 20),
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
                          backgroundColor: AppColors.surfaceContainerHighest.withValues(alpha: 0.6),
                          side: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                        ),
                        onPressed: () {
                          setState(() {
                            _showAuthForm = true;
                            _isSignUp = false;
                          });
                        },
                        icon: const Icon(Icons.lock_open_rounded, color: AppColors.onSurfaceVariant, size: 18),
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
                    EchoGlassCard(
                      padding: const EdgeInsets.all(20),
                      borderRadius: 24,
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: <Widget>[
                                Text(
                                  _isSignUp ? 'Create Account' : 'Welcome Back',
                                  style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                ),
                                TextButton.icon(
                                  icon: const Icon(Icons.arrow_back_rounded, color: AppColors.onSurfaceVariant, size: 16),
                                  label: const Text('Back', style: TextStyle(color: AppColors.onSurfaceVariant, fontSize: 13)),
                                  onPressed: () {
                                    if (widget.initialShowAuthForm && Navigator.canPop(context)) {
                                      Navigator.pop(context);
                                    } else {
                                      setState(() => _showAuthForm = false);
                                    }
                                  },
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),

                            if (_isSignUp) ...<Widget>[
                              TextFormField(
                                controller: _nameController,
                                style: const TextStyle(color: Colors.white, fontSize: 14),
                                validator: (String? val) {
                                  if (val == null || val.trim().isEmpty) return 'Please enter your name';
                                  if (val.trim().length < 2) return 'Name must be at least 2 characters';
                                  return null;
                                },
                                decoration: InputDecoration(
                                  hintText: 'Full Name',
                                  hintStyle: const TextStyle(color: AppColors.outline),
                                  prefixIcon: const Icon(Icons.person_outline_rounded, color: AppColors.electricViolet),
                                  filled: true,
                                  fillColor: AppColors.surfaceContainerLowest,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(14),
                                    borderSide: BorderSide.none,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                            ],

                            TextFormField(
                              controller: _emailController,
                              keyboardType: TextInputType.emailAddress,
                              style: const TextStyle(color: Colors.white, fontSize: 14),
                              validator: (String? val) {
                                if (val == null || val.trim().isEmpty) return 'Email is required';
                                if (!val.contains('@') || !val.contains('.')) return 'Enter a valid email address';
                                return null;
                              },
                              decoration: InputDecoration(
                                hintText: 'Email address',
                                hintStyle: const TextStyle(color: AppColors.outline),
                                prefixIcon: const Icon(Icons.email_outlined, color: AppColors.electricViolet),
                                filled: true,
                                fillColor: AppColors.surfaceContainerLowest,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: BorderSide.none,
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),

                            TextFormField(
                              controller: _passwordController,
                              obscureText: true,
                              style: const TextStyle(color: Colors.white, fontSize: 14),
                              validator: (String? val) {
                                if (val == null || val.length < 6) return 'Password must be at least 6 characters';
                                return null;
                              },
                              decoration: InputDecoration(
                                hintText: 'Password',
                                hintStyle: const TextStyle(color: AppColors.outline),
                                prefixIcon: const Icon(Icons.lock_outline_rounded, color: AppColors.electricViolet),
                                filled: true,
                                fillColor: AppColors.surfaceContainerLowest,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: BorderSide.none,
                                ),
                              ),
                            ),

                            if (_isSignUp) ...<Widget>[
                              const SizedBox(height: 12),
                              TextFormField(
                                controller: _confirmPasswordController,
                                obscureText: true,
                                style: const TextStyle(color: Colors.white, fontSize: 14),
                                validator: (String? val) {
                                  if (val == null || val.isEmpty) return 'Please confirm your password';
                                  if (val != _passwordController.text) return 'Passwords do not match';
                                  return null;
                                },
                                decoration: InputDecoration(
                                  hintText: 'Confirm Password',
                                  hintStyle: const TextStyle(color: AppColors.outline),
                                  prefixIcon: const Icon(Icons.lock_clock_outlined, color: AppColors.electricViolet),
                                  filled: true,
                                  fillColor: AppColors.surfaceContainerLowest,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(14),
                                    borderSide: BorderSide.none,
                                  ),
                                ),
                              ),
                            ],

                            if (!_isSignUp) ...<Widget>[
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
                              ),
                            ] else
                              const SizedBox(height: 12),

                            if (_errorMessage != null)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: AppColors.error.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
                                  ),
                                  child: Row(
                                    children: <Widget>[
                                      const Icon(Icons.error_outline_rounded, color: AppColors.error, size: 16),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          _errorMessage!,
                                          style: const TextStyle(color: AppColors.error, fontSize: 12),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),

                            SizedBox(
                              width: double.infinity,
                              height: 50,
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.electricViolet,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                ),
                                onPressed: _isLoading ? null : _handleAuthSubmit,
                                child: _isLoading
                                    ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                      )
                                    : Text(
                                        _isSignUp ? 'Sign Up' : 'Sign In',
                                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
                                      ),
                              ),
                            ),
                            const SizedBox(height: 12),

                            Center(
                              child: TextButton(
                                onPressed: () {
                                  setState(() {
                                    _isSignUp = !_isSignUp;
                                    _errorMessage = null;
                                  });
                                },
                                child: Text(
                                  _isSignUp
                                      ? 'Already have an account? Sign In'
                                      : "Don't have an account? Create one",
                                  style: const TextStyle(color: AppColors.onSurfaceVariant, fontSize: 13),
                                ),
                              ),
                            ),
                            const SizedBox(height: 6),
                            const Row(
                              children: <Widget>[
                                Expanded(child: Divider(color: AppColors.outlineVariant)),
                                Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 12),
                                  child: Text('OR', style: TextStyle(color: AppColors.outline, fontSize: 11)),
                                ),
                                Expanded(child: Divider(color: AppColors.outlineVariant)),
                              ],
                            ),
                            const SizedBox(height: 12),
                            _buildGoogleButton(),
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
                  Text(
                    'Privacy Policy • Music Attribution Licenses • Terms of Service',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 10,
                      color: AppColors.onSurfaceVariant.withValues(alpha: 0.6),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
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

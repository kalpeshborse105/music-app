import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/constants/app_constants.dart';
import '../../core/utils/app_messenger.dart';
import '../../core/utils/auth_utils.dart';
import '../../data/services/supabase_service.dart';
import '../theme/app_colors.dart';
import '../widgets/glass_card.dart';

/// Dedicated Password Reset and Recovery Screen.
/// Provides real-time validation, show/hide eye toggles, recovery session verification,
/// error handling for 422 same_password / weak_password, and a resend option.
class ResetPasswordScreen extends StatefulWidget {
  const ResetPasswordScreen({super.key});

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();

  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  bool _isSubmitting = false;
  bool _isSuccess = false;
  bool _showResendForm = false;
  bool _isResending = false;
  bool _isCheckingSession = true;
  String? _errorMessage;
  StreamSubscription<AuthState>? _authSub;

  @override
  void initState() {
    super.initState();
    _initSessionCheck();
  }

  @override
  void dispose() {
    _authSub?.cancel();
    _passwordController.dispose();
    _confirmController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  void _initSessionCheck() {
    final SupabaseService supabase = SupabaseService();

    // Listen for incoming password recovery or signedIn event
    _authSub = supabase.authStateChanges.listen((AuthState data) {
      if (data.session != null ||
          data.event == AuthChangeEvent.passwordRecovery ||
          data.event == AuthChangeEvent.signedIn) {
        if (mounted) {
          setState(() {
            _isCheckingSession = false;
            _showResendForm = false;
            _errorMessage = null;
          });
        }
      }
    });

    final Uri uri = Uri.base;
    final String? authCode = uri.queryParameters['code'];
    if (authCode != null && authCode.isNotEmpty) {
      supabase.client.auth.exchangeCodeForSession(authCode).then((dynamic res) {
        if (mounted && res.session != null) {
          setState(() {
            _isCheckingSession = false;
            _showResendForm = false;
            _errorMessage = null;
          });
        }
      }).catchError((dynamic err) {
        debugPrint('[ResetPasswordScreen] exchangeCodeForSession notice: $err');
      });
    }

    final bool urlHasRecovery = uri.path.contains('reset-password') ||
        uri.fragment.contains('type=recovery') ||
        uri.fragment.contains('access_token') ||
        uri.queryParameters.containsKey('code') ||
        uri.queryParameters['type'] == 'recovery';

    if (supabase.isAuthenticated ||
        supabase.currentUser != null ||
        supabase.isPasswordRecovery ||
        urlHasRecovery) {
      setState(() {
        _isCheckingSession = false;
        _showResendForm = false;
      });
    } else {
      Future<void>.delayed(const Duration(milliseconds: 2200), () {
        if (!mounted) return;
        final SupabaseService sb = SupabaseService();
        if (!sb.isAuthenticated && sb.currentUser == null && !sb.isPasswordRecovery) {
          setState(() {
            _isCheckingSession = false;
            _errorMessage =
                'No active recovery session detected. Please enter your email below to receive a fresh password reset link.';
            _showResendForm = true;
          });
        } else {
          setState(() {
            _isCheckingSession = false;
            _showResendForm = false;
          });
        }
      });
    }
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    final String newPassword = _passwordController.text.trim();
    final String confirmPassword = _confirmController.text.trim();

    if (newPassword != confirmPassword) {
      setState(() => _errorMessage = 'Passwords do not match.');
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      final SupabaseService supabase = SupabaseService();
      if (supabase.currentUser == null) {
        final Uri uri = Uri.base;
        final String? authCode = uri.queryParameters['code'];
        if (authCode != null && authCode.isNotEmpty) {
          try {
            await supabase.client.auth.exchangeCodeForSession(authCode);
          } catch (e) {
            debugPrint('[ResetPasswordScreen] code exchange during submit: $e');
          }
        }
      }
      await supabase.updateUserPassword(newPassword);
      supabase.isPasswordRecovery = false;

      if (mounted) {
        setState(() {
          _isSubmitting = false;
          _isSuccess = true;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
          _errorMessage = AuthUtils.getFriendlyErrorMessage(e);
        });
      }
    }
  }

  Future<void> _handleResend() async {
    final String email = _emailController.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      AppMessenger.show('Please enter a valid email address.');
      return;
    }

    setState(() => _isResending = true);
    try {
      await SupabaseService().resetPasswordForEmail(email);
      if (mounted) {
        setState(() {
          _isResending = false;
          _errorMessage = null;
        });
        AppMessenger.show('A new recovery link has been sent to $email');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isResending = false;
          _errorMessage = AuthUtils.getFriendlyErrorMessage(e);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.darkBg,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 32),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: EchoGlassCard(
              padding: const EdgeInsets.all(28),
              borderRadius: 24,
              child: _isCheckingSession
                  ? _buildCheckingView()
                  : (_isSuccess ? _buildSuccessView() : _buildFormView()),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCheckingView() {
    return const Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        SizedBox(height: 24),
        SizedBox(
          width: 38,
          height: 38,
          child: CircularProgressIndicator(
            color: AppColors.electricViolet,
            strokeWidth: 3,
          ),
        ),
        SizedBox(height: 20),
        Text(
          'Verifying Recovery Session...',
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
        SizedBox(height: 8),
        Text(
          'Securing your account for password reset.',
          style: TextStyle(
            color: AppColors.textSecondaryDark,
            fontSize: 13,
          ),
        ),
        SizedBox(height: 24),
      ],
    );
  }

  Widget _buildSuccessView() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            color: AppColors.emerald.withValues(alpha: 0.15),
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.emerald, width: 2),
          ),
          child: const Icon(
            Icons.check_circle_rounded,
            color: AppColors.emerald,
            size: 42,
          ),
        ),
        const SizedBox(height: 20),
        const Text(
          'Password Updated!',
          style: TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 10),
        Text(
          'Your Kalpkrut Beats password has been successfully updated. You can now continue listening.',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.7),
            fontSize: 14,
            height: 1.4,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 28),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.electricViolet,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            onPressed: () {
              Navigator.of(context).pushNamedAndRemoveUntil('/', (Route<dynamic> r) => false);
            },
            child: const Text(
              'Continue to Kalpkrut Beats',
              style: TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFormView() {
    return Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          // Logo & Branding
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Image.asset(
              'assets/icon/app_icon.png',
              width: 60,
              height: 60,
              errorBuilder: (_, __, ___) => Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: <Color>[AppColors.electricViolet, AppColors.neonCyan],
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(Icons.music_note_rounded, color: Colors.white, size: 32),
              ),
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            AppConstants.appName,
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Create New Password',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Please enter a new secure password for your account.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.65),
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 20),

          // Error banner
          if (_errorMessage != null) ...<Widget>[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.error.withValues(alpha: 0.4)),
              ),
              child: Row(
                children: <Widget>[
                  const Icon(Icons.error_outline_rounded, color: AppColors.error, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _errorMessage!,
                      style: const TextStyle(color: Colors.white, fontSize: 13, height: 1.3),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          if (!_showResendForm) ...<Widget>[
            // New Password Field
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'New Password',
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
              style: const TextStyle(color: Colors.white, fontSize: 14),
              validator: (String? val) {
                if (val == null || val.length < 6) {
                  return 'Password must be at least 6 characters long.';
                }
                return null;
              },
              decoration: InputDecoration(
                hintText: 'Enter at least 6 characters',
                hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3)),
                prefixIcon: const Icon(Icons.lock_outline_rounded, color: AppColors.electricViolet, size: 20),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscurePassword ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                    color: AppColors.onSurfaceVariant,
                    size: 20,
                  ),
                  onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                  tooltip: _obscurePassword ? 'Show password' : 'Hide password',
                ),
                filled: true,
                fillColor: const Color(0xFF14141E),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.electricViolet, width: 1.5),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Confirm Password Field
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Confirm New Password',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.white.withValues(alpha: 0.85),
                ),
              ),
            ),
            const SizedBox(height: 6),
            TextFormField(
              controller: _confirmController,
              obscureText: _obscureConfirm,
              style: const TextStyle(color: Colors.white, fontSize: 14),
              validator: (String? val) {
                if (val == null || val.isEmpty) {
                  return 'Please confirm your password.';
                }
                if (val != _passwordController.text) {
                  return 'Passwords do not match.';
                }
                return null;
              },
              decoration: InputDecoration(
                hintText: 'Re-enter your new password',
                hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3)),
                prefixIcon: const Icon(Icons.check_circle_outline_rounded, color: AppColors.electricViolet, size: 20),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscureConfirm ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                    color: AppColors.onSurfaceVariant,
                    size: 20,
                  ),
                  onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
                  tooltip: _obscureConfirm ? 'Show password' : 'Hide password',
                ),
                filled: true,
                fillColor: const Color(0xFF14141E),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.electricViolet, width: 1.5),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Submit Button
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.electricViolet,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: _isSubmitting ? null : _handleSubmit,
                child: _isSubmitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Text(
                        'Update Password',
                        style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                      ),
              ),
            ),
          ] else ...<Widget>[
            // Resend recovery link section
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Enter your account email to receive a fresh password reset link:',
                style: TextStyle(fontSize: 13, color: Colors.white.withValues(alpha: 0.8)),
              ),
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              style: const TextStyle(color: Colors.white, fontSize: 14),
              decoration: InputDecoration(
                hintText: 'name@example.com',
                hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3)),
                prefixIcon: const Icon(Icons.mail_outline_rounded, color: AppColors.electricViolet, size: 20),
                filled: true,
                fillColor: const Color(0xFF14141E),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
                ),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.electricViolet,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: _isResending ? null : _handleResend,
                icon: _isResending
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.send_rounded, size: 18, color: Colors.white),
                label: const Text(
                  'Send Reset Link',
                  style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],

          const SizedBox(height: 16),
          TextButton(
            onPressed: () {
              Navigator.of(context).pushNamedAndRemoveUntil('/', (Route<dynamic> r) => false);
            },
            child: const Text(
              'Back to Sign In',
              style: TextStyle(color: AppColors.electricViolet, fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

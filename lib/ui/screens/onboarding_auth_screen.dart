import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../widgets/glass_card.dart';

/// Screen representing Stitch UI "EchoFlow Music - Onboarding & Auth"
/// (Screen ID: f44179deb8b14f2f84a5766edd493fc7)
class OnboardingAuthScreen extends StatefulWidget {
  final VoidCallback onComplete;

  const OnboardingAuthScreen({
    super.key,
    required this.onComplete,
  });

  @override
  State<OnboardingAuthScreen> createState() => _OnboardingAuthScreenState();
}

class _OnboardingAuthScreenState extends State<OnboardingAuthScreen> {
  bool _showAuthForm = false;
  bool _isSignUp = false;
  bool _isLoading = false;

  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  void _handleGuestLogin() {
    widget.onComplete();
  }

  Future<void> _handleAuthSubmit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    // Simulate / wire authentication
    await Future.delayed(const Duration(milliseconds: 600));
    if (mounted) {
      setState(() => _isLoading = false);
      widget.onComplete();
    }
  }

  void _showForgotPasswordDialog() {
    final resetEmailController = TextEditingController(text: _emailController.text);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceContainerHigh,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.lock_reset_rounded, color: AppColors.neonCyan),
            SizedBox(width: 10),
            Text('Reset Password', style: TextStyle(color: Colors.white, fontSize: 18)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Enter your registered email address. A password recovery link will be sent.',
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
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: AppColors.onSurfaceVariant)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.electricViolet,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () {
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Recovery instructions sent to email'),
                  backgroundColor: AppColors.electricViolet,
                ),
              );
            },
            child: const Text('Send Link', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
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
                children: [
                  const SizedBox(height: 12),
                  // Header Logo & Glow Brand
                  Center(
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            boxShadow: [
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
                              colors: [AppColors.electricViolet, AppColors.neonCyan],
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

                  // Verified badge
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
                      children: [
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

                  if (!_showAuthForm) ...[
                    // Progress indicator matching Stitch Step 3 of 4
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
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
                                colors: [AppColors.electricViolet, AppColors.neonCyan],
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
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Row(
                                children: [
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
                        onPressed: () => setState(() => _showAuthForm = true),
                        child: Ink(
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [AppColors.electricViolet, Color(0xFFA078FF)],
                              begin: Alignment.centerLeft,
                              end: Alignment.centerRight,
                            ),
                            borderRadius: BorderRadius.circular(30),
                          ),
                          child: const Center(
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  'Get Started with EchoFlow',
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
                          'Sign In / Register',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),

                    TextButton.icon(
                      onPressed: _handleGuestLogin,
                      icon: const Icon(Icons.explore_rounded, color: AppColors.neonCyan, size: 18),
                      label: const Text(
                        'Continue as Guest (Instant Discovery)',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.neonCyan,
                        ),
                      ),
                    ),
                  ] else ...[
                    // Interactive Auth Form Card
                    EchoGlassCard(
                      padding: const EdgeInsets.all(20),
                      borderRadius: 24,
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  _isSignUp ? 'Create Account' : 'Welcome Back',
                                  style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.close_rounded, color: AppColors.onSurfaceVariant),
                                  onPressed: () => setState(() => _showAuthForm = false),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),

                            if (_isSignUp) ...[
                              TextFormField(
                                controller: _nameController,
                                style: const TextStyle(color: Colors.white, fontSize: 14),
                                decoration: InputDecoration(
                                  hintText: 'Display Name',
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
                              validator: (val) => val != null && val.contains('@') ? null : 'Enter a valid email',
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
                              validator: (val) => val != null && val.length >= 6 ? null : 'Minimum 6 characters',
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

                            if (!_isSignUp) ...[
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
                                child: Text(
                                  _errorMessage!,
                                  style: const TextStyle(color: AppColors.hyperMagenta, fontSize: 12),
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
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Footer Disclosures matching Stitch
                  const SizedBox(height: 16),
                  Text(
                    'Powered by Kalpkrut Infotech • Privacy Policy • Music Attribution Licenses • Terms of Service',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 10,
                      color: AppColors.onSurfaceVariant.withValues(alpha: 0.8),
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Android 16 MediaSession & Scoped Storage Ready',
                    style: TextStyle(
                      fontSize: 10,
                      color: AppColors.outline,
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
        children: [
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
              children: [
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

import 'dart:async';
import 'package:flutter/material.dart';
import '../../app/app.dart';
import '../../core/utils/auth_utils.dart';
import '../../data/services/supabase_service.dart';
import 'reset_password_screen.dart';

/// Premium Animated Splash Screen
/// Features a 2.5s glowing logo bling, breathing pulse animation,
/// and bottom branding typography before transitioning smoothly to AuthGate.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;
  late Animation<double> _glowAnimation;
  Timer? _timer;

  @override
  void initState() {
    super.initState();

    // Google `?code=` is login — never divert to Create New Password.
    if (AuthUtils.isOAuthLoginCallback(Uri.base)) {
      SupabaseService().isPasswordRecovery = false;
    }

    final bool isRecovery = !AuthUtils.isOAuthLoginCallback(Uri.base) &&
        (SupabaseService().isPasswordRecovery ||
            AuthUtils.isPasswordRecoveryUri(Uri.base));

    if (isRecovery) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute<void>(
              settings: const RouteSettings(name: '/reset-password'),
              builder: (_) => const ResetPasswordScreen(),
            ),
          );
        }
      });
      return;
    }

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );

    _scaleAnimation = Tween<double>(begin: 0.75, end: 1.05).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.7, curve: Curves.easeOutBack),
      ),
    );

    _opacityAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.45, curve: Curves.easeIn),
      ),
    );

    _glowAnimation = Tween<double>(begin: 0.2, end: 0.85).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.3, 1.0, curve: Curves.easeInOut),
      ),
    );

    _controller.forward();

    // 2.5 seconds splash display, then smoothly transition to AuthGate
    _timer = Timer(const Duration(milliseconds: 2500), _navigateToHome);
  }

  void _navigateToHome() {
    if (!mounted) return;
    if (AuthUtils.isOAuthLoginCallback(Uri.base)) {
      SupabaseService().isPasswordRecovery = false;
    } else if (SupabaseService().isPasswordRecovery) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          settings: const RouteSettings(name: '/reset-password'),
          builder: (_) => const ResetPasswordScreen(),
        ),
      );
      return;
    }
    Navigator.of(context).pushReplacement(
      PageRouteBuilder<void>(
        pageBuilder: (BuildContext context, Animation<double> animation,
                Animation<double> secondaryAnimation) =>
            const AuthGate(),
        transitionsBuilder: (BuildContext context, Animation<double> animation,
                Animation<double> secondaryAnimation, Widget child) =>
            FadeTransition(opacity: animation, child: child),
        transitionDuration: const Duration(milliseconds: 600),
      ),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A14),
      body: Stack(
        children: <Widget>[
          // Background subtle ambient radial glow
          Center(
            child: AnimatedBuilder(
              animation: _glowAnimation,
              builder: (BuildContext context, Widget? child) {
                return Container(
                  width: 320,
                  height: 320,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: <Color>[
                        const Color(0xFF6366F1).withValues(alpha: _glowAnimation.value * 0.28),
                        const Color(0xFFA855F7).withValues(alpha: _glowAnimation.value * 0.12),
                        Colors.transparent,
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          // Centered Bling Logo
          Center(
            child: AnimatedBuilder(
              animation: _controller,
              builder: (BuildContext context, Widget? child) {
                return Opacity(
                  opacity: _opacityAnimation.value,
                  child: Transform.scale(
                    scale: _scaleAnimation.value,
                    child: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: <BoxShadow>[
                          BoxShadow(
                            color: const Color(0xFF8B5CF6).withValues(alpha: _glowAnimation.value * 0.5),
                            blurRadius: 40,
                            spreadRadius: 8,
                          ),
                          BoxShadow(
                            color: const Color(0xFF6366F1).withValues(alpha: _glowAnimation.value * 0.35),
                            blurRadius: 70,
                            spreadRadius: 15,
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(32),
                        child: Image.asset(
                          'assets/icon/app_icon.png',
                          width: 130,
                          height: 130,
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          // Bottom Branding Typography
          Positioned(
            left: 0,
            right: 0,
            bottom: 48,
            child: AnimatedBuilder(
              animation: _opacityAnimation,
              builder: (BuildContext context, Widget? child) {
                return Opacity(
                  opacity: _opacityAnimation.value,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      // Gradient Brand Name
                      ShaderMask(
                        shaderCallback: (Rect bounds) {
                          return const LinearGradient(
                            colors: <Color>[
                              Color(0xFFFFFFFF),
                              Color(0xFFC4B5FD),
                              Color(0xFFA78BFA),
                            ],
                          ).createShader(bounds);
                        },
                        child: const Text(
                          'KALPKRUT BEATS',
                          style: TextStyle(
                            fontFamily: 'Plus Jakarta Sans',
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 3.5,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'High-Fidelity Music Streaming',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          letterSpacing: 1.2,
                          color: Colors.white.withValues(alpha: 0.55),
                        ),
                      ),
                      const SizedBox(height: 18),
                      // Subtle Loading Indicator Bar
                      SizedBox(
                        width: 48,
                        child: LinearProgressIndicator(
                          minHeight: 2,
                          backgroundColor: Colors.white.withValues(alpha: 0.1),
                          valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFA855F7)),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

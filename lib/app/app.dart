import 'dart:async';

import 'package:flutter/material.dart' hide SearchController;
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/storage/settings_store.dart';
import '../core/utils/app_messenger.dart';
import '../data/music_repository.dart';
import '../data/provider_registry.dart';
import '../data/services/supabase_service.dart';
import '../domain/playback/playback_controller.dart';
import '../domain/recommendations/recommendation_engine.dart';
import '../domain/providers/local_provider.dart';
import '../state/downloads_controller.dart';
import '../state/library_controller.dart';
import '../state/search_controller.dart';
import '../ui/screens/admin_screen.dart';
import '../ui/screens/app_shell.dart';
import '../ui/screens/delete_account_screen.dart';
import '../ui/screens/onboarding_auth_screen.dart';
import '../ui/theme/app_colors.dart';
import '../ui/theme/app_theme.dart';
import 'app_dependencies.dart';

/// Root of the application. Injects dependencies via [provider] and builds the
/// MaterialApp. Startup is non-blocking: [AppDependencies.warmUp] runs after the
/// first frame (spec §37).
class KalpkrutBeatsApp extends StatefulWidget {
  const KalpkrutBeatsApp({super.key, required this.dependencies});

  final AppDependencies dependencies;

  @override
  State<KalpkrutBeatsApp> createState() => _KalpkrutBeatsAppState();
}

class _KalpkrutBeatsAppState extends State<KalpkrutBeatsApp> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.dependencies.warmUp();
    });
  }

  @override
  Widget build(BuildContext context) {
    final AppDependencies deps = widget.dependencies;
    return MultiProvider(
      providers: <SingleChildWidget>[
        Provider<AppDependencies>.value(value: deps),
        Provider<MusicRepository>.value(value: deps.repository),
        Provider<ProviderRegistry>.value(value: deps.registry),
        Provider<RecommendationEngine>.value(value: deps.recommendations),
        Provider<LocalMusicProvider?>.value(value: deps.localProvider),
        ChangeNotifierProvider<SearchController>.value(value: deps.search),
        ChangeNotifierProvider<SettingsStore>.value(value: deps.settings),
        ChangeNotifierProvider<PlaybackController>.value(value: deps.playback),
        ChangeNotifierProvider<LibraryController>.value(value: deps.library),
        ChangeNotifierProvider<DownloadsController>.value(value: deps.downloads),
      ],
      child: Consumer<SettingsStore>(
        builder: (BuildContext context, SettingsStore settings, Widget? _) {
          return MaterialApp(
            title: 'Kalpkrut Beats',
            debugShowCheckedModeBanner: false,
            scaffoldMessengerKey: AppMessenger.key,
            theme: AppTheme.light(),
            darkTheme: AppTheme.dark(),
            themeMode: settings.themeMode,
            home: const AuthGate(),
            onGenerateRoute: (RouteSettings routeSettings) {
              if (routeSettings.name == '/delete-account') {
                return MaterialPageRoute<void>(
                  settings: routeSettings,
                  builder: (BuildContext context) => const DeleteAccountPortalScreen(),
                );
              }
              if (routeSettings.name == '/operations' || routeSettings.name == '/admin') {
                return MaterialPageRoute<void>(
                  settings: routeSettings,
                  builder: (BuildContext context) {
                    final SupabaseService supabase = SupabaseService();
                    if (!supabase.isAuthenticated) {
                      return OnboardingAuthScreen(
                        initialShowAuthForm: true,
                        onComplete: () {
                          Navigator.pushReplacementNamed(context, routeSettings.name ?? '/admin');
                        },
                      );
                    }
                    return const AdminScreen();
                  },
                );
              }
              if (routeSettings.name == '/login' || routeSettings.name == '/signup') {
                return MaterialPageRoute<void>(
                  settings: routeSettings,
                  builder: (BuildContext context) {
                    final SupabaseService supabase = SupabaseService();
                    if (supabase.isAuthenticated) {
                      return const AppShell();
                    }
                    return OnboardingAuthScreen(
                      initialShowAuthForm: true,
                      onComplete: () {
                        Navigator.pushReplacementNamed(context, '/');
                      },
                    );
                  },
                );
              }
              if (routeSettings.name == '/search') {
                return MaterialPageRoute<void>(
                  settings: routeSettings,
                  builder: (BuildContext context) => const AppShell(initialIndex: 1),
                );
              }
              if (routeSettings.name == '/library') {
                return MaterialPageRoute<void>(
                  settings: routeSettings,
                  builder: (BuildContext context) => const AppShell(initialIndex: 3),
                );
              }
              if (routeSettings.name == '/profile') {
                return MaterialPageRoute<void>(
                  settings: routeSettings,
                  builder: (BuildContext context) => const AppShell(initialIndex: 4),
                );
              }
              return null;
            },
          );
        },
      ),
    );
  }
}

/// Central production Authentication Gate.
/// Strictly enforces that unauthenticated sessions only see OnboardingAuthScreen,
/// while authenticated sessions fetch/create their profile and access AppShell.
class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  StreamSubscription<AuthState>? _authSub;
  bool _isLoading = true;
  bool _isAuthenticated = false;

  @override
  void initState() {
    super.initState();
    _checkInitialAuth();
    _listenAuth();
  }

  void _checkInitialAuth() {
    final SupabaseService supabase = SupabaseService();
    final bool auth = supabase.isAuthenticated && supabase.currentSession != null;
    if (auth) {
      supabase.ensureProfile();
    }
    setState(() {
      _isAuthenticated = auth;
      _isLoading = false;
    });
  }

  void _listenAuth() {
    _authSub = SupabaseService().authStateChanges.listen((AuthState data) {
      final bool auth = data.session != null;
      if (mounted && _isAuthenticated != auth) {
        if (auth) {
          SupabaseService().ensureProfile();
        }
        setState(() {
          _isAuthenticated = auth;
          _isLoading = false;
        });
      }
      if (mounted && data.event == AuthChangeEvent.passwordRecovery) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _showNewPasswordModal(context);
        });
      }
    });
  }

  void _showNewPasswordModal(BuildContext context) {
    final TextEditingController pwdController = TextEditingController();
    final TextEditingController confirmController = TextEditingController();
    bool isSubmitting = false;

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext ctx) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return AlertDialog(
              backgroundColor: AppColors.surfaceContainerHigh,
              title: const Row(
                children: <Widget>[
                  Icon(Icons.lock_reset_rounded, color: AppColors.electricViolet),
                  SizedBox(width: 8),
                  Text('Set New Password', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  const Text(
                    'You opened a password reset link. Enter your new account password below.',
                    style: TextStyle(color: AppColors.textSecondaryDark, fontSize: 13),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: pwdController,
                    obscureText: true,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: 'New Password',
                      labelStyle: const TextStyle(color: AppColors.textMutedDark),
                      prefixIcon: const Icon(Icons.key_rounded, color: AppColors.electricViolet),
                      filled: true,
                      fillColor: AppColors.darkBg,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: confirmController,
                    obscureText: true,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: 'Confirm New Password',
                      labelStyle: const TextStyle(color: AppColors.textMutedDark),
                      prefixIcon: const Icon(Icons.check_circle_outline, color: AppColors.electricViolet),
                      filled: true,
                      fillColor: AppColors.darkBg,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ],
              ),
              actions: <Widget>[
                TextButton(
                  onPressed: isSubmitting ? null : () => Navigator.of(ctx).pop(),
                  child: const Text('Cancel', style: TextStyle(color: AppColors.textMutedDark)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.electricViolet),
                  onPressed: isSubmitting
                      ? null
                      : () async {
                          final String p1 = pwdController.text.trim();
                          final String p2 = confirmController.text.trim();
                          if (p1.isEmpty || p1.length < 6) {
                            AppMessenger.show('Password must be at least 6 characters long.');
                            return;
                          }
                          if (p1 != p2) {
                            AppMessenger.show('Passwords do not match.');
                            return;
                          }
                          setModalState(() => isSubmitting = true);
                          try {
                            await SupabaseService().updateUserPassword(p1);
                            if (ctx.mounted) Navigator.of(ctx).pop();
                            AppMessenger.show('New password saved successfully!');
                          } catch (e) {
                            setModalState(() => isSubmitting = false);
                            AppMessenger.showError('Failed to update password: $e');
                          }
                        },
                  child: isSubmitting
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('Save Password', style: TextStyle(color: Colors.white)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  void dispose() {
    _authSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: AppColors.darkBg,
        body: Center(
          child: CircularProgressIndicator(color: AppColors.electricViolet),
        ),
      );
    }

    if (!_isAuthenticated) {
      return OnboardingAuthScreen(
        initialShowAuthForm: false,
        onComplete: () {
          final SupabaseService supabase = SupabaseService();
          if (mounted && supabase.isAuthenticated) {
            supabase.ensureProfile();
            setState(() {
              _isAuthenticated = true;
            });
          }
        },
      );
    }

    return const AppShell();
  }
}

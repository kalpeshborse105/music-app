import 'dart:async';

import 'package:flutter/material.dart' hide SearchController;
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/storage/settings_store.dart';
import '../core/utils/app_messenger.dart';
import '../core/utils/auth_utils.dart';
import '../data/music_repository.dart';
import '../data/provider_registry.dart';
import '../data/services/deep_link_service.dart';
import '../data/services/fcm_service.dart';
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
import '../ui/screens/home_screen.dart';
import '../ui/screens/onboarding_auth_screen.dart';
import '../ui/screens/reset_password_screen.dart';
import '../ui/screens/splash_screen.dart';
import '../ui/theme/app_colors.dart';
import '../ui/theme/app_theme.dart';
import 'app_dependencies.dart';

/// Root of the application. Injects dependencies via [provider] and builds the
/// MaterialApp. Startup is non-blocking: [AppDependencies.warmUp] runs after the
/// first frame (spec §37).
class KalpkrutBeatsApp extends StatefulWidget {
  const KalpkrutBeatsApp({super.key, required this.dependencies});

  final AppDependencies dependencies;
  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  @override
  State<KalpkrutBeatsApp> createState() => _KalpkrutBeatsAppState();
}

class _KalpkrutBeatsAppState extends State<KalpkrutBeatsApp> {
  StreamSubscription<AuthState>? _globalAuthSub;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.dependencies.warmUp();
    });

    _globalAuthSub = SupabaseService().authStateChanges.listen((AuthState data) {
      if (data.event == AuthChangeEvent.signedIn ||
          data.event == AuthChangeEvent.tokenRefreshed) {
        FcmService.instance.syncUser();
        // New / returning login: pull latest catalogue + library quietly.
        if (data.event == AuthChangeEvent.signedIn) {
          HomeScreen.silentRefreshLatest();
        }
      }
      if (data.event == AuthChangeEvent.passwordRecovery) {
        // Google OAuth `?code=` must never open Create New Password.
        if (AuthUtils.isOAuthLoginCallback(Uri.base)) {
          SupabaseService().isPasswordRecovery = false;
          return;
        }
        SupabaseService().isPasswordRecovery = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          KalpkrutBeatsApp.navigatorKey.currentState?.pushNamedAndRemoveUntil(
            '/reset-password',
            (Route<dynamic> route) => false,
          );
        });
      }
    });
  }

  @override
  void dispose() {
    _globalAuthSub?.cancel();
    DeepLinkService.instance.dispose();
    super.dispose();
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
            navigatorKey: KalpkrutBeatsApp.navigatorKey,
            debugShowCheckedModeBanner: false,
            scaffoldMessengerKey: AppMessenger.key,
            theme: AppTheme.light(),
            darkTheme: AppTheme.dark(),
            themeMode: settings.themeMode,
            locale: const Locale('en', 'US'),
            supportedLocales: const <Locale>[
              Locale('en', 'US'),
              Locale('en'),
            ],
            home: const SplashScreen(),
            onGenerateRoute: (RouteSettings routeSettings) {
              final String name = routeSettings.name ?? '';
              final Uri? parsedUri = Uri.tryParse(name);
              final String path = parsedUri?.path ?? name;

              if (path == '/splash') {
                return MaterialPageRoute<void>(
                  settings: routeSettings,
                  builder: (BuildContext context) => const SplashScreen(),
                );
              }
              if (path == '/reset-password' ||
                  path.startsWith('/reset-password') ||
                  name.contains('reset-password')) {
                // Google `?code=` must not open Create New Password.
                if (AuthUtils.isOAuthLoginCallback(Uri.base)) {
                  SupabaseService().isPasswordRecovery = false;
                  return MaterialPageRoute<void>(
                    settings: routeSettings,
                    builder: (BuildContext context) => const AuthGate(),
                  );
                }
                return MaterialPageRoute<void>(
                  settings: routeSettings,
                  builder: (BuildContext context) => const ResetPasswordScreen(),
                );
              }
              if (routeSettings.name == '/delete-account') {
                return MaterialPageRoute<void>(
                  settings: routeSettings,
                  builder: (BuildContext context) =>
                      const DeleteAccountPortalScreen(),
                );
              }
              if (routeSettings.name == '/operations' ||
                  routeSettings.name == '/admin') {
                return MaterialPageRoute<void>(
                  settings: routeSettings,
                  builder: (BuildContext context) {
                    final SupabaseService supabase = SupabaseService();
                    if (!supabase.isAuthenticated) {
                      return OnboardingAuthScreen(
                        initialShowAuthForm: true,
                        onComplete: () {
                          Navigator.pushReplacementNamed(
                              context, routeSettings.name ?? '/admin');
                        },
                      );
                    }
                    return const AdminScreen();
                  },
                );
              }
              if (routeSettings.name == '/login' ||
                  routeSettings.name == '/signup') {
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
              if (routeSettings.name == '/search' ||
                  routeSettings.name == '/library') {
                return MaterialPageRoute<void>(
                  settings: routeSettings,
                  builder: (BuildContext context) =>
                      const AppShell(initialIndex: 1),
                );
              }
              if (routeSettings.name == '/radio') {
                return MaterialPageRoute<void>(
                  settings: routeSettings,
                  builder: (BuildContext context) =>
                      const AppShell(initialIndex: 2),
                );
              }
              if (routeSettings.name == '/profile') {
                return MaterialPageRoute<void>(
                  settings: routeSettings,
                  builder: (BuildContext context) =>
                      const AppShell(initialIndex: 3),
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
    unawaited(_checkInitialAuth());
    _listenAuth();
  }

  Future<void> _checkInitialAuth() async {
    final SupabaseService supabase = SupabaseService();
    final Uri uri = Uri.base;

    // Stale Google redirect (refresh / double open): code already consumed.
    // Do not retry exchange — PKCE client already handled it once.
    final bool oauthError = (uri.queryParameters['error'] ?? '').isNotEmpty ||
        (uri.queryParameters['error_code'] ?? '') == 'flow_state_already_used';

    // Wait briefly for supabase_flutter auto PKCE session (do NOT exchange twice).
    if (supabase.isInitialized &&
        !AuthUtils.isPasswordRecoveryUri(uri) &&
        !oauthError &&
        (uri.queryParameters['code'] ?? '').isNotEmpty &&
        supabase.currentSession == null) {
      for (int i = 0; i < 20 && supabase.currentSession == null; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 100));
      }
    }

    final bool auth =
        supabase.isAuthenticated && supabase.currentSession != null;
    if (auth) {
      supabase.isPasswordRecovery = false;
      await supabase.ensureProfile();
    }
    if (!mounted) return;
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
      if (mounted &&
          data.event == AuthChangeEvent.passwordRecovery &&
          !AuthUtils.isOAuthLoginCallback(Uri.base)) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              settings: const RouteSettings(name: '/reset-password'),
              builder: (BuildContext context) => const ResetPasswordScreen(),
            ),
          );
        });
      }
    });
  }

  @override
  void dispose() {
    _authSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Google OAuth lands on `/?code=…` (sometimes mis-hashed as #/reset-password).
    if (AuthUtils.isOAuthLoginCallback(Uri.base)) {
      SupabaseService().isPasswordRecovery = false;
    } else if (SupabaseService().isPasswordRecovery ||
        AuthUtils.isPasswordRecoveryUri(Uri.base)) {
      return const ResetPasswordScreen();
    }

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

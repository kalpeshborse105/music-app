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
import '../ui/screens/app_shell.dart';
import '../ui/screens/onboarding_auth_screen.dart';
import '../ui/theme/app_colors.dart';
import '../ui/theme/app_theme.dart';
import 'app_dependencies.dart';

/// Root of the application. Injects dependencies via [provider] and builds the
/// MaterialApp. Startup is non-blocking: [AppDependencies.warmUp] runs after the
/// first frame (spec §37).
class EchoFlowApp extends StatefulWidget {
  const EchoFlowApp({super.key, required this.dependencies});

  final AppDependencies dependencies;

  @override
  State<EchoFlowApp> createState() => _EchoFlowAppState();
}

class _EchoFlowAppState extends State<EchoFlowApp> {
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
            title: 'EchoFlow Music',
            debugShowCheckedModeBanner: false,
            scaffoldMessengerKey: AppMessenger.key,
            theme: AppTheme.light(),
            darkTheme: AppTheme.dark(),
            themeMode: settings.themeMode,
            home: const AuthGate(),
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
    });
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

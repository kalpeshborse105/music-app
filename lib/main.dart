import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app/app.dart';
import 'app/app_dependencies.dart';
import 'ui/theme/app_colors.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Immersive, portrait-first experience.
  await SystemChrome.setPreferredOrientations(<DeviceOrientation>[
    DeviceOrientation.portraitUp,
  ]);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    systemNavigationBarColor: AppColors.darkBg,
  ));

  runApp(const _Bootstrap());
}

/// Minimal, branded splash that initializes dependencies while showing an
/// instant first frame (fast cold start, spec §27/§37).
class _Bootstrap extends StatefulWidget {
  const _Bootstrap();

  @override
  State<_Bootstrap> createState() => _BootstrapState();
}

class _BootstrapState extends State<_Bootstrap> {
  late final Future<AppDependencies> _future = AppDependencies.bootstrap();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<AppDependencies>(
      future: _future,
      builder: (BuildContext context, AsyncSnapshot<AppDependencies> snapshot) {
        if (snapshot.hasError) {
          return _BootstrapError(error: snapshot.error!);
        }
        if (!snapshot.hasData) {
          return const _SplashScreen();
        }
        return EchoFlowApp(dependencies: snapshot.data!);
      },
    );
  }
}

class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: AppColors.darkBg,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              _Logo(),
              SizedBox(height: 24),
              SizedBox(
                width: 26,
                height: 26,
                child: CircularProgressIndicator(
                  strokeWidth: 2.4,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Logo extends StatelessWidget {
  const _Logo();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Container(
          width: 84,
          height: 84,
          decoration: const BoxDecoration(
            gradient: AppColors.heroGradient,
            borderRadius: BorderRadius.all(Radius.circular(24)),
          ),
          child: const Icon(Icons.graphic_eq_rounded, color: Colors.white, size: 44),
        ),
        const SizedBox(height: 18),
        const Text(
          'EchoFlow',
          style: TextStyle(
            color: Colors.white,
            fontSize: 26,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'Music, flowing',
          style: TextStyle(color: AppColors.textSecondaryDark, fontSize: 13),
        ),
      ],
    );
  }
}

class _BootstrapError extends StatelessWidget {
  const _BootstrapError({required this.error});

  final Object error;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: AppColors.darkBg,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                const Icon(Icons.error_outline, color: AppColors.error, size: 48),
                const SizedBox(height: 16),
                const Text(
                  'EchoFlow could not start',
                  style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Please restart the app. If the problem persists, reinstall '
                  'or contact support.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.textSecondaryDark, fontSize: 13),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

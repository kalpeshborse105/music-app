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
        return KalpkrutBeatsApp(dependencies: snapshot.data!);
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
        body: SizedBox.expand(),
      ),
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
                  'Kalpkrut Beats could not start',
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

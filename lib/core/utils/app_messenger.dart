import 'package:flutter/material.dart';

import '../errors/app_exception.dart';

/// Global snackbar helper so any layer (controllers, actions) can surface a
/// friendly message without holding a BuildContext.
class AppMessenger {
  AppMessenger._();

  static final GlobalKey<ScaffoldMessengerState> key =
      GlobalKey<ScaffoldMessengerState>();

  static void _show(String message, {bool isError = false}) {
    final ScaffoldMessengerState? messenger = key.currentState;
    if (messenger == null) return;
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(12),
          duration: Duration(seconds: isError ? 4 : 2),
        ),
      );
  }

  /// Show a (already user-friendly) message.
  static void show(String message) => _show(message);

  /// Map any error onto a friendly message and show it.
  static void showError(Object error) {
    final AppException ex = toAppException(error);
    _show(ex.message, isError: true);
  }
}

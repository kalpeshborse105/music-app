import 'package:flutter/foundation.dart';

/// Minimal logging facade.
///
/// - Never logs tokens, secrets, stream URLs or private user data (spec §31).
/// - Silent in release builds.
class Logger {
  Logger._();

  static void _log(String level, String message, {Object? error}) {
    if (!kDebugMode) return;
    final String prefix = '[EchoFlow][$level]';
    if (error != null) {
      debugPrint('$prefix $message :: $error');
    } else {
      debugPrint('$prefix $message');
    }
  }

  static void info(String message) => _log('INFO', message);
  static void warn(String message, {Object? error}) => _log('WARN', message, error: error);
  static void error(String message, {Object? error}) => _log('ERROR', message, error: error);
  static void debug(String message) => _log('DEBUG', message);

  /// Redacts a URL's query string for safe logging (removes client_id etc).
  static String redactUrl(String url) {
    final int q = url.indexOf('?');
    return q == -1 ? url : '${url.substring(0, q)}?<redacted>';
  }
}

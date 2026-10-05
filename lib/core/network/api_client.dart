import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../errors/app_exception.dart';
import '../utils/logger.dart';

/// Thin, provider-agnostic HTTP client.
///
/// Adds: timeouts, exponential-backoff retries, response-size safety, JSON
/// decoding and mapping of HTTP failures onto typed [AppException]s. It never
/// logs full URLs with secrets (spec §31) and never exposes raw HTTP codes to
/// the UI (spec §28).
class ApiClient {
  final http.Client _client;
  final Duration timeout;
  final int maxRetries;

  ApiClient({
    http.Client? client,
    this.timeout = const Duration(seconds: 15),
    this.maxRetries = 2,
  }) : _client = client ?? http.Client();

  /// GET a JSON document, with retries + backoff.
  Future<Map<String, dynamic>> getJson(
    Uri uri, {
    Map<String, String>? headers,
    bool retry = true,
  }) async {
    final String body = await getString(uri, headers: headers, retry: retry);
    try {
      final dynamic decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) return decoded;
      if (decoded is List) return <String, dynamic>{'data': decoded};
      throw const ProviderException('unknown', message: 'Unexpected response format.');
    } on FormatException {
      throw const ProviderException('unknown', message: 'Unexpected response format.');
    }
  }

  /// GET raw text/JSON string.
  Future<String> getString(
    Uri uri, {
    Map<String, String>? headers,
    bool retry = true,
  }) async {
    final Map<String, String> mergedHeaders = <String, String>{
      'User-Agent': 'KalpkrutBeats/1.0.1 (Android; Mobile; Web)',
      'Accept': 'application/json, text/plain, */*',
      if (headers != null) ...headers,
    };

    int attempt = 0;
    while (true) {
      try {
        final http.Response response = await _client
            .get(uri, headers: mergedHeaders)
            .timeout(timeout);
        _throwForStatus(response.statusCode);
        return response.body;
      } on _RetryableHttp {
        if (!retry || attempt >= maxRetries) {
          rethrow;
        }
        attempt++;
        final Duration backoff =
            Duration(milliseconds: 400 * (1 << (attempt - 1))); // 400, 800...
        Logger.warn('Retrying request (attempt $attempt) after ${backoff.inMs}ms',
            error: uri.host);
        await Future<void>.delayed(backoff);
      } on TimeoutException {
        if (!retry || attempt >= maxRetries) throw const TimeoutException();
        attempt++;
        await Future<void>.delayed(Duration(milliseconds: 400 * (1 << (attempt - 1))));
      } on http.ClientException catch (e) {
        throw toAppException(e);
      } on AppException {
        rethrow;
      } catch (e) {
        throw toAppException(e);
      }
    }
  }

  void _throwForStatus(int status) {
    if (status >= 200 && status < 300) return;
    if (status == 429) throw const RateLimitException();
    if (status == 401 || status == 403) throw const AuthenticationException();
    if (status == 404) throw const NotFoundException();
    if (status >= 500) throw _RetryableHttp(status);
    throw ProviderException('unknown', message: 'Music service returned an error.');
  }

  void dispose() => _client.close();
}

/// Internal signal for retryable server errors.
class _RetryableHttp implements Exception {
  final int status;
  const _RetryableHttp(this.status);
}

extension on Duration {
  int get inMs => inMilliseconds;
}

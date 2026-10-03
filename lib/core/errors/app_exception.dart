/// Centralized, typed error hierarchy.
///
/// Raw technical exceptions are never shown to users — each type carries a
/// friendly [message] the UI can display (spec §28/§33).
sealed class AppException implements Exception {
  final String message;
  final String? technicalDetails;

  const AppException(this.message, {this.technicalDetails});

  @override
  String toString() => 'AppException($message)';
}

/// No usable network connection.
class OfflineException extends AppException {
  const OfflineException()
      : super('Check your internet connection.', technicalDetails: 'offline');
}

/// The request timed out.
class TimeoutException extends AppException {
  const TimeoutException()
      : super('This is taking longer than expected. Please try again.',
            technicalDetails: 'timeout');
}

/// Provider returned an error or is unavailable.
class ProviderException extends AppException {
  final String providerId;
  const ProviderException(this.providerId, {String? message})
      : super(message ?? 'Music service temporarily unavailable.',
            technicalDetails: 'provider:$providerId');

  factory ProviderException.unavailable(String providerId) =>
      ProviderException(providerId, message: 'Music service temporarily unavailable.');
}

/// Rate limited (HTTP 429 etc).
class RateLimitException extends AppException {
  const RateLimitException()
      : super('Music service is temporarily busy. Please try again.',
            technicalDetails: 'rate_limited');
}

/// Authentication / authorization problem (bad or missing API key, 401/403).
class AuthenticationException extends AppException {
  const AuthenticationException({String? message})
      : super(message ?? 'Music service needs to be configured.',
            technicalDetails: 'auth');
}

/// The specific resource (track/album/artist) is not available.
class NotFoundException extends AppException {
  const NotFoundException({String? message})
      : super(message ?? "This isn't available right now.",
            technicalDetails: 'not_found');
}

/// A track cannot be streamed (unavailable / not streamable).
class TrackUnavailableException extends AppException {
  const TrackUnavailableException()
      : super("This track isn't available right now.",
            technicalDetails: 'track_unavailable');
}

/// Feature is not offered by the provider.
class UnsupportedOperationException extends AppException {
  const UnsupportedOperationException({String? message})
      : super(message ?? 'This action is not supported here.',
            technicalDetails: 'unsupported');
}

/// Disk cache / storage problem.
class StorageException extends AppException {
  const StorageException({String? message})
      : super(message ?? 'Storage error. Please check available space.',
            technicalDetails: 'storage');
}

/// Player-specific failure (decode error, unsupported codec...).
class PlaybackException extends AppException {
  const PlaybackException({String? message})
      : super(message ?? 'Playback failed. Please try another track.',
            technicalDetails: 'playback');
}

/// Fallback mapping of any caught error to a user-friendly [AppException].
AppException toAppException(Object error) {
  if (error is AppException) return error;
  final String s = error.toString().toLowerCase();
  if (s.contains('socketexception') ||
      s.contains('failed host lookup') ||
      s.contains('network is unreachable') ||
      s.contains('connection refused')) {
    return const OfflineException();
  }
  if (s.contains('timeout') || s.contains('timed out')) {
    return const TimeoutException();
  }
  if (s.contains('401') || s.contains('403') || s.contains('unauthorized')) {
    return const AuthenticationException();
  }
  if (s.contains('429') || s.contains('rate limit') || s.contains('too many')) {
    return const RateLimitException();
  }
  if (s.contains('404') || s.contains('not found')) {
    return const NotFoundException();
  }
  return const ProviderException('unknown');
}

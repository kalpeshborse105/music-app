import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Authentication utility helpers for sanitized error messages and validation.
class AuthUtils {
  AuthUtils._();

  /// Translates raw AuthException or generic exceptions into friendly, actionable
  /// messages for users without leaking raw URLs, project IDs, or internal errors.
  static String getFriendlyErrorMessage(dynamic error) {
    if (error == null) return 'An unexpected error occurred. Please try again.';

    // Log full technical error for developers
    debugPrint('[AuthUtils] Raw auth error: $error');

    if (error is AuthException) {
      final String code = (error.code ?? '').toLowerCase();
      final String msg = error.message.toLowerCase();

      // Same password error (HTTP 422)
      if (code == 'same_password' || msg.contains('same_password') || msg.contains('different from the old password')) {
        return 'Your new password must be different from your current password.';
      }

      // Weak password error (HTTP 422)
      if (code == 'weak_password' || msg.contains('weak_password') || msg.contains('should be at least')) {
        return 'Password must be at least 6 characters long.';
      }

      // Pwned / breached password
      if (code == 'pwned_password' || msg.contains('pwned') || msg.contains('breach')) {
        return 'This password is too common or compromised. Please choose a stronger password.';
      }

      // Invalid credentials
      if (code == 'invalid_credentials' ||
          msg.contains('invalid login credentials') ||
          msg.contains('invalid grant') ||
          msg.contains('invalid email or password')) {
        return 'Incorrect email or password. Please try again.';
      }

      // User already registered
      if (code == 'user_already_exists' || msg.contains('already registered') || msg.contains('already exists')) {
        return 'An account with this email address already exists. Please sign in instead.';
      }

      // Email unconfirmed
      if (code == 'email_not_confirmed' || msg.contains('email not confirmed')) {
        return 'Please confirm your email address by checking your inbox before signing in.';
      }

      // Rate limit
      if (code == 'over_request_rate_limit' ||
          code == 'over_email_send_rate_limit' ||
          msg.contains('rate limit') ||
          msg.contains('too many requests')) {
        return 'Too many attempts. Please wait a few moments and try again.';
      }

      // Expired / invalid recovery link or token
      if (msg.contains('token has expired') ||
          msg.contains('invalid token') ||
          msg.contains('otp expired') ||
          msg.contains('flow state not found') ||
          msg.contains('access denied')) {
        return 'The password reset link has expired or has already been used. Please request a new link.';
      }

      // Clean message if it doesn't contain sensitive technical URLs
      if (!error.message.contains('http') &&
          !error.message.contains('supabase.co') &&
          !error.message.contains('{') &&
          error.message.isNotEmpty) {
        return error.message;
      }
    }

    final String str = error.toString().toLowerCase();
    if (str.contains('socketexception') || str.contains('network') || str.contains('timeout')) {
      return 'Network connection issue. Please check your internet connection.';
    }

    return 'Unable to complete request. Please verify your details and try again.';
  }
}

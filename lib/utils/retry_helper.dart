// lib/utils/retry_helper.dart
// Exponential backoff retry for HTTP calls and other fallible operations.

import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';

/// Retries [action] up to [maxAttempts] times with exponential backoff.
/// Throws the last error if all attempts fail.
Future<T> retryWithBackoff<T>(
  Future<T> Function() action, {
  int maxAttempts = 3,
  Duration initialDelay = const Duration(seconds: 1),
  double multiplier = 2.0,
  Duration maxDelay = const Duration(seconds: 16),
}) async {
  Duration delay = initialDelay;
  Object? lastError;

  for (int attempt = 1; attempt <= maxAttempts; attempt++) {
    try {
      return await action();
    } catch (e) {
      lastError = e;
      if (attempt == maxAttempts) break;

      // Add jitter: delay * (0.5 .. 1.5)
      final jitter = 0.5 + Random().nextDouble();
      final waitMs = (delay.inMilliseconds * jitter).round();
      debugPrint('⏳ Retry $attempt/$maxAttempts in ${waitMs}ms — $e');
      await Future.delayed(Duration(milliseconds: waitMs));

      delay = Duration(
        milliseconds: min(
          (delay.inMilliseconds * multiplier).round(),
          maxDelay.inMilliseconds,
        ),
      );
    }
  }
  throw lastError!;
}

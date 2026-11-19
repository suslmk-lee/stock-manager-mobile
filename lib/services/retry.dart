import 'package:dio/dio.dart';

// 일시적인 네트워크/서버 오류(타임아웃, 5xx, DB connection pool 초과 등)만 재시도합니다.
Future<T> withRetry<T>(
  Future<T> Function() task, {
  int maxAttempts = 3,
}) async {
  Object? lastError;
  for (var attempt = 1; attempt <= maxAttempts; attempt++) {
    try {
      return await task();
    } catch (e) {
      lastError = e;
      if (!isRetryable(e) || attempt == maxAttempts) {
        rethrow;
      }
      await Future<void>.delayed(Duration(milliseconds: 250 * attempt));
    }
  }
  throw lastError ?? StateError('Unknown error');
}

bool isRetryable(Object error) {
  if (error is! DioException) return false;

  final statusCode = error.response?.statusCode;
  final body = (error.response?.data ?? '').toString().toLowerCase();

  if (error.type == DioExceptionType.connectionTimeout ||
      error.type == DioExceptionType.sendTimeout ||
      error.type == DioExceptionType.receiveTimeout ||
      error.type == DioExceptionType.connectionError) {
    return true;
  }
  if (statusCode != null && statusCode >= 500) {
    return true;
  }
  if (body.contains('max clients reached') ||
      body.contains('too many connections') ||
      body.contains('temporarily unavailable')) {
    return true;
  }
  return false;
}

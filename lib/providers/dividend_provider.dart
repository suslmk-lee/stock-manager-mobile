import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/dividend.dart';
import '../services/api_service.dart';

Future<T> _withRetry<T>(
  Future<T> Function() task, {
  int maxAttempts = 3,
}) async {
  Object? lastError;
  for (var attempt = 1; attempt <= maxAttempts; attempt++) {
    try {
      return await task();
    } catch (e) {
      lastError = e;
      if (!_isRetryable(e) || attempt == maxAttempts) {
        rethrow;
      }
      await Future<void>.delayed(Duration(milliseconds: 250 * attempt));
    }
  }
  throw lastError ?? StateError('Unknown error');
}

bool _isRetryable(Object error) {
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

final dividendStatsProvider = FutureProvider<DividendStats>((ref) async {
  return ref.watch(apiServiceProvider).getDividendStats();
});

final monthlyDividendsProvider = FutureProvider<List<MonthlyDividend>>((ref) async {
  final now = DateTime.now();
  final startDate = '${now.year - 1}-01-01';
  final endDate = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  return ref.watch(apiServiceProvider).getMonthlyDividends(
        startDate: startDate,
        endDate: endDate,
      );
});

// 전체 배당금 (계좌/자산 정보 enriched)
final allDividendsProvider = FutureProvider<List<Dividend>>((ref) async {
  final api = ref.watch(apiServiceProvider);
  final accounts = await _withRetry(() => api.getAccounts());
  final assets = await _withRetry(() => api.getAssets());

  final assetMap = {for (final a in assets) a.id: a};
  final accountMap = {for (final a in accounts) a.id: a};

  final allDividends = <Dividend>[];
  // NOTE:
  // 계좌 수가 많을 때 병렬 요청(Future.wait)로 DB connection pool 한도에 걸려
  // 일부 계좌 데이터가 누락될 수 있어 순차 조회로 정확도를 우선합니다.
  for (final account in accounts) {
    List<Dividend> dividends;
    try {
      dividends = await _withRetry(() => api.getAccountDividends(account.id));
    } catch (_) {
      throw StateError(
        '정확한 배당 집계를 위해 모든 계좌 조회가 필요합니다. '
        '계좌 "${account.name}" 조회에 실패해 집계를 중단했습니다. 잠시 후 다시 시도해 주세요.',
      );
    }
    for (final d in dividends) {
      final asset = assetMap[d.assetId];
      final acc = accountMap[d.accountId];
      allDividends.add(Dividend(
        id: d.id,
        accountId: d.accountId,
        assetId: d.assetId,
        date: d.date,
        amount: d.amount,
        tax: d.tax,
        currency: d.currency,
        isReceived: d.isReceived,
        notes: d.notes,
        assetName: d.assetName ?? asset?.name,
        ticker: d.ticker ?? asset?.ticker,
        accountName: acc?.name,
        accountBroker: acc?.broker,
      ));
    }
  }
  allDividends.sort((a, b) => b.date.compareTo(a.date));
  return allDividends;
});

// 최근 10건 (allDividendsProvider 기반)
final recentDividendsProvider = FutureProvider<List<Dividend>>((ref) async {
  final all = await ref.watch(allDividendsProvider.future);
  return all.take(10).toList();
});

final exchangeRateProvider = FutureProvider<double>((ref) async {
  return ref.watch(apiServiceProvider).getExchangeRate();
});

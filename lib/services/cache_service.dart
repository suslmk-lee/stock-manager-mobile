import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

final cacheServiceProvider = Provider<CacheService>((ref) => CacheService());

class CacheService {
  // 캐시는 API 실패 시 대체 데이터(fallback)로만 사용합니다.
  // 30분처럼 짧게 두면 오프라인이 조금만 길어져도 fallback이 사라지므로 넉넉하게 둡니다.
  // (나중에 "캐시 우선 표시" 같은 신선도 기준이 필요하면 load의 maxAge로 짧게 지정)
  static const fallbackMaxAge = Duration(days: 7);

  Future<void> save(String key, dynamic data) async {
    final prefs = await SharedPreferences.getInstance();
    final payload = jsonEncode({
      'data': data,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });
    await prefs.setString(key, payload);
  }

  Future<T?> load<T>(
    String key,
    T Function(dynamic) fromJson, {
    Duration maxAge = fallbackMaxAge,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(key);
    if (raw == null) return null;

    try {
      final payload = jsonDecode(raw);
      final timestamp = payload['timestamp'] as int;
      final age = DateTime.now().millisecondsSinceEpoch - timestamp;

      // 허용 기간 초과 시 null 반환
      if (age > maxAge.inMilliseconds) return null;

      return fromJson(payload['data']);
    } catch (_) {
      return null;
    }
  }

  Future<void> clear(String key) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(key);
  }

  static bool _isCacheKey(String key) => key.startsWith(CacheKeys.prefix);

  /// 저장된 캐시 항목 수와 크기 (UTF-8 바이트). 설정 값은 세지 않는다
  Future<({int count, int bytes})> stats() async {
    final prefs = await SharedPreferences.getInstance();
    var count = 0, bytes = 0;
    for (final key in prefs.getKeys().where(_isCacheKey)) {
      final raw = prefs.get(key);
      count++;
      if (raw is String) bytes += utf8.encode(raw).length;
    }
    return (count: count, bytes: bytes);
  }

  /// 캐시만 모두 지운다 (설정 값은 남긴다). 지운 항목 수를 돌려준다
  Future<int> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys().where(_isCacheKey).toList();
    for (final key in keys) {
      await prefs.remove(key);
    }
    return keys.length;
  }

  // API 호출 성공 시 캐시 저장, 실패 시 캐시에서 복원 (캐시도 없으면 원래 에러)
  Future<T> fetchWithFallback<T>(
    String key, {
    required Future<T> Function() fetch,
    required dynamic Function(T) toJson,
    required T Function(dynamic) fromJson,
  }) async {
    final T data;
    try {
      data = await fetch();
    } catch (_) {
      final cached = await load<T>(key, fromJson);
      if (cached != null) return cached;
      rethrow;
    }

    // 저장을 위 try 안에 두면 저장 실패 시 새 데이터를 버리고 예전 캐시를 돌려주게 됩니다.
    try {
      await save(key, toJson(data));
    } catch (_) {
      // 캐시 저장 실패(직렬화 오류 등)는 무시하고 방금 받은 데이터를 그대로 반환합니다.
    }
    return data;
  }
}

// 캐시 키 상수
class CacheKeys {
  /// 모든 캐시 키의 앞부분 (설정 값과 구분)
  static const prefix = 'cache_';
  static const accounts = 'cache_accounts';
  static const assets = 'cache_assets';
  static const dividendStats = 'cache_dividend_stats';
  static const monthlyDividends = 'cache_monthly_dividends';
  static const exchangeRate = 'cache_exchange_rate';
  static String accountDividends(int accountId) =>
      'cache_account_dividends_$accountId';
}

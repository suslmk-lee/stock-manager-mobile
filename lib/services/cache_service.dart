import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

final cacheServiceProvider = Provider<CacheService>((ref) => CacheService());

class CacheService {
  static const _ttlMinutes = 30; // 30분 캐시

  Future<void> save(String key, dynamic data) async {
    final prefs = await SharedPreferences.getInstance();
    final payload = jsonEncode({
      'data': data,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });
    await prefs.setString(key, payload);
  }

  Future<T?> load<T>(String key, T Function(dynamic) fromJson) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(key);
    if (raw == null) return null;

    try {
      final payload = jsonDecode(raw);
      final timestamp = payload['timestamp'] as int;
      final age = DateTime.now().millisecondsSinceEpoch - timestamp;

      // TTL 초과 시 null 반환
      if (age > _ttlMinutes * 60 * 1000) return null;

      return fromJson(payload['data']);
    } catch (_) {
      return null;
    }
  }

  Future<void> clear(String key) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(key);
  }
}

// 캐시 키 상수
class CacheKeys {
  static const accounts = 'cache_accounts';
  static const assets = 'cache_assets';
  static const dividendStats = 'cache_dividend_stats';
  static const monthlyDividends = 'cache_monthly_dividends';
}

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stock_manager/services/cache_service.dart';

void main() {
  late CacheService cache;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    cache = CacheService();
  });

  test('저장한 값을 그대로 불러옴', () async {
    await cache.save('k', {'a': 1});
    final v = await cache.load('k', (json) => json['a'] as int);
    expect(v, 1);
  });

  test('TTL(30분) 지난 캐시는 null', () async {
    final old = DateTime.now()
        .subtract(const Duration(minutes: 31))
        .millisecondsSinceEpoch;
    SharedPreferences.setMockInitialValues({
      'k': jsonEncode({'data': 1, 'timestamp': old}),
    });
    expect(await cache.load('k', (json) => json as int), isNull);
  });

  test('손상된 캐시는 null', () async {
    SharedPreferences.setMockInitialValues({'k': 'not json'});
    expect(await cache.load('k', (json) => json as int), isNull);
  });

  group('fetchWithFallback', () {
    Future<double> run(Future<double> Function() fetch) =>
        cache.fetchWithFallback<double>(
          CacheKeys.exchangeRate,
          fetch: fetch,
          toJson: (v) => v,
          fromJson: (json) => (json as num).toDouble(),
        );

    test('성공 시 결과를 반환하고 캐시에 저장', () async {
      expect(await run(() async => 1380.5), 1380.5);
      final cached = await cache.load(
          CacheKeys.exchangeRate, (json) => (json as num).toDouble());
      expect(cached, 1380.5);
    });

    test('실패 시 캐시된 값으로 대체', () async {
      await run(() async => 1380.5);
      expect(await run(() async => throw Exception('offline')), 1380.5);
    });

    test('실패했는데 캐시도 없으면 원래 에러를 던짐', () async {
      expect(
        run(() async => throw StateError('offline')),
        throwsA(isA<StateError>()),
      );
    });
  });
}

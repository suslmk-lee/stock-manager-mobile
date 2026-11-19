import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stock_manager/models/asset.dart';
import 'package:stock_manager/providers/price_provider.dart';
import 'package:stock_manager/services/api_service.dart';

Asset _asset(int id, String ticker) =>
    Asset(id: id, ticker: ticker, name: ticker, type: 'Stock', holdings: []);

class _FakeApi extends ApiService {
  _FakeApi(this.assets, {Set<int>? failRequests})
    : failRequests = failRequests ?? {};

  final List<Asset> assets;
  final Set<int> failRequests; // 실패시킬 요청 순번 (0부터)
  bool failAll = false;
  Duration delay = Duration.zero;
  final requests = <List<String>>[];
  int _inFlight = 0;
  int maxInFlight = 0;

  @override
  Future<List<Asset>> getAssets() async => assets;

  @override
  Future<Map<String, dynamic>> getTickerPrices(List<String> tickers) async {
    final index = requests.length;
    requests.add(tickers);
    _inFlight++;
    maxInFlight = _inFlight > maxInFlight ? _inFlight : maxInFlight;
    try {
      if (delay > Duration.zero) await Future<void>.delayed(delay);
    } finally {
      _inFlight--;
    }
    if (failAll || failRequests.contains(index)) {
      throw Exception('request $index failed');
    }
    return {
      for (final t in tickers)
        if (t != 'NOPRICE')
          t: <String, dynamic>{
            'symbol': t,
            'price': 100.0,
            'currency': t.endsWith('.KS') ? 'KRW' : 'USD',
            'change_percent': 1.5,
          },
    };
  }
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  ProviderContainer makeContainer(_FakeApi api) {
    final container = ProviderContainer(
      overrides: [apiServiceProvider.overrideWithValue(api)],
    );
    addTearDown(container.dispose);
    return container;
  }

  List<Asset> manyAssets(int n) => List.generate(
    n,
    (i) => _asset(i, 'T${i.toString().padLeft(3, '0')}'),
  );

  test('보유 종목 현재가를 요청 한 번으로 조회 (중복·대소문자·공백 정리)', () async {
    final api = _FakeApi([
      _asset(1, 'AAPL'),
      _asset(2, ' aapl '),
      _asset(3, '005930.KS'),
      _asset(4, 'NOPRICE'),
    ]);
    final container = makeContainer(api);

    final prices = await container.read(allTickerPricesProvider.future);

    expect(api.requests, [
      ['005930.KS', 'AAPL', 'NOPRICE'],
    ]);
    expect(prices.keys, unorderedEquals(['005930.KS', 'AAPL']));

    final aapl = container.read(tickerPricesProvider(' aapl ')).valueOrNull;
    expect(aapl?.price, 100.0);
    expect(aapl?.currency, 'USD');
    expect(
      container.read(tickerPricesProvider('005930.KS')).valueOrNull?.currency,
      'KRW',
    );
    // 응답에 없는 종목은 null (에러 아님)
    final missing = container.read(tickerPricesProvider('NOPRICE'));
    expect(missing.hasError, isFalse);
    expect(missing.valueOrNull, isNull);
  });

  test('종목이 많으면 $tickerPriceChunkSize개씩 나눠서 요청', () async {
    final api = _FakeApi(manyAssets(250));
    final prices = await makeContainer(
      api,
    ).read(allTickerPricesProvider.future);

    expect(api.requests.map((r) => r.length), [100, 100, 50]);
    expect(prices, hasLength(250));
  });

  test('묶음 요청은 최대 $tickerPriceMaxParallelRequests개까지 동시에 보냄', () async {
    final api = _FakeApi(manyAssets(550))
      ..delay = const Duration(milliseconds: 20);
    final prices = await makeContainer(
      api,
    ).read(allTickerPricesProvider.future);

    expect(api.requests, hasLength(6));
    expect(api.maxInFlight, tickerPriceMaxParallelRequests);
    expect(prices, hasLength(550));
  });

  test('일부 요청만 실패하면 성공한 현재가는 그대로 사용', () async {
    final api = _FakeApi(manyAssets(250), failRequests: {1});
    final prices = await makeContainer(
      api,
    ).read(allTickerPricesProvider.future);

    expect(prices, hasLength(150));
    expect(prices.containsKey('T000'), isTrue);
    expect(prices.containsKey('T100'), isFalse);
  });

  test('전부 실패하면 에러', () async {
    final api = _FakeApi([_asset(1, 'AAPL')])..failAll = true;
    final container = makeContainer(api);

    await expectLater(
      container.read(allTickerPricesProvider.future),
      throwsA(isA<Exception>()),
    );
    expect(container.read(tickerPricesProvider('AAPL')).hasError, isTrue);
  });

  test('갱신이 실패해도 이전에 받은 현재가를 계속 표시', () async {
    final api = _FakeApi([_asset(1, 'AAPL')]);
    final container = makeContainer(api);
    await container.read(allTickerPricesProvider.future);

    api.failAll = true;
    container.invalidate(allTickerPricesProvider);
    await expectLater(
      container.read(allTickerPricesProvider.future),
      throwsA(isA<Exception>()),
    );

    final price = container.read(tickerPricesProvider('AAPL'));
    expect(price.hasError, isFalse);
    expect(price.valueOrNull?.price, 100.0);
  });

  test('보유 종목이 없으면 요청하지 않음', () async {
    final api = _FakeApi([]);
    final prices = await makeContainer(
      api,
    ).read(allTickerPricesProvider.future);

    expect(prices, isEmpty);
    expect(api.requests, isEmpty);
  });
}

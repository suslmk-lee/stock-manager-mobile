import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stock_manager/models/asset.dart';
import 'package:stock_manager/providers/dividend_provider.dart';
import 'package:stock_manager/providers/portfolio_provider.dart';
import 'package:stock_manager/services/api_service.dart';

Asset _asset(int id, String ticker) => Asset(
  id: id,
  ticker: ticker,
  name: ticker,
  type: 'Stock',
  holdings: [Holding(id: id, accountId: 1, quantity: 10, averagePrice: 1)],
);

class _FakeApi extends ApiService {
  _FakeApi(this.assets);

  final List<Asset> assets;
  final requests = <List<String>>[];

  static const quotes = <String, Map<String, dynamic>>{
    '7203.T': {'price': 3000, 'currency': 'JPY'},
    'VOD.L': {'price': 72, 'currency': 'GBp'},
    'AAPL': {'price': 200, 'currency': 'USD'},
    '005930.KS': {'price': 10000, 'currency': 'KRW'},
    'JPYKRW=X': {'price': 8.3, 'currency': 'KRW'},
    'GBPKRW=X': {'price': 1800, 'currency': 'KRW'},
  };

  @override
  Future<List<Asset>> getAssets() async => assets;

  @override
  Future<Map<String, dynamic>> getTickerPrices(List<String> tickers) async {
    requests.add(tickers);
    return {
      for (final t in tickers)
        if (quotes.containsKey(t)) t: quotes[t],
    };
  }
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  ProviderContainer makeContainer(_FakeApi api) {
    final c = ProviderContainer(
      overrides: [
        apiServiceProvider.overrideWithValue(api),
        exchangeRateProvider.overrideWith((ref) async => 1350),
      ],
    );
    addTearDown(c.dispose);
    return c;
  }

  test('원화·달러가 아닌 통화만 {통화}KRW=X 시세로 받아 원화 환율을 만든다', () async {
    final api = _FakeApi([
      _asset(1, '7203.T'),
      _asset(2, 'VOD.L'),
      _asset(3, 'AAPL'),
      _asset(4, '005930.KS'),
    ]);
    final c = makeContainer(api);

    final rates = await c.read(otherFxRatesProvider.future);
    await c.read(exchangeRateProvider.future);

    expect(api.requests.last, ['GBPKRW=X', 'JPYKRW=X']);
    expect(rates['JPY'], 8.3);
    expect(rates['GBp'], closeTo(18, 1e-9)); // 펜스 = 파운드의 1/100
    final fx = c.read(fxRatesProvider);
    expect(fx.usdKrw, 1350);

    final snap = c.read(portfolioProvider(null)).value!;
    expect(snap.pricesLoading, isFalse);
    expect(snap.totals.pricedCount, 4);
    expect(
      snap.totals.valueKrw,
      closeTo(
        10 * 3000 * 8.3 + 10 * 72 * 18 + 10 * 200 * 1350 + 10 * 10000,
        1e-6,
      ),
    );
  });

  test('원화·달러 종목만 있으면 환율 시세를 따로 요청하지 않는다', () async {
    final api = _FakeApi([_asset(1, 'AAPL'), _asset(2, '005930.KS')]);
    final c = makeContainer(api);

    expect(await c.read(otherFxRatesProvider.future), isEmpty);
    expect(api.requests, hasLength(1)); // 보유 종목 현재가 요청만
  });
}

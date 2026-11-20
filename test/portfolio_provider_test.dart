import 'package:flutter_test/flutter_test.dart';
import 'package:stock_manager/core/fx.dart';
import 'package:stock_manager/models/asset.dart';
import 'package:stock_manager/providers/portfolio_provider.dart';
import 'package:stock_manager/providers/price_provider.dart';

Holding _h(int account, double qty, double avg) => Holding(
  id: account * 100 + qty.toInt(),
  accountId: account,
  quantity: qty,
  averagePrice: avg,
);

Asset _asset(int id, String ticker, List<Holding> holdings) => Asset(
  id: id,
  ticker: ticker,
  name: ticker,
  type: 'Stock',
  holdings: holdings,
);

TickerPrice _price(double price, String currency, [double change = 0]) =>
    TickerPrice(price: price, currency: currency, changePercent: change);

void main() {
  const fx = FxRates(usdKrw: 1000);

  final assets = [
    // 국내: 10주 × 평단 9,000 → 현재가 10,000 (+10% 오늘)
    _asset(1, '005930.KS', [_h(1, 6, 9000), _h(2, 4, 9000)]),
    // 해외: 2주 × 평단 $100 → 현재가 $150 (−25% 오늘)
    _asset(2, 'AAPL', [_h(2, 2, 100)]),
    // 현재가 없음
    _asset(3, 'NOPRICE', [_h(1, 1, 50)]),
  ];
  final prices = {
    '005930.KS': _price(10000, 'KRW', 10),
    'AAPL': _price(150, 'USD', -25),
  };

  test('평가금액·원금·손익을 원화로 환산해 합친다 (현재가 없는 종목은 빼고)', () {
    final snap = buildPortfolio(assets: assets, prices: prices, fx: fx);
    final t = snap.totals;

    expect(t.assetCount, 3);
    expect(t.pricedCount, 2);
    expect(t.valueKrw, 100000 + 300000); // 10×10,000 + 2×$150×1,000
    expect(t.costKrw, 90000 + 200000); // NOPRICE 원금은 넣지 않는다
    expect(t.profitKrw, 110000);
    expect(t.profitPct, closeTo(110000 / 290000 * 100, 1e-9));
    expect(t.domesticKrw, 100000);
    expect(t.overseasKrw, 300000);
  });

  test('오늘 변화는 어제 평가금액 대비로 계산한다', () {
    final t = buildPortfolio(assets: assets, prices: prices, fx: fx).totals;
    // 국내: 어제 100,000/1.1 → 오늘 +9,090.9 / 해외: 어제 300,000/0.75 → 오늘 −100,000
    expect(t.todayChangeKrw, closeTo(100000 * 10 / 110 - 100000, 1e-6));
    final yesterday = 100000 / 1.1 + 300000 / 0.75;
    expect(t.todayPct, closeTo(t.todayChangeKrw / yesterday * 100, 1e-9));
  });

  test('계좌를 고르면 그 계좌 보유분만 보고, 평가금액 큰 순서로 정렬한다', () {
    final snap = buildPortfolio(
      assets: assets,
      prices: prices,
      fx: fx,
      accountId: 2,
    );
    expect(snap.lines.map((l) => l.asset.ticker), ['AAPL', '005930.KS']);
    expect(snap.lines.last.quantity, 4);
    expect(snap.totals.valueKrw, 40000 + 300000);

    final account1 = buildPortfolio(
      assets: assets,
      prices: prices,
      fx: fx,
      accountId: 1,
    );
    // 현재가 없는 종목은 맨 뒤
    expect(account1.lines.map((l) => l.asset.ticker), ['005930.KS', 'NOPRICE']);
    expect(account1.lines.last.value, isNull);
    expect(account1.lines.last.currency, 'USD');
  });

  test('줄 하나의 수익률과 통화', () {
    final snap = buildPortfolio(assets: assets, prices: prices, fx: fx);
    final aapl = snap.lines.firstWhere((l) => l.asset.ticker == 'AAPL');
    expect(aapl.currency, 'USD');
    expect(aapl.value, 300);
    expect(aapl.returnPct, closeTo(50, 1e-9));
  });

  test('평단이 0이면 수익률을 계산하지 않는다', () {
    final snap = buildPortfolio(
      assets: [
        _asset(9, 'FREE', [_h(1, 3, 0)]),
      ],
      prices: {'FREE': _price(10, 'USD')},
      fx: fx,
    );
    expect(snap.lines.single.returnPct, isNull);
    expect(snap.totals.profitPct, isNull);
  });

  group('원화·달러가 아닌 통화', () {
    // 엔화 20주 × ¥3,000, 평단 ¥2,800 / 유로 2주 × €500, 평단 €400
    final foreign = [
      _asset(1, '7203.T', [_h(1, 20, 2800)]),
      _asset(2, 'SIE.DE', [_h(1, 2, 400)]),
      _asset(3, '005930.KS', [_h(1, 1, 9000)]),
    ];
    final quotes = {
      '7203.T': _price(3000, 'JPY'),
      'SIE.DE': _price(500, 'EUR'),
      '005930.KS': _price(10000, 'KRW'),
    };

    test('통화별 환율로 원화 환산 (엔화를 달러 환율로 보지 않는다)', () {
      const rates = FxRates(usdKrw: 1300, others: {'JPY': 8.5, 'EUR': 1450});
      final snap = buildPortfolio(assets: foreign, prices: quotes, fx: rates);
      final jpy = snap.lines.firstWhere((l) => l.asset.ticker == '7203.T');
      expect(jpy.currency, 'JPY');
      expect(jpy.valueKrw, closeTo(20 * 3000 * 8.5, 1e-6));
      expect(jpy.costKrw, closeTo(20 * 2800 * 8.5, 1e-6));
      expect(
        snap.totals.valueKrw,
        closeTo(20 * 3000 * 8.5 + 2 * 500 * 1450 + 10000, 1e-6),
      );
      expect(snap.totals.domesticKrw, 10000);
      expect(snap.totals.pricedCount, 3);
    });

    test('환율을 모르는 통화는 합계에서 빼고 줄은 남긴다', () {
      const rates = FxRates(usdKrw: 1300, others: {'EUR': 1450});
      final snap = buildPortfolio(assets: foreign, prices: quotes, fx: rates);
      expect(snap.totals.assetCount, 3);
      expect(snap.totals.pricedCount, 2);
      expect(snap.totals.valueKrw, closeTo(2 * 500 * 1450 + 10000, 1e-6));
      final jpy = snap.lines.last;
      expect(jpy.asset.ticker, '7203.T');
      expect(jpy.value, 20 * 3000); // 엔화 금액은 그대로 보여 줄 수 있다
      expect(jpy.valueKrw, isNull);
    });

    test('시세 통화가 비어 있으면 거래소 꼬리표로 짐작한다', () {
      final snap = buildPortfolio(
        assets: [
          _asset(1, '7203.T', [_h(1, 1, 100)]),
          _asset(2, 'TGNA', []),
        ],
        prices: {'7203.T': _price(3000, ''), 'TGNA': _price(0, '')},
        fx: const FxRates(usdKrw: 1300, others: {'JPY': 9}),
      );
      expect(snap.lines.map((l) => l.currency), ['JPY', 'USD']);
      // 수량 0 인 종목은 환율과 관계없이 0원으로 합계에 들어간다
      expect(snap.totals.pricedCount, 2);
      expect(snap.totals.valueKrw, 27000);
    });

    test('통화 표시', () {
      expect(formatCurrency(12345, 'JPY'), '¥12,345');
      expect(formatCurrency(99.5, 'EUR'), '€99.50');
      expect(formatCurrency(-1234.4, 'KRW'), '−₩1,234');
      expect(formatCurrency(-0.2, 'KRW'), '₩0');
      expect(formatCurrency(12.3, 'GBp'), '12.30p');
      expect(formatCurrency(5, 'CHF'), 'CHF 5.00');
      expect(currencyOfTicker('7203.t'), 'JPY');
      expect(currencyOfTicker('AAPL'), 'USD');
      expect(fxSymbolOf('GBp'), ('GBPKRW=X', 0.01));
    });
  });
}

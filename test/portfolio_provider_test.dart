import 'package:flutter_test/flutter_test.dart';
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
  const rate = 1000.0;

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
    final snap = buildPortfolio(assets: assets, prices: prices, rate: rate);
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
    final t = buildPortfolio(assets: assets, prices: prices, rate: rate).totals;
    // 국내: 어제 100,000/1.1 → 오늘 +9,090.9 / 해외: 어제 300,000/0.75 → 오늘 −100,000
    expect(t.todayChangeKrw, closeTo(100000 * 10 / 110 - 100000, 1e-6));
    final yesterday = 100000 / 1.1 + 300000 / 0.75;
    expect(t.todayPct, closeTo(t.todayChangeKrw / yesterday * 100, 1e-9));
  });

  test('계좌를 고르면 그 계좌 보유분만 보고, 평가금액 큰 순서로 정렬한다', () {
    final snap = buildPortfolio(
      assets: assets,
      prices: prices,
      rate: rate,
      accountId: 2,
    );
    expect(snap.lines.map((l) => l.asset.ticker), ['AAPL', '005930.KS']);
    expect(snap.lines.last.quantity, 4);
    expect(snap.totals.valueKrw, 40000 + 300000);

    final account1 = buildPortfolio(
      assets: assets,
      prices: prices,
      rate: rate,
      accountId: 1,
    );
    // 현재가 없는 종목은 맨 뒤
    expect(account1.lines.map((l) => l.asset.ticker), ['005930.KS', 'NOPRICE']);
    expect(account1.lines.last.value, isNull);
    expect(account1.lines.last.currency, 'USD');
  });

  test('줄 하나의 수익률과 통화', () {
    final snap = buildPortfolio(assets: assets, prices: prices, rate: rate);
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
      rate: rate,
    );
    expect(snap.lines.single.returnPct, isNull);
    expect(snap.totals.profitPct, isNull);
  });
}

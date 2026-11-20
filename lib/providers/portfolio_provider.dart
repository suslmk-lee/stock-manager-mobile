import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/fx.dart';
import '../models/asset.dart';
import '../services/api_service.dart';
import 'asset_provider.dart';
import 'dividend_provider.dart';
import 'price_provider.dart';

/// 환율을 아직 못 받았을 때 쓰는 값 (예전 화면들과 같은 기준)
const fallbackUsdKrw = 1300.0;

/// 원화·달러가 아닌 통화(엔화·유로 등)의 원화 환율.
/// 보유 종목 현재가의 통화를 보고 {통화}KRW=X 시세를 한 번에 받는다 (현재가가 갱신될 때 함께).
final otherFxRatesProvider = FutureProvider<Map<String, double>>((ref) async {
  final prices = await ref.watch(allTickerPricesProvider.future);
  final need = {for (final p in prices.values) normalizeCurrency(p.currency)}
    ..removeAll(const ['', 'KRW', 'USD']);
  if (need.isEmpty) return const {};

  final symbols = {for (final c in need) c: fxSymbolOf(c)};
  final data = await ref
      .watch(apiServiceProvider)
      .getTickerPrices(
        ({for (final s in symbols.values) s.$1}.toList()..sort()),
      );
  final quotes = {
    for (final e in data.entries)
      if (e.value is Map) normalizeTicker(e.key): e.value as Map,
  };

  final rates = <String, double>{};
  symbols.forEach((currency, s) {
    final price = quotes[normalizeTicker(s.$1)]?['price'];
    if (price is num && price > 0) rates[currency] = price.toDouble() * s.$2;
  });
  return rates;
});

/// 통화별 원화 환율 (달러는 앱 환율, 그 밖의 통화는 시세)
final fxRatesProvider = Provider<FxRates>((ref) {
  final usd = ref.watch(exchangeRateProvider).valueOrNull ?? fallbackUsdKrw;
  final others = ref.watch(otherFxRatesProvider).valueOrNull ?? const {};
  return FxRates(usdKrw: usd, others: others);
});

/// 종목 한 줄: 보유 수량·원금과 현재가로 계산한 평가금액
class HoldingLine {
  final Asset asset;
  final double quantity;

  /// 종목 통화 기준 원금 (수량 × 평균단가)
  final double cost;
  final TickerPrice? price;

  /// 종목 통화 (현재가 통화, 없으면 거래소 꼬리표로 추정)
  final String currency;
  final FxRates fx;

  const HoldingLine({
    required this.asset,
    required this.quantity,
    required this.cost,
    required this.price,
    required this.currency,
    required this.fx,
  });

  /// 원화로. 환율을 모르는 통화면 null
  double? toKrw(double v) => v == 0 ? 0 : fx.toKrw(v, currency);

  /// 종목 통화 기준 평가금액
  double? get value => price == null ? null : quantity * price!.price;

  /// 원화 환산 평가금액. 현재가나 환율이 없으면 null (합계에서 빠진다)
  double? get valueKrw => value == null ? null : toKrw(value!);
  double? get costKrw => toKrw(cost);

  /// 평가 수익률 (%), 원금이 없으면 null
  double? get returnPct =>
      value == null || cost <= 0 ? null : (value! - cost) / cost * 100;

  /// 오늘 평가금액 변화 (종목 통화)
  double? get todayChange {
    final v = value;
    final cp = price?.changePercent;
    if (v == null || cp == null || cp <= -100) return null;
    return v * cp / (100 + cp);
  }
}

class PortfolioTotals {
  final int assetCount;

  /// 현재가와 환율이 있어 합계에 들어간 종목 수
  final int pricedCount;

  /// 아래 금액은 모두 원화 환산. 원금·손익도 합계에 들어간 종목만 더한다.
  final double valueKrw;
  final double costKrw;
  final double todayChangeKrw;
  final double domesticKrw;
  final double overseasKrw;

  const PortfolioTotals({
    required this.assetCount,
    required this.pricedCount,
    required this.valueKrw,
    required this.costKrw,
    required this.todayChangeKrw,
    required this.domesticKrw,
    required this.overseasKrw,
  });

  double get profitKrw => valueKrw - costKrw;
  double? get profitPct => costKrw > 0 ? profitKrw / costKrw * 100 : null;

  /// 오늘 변화율: 어제 평가금액 대비
  double? get todayPct {
    final before = valueKrw - todayChangeKrw;
    return before > 0 ? todayChangeKrw / before * 100 : null;
  }

  double get domesticShare => valueKrw > 0 ? domesticKrw / valueKrw : 0;
}

class PortfolioSnapshot {
  final List<HoldingLine> lines;
  final PortfolioTotals totals;
  final FxRates fx;

  /// 현재가(또는 필요한 환율)를 아직 한 번도 받지 못했다 (금액 자리에 로딩 표시)
  final bool pricesLoading;

  const PortfolioSnapshot({
    required this.lines,
    required this.totals,
    required this.fx,
    required this.pricesLoading,
  });

  /// 달러 환율 (USD 로 보기에 쓴다)
  double get rate => fx.usdKrw;
}

/// 보유 종목과 현재가로 평가금액·원금·손익·오늘 변화를 계산한다.
/// accountId 를 주면 그 계좌의 보유분만 본다. 줄은 원화 환산 평가금액이 큰 순서.
PortfolioSnapshot buildPortfolio({
  required List<Asset> assets,
  required Map<String, TickerPrice> prices,
  required FxRates fx,
  int? accountId,
  bool pricesLoading = false,
}) {
  final lines = <HoldingLine>[];
  for (final asset in assets) {
    final holdings = accountId == null
        ? asset.holdings
        : asset.holdings.where((h) => h.accountId == accountId).toList();
    if (accountId != null && holdings.isEmpty) continue;
    final quantity = holdings.isEmpty
        ? asset.totalQuantity
        : holdings.fold<double>(0, (s, h) => s + h.quantity);
    final cost = holdings.fold<double>(
      0,
      (s, h) => s + h.quantity * h.averagePrice,
    );
    final price = prices[normalizeTicker(asset.ticker)];
    final priceCurrency = normalizeCurrency(price?.currency);
    lines.add(
      HoldingLine(
        asset: asset,
        quantity: quantity,
        cost: cost,
        price: price,
        currency: priceCurrency.isEmpty
            ? currencyOfTicker(asset.ticker)
            : priceCurrency,
        fx: fx,
      ),
    );
  }

  lines.sort((a, b) {
    final av = a.valueKrw, bv = b.valueKrw;
    if (av == null && bv == null) return a.asset.name.compareTo(b.asset.name);
    if (av == null) return 1;
    if (bv == null) return -1;
    return bv.compareTo(av);
  });

  var value = 0.0, cost = 0.0, today = 0.0, domestic = 0.0, overseas = 0.0;
  var priced = 0;
  for (final line in lines) {
    final v = line.valueKrw;
    if (v == null) continue;
    priced++;
    value += v;
    cost += line.costKrw ?? 0;
    today += line.toKrw(line.todayChange ?? 0) ?? 0;
    if (line.currency == 'KRW') {
      domestic += v;
    } else {
      overseas += v;
    }
  }

  return PortfolioSnapshot(
    lines: lines,
    fx: fx,
    pricesLoading: pricesLoading,
    totals: PortfolioTotals(
      assetCount: lines.length,
      pricedCount: priced,
      valueKrw: value,
      costKrw: cost,
      todayChangeKrw: today,
      domesticKrw: domestic,
      overseasKrw: overseas,
    ),
  );
}

/// 현재가나 (원화·달러가 아닌 종목의) 환율을 아직 한 번도 받지 못했나
bool _waitingForQuotes(Ref ref) {
  final prices = ref.watch(allTickerPricesProvider);
  if (prices.valueOrNull == null) return !prices.hasError;
  final fx = ref.watch(otherFxRatesProvider);
  return fx.valueOrNull == null && !fx.hasError;
}

/// 전체(null) 또는 계좌 하나의 포트폴리오. 보유 종목이 오면 바로 줄을 보여 주고,
/// 현재가·환율은 받는 대로 채운다.
final portfolioProvider = Provider.family<AsyncValue<PortfolioSnapshot>, int?>((
  ref,
  accountId,
) {
  final assetsAsync = ref.watch(assetsProvider);
  final assets = assetsAsync.valueOrNull;
  if (assets == null) {
    if (assetsAsync.hasError) {
      return AsyncError(
        assetsAsync.error!,
        assetsAsync.stackTrace ?? StackTrace.empty,
      );
    }
    return const AsyncLoading();
  }
  return AsyncData(
    buildPortfolio(
      assets: assets,
      prices: ref.watch(allTickerPricesProvider).valueOrNull ?? const {},
      fx: ref.watch(fxRatesProvider),
      accountId: accountId,
      pricesLoading: _waitingForQuotes(ref),
    ),
  );
});

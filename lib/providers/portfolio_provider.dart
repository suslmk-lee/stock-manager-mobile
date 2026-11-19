import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/format.dart';
import '../models/asset.dart';
import 'asset_provider.dart';
import 'dividend_provider.dart';
import 'price_provider.dart';

/// 환율을 아직 못 받았을 때 쓰는 값 (예전 화면들과 같은 기준)
const fallbackUsdKrw = 1300.0;

/// 종목 한 줄: 보유 수량·원금과 현재가로 계산한 평가금액
class HoldingLine {
  final Asset asset;
  final double quantity;

  /// 종목 통화 기준 원금 (수량 × 평균단가)
  final double cost;
  final TickerPrice? price;

  /// 종목 통화 (현재가 통화, 없으면 티커로 추정)
  final String currency;
  final double rate;

  const HoldingLine({
    required this.asset,
    required this.quantity,
    required this.cost,
    required this.price,
    required this.currency,
    required this.rate,
  });

  double toKrw(double v) => currency == 'KRW' ? v : v * rate;

  /// 종목 통화 기준 평가금액
  double? get value => price == null ? null : quantity * price!.price;
  double? get valueKrw => value == null ? null : toKrw(value!);
  double get costKrw => toKrw(cost);

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
  final int pricedCount;

  /// 아래 금액은 모두 원화 환산. 원금·손익은 현재가를 받은 종목만 더한다.
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
  final double rate;

  /// 현재가를 아직 한 번도 받지 못했다 (금액 자리에 로딩 표시)
  final bool pricesLoading;

  const PortfolioSnapshot({
    required this.lines,
    required this.totals,
    required this.rate,
    required this.pricesLoading,
  });
}

/// 보유 종목과 현재가로 평가금액·원금·손익·오늘 변화를 계산한다.
/// accountId 를 주면 그 계좌의 보유분만 본다. 줄은 원화 환산 평가금액이 큰 순서.
PortfolioSnapshot buildPortfolio({
  required List<Asset> assets,
  required Map<String, TickerPrice> prices,
  required double rate,
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
    lines.add(
      HoldingLine(
        asset: asset,
        quantity: quantity,
        cost: cost,
        price: price,
        currency:
            price?.currency ?? (isKrwTicker(asset.ticker) ? 'KRW' : 'USD'),
        rate: rate,
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
    cost += line.costKrw;
    today += line.toKrw(line.todayChange ?? 0);
    if (line.currency == 'KRW') {
      domestic += v;
    } else {
      overseas += v;
    }
  }

  return PortfolioSnapshot(
    lines: lines,
    rate: rate,
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
  final pricesAsync = ref.watch(allTickerPricesProvider);
  final rate = ref.watch(exchangeRateProvider).valueOrNull ?? fallbackUsdKrw;
  return AsyncData(
    buildPortfolio(
      assets: assets,
      prices: pricesAsync.valueOrNull ?? const {},
      rate: rate,
      accountId: accountId,
      pricesLoading: pricesAsync.valueOrNull == null && !pricesAsync.hasError,
    ),
  );
});

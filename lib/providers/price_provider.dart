import 'dart:async';
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/api_service.dart';
import 'asset_provider.dart';

class TickerPrice {
  final double price;
  final String currency;
  final double changePercent;

  TickerPrice({
    required this.price,
    required this.currency,
    required this.changePercent,
  });

  factory TickerPrice.fromJson(Map<String, dynamic> json) => TickerPrice(
        price: ((json['price'] ?? 0) as num).toDouble(),
        currency: json['currency'] ?? 'USD',
        changePercent: ((json['change_percent'] ?? 0) as num).toDouble(),
      );
}

// 한 번의 요청에 담는 최대 종목 수 (URL 길이와 응답 시간을 적당히 유지)
const tickerPriceChunkSize = 100;
// 동시에 보내는 묶음 요청 수. 서버는 요청마다 시세를 5개씩 동시에 가져오므로
// 묶음을 나란히 보내면 서버 캐시가 비어 있을 때 대기 시간이 줄어듭니다.
const tickerPriceMaxParallelRequests = 3;
const _refreshInterval = Duration(minutes: 5);
const _retryInterval = Duration(seconds: 30);

String normalizeTicker(String ticker) => ticker.trim().toUpperCase();

// 보유 종목 전체의 현재가를 /ticker/prices로 묶어서 조회합니다. (키: 대문자 티커)
// 종목마다 /ticker/price를 따로 부르면 종목 수만큼 요청이 몰리므로 한 번에 받습니다.
// - 5분마다 자동 갱신하고, 일부 또는 전체가 실패하면 30초 뒤 다시 시도합니다.
// - 갱신이 실패해도 Riverpod이 이전 값을 유지하므로 마지막 현재가가 계속 표시됩니다.
final allTickerPricesProvider = FutureProvider<Map<String, TickerPrice>>((
  ref,
) async {
  final api = ref.watch(apiServiceProvider);

  var disposed = false;
  Timer? timer;
  ref.onDispose(() {
    disposed = true;
    timer?.cancel();
  });
  void scheduleRefresh(Duration after) {
    if (disposed) return;
    timer = Timer(after, ref.invalidateSelf);
  }

  final assets = await ref.watch(assetsProvider.future);
  final tickers =
      ({for (final a in assets) normalizeTicker(a.ticker)}..remove(''))
          .toList()
        ..sort();
  if (tickers.isEmpty) return <String, TickerPrice>{};

  final chunks = [
    for (var i = 0; i < tickers.length; i += tickerPriceChunkSize)
      tickers.sublist(i, min(i + tickerPriceChunkSize, tickers.length)),
  ];

  final prices = <String, TickerPrice>{};
  Object? lastError;
  StackTrace? lastStackTrace;
  Future<void> fetchChunk(List<String> chunk) async {
    try {
      final data = await api.getTickerPrices(chunk);
      data.forEach((ticker, json) {
        if (json is Map<String, dynamic>) {
          prices[normalizeTicker(ticker)] = TickerPrice.fromJson(json);
        }
      });
    } catch (e, st) {
      lastError = e;
      lastStackTrace = st;
    }
  }

  for (var i = 0; i < chunks.length; i += tickerPriceMaxParallelRequests) {
    await Future.wait(
      chunks.skip(i).take(tickerPriceMaxParallelRequests).map(fetchChunk),
    );
  }

  final error = lastError;
  if (error != null && prices.isEmpty) {
    scheduleRefresh(_retryInterval);
    Error.throwWithStackTrace(error, lastStackTrace ?? StackTrace.current);
  }
  scheduleRefresh(error == null ? _refreshInterval : _retryInterval);
  return prices;
});

// 종목 하나의 현재가. allTickerPricesProvider 결과에서 꺼내 씁니다.
// 갱신 중이거나 갱신이 실패해도 이전에 받은 값이 있으면 그 값을 돌려줍니다.
final tickerPricesProvider =
    Provider.family<AsyncValue<TickerPrice?>, String>((ref, ticker) {
  final all = ref.watch(allTickerPricesProvider);
  final prices = all.valueOrNull;
  if (prices != null) return AsyncData(prices[normalizeTicker(ticker)]);
  if (all.hasError) {
    return AsyncError(all.error!, all.stackTrace ?? StackTrace.empty);
  }
  return const AsyncLoading();
});

// KRW/USD 토글 (true = KRW)
final portfolioCurrencyProvider = StateProvider<bool>((ref) => true);

// Home 화면도 포트폴리오와 같은 통화 기준을 공유합니다. (true = KRW)
final homeCurrencyProvider = portfolioCurrencyProvider;

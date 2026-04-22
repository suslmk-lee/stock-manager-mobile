import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/api_service.dart';

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

final tickerPricesProvider =
    FutureProvider.family<TickerPrice?, String>((ref, ticker) async {
  try {
    final data = await ref.watch(apiServiceProvider).getTickerPrice(ticker);
    final price = TickerPrice.fromJson(data);

    // 5분 후 자동 만료
    Future.delayed(const Duration(minutes: 5), () {
      ref.invalidateSelf();
    });

    return price;
  } catch (_) {
    return null;
  }
});

// KRW/USD 토글 (true = KRW)
final portfolioCurrencyProvider = StateProvider<bool>((ref) => true);

// Home 화면 배당금 통화 토글 (true = KRW)
final homeCurrencyProvider = StateProvider<bool>((ref) => false);

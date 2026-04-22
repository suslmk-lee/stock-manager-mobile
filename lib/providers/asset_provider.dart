import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/asset.dart';
import '../services/api_service.dart';
import '../services/cache_service.dart';

final assetsProvider = FutureProvider<List<Asset>>((ref) async {
  final api = ref.watch(apiServiceProvider);
  final cache = ref.watch(cacheServiceProvider);

  try {
    final data = await api.getAssets();
    await cache.save(CacheKeys.assets, data.map((a) => {
      'id': a.id,
      'ticker': a.ticker,
      'name': a.name,
      'type': a.type,
      'sector': a.sector,
      'holdings': a.holdings.map((h) => {
        'id': h.id,
        'account_id': h.accountId,
        'quantity': h.quantity,
        'average_price': h.averagePrice,
      }).toList(),
    }).toList());
    return data;
  } catch (e) {
    final cached = await cache.load<List<Asset>>(
      CacheKeys.assets,
      (json) => (json as List).map((e) => Asset.fromJson(e)).toList(),
    );
    if (cached != null) return cached;
    rethrow;
  }
});

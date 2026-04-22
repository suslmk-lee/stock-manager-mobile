import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/account.dart';
import '../services/api_service.dart';
import '../services/cache_service.dart';

final accountsProvider = FutureProvider<List<Account>>((ref) async {
  final api = ref.watch(apiServiceProvider);
  final cache = ref.watch(cacheServiceProvider);

  try {
    final data = await api.getAccounts();
    // 성공 시 캐시 저장
    await cache.save(CacheKeys.accounts, data.map((a) => {
      'id': a.id,
      'name': a.name,
      'broker': a.broker,
      'accountNumber': a.accountNumber,
      'market_type': a.marketType,
      'currency': a.currency,
      'description': a.description,
    }).toList());
    return data;
  } catch (e) {
    // 실패 시 캐시에서 복원
    final cached = await cache.load<List<Account>>(
      CacheKeys.accounts,
      (json) => (json as List).map((e) => Account.fromJson(e)).toList(),
    );
    if (cached != null) return cached;
    rethrow;
  }
});

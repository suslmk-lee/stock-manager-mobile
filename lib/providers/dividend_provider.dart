import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/dividend.dart';
import '../services/api_service.dart';
import 'account_provider.dart';
import 'asset_provider.dart';

final dividendStatsProvider = FutureProvider<DividendStats>((ref) async {
  return ref.watch(apiServiceProvider).getDividendStats();
});

final monthlyDividendsProvider = FutureProvider<List<MonthlyDividend>>((ref) async {
  final now = DateTime.now();
  final startDate = '${now.year - 1}-01-01';
  final endDate = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  return ref.watch(apiServiceProvider).getMonthlyDividends(
        startDate: startDate,
        endDate: endDate,
      );
});

// 전체 배당금 (계좌/자산 정보 enriched)
final allDividendsProvider = FutureProvider<List<Dividend>>((ref) async {
  final accounts = await ref.watch(accountsProvider.future);
  final assets = await ref.watch(assetsProvider.future);
  final api = ref.watch(apiServiceProvider);

  final assetMap = {for (final a in assets) a.id: a};
  final accountMap = {for (final a in accounts) a.id: a};

  final results = await Future.wait(
    accounts.map((account) =>
        api.getAccountDividends(account.id).catchError((_) => <Dividend>[])),
  );

  final allDividends = <Dividend>[];
  for (int i = 0; i < accounts.length; i++) {
    for (final d in results[i]) {
      final asset = assetMap[d.assetId];
      final acc = accountMap[d.accountId];
      allDividends.add(Dividend(
        id: d.id,
        accountId: d.accountId,
        assetId: d.assetId,
        date: d.date,
        amount: d.amount,
        tax: d.tax,
        currency: d.currency,
        isReceived: d.isReceived,
        notes: d.notes,
        assetName: d.assetName ?? asset?.name,
        ticker: d.ticker ?? asset?.ticker,
        accountName: acc?.name,
        accountBroker: acc?.broker,
      ));
    }
  }
  allDividends.sort((a, b) => b.date.compareTo(a.date));
  return allDividends;
});

// 최근 10건 (allDividendsProvider 기반)
final recentDividendsProvider = FutureProvider<List<Dividend>>((ref) async {
  final all = await ref.watch(allDividendsProvider.future);
  return all.take(10).toList();
});

final exchangeRateProvider = FutureProvider<double>((ref) async {
  return ref.watch(apiServiceProvider).getExchangeRate();
});

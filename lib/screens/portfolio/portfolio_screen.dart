import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_theme.dart';
import '../../models/account.dart';
import '../../models/asset.dart';
import '../../providers/account_provider.dart';
import '../../providers/asset_provider.dart';
import '../../providers/dividend_provider.dart';
import '../../providers/price_provider.dart';
import '../../widgets/error_retry.dart';
import 'add_asset_sheet.dart';
import 'asset_detail_sheet.dart';

bool _isKoreanTicker(String ticker) =>
    ticker.endsWith('.KS') || ticker.endsWith('.KQ');

class PortfolioScreen extends ConsumerStatefulWidget {
  const PortfolioScreen({super.key});

  @override
  ConsumerState<PortfolioScreen> createState() => _PortfolioScreenState();
}

class _PortfolioScreenState extends ConsumerState<PortfolioScreen>
    with SingleTickerProviderStateMixin {
  TabController? _tabController;
  List<Account> _accounts = [];

  @override
  void dispose() {
    _tabController?.dispose();
    super.dispose();
  }

  void _initTabs(List<Account> accounts) {
    if (_accounts.length != accounts.length) {
      _tabController?.dispose();
      _tabController = TabController(length: accounts.length + 1, vsync: this);
      _accounts = accounts;
    }
  }

  @override
  Widget build(BuildContext context) {
    final accountsAsync = ref.watch(accountsProvider);
    final assetsAsync = ref.watch(assetsProvider);

    return accountsAsync.when(
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(
        appBar: AppBar(title: const Text('Portfolio')),
        body: ErrorRetry(
          message: e.toString(),
          onRetry: () => ref.invalidate(accountsProvider),
        ),
      ),
      data: (accounts) {
        _initTabs(accounts);
        return Scaffold(
          appBar: AppBar(
            title: const Text('Portfolio'),
            bottom: TabBar(
              controller: _tabController,
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              labelColor: AppColors.primary,
              unselectedLabelColor: AppColors.textSecondary,
              indicatorColor: AppColors.primary,
              tabs: [
                const Tab(text: '전체'),
                ...accounts.map((a) => Tab(text: a.name)),
              ],
            ),
          ),
          body: RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(accountsProvider);
              ref.invalidate(assetsProvider);
            },
            child: assetsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => ErrorRetry(
                message: e.toString(),
                onRetry: () => ref.invalidate(assetsProvider),
              ),
              data: (assets) => TabBarView(
                controller: _tabController,
                children: [
                  _AssetList(assets: assets, accountId: null),
                  ...accounts.map((a) => _AssetList(assets: assets, accountId: a.id)),
                ],
              ),
            ),
          ),
          floatingActionButton: FloatingActionButton(
            onPressed: () => showAddAssetSheet(context),
            child: const Icon(Icons.add),
          ),
        );
      },
    );
  }
}

class _AssetList extends ConsumerWidget {
  final List<Asset> assets;
  final int? accountId;

  const _AssetList({required this.assets, required this.accountId});

  double _qty(Asset asset) {
    final holdings = accountId == null
        ? asset.holdings
        : asset.holdings.where((h) => h.accountId == accountId).toList();
    return holdings.isEmpty
        ? asset.totalQuantity
        : holdings.fold<double>(0, (s, h) => s + h.quantity);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filtered = accountId == null
        ? assets
        : assets.where((a) => a.holdings.any((h) => h.accountId == accountId)).toList();

    if (filtered.isEmpty) {
      return const Center(
        child: Text('보유 자산이 없습니다',
            style: TextStyle(color: AppColors.textSecondary)),
      );
    }

    final showKrw = ref.watch(portfolioCurrencyProvider);
    final exchangeRate = ref.watch(exchangeRateProvider).valueOrNull ?? 1300.0;

    // 캐시된 현재가로 합산 (로딩 완료된 것만)
    double totalKrw = 0;
    double totalUsd = 0;
    for (final asset in filtered) {
      final price = ref.watch(tickerPricesProvider(asset.ticker)).valueOrNull;
      if (price != null) {
        final value = _qty(asset) * price.price;
        if (price.currency == 'KRW') {
          totalKrw += value;
        } else {
          totalUsd += value;
        }
      }
    }

    final displayTotal = showKrw
        ? totalKrw + totalUsd * exchangeRate
        : totalKrw / exchangeRate + totalUsd;
    final totalText = showKrw
        ? '₩${NumberFormat('#,###').format(displayTotal.round())}'
        : '\$${NumberFormat('#,##0.00').format(displayTotal)}';

    return Column(
      children: [
        // 합계 헤더
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          color: AppColors.surface,
          child: Row(
            children: [
              Text('총 ${filtered.length}종목',
                  style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w500,
                      fontSize: 13)),
              const Spacer(),
              Text('평가 $totalText',
                  style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w700,
                      fontSize: 14)),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () => ref.read(portfolioCurrencyProvider.notifier).state = !showKrw,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.primaryDim,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    showKrw ? 'KRW' : 'USD',
                    style: const TextStyle(
                        color: AppColors.primary,
                        fontSize: 11,
                        fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: filtered.length,
            separatorBuilder: (_, p1) => const SizedBox(height: 8),
            itemBuilder: (_, i) => _AssetCard(
              asset: filtered[i],
              quantity: _qty(filtered[i]),
            ),
          ),
        ),
      ],
    );
  }
}

class _AssetCard extends ConsumerWidget {
  final Asset asset;
  final double quantity;

  const _AssetCard({
    required this.asset,
    required this.quantity,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final priceAsync = ref.watch(tickerPricesProvider(asset.ticker));

    return GestureDetector(
      onLongPress: () => showAssetDetailSheet(context, asset),
      child: Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: AppColors.primaryDim,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Center(
              child: Text(
                _isKoreanTicker(asset.ticker)
                    ? asset.name.substring(0, asset.name.length > 3 ? 3 : asset.name.length)
                    : (asset.ticker.length > 4 ? asset.ticker.substring(0, 4) : asset.ticker),
                style: const TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w700,
                  fontSize: 11,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _isKoreanTicker(asset.ticker)
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(asset.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                            color: AppColors.textPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                      Text(asset.ticker,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          )),
                    ],
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(asset.ticker,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                            color: AppColors.textPrimary,
                          )),
                      Text(asset.name,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                    ],
                  ),
          ),
          priceAsync.when(
            loading: () => const SizedBox(
              width: 80,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  SizedBox(
                    width: 60, height: 14,
                    child: LinearProgressIndicator(
                      backgroundColor: AppColors.border,
                      color: AppColors.primary,
                    ),
                  ),
                  SizedBox(height: 4),
                  SizedBox(
                    width: 40, height: 11,
                    child: LinearProgressIndicator(
                      backgroundColor: AppColors.border,
                      color: AppColors.primaryDim,
                    ),
                  ),
                ],
              ),
            ),
            error: (_, p1) => _PriceColumn(
              evalValue: null,
              currentPrice: null,
              changePercent: null,
              quantity: quantity,
            ),
            data: (price) => _PriceColumn(
              evalValue: price != null ? quantity * price.price : null,
              currentPrice: price?.price,
              changePercent: price?.changePercent,
              currency: price?.currency ?? 'USD',
              quantity: quantity,
            ),
          ),
        ],
      ),
    ));
  }
}

class _PriceColumn extends StatelessWidget {
  final double? evalValue;
  final double? currentPrice;
  final double? changePercent;
  final String currency;
  final double quantity;

  const _PriceColumn({
    required this.evalValue,
    required this.currentPrice,
    required this.changePercent,
    this.currency = 'USD',
    required this.quantity,
  });

  String _formatAmount(double value) {
    if (currency == 'KRW') {
      return '₩${NumberFormat('#,###').format(value.round())}';
    }
    return '\$${NumberFormat('#,##0.00').format(value)}';
  }

  @override
  Widget build(BuildContext context) {
    final qtyFmt = NumberFormat('#,##0.####');
    final isPositive = (changePercent ?? 0) >= 0;
    final changeColor = changePercent == null
        ? AppColors.textSecondary
        : isPositive
            ? AppColors.positive
            : Colors.red;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          evalValue != null ? _formatAmount(evalValue!) : '-',
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 14,
            color: AppColors.textPrimary,
          ),
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '${qtyFmt.format(quantity)}주',
              style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
            ),
            if (changePercent != null) ...[
              const SizedBox(width: 4),
              Text(
                '${isPositive ? '+' : ''}${changePercent!.toStringAsFixed(2)}%',
                style: TextStyle(fontSize: 11, color: changeColor),
              ),
            ],
          ],
        ),
        if (currentPrice != null)
          Text(
            _formatAmount(currentPrice!),
            style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
          ),
      ],
    );
  }
}

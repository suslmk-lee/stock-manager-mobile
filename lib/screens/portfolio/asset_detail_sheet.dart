import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/fx.dart';
import '../../core/theme/app_theme.dart';
import '../../models/asset.dart';
import '../../providers/account_provider.dart';
import '../../providers/asset_provider.dart';
import '../../providers/price_provider.dart';
import '../../services/api_service.dart';

void showAssetDetailSheet(BuildContext context, Asset asset) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => AssetDetailSheet(asset: asset),
  );
}

class AssetDetailSheet extends ConsumerWidget {
  final Asset asset;

  const AssetDetailSheet({super.key, required this.asset});

  bool get _isKorean =>
      asset.ticker.endsWith('.KS') || asset.ticker.endsWith('.KQ');

  void _showDeleteConfirmDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.colors.surface,
        title: Text(
          '자산 삭제',
          style: TextStyle(
            color: context.colors.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
        content: Text(
          "'${asset.name}' 자산을 삭제하시겠습니까?\n\n보유 내역, 거래 기록, 배당 기록이 있는 경우 삭제할 수 없습니다.",
          style: TextStyle(
            color: context.colors.textSecondary,
            fontSize: 14,
            height: 1.5,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              '취소',
              style: TextStyle(color: context.colors.textSecondary),
            ),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await ref.read(apiServiceProvider).deleteAsset(asset.id);
                ref.invalidate(assetsProvider);
                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('자산이 삭제되었습니다.')),
                  );
                }
              } on DioException catch (e) {
                if (context.mounted) {
                  final msg = e.response?.data is Map
                      ? (e.response!.data['error'] ?? '삭제 실패')
                      : '삭제 실패';
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(msg),
                      backgroundColor: context.colors.negative,
                    ),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('삭제 실패: $e'),
                      backgroundColor: context.colors.negative,
                    ),
                  );
                }
              }
            },
            style: FilledButton.styleFrom(
              backgroundColor: context.colors.negative,
            ),
            child: const Text('삭제'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accountsAsync = ref.watch(accountsProvider);
    final priceAsync = ref.watch(tickerPricesProvider(asset.ticker));

    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      builder: (_, controller) => Container(
        decoration: BoxDecoration(
          color: context.colors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            // 핸들
            Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: context.colors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // 자산 헤더
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: context.colors.primaryDim,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Center(
                      child: Text(
                        _isKorean
                            ? asset.name.substring(0, asset.name.length > 3 ? 3 : asset.name.length)
                            : (asset.ticker.length > 4 ? asset.ticker.substring(0, 4) : asset.ticker),
                        style: TextStyle(
                          color: context.colors.primary,
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _isKorean ? asset.name : asset.ticker,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: context.colors.textPrimary,
                          ),
                        ),
                        Text(
                          _isKorean ? asset.ticker : asset.name,
                          style: TextStyle(
                            fontSize: 13,
                            color: context.colors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // 현재가
                  priceAsync.when(
                    loading: () => const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    error: (_, p1) => const SizedBox.shrink(),
                    data: (price) => price == null
                        ? const SizedBox.shrink()
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                formatCurrency(price.price, price.currency),
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: context.colors.textPrimary,
                                ),
                              ),
                              Text(
                                '${price.changePercent >= 0 ? '+' : ''}${price.changePercent.toStringAsFixed(2)}%',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: price.changePercent >= 0
                                      ? context.colors.positive
                                      : context.colors.negative,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                  ),
                  const SizedBox(width: 4),
                  IconButton(
                    icon: Icon(Icons.delete_outline,
                        color: context.colors.negative, size: 22),
                    tooltip: '자산 삭제',
                    onPressed: () =>
                        _showDeleteConfirmDialog(context, ref),
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: context.colors.border),
            // 보유 현황 목록
            Expanded(
              child: accountsAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('오류: $e')),
                data: (accounts) {
                  final accountMap = {for (final a in accounts) a.id: a};
                  return ListView(
                    controller: controller,
                    padding: const EdgeInsets.all(16),
                    children: [
                      Text(
                        '계좌별 보유 현황',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: context.colors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 12),
                      ...asset.holdings.map((holding) {
                        final account = accountMap[holding.accountId];
                        return _HoldingRow(
                          holding: holding,
                          ticker: asset.ticker,
                          accountName: account?.name ?? '계좌 #${holding.accountId}',
                          broker: account?.broker ?? '',
                          isKorean: _isKorean,
                          onUpdated: () {
                            ref.invalidate(assetsProvider);
                            Navigator.pop(context);
                          },
                        );
                      }),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HoldingRow extends ConsumerWidget {
  final Holding holding;
  final String ticker;
  final String accountName;
  final String broker;
  final bool isKorean;
  final VoidCallback onUpdated;

  const _HoldingRow({
    required this.holding,
    required this.ticker,
    required this.accountName,
    required this.broker,
    required this.isKorean,
    required this.onUpdated,
  });

  // 종목 통화 그대로 (엔화·유로 종목도 $ 로 보이지 않게)
  String _formatValue(double value, String currency) =>
      formatCurrency(value, currency);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final priceAsync = ref.watch(tickerPricesProvider(ticker));

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.colors.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.colors.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  accountName,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: context.colors.textPrimary,
                  ),
                ),
                if (broker.isNotEmpty)
                  Text(
                    broker,
                    style: TextStyle(
                      fontSize: 12,
                      color: context.colors.textSecondary,
                    ),
                  ),
                const SizedBox(height: 4),
                Text(
                  '${NumberFormat('#,##0.####').format(holding.quantity)}주',
                  style: TextStyle(
                    fontSize: 13,
                    color: context.colors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          // 평가금액
          priceAsync.when(
            loading: () => const SizedBox(
              width: 16, height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            error: (_, p1) => const SizedBox.shrink(),
            data: (price) => price == null
                ? const SizedBox.shrink()
                : Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: Text(
                      _formatValue(holding.quantity * price.price, price.currency),
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: context.colors.textPrimary,
                      ),
                    ),
                  ),
          ),
          IconButton(
            icon: Icon(Icons.edit_outlined,
                color: context.colors.primary, size: 20),
            onPressed: () => _showEditDialog(context, ref),
          ),
        ],
      ),
    );
  }

  void _showEditDialog(BuildContext context, WidgetRef ref) {
    final qtyController =
        TextEditingController(text: holding.quantity.toString());
    final avgController =
        TextEditingController(text: holding.averagePrice == 0 ? '' : holding.averagePrice.toString());

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(accountName),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: qtyController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))],
              decoration: const InputDecoration(
                labelText: '수량 (주)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: avgController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))],
              decoration: InputDecoration(
                labelText: '평균단가 (${currencySymbol(currencyOfTicker(ticker))})',
                border: const OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () async {
              final qty = double.tryParse(qtyController.text);
              final avg = double.tryParse(avgController.text) ?? 0;
              if (qty == null || qty <= 0) return;

              try {
                await ref.read(apiServiceProvider).updateHolding(
                  holding.id,
                  {'quantity': qty, 'averagePrice': avg},
                );
                if (ctx.mounted) Navigator.pop(ctx);
                onUpdated();
              } catch (e) {
                if (ctx.mounted) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    SnackBar(content: Text('저장 실패: $e')),
                  );
                }
              }
            },
            style: FilledButton.styleFrom(backgroundColor: context.colors.primary),
            child: const Text('저장'),
          ),
        ],
      ),
    );
  }
}

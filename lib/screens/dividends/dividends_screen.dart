import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import '../../core/theme/app_theme.dart';
import '../../models/dividend.dart';
import '../../providers/dividend_provider.dart';
import '../../services/api_service.dart';
import 'add_dividend_sheet.dart';

// true: KRW, false: USD (기본 KRW)
final accountDividendCurrencyKrwProvider = StateProvider<bool>((ref) => true);

class DividendsScreen extends ConsumerStatefulWidget {
  const DividendsScreen({super.key});

  @override
  ConsumerState<DividendsScreen> createState() => _DividendsScreenState();
}

class _DividendsScreenState extends ConsumerState<DividendsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  int _currentTab = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() => _currentTab = _tabController.index);
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dividends'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: '내역'),
            Tab(text: '분석'),
          ],
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textSecondary,
          indicatorColor: AppColors.primary,
          indicatorSize: TabBarIndicatorSize.label,
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [_HistoryTab(), _AnalysisTab()],
      ),
      floatingActionButton: _currentTab == 0
          ? FloatingActionButton(
              onPressed: () => showAddDividendSheet(context),
              child: const Icon(Icons.add),
            )
          : null,
    );
  }
}

// ─── History Tab ────────────────────────────────────────────────────────────

class _HistoryTab extends ConsumerStatefulWidget {
  const _HistoryTab();

  @override
  ConsumerState<_HistoryTab> createState() => _HistoryTabState();
}

class _HistoryTabState extends ConsumerState<_HistoryTab> {
  int? _selectedAccountId;
  final Set<int> _collapsedAccountIds = <int>{};

  @override
  Widget build(BuildContext context) {
    final allAsync = ref.watch(allDividendsProvider);

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(dividendStatsProvider);
        ref.invalidate(allDividendsProvider);
        ref.invalidate(recentDividendsProvider);
        ref.invalidate(monthlyDividendsProvider);
      },
      child: Column(
        children: [
          // 요약 카드
          allAsync.when(
            loading: () => const SizedBox(
              height: 80,
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (_, __) => const SizedBox.shrink(),
            data: (dividends) {
              final validSelectedAccountId =
                  dividends.any((d) => d.accountId == _selectedAccountId)
                  ? _selectedAccountId
                  : null;
              final summaryDividends = validSelectedAccountId == null
                  ? dividends
                  : dividends
                        .where((d) => d.accountId == validSelectedAccountId)
                        .toList();
              final totalUsd = summaryDividends
                  .where((d) => d.currency == 'USD')
                  .fold(0.0, (sum, d) => sum + d.amount);
              final totalKrw = summaryDividends
                  .where((d) => d.currency == 'KRW')
                  .fold(0.0, (sum, d) => sum + d.amount);

              return Container(
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.primaryDim, width: 1),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: _SummaryItem(
                        label: 'USD 배당',
                        value: '\$${NumberFormat('#,##0.00').format(totalUsd)}',
                        color: AppColors.primary,
                      ),
                    ),
                    Container(width: 1, height: 40, color: AppColors.border),
                    Expanded(
                      child: _SummaryItem(
                        label: 'KRW 배당',
                        value:
                            '₩${NumberFormat('#,###').format(totalKrw.round())}',
                        color: AppColors.positive,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          // 목록
          Expanded(
            child: allAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('오류: $e')),
              data: (dividends) {
                if (dividends.isEmpty) {
                  return const Center(
                    child: Text(
                      '배당금 내역이 없습니다',
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                  );
                }

                final accountOptions = <_AccountFilterOption>[];
                final accountIdSet = <int>{};
                for (final d in dividends) {
                  if (accountIdSet.contains(d.accountId)) continue;
                  accountIdSet.add(d.accountId);

                  final accountName = (d.accountName ?? '').trim();
                  final broker = (d.accountBroker ?? '').trim();
                  String label = accountName.isNotEmpty
                      ? accountName
                      : '계좌 ${d.accountId}';
                  if (broker.isNotEmpty &&
                      !label.toLowerCase().contains(broker.toLowerCase())) {
                    label = '$broker · $label';
                  }
                  accountOptions.add(
                    _AccountFilterOption(id: d.accountId, label: label),
                  );
                }
                accountOptions.sort((a, b) => a.label.compareTo(b.label));

                final selectedAccountId =
                    accountIdSet.contains(_selectedAccountId)
                    ? _selectedAccountId
                    : null;
                if (selectedAccountId != _selectedAccountId) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted) setState(() => _selectedAccountId = null);
                  });
                }

                final filteredDividends = selectedAccountId == null
                    ? dividends
                    : dividends
                          .where((d) => d.accountId == selectedAccountId)
                          .toList();
                final groupedDividends = accountOptions
                    .map((option) {
                      final items = dividends
                          .where((d) => d.accountId == option.id)
                          .toList();
                      return _AccountDividendGroup(
                        id: option.id,
                        label: option.label,
                        items: items,
                      );
                    })
                    .where((group) => group.items.isNotEmpty)
                    .toList();

                Future<void> deleteDividend(Dividend dividend) async {
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (dialogContext) => AlertDialog(
                      title: const Text('배당금 삭제'),
                      content: Text(
                        '${dividend.ticker ?? '종목'} ${NumberFormat('###,##0.00').format(dividend.amount)} 삭제할까요?',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(dialogContext, false),
                          child: const Text('취소'),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(dialogContext, true),
                          child: const Text(
                            '삭제',
                            style: TextStyle(color: AppColors.negative),
                          ),
                        ),
                      ],
                    ),
                  );

                  if (confirm != true) return;
                  try {
                    await ref
                        .read(apiServiceProvider)
                        .deleteDividend(dividend.id);
                    ref.invalidate(dividendStatsProvider);
                    ref.invalidate(allDividendsProvider);
                    ref.invalidate(recentDividendsProvider);
                    ref.invalidate(monthlyDividendsProvider);
                    if (context.mounted) {
                      ScaffoldMessenger.of(
                        context,
                      ).showSnackBar(const SnackBar(content: Text('삭제되었습니다')));
                    }
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('삭제 실패: $e'),
                          backgroundColor: AppColors.negative,
                        ),
                      );
                    }
                  }
                }

                return Column(
                  children: [
                    SizedBox(
                      height: 42,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        children: [
                          _AccountFilterChip(
                            label: '전체',
                            selected: selectedAccountId == null,
                            onTap: () =>
                                setState(() => _selectedAccountId = null),
                          ),
                          ...accountOptions.map(
                            (option) => Padding(
                              padding: const EdgeInsets.only(left: 8),
                              child: _AccountFilterChip(
                                label: option.label,
                                selected: selectedAccountId == option.id,
                                onTap: () => setState(
                                  () => _selectedAccountId = option.id,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 6),
                    Expanded(
                      child: selectedAccountId == null
                          ? ListView.separated(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                              ),
                              itemCount: groupedDividends.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(height: 8),
                              itemBuilder: (_, i) {
                                final group = groupedDividends[i];
                                final collapsed = _collapsedAccountIds.contains(
                                  group.id,
                                );
                                return Container(
                                  decoration: BoxDecoration(
                                    color: AppColors.surface,
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(
                                      color: AppColors.cardBorder,
                                    ),
                                  ),
                                  child: Column(
                                    children: [
                                      _AccountGroupHeader(
                                        label: group.label,
                                        count: group.items.length,
                                        collapsed: collapsed,
                                        onTap: () {
                                          setState(() {
                                            if (collapsed) {
                                              _collapsedAccountIds.remove(
                                                group.id,
                                              );
                                            } else {
                                              _collapsedAccountIds.add(
                                                group.id,
                                              );
                                            }
                                          });
                                        },
                                      ),
                                      if (!collapsed)
                                        ListView.separated(
                                          shrinkWrap: true,
                                          physics:
                                              const NeverScrollableScrollPhysics(),
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 2,
                                          ),
                                          itemCount: group.items.length,
                                          separatorBuilder: (_, __) =>
                                              const Divider(
                                                color: AppColors.cardBorder,
                                                height: 4,
                                                thickness: 1,
                                              ),
                                          itemBuilder: (_, j) => _DividendItem(
                                            dividend: group.items[j],
                                            onEdit: () => showAddDividendSheet(
                                              context,
                                              dividend: group.items[j],
                                            ),
                                            onDelete: () =>
                                                deleteDividend(group.items[j]),
                                          ),
                                        ),
                                    ],
                                  ),
                                );
                              },
                            )
                          : filteredDividends.isEmpty
                          ? const Center(
                              child: Text(
                                '선택한 계좌의 배당 내역이 없습니다',
                                style: TextStyle(
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            )
                          : ListView.separated(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                              ),
                              itemCount: filteredDividends.length,
                              separatorBuilder: (_, __) => const Divider(
                                color: AppColors.cardBorder,
                                height: 4,
                                thickness: 1,
                              ),
                              itemBuilder: (_, i) => _DividendItem(
                                dividend: filteredDividends[i],
                                onEdit: () => showAddDividendSheet(
                                  context,
                                  dividend: filteredDividends[i],
                                ),
                                onDelete: () =>
                                    deleteDividend(filteredDividends[i]),
                              ),
                            ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _AccountFilterOption {
  final int id;
  final String label;
  const _AccountFilterOption({required this.id, required this.label});
}

class _AccountDividendGroup {
  final int id;
  final String label;
  final List<Dividend> items;

  const _AccountDividendGroup({
    required this.id,
    required this.label,
    required this.items,
  });
}

class _AccountFilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _AccountFilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: selected ? AppColors.primaryDim : AppColors.surfaceHigh,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: selected ? AppColors.primary : AppColors.cardBorder,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? AppColors.primary : AppColors.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}

class _AccountGroupHeader extends StatelessWidget {
  final String label;
  final int count;
  final bool collapsed;
  final VoidCallback onTap;

  const _AccountGroupHeader({
    required this.label,
    required this.count,
    required this.collapsed,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Text(
              '${count}건',
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              collapsed
                  ? Icons.keyboard_arrow_down_rounded
                  : Icons.keyboard_arrow_up_rounded,
              color: AppColors.textSecondary,
              size: 18,
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Analysis Tab ────────────────────────────────────────────────────────────

class _AssetStat {
  final String name;
  final String ticker;
  double usdTotal = 0;
  double krwTotal = 0;
  _AssetStat({required this.name, required this.ticker});
  double totalKrw(double rate) => usdTotal * rate + krwTotal;
  String get displayName {
    final truncated = name.length > 14 ? '${name.substring(0, 14)}…' : name;
    return ticker.isNotEmpty ? '$truncated ($ticker)' : truncated;
  }
}

class _AccountStat {
  final String name;
  double usdTotal = 0;
  double krwTotal = 0;
  _AccountStat({required this.name});
  double totalKrw(double rate) => usdTotal * rate + krwTotal;
}

class _YearStat {
  double usdTotal = 0;
  double krwTotal = 0;
}

class _AnalysisTab extends ConsumerWidget {
  const _AnalysisTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final allAsync = ref.watch(allDividendsProvider);
    final rateAsync = ref.watch(exchangeRateProvider);
    final showKrw = ref.watch(accountDividendCurrencyKrwProvider);

    return allAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('오류: $e')),
      data: (dividends) {
        final rate = rateAsync.valueOrNull ?? 1300.0;

        if (dividends.isEmpty) {
          return const Center(
            child: Text(
              '분석할 배당 데이터가 없습니다',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          );
        }

        // 종목별 집계
        final byAsset = <int, _AssetStat>{};
        for (final d in dividends) {
          final stat = byAsset.putIfAbsent(
            d.assetId,
            () => _AssetStat(
              name: d.assetName ?? 'Unknown',
              ticker: d.ticker ?? '',
            ),
          );
          if (d.currency == 'KRW') {
            stat.krwTotal += d.amount;
          } else {
            stat.usdTotal += d.amount;
          }
        }
        final sortedAssets = byAsset.values.toList()
          ..sort((a, b) => b.totalKrw(rate).compareTo(a.totalKrw(rate)));
        final topAssets = sortedAssets.take(5).toList();
        final maxAssetKrw = topAssets.isNotEmpty
            ? topAssets.first.totalKrw(rate)
            : 1.0;

        // 계좌별 집계
        final byAccount = <int, _AccountStat>{};
        for (final d in dividends) {
          final stat = byAccount.putIfAbsent(
            d.accountId,
            () => _AccountStat(name: d.accountName ?? 'Unknown'),
          );
          if (d.currency == 'KRW') {
            stat.krwTotal += d.amount;
          } else {
            stat.usdTotal += d.amount;
          }
        }
        final sortedAccounts = byAccount.values.toList()
          ..sort((a, b) => b.totalKrw(rate).compareTo(a.totalKrw(rate)));
        final maxAccountKrw = sortedAccounts.isNotEmpty
            ? sortedAccounts.first.totalKrw(rate)
            : 1.0;

        // 연도별 집계
        final byYear = <String, _YearStat>{};
        for (final d in dividends) {
          final year = d.date.length >= 4 ? d.date.substring(0, 4) : 'Unknown';
          final stat = byYear.putIfAbsent(year, () => _YearStat());
          if (d.currency == 'KRW') {
            stat.krwTotal += d.amount;
          } else {
            stat.usdTotal += d.amount;
          }
        }
        final sortedYears = byYear.entries.toList()
          ..sort((a, b) => b.key.compareTo(a.key));

        return RefreshIndicator(
          onRefresh: () async => ref.invalidate(allDividendsProvider),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
            children: [
              _AnalysisFilterBar(
                showKrw: showKrw,
                onChanged: (value) =>
                    ref
                            .read(accountDividendCurrencyKrwProvider.notifier)
                            .state =
                        value,
              ),
              const SizedBox(height: 12),
              // 종목별 TOP 5
              const _SectionHeader('종목별 배당 TOP 5', Icons.bar_chart_rounded),
              _StatCard(
                children: [
                  for (int i = 0; i < topAssets.length; i++)
                    _StatBarRow(
                      rank: i + 1,
                      title: topAssets[i].displayName,
                      subtitle: _fmtUnifiedAmount(
                        usd: topAssets[i].usdTotal,
                        krw: topAssets[i].krwTotal,
                        rate: rate,
                        showKrw: showKrw,
                      ),
                      progress: maxAssetKrw > 0
                          ? topAssets[i].totalKrw(rate) / maxAssetKrw
                          : 0,
                      isLast: i == topAssets.length - 1,
                    ),
                ],
              ),
              const SizedBox(height: 20),

              // 계좌별
              const _SectionHeader('계좌별 배당', Icons.account_balance_rounded),
              _StatCard(
                children: [
                  for (int i = 0; i < sortedAccounts.length; i++)
                    _StatBarRow(
                      rank: i + 1,
                      title: sortedAccounts[i].name,
                      subtitle: _fmtUnifiedAmount(
                        usd: sortedAccounts[i].usdTotal,
                        krw: sortedAccounts[i].krwTotal,
                        rate: rate,
                        showKrw: showKrw,
                      ),
                      progress: maxAccountKrw > 0
                          ? sortedAccounts[i].totalKrw(rate) / maxAccountKrw
                          : 0,
                      isLast: i == sortedAccounts.length - 1,
                    ),
                ],
              ),
              const SizedBox(height: 20),

              // 연도별
              const _SectionHeader('연도별 배당', Icons.calendar_today_rounded),
              ...sortedYears.map(
                (e) => _YearRow(
                  year: e.key,
                  stat: e.value,
                  rate: rate,
                  showKrw: showKrw,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  static String _fmtUnifiedAmount({
    required double usd,
    required double krw,
    required double rate,
    required bool showKrw,
  }) {
    if (showKrw) {
      final totalKrw = krw + (usd * rate);
      return '₩${NumberFormat('#,###').format(totalKrw.round())}';
    }
    final totalUsd = usd + (rate > 0 ? krw / rate : 0);
    return '\$${NumberFormat('#,##0.00').format(totalUsd)}';
  }
}

// ─── Analysis Widgets ────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget? trailing;
  const _SectionHeader(this.title, this.icon, {this.trailing});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, color: AppColors.primary, size: 18),
          const SizedBox(width: 8),
          Text(
            title,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (trailing != null) ...[const Spacer(), trailing!],
        ],
      ),
    );
  }
}

class _AnalysisFilterBar extends StatelessWidget {
  final bool showKrw;
  final ValueChanged<bool> onChanged;

  const _AnalysisFilterBar({required this.showKrw, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.tune_rounded,
            size: 16,
            color: AppColors.textSecondary,
          ),
          const SizedBox(width: 8),
          const Text(
            '통화 표시',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const Spacer(),
          _CurrencyToggle(showKrw: showKrw, onChanged: onChanged),
        ],
      ),
    );
  }
}

class _CurrencyToggle extends StatelessWidget {
  final bool showKrw;
  final ValueChanged<bool> onChanged;

  const _CurrencyToggle({required this.showKrw, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceHigh,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _CurrencyChip(
            label: 'KRW',
            selected: showKrw,
            onTap: () => onChanged(true),
          ),
          _CurrencyChip(
            label: 'USD',
            selected: !showKrw,
            onTap: () => onChanged(false),
          ),
        ],
      ),
    );
  }
}

class _CurrencyChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _CurrencyChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: selected ? AppColors.primaryDim : Colors.transparent,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected ? AppColors.primary : Colors.transparent,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: selected ? AppColors.primary : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final List<Widget> children;
  const _StatCard({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(children: children),
    );
  }
}

class _StatBarRow extends StatelessWidget {
  final int rank;
  final String title;
  final String subtitle;
  final double progress;
  final bool isLast;

  const _StatBarRow({
    required this.rank,
    required this.title,
    required this.subtitle,
    required this.progress,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    final isTop = rank == 1;
    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: isTop ? AppColors.primary : AppColors.surfaceHigh,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Center(
                  child: Text(
                    '$rank',
                    style: TextStyle(
                      color: isTop ? Colors.black : AppColors.textSecondary,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                subtitle,
                style: const TextStyle(
                  color: AppColors.primary,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: progress.clamp(0.0, 1.0),
              backgroundColor: AppColors.border,
              valueColor: const AlwaysStoppedAnimation(AppColors.primary),
              minHeight: 3,
            ),
          ),
        ],
      ),
    );
  }
}

class _YearRow extends StatelessWidget {
  final String year;
  final _YearStat stat;
  final double rate;
  final bool showKrw;
  const _YearRow({
    required this.year,
    required this.stat,
    required this.rate,
    required this.showKrw,
  });

  String _fmtUnifiedAmount() {
    if (showKrw) {
      final totalKrw = stat.krwTotal + (stat.usdTotal * rate);
      return '₩${NumberFormat('#,###').format(totalKrw.round())}';
    }
    final totalUsd = stat.usdTotal + (rate > 0 ? stat.krwTotal / rate : 0);
    return '\$${NumberFormat('#,##0.00').format(totalUsd)}';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Text(
            '$year년',
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
          const Spacer(),
          Text(
            _fmtUnifiedAmount(),
            style: const TextStyle(
              color: AppColors.primary,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Existing Widgets ────────────────────────────────────────────────────────

class _SummaryItem extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _SummaryItem({
    required this.label,
    required this.value,
    this.color = AppColors.primary,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
        ),
        const SizedBox(height: 6),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 15,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

class _DividendItem extends StatelessWidget {
  final Dividend dividend;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  const _DividendItem({
    required this.dividend,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final name = dividend.assetName ?? 'Unknown';
    final ticker = dividend.ticker ?? '';
    final fallbackTicker = ticker.trim().toUpperCase();
    final logoUrl =
        (dividend.logoUrl != null && dividend.logoUrl!.trim().isNotEmpty)
        ? dividend.logoUrl!.trim()
        : (fallbackTicker.isNotEmpty
              ? 'https://financialmodelingprep.com/image-stock/${Uri.encodeComponent(fallbackTicker)}.png'
              : null);
    String date = dividend.date;
    try {
      date = DateFormat('MMM dd, yyyy').format(DateTime.parse(dividend.date));
    } catch (_) {}

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: SizedBox(
        height: 88,
        child: Slidable(
          key: ValueKey('dividend-${dividend.id}'),
          endActionPane: ActionPane(
            motion: const DrawerMotion(),
            extentRatio: 0.45,
            children: [
              SlidableAction(
                onPressed: (_) => onEdit(),
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.background,
                icon: Icons.edit_outlined,
                label: '수정',
              ),
              SlidableAction(
                onPressed: (_) => onDelete(),
                backgroundColor: AppColors.negative,
                foregroundColor: Colors.white,
                icon: Icons.delete_outline,
                label: '삭제',
              ),
            ],
          ),
          child: Row(
            children: [
              _AssetLogoBadge(logoUrl: logoUrl, ticker: ticker, name: name),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      ticker.isNotEmpty ? '$name ($ticker)' : name,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      date,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    dividend.currency == 'KRW'
                        ? '+₩${NumberFormat('#,###').format(dividend.amount)}'
                        : '+\$${NumberFormat('#,##0.00').format(dividend.amount)}',
                    style: const TextStyle(
                      color: AppColors.positive,
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                  Text(
                    dividend.currency == 'KRW'
                        ? '-₩${NumberFormat('#,###').format(dividend.tax)} 세금'
                        : '-\$${NumberFormat('#,##0.00').format(dividend.tax)} 세금',
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AssetLogoBadge extends StatelessWidget {
  final String? logoUrl;
  final String ticker;
  final String name;

  const _AssetLogoBadge({
    required this.logoUrl,
    required this.ticker,
    required this.name,
  });

  @override
  Widget build(BuildContext context) {
    const badgeOuter = Color(0x332E3340);
    const badgeInner = Color(0xFF2B2F3A);
    const badgeBorder = Color(0xFF3B4150);

    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: badgeOuter,
        borderRadius: BorderRadius.circular(13),
      ),
      child: Center(
        child: Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: badgeInner,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: badgeBorder),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: logoUrl == null
                ? _LogoFallbackText(ticker: ticker, name: name)
                : Padding(
                    padding: const EdgeInsets.all(4),
                    child: Image.network(
                      logoUrl!,
                      fit: BoxFit.contain,
                      filterQuality: FilterQuality.medium,
                      loadingBuilder: (_, child, progress) {
                        if (progress == null) return child;
                        return _LogoFallbackText(ticker: ticker, name: name);
                      },
                      errorBuilder: (_, __, ___) =>
                          _LogoFallbackText(ticker: ticker, name: name),
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

class _LogoFallbackText extends StatelessWidget {
  final String ticker;
  final String name;

  const _LogoFallbackText({required this.ticker, required this.name});

  String _monogram() {
    String sanitize(String value) =>
        value.replaceAll(RegExp(r'[^A-Za-z0-9가-힣]'), '');

    final source = sanitize(ticker).isNotEmpty
        ? sanitize(ticker)
        : sanitize(name);
    if (source.isEmpty) return '•';
    final chars = source.runes.toList();
    if (chars.length == 1)
      return String.fromCharCode(chars.first).toUpperCase();
    return (String.fromCharCode(chars[0]) + String.fromCharCode(chars[1]))
        .toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        _monogram(),
        style: const TextStyle(
          color: Color(0xFFD1D5DB),
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

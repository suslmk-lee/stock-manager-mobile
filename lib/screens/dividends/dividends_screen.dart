import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_theme.dart';
import '../../models/dividend.dart';
import '../../providers/dividend_provider.dart';
import 'add_dividend_sheet.dart';

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
        children: const [
          _HistoryTab(),
          _AnalysisTab(),
        ],
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

class _HistoryTab extends ConsumerWidget {
  const _HistoryTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recentAsync = ref.watch(recentDividendsProvider);
    final statsAsync = ref.watch(dividendStatsProvider);

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(dividendStatsProvider);
        ref.invalidate(allDividendsProvider);
      },
      child: Column(
        children: [
          // 요약 카드
          statsAsync.when(
            loading: () => const SizedBox(
                height: 80, child: Center(child: CircularProgressIndicator())),
            error: (_, __) => const SizedBox.shrink(),
            data: (stats) => Container(
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
                      value:
                          '\$${NumberFormat('#,##0.00').format(stats.totalDividendsUsd)}',
                      color: AppColors.primary,
                    ),
                  ),
                  Container(width: 1, height: 40, color: AppColors.border),
                  Expanded(
                    child: _SummaryItem(
                      label: 'KRW 배당',
                      value:
                          '₩${NumberFormat('#,###').format(stats.totalDividendsKrw.round())}',
                      color: AppColors.positive,
                    ),
                  ),
                ],
              ),
            ),
          ),
          // 목록
          Expanded(
            child: recentAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('오류: $e')),
              data: (dividends) {
                if (dividends.isEmpty) {
                  return const Center(
                    child: Text('배당금 내역이 없습니다',
                        style: TextStyle(color: AppColors.textSecondary)),
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: dividends.length,
                  separatorBuilder: (_, __) =>
                      const Divider(color: AppColors.cardBorder),
                  itemBuilder: (_, i) =>
                      _DividendItem(dividend: dividends[i]),
                );
              },
            ),
          ),
        ],
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

    return allAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('오류: $e')),
      data: (dividends) {
        final rate = rateAsync.valueOrNull ?? 1300.0;

        if (dividends.isEmpty) {
          return const Center(
            child: Text('분석할 배당 데이터가 없습니다',
                style: TextStyle(color: AppColors.textSecondary)),
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
                  ));
          if (d.currency == 'KRW') {
            stat.krwTotal += d.amount;
          } else {
            stat.usdTotal += d.amount;
          }
        }
        final sortedAssets = byAsset.values.toList()
          ..sort((a, b) => b.totalKrw(rate).compareTo(a.totalKrw(rate)));
        final topAssets = sortedAssets.take(5).toList();
        final maxAssetKrw =
            topAssets.isNotEmpty ? topAssets.first.totalKrw(rate) : 1.0;

        // 계좌별 집계
        final byAccount = <int, _AccountStat>{};
        for (final d in dividends) {
          final stat = byAccount.putIfAbsent(
              d.accountId,
              () => _AccountStat(
                    name: d.accountName ?? 'Unknown',
                  ));
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
          final year =
              d.date.length >= 4 ? d.date.substring(0, 4) : 'Unknown';
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
              // 종목별 TOP 5
              const _SectionHeader('종목별 배당 TOP 5', Icons.bar_chart_rounded),
              _StatCard(
                children: [
                  for (int i = 0; i < topAssets.length; i++)
                    _StatBarRow(
                      rank: i + 1,
                      title: topAssets[i].displayName,
                      subtitle: _fmtAmount(
                          topAssets[i].usdTotal, topAssets[i].krwTotal),
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
                      subtitle: _fmtAmount(
                          sortedAccounts[i].usdTotal,
                          sortedAccounts[i].krwTotal),
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
              ...sortedYears
                  .map((e) => _YearRow(year: e.key, stat: e.value)),
            ],
          ),
        );
      },
    );
  }

  static String _fmtAmount(double usd, double krw) {
    final parts = <String>[];
    if (usd > 0) parts.add('\$${NumberFormat('#,##0.00').format(usd)}');
    if (krw > 0) parts.add('₩${NumberFormat('#,###').format(krw.round())}');
    return parts.join('  ');
  }
}

// ─── Analysis Widgets ────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String title;
  final IconData icon;
  const _SectionHeader(this.title, this.icon);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, color: AppColors.primary, size: 18),
          const SizedBox(width: 8),
          Text(title,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              )),
        ],
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
                      fontWeight: FontWeight.w600),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                subtitle,
                style: const TextStyle(
                    color: AppColors.primary,
                    fontSize: 12,
                    fontWeight: FontWeight.w700),
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
  const _YearRow({required this.year, required this.stat});

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
          Text('$year년',
              style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w700)),
          const Spacer(),
          if (stat.usdTotal > 0)
            Text(
              '\$${NumberFormat('#,##0.00').format(stat.usdTotal)}',
              style: const TextStyle(
                  color: AppColors.primary,
                  fontSize: 13,
                  fontWeight: FontWeight.w700),
            ),
          if (stat.usdTotal > 0 && stat.krwTotal > 0)
            const SizedBox(width: 12),
          if (stat.krwTotal > 0)
            Text(
              '₩${NumberFormat('#,###').format(stat.krwTotal.round())}',
              style: const TextStyle(
                  color: AppColors.positive,
                  fontSize: 13,
                  fontWeight: FontWeight.w700),
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
  const _SummaryItem(
      {required this.label, required this.value, this.color = AppColors.primary});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(label,
            style: const TextStyle(
                color: AppColors.textSecondary, fontSize: 11)),
        const SizedBox(height: 6),
        Text(value,
            style: TextStyle(
              color: color,
              fontSize: 15,
              fontWeight: FontWeight.w800,
            )),
      ],
    );
  }
}

class _DividendItem extends StatelessWidget {
  final Dividend dividend;
  const _DividendItem({required this.dividend});

  @override
  Widget build(BuildContext context) {
    final name = dividend.assetName ?? 'Unknown';
    final ticker = dividend.ticker ?? '';
    String date = dividend.date;
    try {
      date = DateFormat('MMM dd, yyyy').format(DateTime.parse(dividend.date));
    } catch (_) {}

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.primaryDim,
              borderRadius: BorderRadius.circular(13),
            ),
            child: const Icon(Icons.account_balance_rounded,
                color: AppColors.primary, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
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
                Text(date,
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.textSecondary)),
              ],
            ),
          ),
          Column(
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
                    fontSize: 11, color: AppColors.textSecondary),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

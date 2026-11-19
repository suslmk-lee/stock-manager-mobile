import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/format.dart';
import '../../core/theme/palette.dart';
import '../../core/theme/typography.dart';
import '../../models/dividend.dart';
import '../../providers/account_provider.dart';
import '../../providers/asset_provider.dart';
import '../../providers/dividend_provider.dart';
import '../../providers/portfolio_provider.dart';
import '../../providers/price_provider.dart';
import '../../widgets/ui/app_icon.dart';
import '../../widgets/ui/app_shell.dart';
import '../../widgets/ui/controls.dart';
import '../../widgets/ui/logos.dart';
import '../../widgets/ui/surfaces.dart';

/// 금액 표시: 원화 환산 값을 받아 지금 고른 통화(KRW/USD)로
String _money(double krw, bool showKrw, double rate) =>
    showKrw ? fmtKrw(krw) : fmtUsd(rate > 0 ? krw / rate : 0);

String _signedMoney(double krw, bool showKrw, double rate) => showKrw
    ? fmtSignedMoney(krw, 'KRW')
    : fmtSignedMoney(rate > 0 ? krw / rate : 0, 'USD');

class HomeScreen extends ConsumerWidget {
  final VoidCallback? onViewAllDividends;

  const HomeScreen({super.key, this.onViewAllDividends});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(dividendStatsProvider);
    final monthlyAsync = ref.watch(monthlyDividendsProvider);
    final recentAsync = ref.watch(recentDividendsProvider);
    final rate = ref.watch(exchangeRateProvider).valueOrNull;

    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      appBar: const AppTopBar(title: BrandTitle()),
      body: Builder(
        builder: (context) => RefreshIndicator(
          edgeOffset: MediaQuery.paddingOf(context).top,
          onRefresh: () async {
            ref.invalidate(assetsProvider);
            ref.invalidate(accountsProvider);
            ref.invalidate(allTickerPricesProvider);
            ref.invalidate(exchangeRateProvider);
            ref.invalidate(dividendStatsProvider);
            ref.invalidate(monthlyDividendsProvider);
            ref.invalidate(allDividendsProvider);
          },
          child: ListView(
            padding: listPadding(context, top: 16),
            children: [
              const _PortfolioHero(),
              const SizedBox(height: 14),
              statsAsync.when(
                loading: () => const _SkeletonCard(height: 250),
                error: (e, _) => _ErrorCard(message: e.toString()),
                data: (stats) => _DividendSummaryCard(
                  stats: stats,
                  monthly: monthlyAsync.valueOrNull ?? const [],
                  rate: rate,
                  onViewAll: onViewAllDividends,
                ),
              ),
              const SizedBox(height: 14),
              monthlyAsync.when(
                loading: () => const _SkeletonCard(height: 230),
                error: (_, _) => const SizedBox.shrink(),
                data: (monthly) =>
                    _MonthlyChartCard(monthly: monthly, rate: rate),
              ),
              const SizedBox(height: 14),
              recentAsync.when(
                loading: () => const _SkeletonCard(height: 220),
                error: (e, _) => _ErrorCard(message: e.toString()),
                data: (list) => _RecentDividendsCard(
                  dividends: list,
                  onViewAll: onViewAllDividends,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── 총 자산 평가액 (그레인 히어로) ──────────────────────────────
class _PortfolioHero extends ConsumerWidget {
  const _PortfolioHero();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.pal;
    final showKrw = ref.watch(homeCurrencyProvider);
    final snapshotAsync = ref.watch(portfolioProvider(null));
    final accounts = ref.watch(accountsProvider).valueOrNull;

    return HeroCard(
      child: snapshotAsync.when(
        loading: () => const _HeroPlaceholder(),
        error: (e, _) => Text(
          '보유 종목을 불러오지 못했습니다\n${_ErrorCard.display(e.toString())}',
          style: AppText.body(p, size: 13, color: p.rose.s300),
        ),
        data: (snap) {
          final t = snap.totals;
          final rate = snap.rate;
          final loading = snap.pricesLoading;
          final intlAccounts = accounts
              ?.where((a) => a.marketType == 'International')
              .length;
          final domesticAccounts = accounts == null
              ? null
              : accounts.length - intlAccounts!;
          final domesticPct = (t.domesticShare * 100).round();

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text('총 자산 평가액', style: AppText.label(p, color: p.zinc.s400)),
                  const SizedBox(width: 8),
                  MonoChip(
                    label: showKrw ? 'KRW 환산' : 'USD 환산',
                    onTap: () => ref.read(homeCurrencyProvider.notifier).state =
                        !showKrw,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (loading)
                const _Bar(width: 210, height: 34)
              else
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    _money(t.valueKrw, showKrw, rate),
                    style: AppText.bigNumber(p, size: 36),
                  ),
                ),
              const SizedBox(height: 10),
              Text(
                loading
                    ? '현재가를 불러오는 중…'
                    : '투자 원금 ${_money(t.costKrw, showKrw, rate)}',
                style: AppText.num(p, size: 13, color: p.zinc.s400),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _DeltaPanel(
                      label: '평가손익',
                      amount: loading
                          ? null
                          : _signedMoney(t.profitKrw, showKrw, rate),
                      pct: t.profitPct,
                      positive: t.profitKrw >= 0,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _DeltaPanel(
                      label: '오늘',
                      amount: loading
                          ? null
                          : _signedMoney(t.todayChangeKrw, showKrw, rate),
                      pct: t.todayPct,
                      positive: t.todayChangeKrw >= 0,
                    ),
                  ),
                ],
              ),
              if (!loading && t.valueKrw > 0) ...[
                const SizedBox(height: 16),
                ClipRRect(
                  borderRadius: BorderRadius.circular(99),
                  child: SizedBox(
                    height: 6,
                    child: Row(
                      children: [
                        if (t.domesticKrw > 0)
                          Expanded(
                            flex: (t.domesticShare * 1000).round().clamp(
                              1,
                              1000,
                            ),
                            child: ColoredBox(color: p.mint.s400),
                          ),
                        if (t.domesticKrw > 0 && t.overseasKrw > 0)
                          const SizedBox(width: 2),
                        if (t.overseasKrw > 0)
                          Expanded(
                            flex: ((1 - t.domesticShare) * 1000).round().clamp(
                              1,
                              1000,
                            ),
                            child: ColoredBox(
                              color: p.sky.s400.withValues(alpha: 0.7),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _Dot(color: p.mint.s400),
                    const SizedBox(width: 6),
                    Text(
                      '국내 $domesticPct%${domesticAccounts != null ? ' · $domesticAccounts계좌' : ''}',
                      style: AppText.label(p),
                    ),
                    const Spacer(),
                    Text(
                      '해외 ${100 - domesticPct}%${intlAccounts != null ? ' · $intlAccounts계좌' : ''}',
                      style: AppText.label(p),
                    ),
                    const SizedBox(width: 6),
                    _Dot(color: p.sky.s400),
                  ],
                ),
              ],
              if (!loading && t.pricedCount < t.assetCount) ...[
                const SizedBox(height: 10),
                Text(
                  '현재가 ${t.assetCount}종목 중 ${t.pricedCount}종목 반영',
                  style: AppText.label(p, color: p.amber.s300),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _DeltaPanel extends StatelessWidget {
  final String label;
  final String? amount;
  final double? pct;
  final bool positive;

  const _DeltaPanel({
    required this.label,
    required this.amount,
    required this.pct,
    required this.positive,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final color = positive ? p.mint.s300 : p.rose.s300;
    return InsetPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: AppText.label(p)),
          const SizedBox(height: 5),
          if (amount == null)
            const _Bar(width: 90, height: 16)
          else
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                amount!,
                style: AppText.num(p, size: 16, color: color),
              ),
            ),
          const SizedBox(height: 2),
          Text(
            amount == null || pct == null ? ' ' : fmtSignedPct(pct!),
            style: AppText.num(
              p,
              size: 11,
              color: color.withValues(alpha: 0.8),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroPlaceholder extends StatelessWidget {
  const _HeroPlaceholder();

  @override
  Widget build(BuildContext context) => const Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _Bar(width: 110, height: 12),
      SizedBox(height: 18),
      _Bar(width: 220, height: 34),
      SizedBox(height: 12),
      _Bar(width: 150, height: 12),
      SizedBox(height: 18),
      Row(
        children: [
          Expanded(child: _Bar(height: 70)),
          SizedBox(width: 8),
          Expanded(child: _Bar(height: 70)),
        ],
      ),
    ],
  );
}

// ── 누적 배당금 ──────────────────────────────────────────
class _DividendSummaryCard extends ConsumerWidget {
  final DividendStats stats;
  final List<MonthlyDividend> monthly;
  final double? rate;
  final VoidCallback? onViewAll;

  const _DividendSummaryCard({
    required this.stats,
    required this.monthly,
    required this.rate,
    this.onViewAll,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.pal;
    final showKrw = ref.watch(homeCurrencyProvider);
    final r = rate ?? fallbackUsdKrw;
    final totalKrw = stats.totalDividendsUsd * r + stats.totalDividendsKrw;

    final insights = _MonthlyInsights.from(monthly, r);

    return GestureDetector(
      onTap: () => ref.read(homeCurrencyProvider.notifier).state = !showKrw,
      child: GlassCard(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CardHeader(
              glyph: AppGlyph.coin,
              title: '누적 배당금',
              statLabel: true,
              trailing: TextLink(label: '배당 기록', onTap: onViewAll),
            ),
            const SizedBox(height: 12),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                _money(totalKrw, showKrw, r),
                style: AppText.bigNumber(p, size: 30),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              [
                'KRW ${fmtKrw(stats.totalDividendsKrw)}',
                'USD ${fmtUsd(stats.totalDividendsUsd)}',
                if (rate != null) '환율 ${fmtQty(rate!.round())}',
              ].join(' · '),
              style: AppText.label(p),
            ),
            if (insights != null) ...[
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _MiniStat(
                      label: '이번 달',
                      value: insights.thisMonthKrw == null
                          ? '—'
                          : _money(insights.thisMonthKrw!, showKrw, r),
                      badge: insights.momPct == null
                          ? null
                          : StatusBadge(
                              label:
                                  '${insights.momPct!.abs().toStringAsFixed(1)}%',
                              tone: insights.momPct! >= 0
                                  ? BadgeTone.mint
                                  : BadgeTone.rose,
                              icon: insights.momPct! >= 0
                                  ? Icons.keyboard_arrow_up_rounded
                                  : Icons.keyboard_arrow_down_rounded,
                            ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _MiniStat(
                      label: '월평균',
                      value: _money(insights.averageKrw, showKrw, r),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _MiniStat(
                      label: insights.lastMonthLabel == null
                          ? '지난달'
                          : '지난달 · ${insights.lastMonthLabel}',
                      value: insights.lastMonthKrw == null
                          ? '—'
                          : _money(insights.lastMonthKrw!, showKrw, r),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _MiniStat(
                      label: '최고 달 · ${insights.bestLabel}',
                      value: _money(insights.bestKrw, showKrw, r),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String label;
  final String value;
  final Widget? badge;

  const _MiniStat({required this.label, required this.value, this.badge});

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return InsetPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 20,
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    label,
                    style: AppText.label(p),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                ?badge,
              ],
            ),
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(value, style: AppText.num(p, size: 16)),
          ),
        ],
      ),
    );
  }
}

String _monthKey(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}';

/// 월별 배당 요약 (이번 달 · 월평균 · 지난달 · 최고 달). 금액은 원화 환산
class _MonthlyInsights {
  final double? thisMonthKrw;
  final double? lastMonthKrw;
  final String? lastMonthLabel;
  final double averageKrw;
  final double bestKrw;
  final String bestLabel;
  final double? momPct;

  const _MonthlyInsights({
    required this.thisMonthKrw,
    required this.lastMonthKrw,
    required this.lastMonthLabel,
    required this.averageKrw,
    required this.bestKrw,
    required this.bestLabel,
    required this.momPct,
  });

  static _MonthlyInsights? from(List<MonthlyDividend> monthly, double rate) {
    if (monthly.isEmpty) return null;
    double krw(MonthlyDividend m) => m.totalUsd * rate + m.totalKrw;
    final byMonth = {for (final m in monthly) m.month: krw(m)};
    final now = DateTime.now();
    final last = DateTime(now.year, now.month - 1);
    final thisMonth = byMonth[_monthKey(now)];
    final lastMonth = byMonth[_monthKey(last)];
    final best = monthly.reduce((a, b) => krw(a) >= krw(b) ? a : b);
    final average = byMonth.values.reduce((a, b) => a + b) / byMonth.length;
    String yyMM(String key) =>
        key.length >= 7 ? '${key.substring(2, 4)}.${key.substring(5, 7)}' : key;

    return _MonthlyInsights(
      thisMonthKrw: thisMonth,
      lastMonthKrw: lastMonth,
      lastMonthLabel: '${last.month}월',
      averageKrw: average,
      bestKrw: krw(best),
      bestLabel: yyMM(best.month),
      momPct: thisMonth != null && lastMonth != null && lastMonth > 0
          ? (thisMonth - lastMonth) / lastMonth * 100
          : null,
    );
  }
}

// ── 월별 배당 차트 ──────────────────────────────────────
class _MonthlyChartCard extends ConsumerStatefulWidget {
  final List<MonthlyDividend> monthly;
  final double? rate;

  const _MonthlyChartCard({required this.monthly, required this.rate});

  @override
  ConsumerState<_MonthlyChartCard> createState() => _MonthlyChartCardState();
}

class _MonthlyChartCardState extends ConsumerState<_MonthlyChartCard> {
  int _touched = -1;

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final showKrw = ref.watch(homeCurrencyProvider);
    final rate = widget.rate ?? fallbackUsdKrw;
    if (widget.monthly.isEmpty) return const SizedBox.shrink();

    // 이번 달까지 최근 12개월 (배당이 없는 달은 0)
    final byMonth = {
      for (final m in widget.monthly) m.month: m.totalUsd * rate + m.totalKrw,
    };
    final now = DateTime.now();
    final months = [
      for (var i = 11; i >= 0; i--) DateTime(now.year, now.month - i),
    ];
    final values = [for (final m in months) byMonth[_monthKey(m)] ?? 0.0];
    final maxV = values.fold<double>(0, (a, b) => b > a ? b : a);
    // 위 카드의 '월평균'과 같은 값 (배당이 있는 달의 평균)
    final avg = byMonth.values.reduce((a, b) => a + b) / byMonth.length;
    double shown(double krw) => showKrw ? krw : krw / rate;
    String label(double krw) => showKrw ? fmtKrwShort(krw) : fmtUsd(krw / rate);

    final touched = _touched >= 0 && _touched < months.length ? _touched : -1;

    return GlassCard(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text('월별 배당', style: AppText.sectionTitle(p))),
              Text(
                touched >= 0
                    ? '${months[touched].year % 100}.${months[touched].month.toString().padLeft(2, '0')} · ${showKrw ? fmtKrw(values[touched]) : fmtUsd(values[touched] / rate)}'
                    : '최근 12개월',
                style: AppText.label(
                  p,
                  color: touched >= 0 ? p.mint.s300 : null,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          SizedBox(
            height: 150,
            child: BarChart(
              BarChartData(
                maxY: maxV <= 0 ? 1 : shown(maxV) * 1.18,
                minY: 0,
                alignment: BarChartAlignment.spaceBetween,
                barTouchData: BarTouchData(
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipColor: (_) => Colors.transparent,
                    tooltipPadding: EdgeInsets.zero,
                    getTooltipItem: (_, _, _, _) => null,
                  ),
                  touchCallback: (event, response) {
                    final spot = response?.spot;
                    setState(() {
                      _touched =
                          spot != null &&
                              event is! FlTapUpEvent &&
                              event is! FlPanEndEvent
                          ? spot.touchedBarGroupIndex
                          : -1;
                    });
                  },
                ),
                extraLinesData: ExtraLinesData(
                  horizontalLines: [
                    if (avg > 0)
                      HorizontalLine(
                        y: shown(avg),
                        color: p.mint.s400.withValues(alpha: 0.45),
                        strokeWidth: 1,
                        dashArray: [4, 4],
                        label: HorizontalLineLabel(
                          show: true,
                          alignment: Alignment.topLeft,
                          padding: const EdgeInsets.only(bottom: 3),
                          style: AppText.label(
                            p,
                            size: 10,
                            color: p.mint.s300.withValues(alpha: 0.85),
                          ),
                          labelResolver: (_) => '월평균 ${label(avg)}',
                        ),
                      ),
                  ],
                ),
                titlesData: FlTitlesData(
                  leftTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 24,
                      getTitlesWidget: (value, meta) {
                        final i = value.toInt();
                        if (i < 0 || i >= months.length) {
                          return const SizedBox.shrink();
                        }
                        final current = i == months.length - 1;
                        return Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            '${months[i].month}',
                            style: AppText.label(
                              p,
                              size: 10,
                              color: i == touched || current
                                  ? p.mint.s300
                                  : p.zinc.s500,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                gridData: const FlGridData(show: false),
                borderData: FlBorderData(show: false),
                barGroups: [
                  for (var i = 0; i < months.length; i++)
                    BarChartGroupData(
                      x: i,
                      barRods: [
                        BarChartRodData(
                          toY: shown(values[i]),
                          width: 16,
                          color: i == touched
                              ? p.mint.s300
                              : i == months.length - 1
                              ? p.mint.s400
                              : p.w(0.12),
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(5),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
              duration: const Duration(milliseconds: 150),
            ),
          ),
        ],
      ),
    );
  }
}

// ── 최근 배당 ──────────────────────────────────────────
class _RecentDividendsCard extends StatelessWidget {
  final List<Dividend> dividends;
  final VoidCallback? onViewAll;

  const _RecentDividendsCard({required this.dividends, this.onViewAll});

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final items = dividends.take(4).toList();
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 16, 8),
            child: Row(
              children: [
                Expanded(child: Text('최근 배당', style: AppText.sectionTitle(p))),
                TextLink(label: '전체 보기', onTap: onViewAll),
              ],
            ),
          ),
          if (items.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
              child: Text(
                '배당금 내역이 없습니다',
                style: AppText.body(p, color: p.zinc.s500),
              ),
            ),
          for (final d in items) ...[
            const RowDivider(),
            _RecentRow(dividend: d),
          ],
        ],
      ),
    );
  }
}

class _RecentRow extends StatelessWidget {
  final Dividend dividend;

  const _RecentRow({required this.dividend});

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final d = dividend;
    final account = [
      if ((d.accountBroker ?? '').trim().isNotEmpty) d.accountBroker!.trim(),
      if ((d.accountName ?? '').trim().isNotEmpty) d.accountName!.trim(),
    ].join(' · ');
    final parsed = DateTime.tryParse(d.date);
    final date = parsed == null
        ? d.date
        : '${parsed.month.toString().padLeft(2, '0')}.${parsed.day.toString().padLeft(2, '0')}';

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
      child: Row(
        children: [
          TickerLogo(
            ticker: d.ticker ?? '',
            name: d.assetName ?? '',
            logoUrl: d.logoUrl,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  d.assetName ?? d.ticker ?? '종목',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.body(p),
                ),
                const SizedBox(height: 2),
                Text(
                  account.isEmpty ? date : '$account · $date',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.label(p),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            fmtSignedMoney(d.amount, d.currency),
            style: AppText.num(p, color: p.mint.s300),
          ),
        ],
      ),
    );
  }
}

// ── 공통 조각 ──────────────────────────────────────────
class _Dot extends StatelessWidget {
  final Color color;

  const _Dot({required this.color});

  @override
  Widget build(BuildContext context) => Container(
    width: 6,
    height: 6,
    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
  );
}

/// 불러오는 동안 자리 표시
class _Bar extends StatelessWidget {
  final double? width;
  final double height;

  const _Bar({this.width, required this.height});

  @override
  Widget build(BuildContext context) => Container(
    width: width,
    height: height,
    decoration: BoxDecoration(
      color: context.pal.w(0.07),
      borderRadius: BorderRadius.circular(8),
    ),
  );
}

class _SkeletonCard extends StatelessWidget {
  final double height;

  const _SkeletonCard({required this.height});

  @override
  Widget build(BuildContext context) => GlassCard(
    child: SizedBox(
      height: height,
      child: const Padding(
        padding: EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Bar(width: 120, height: 14),
            SizedBox(height: 16),
            _Bar(width: 200, height: 28),
          ],
        ),
      ),
    ),
  );
}

class _ErrorCard extends StatelessWidget {
  final String message;

  const _ErrorCard({required this.message});

  static String display(String raw) {
    final lower = raw.toLowerCase();
    if (lower.contains('api_key') || lower.contains('401')) {
      return '인증 실패(401)\nAPI_KEY를 확인하고 --dart-define-from-file=.env.json 옵션으로 다시 실행해 주세요.';
    }
    if (lower.contains('timeout')) return '요청 시간이 초과되었습니다. 네트워크 상태를 확인해 주세요.';
    if (lower.contains('socketexception') || lower.contains('connection')) {
      return '네트워크 연결 오류가 발생했습니다.';
    }
    return raw.length > 180 ? '${raw.substring(0, 180)}...' : raw;
  }

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: p.rose.s500.withValues(alpha: 0.08),
        border: Border.all(color: p.rose.s400.withValues(alpha: 0.3)),
      ),
      child: Text(
        '서버 연결 실패\n${display(message)}',
        style: AppText.body(p, size: 12.5, color: p.rose.s200),
      ),
    );
  }
}

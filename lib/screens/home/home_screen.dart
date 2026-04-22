import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_theme.dart';
import '../../models/dividend.dart';
import '../../providers/dividend_provider.dart';
import '../../providers/price_provider.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(dividendStatsProvider);
    final exchangeRateAsync = ref.watch(exchangeRateProvider);
    final recentAsync = ref.watch(recentDividendsProvider);
    final monthlyAsync = ref.watch(monthlyDividendsProvider);

    return Scaffold(
      appBar: AppBar(
        leading: Padding(
          padding: const EdgeInsets.all(8.0),
          child: CircleAvatar(
            backgroundColor: AppColors.surfaceHigh,
            child: Icon(Icons.person, color: AppColors.primary, size: 20),
          ),
        ),
        title: const Text('Home'),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_none_rounded),
            onPressed: () {},
            color: AppColors.textSecondary,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(dividendStatsProvider);
          ref.invalidate(exchangeRateProvider);
          ref.invalidate(recentDividendsProvider);
          ref.invalidate(monthlyDividendsProvider);
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // 총 배당금 카드
            statsAsync.when(
              loading: () => const _StatCardSkeleton(),
              error: (e, _) => _ErrorCard(message: e.toString()),
              data: (stats) => exchangeRateAsync.when(
                loading: () => _TotalDividendCard(stats: stats, exchangeRate: null),
                error: (_, p1) => _TotalDividendCard(stats: stats, exchangeRate: null),
                data: (rate) => _TotalDividendCard(stats: stats, exchangeRate: rate),
              ),
            ),
            const SizedBox(height: 12),
            // 월별 인사이트 2x2 그리드
            monthlyAsync.when(
              loading: () => const _InsightGridSkeleton(),
              error: (_, p1) => const SizedBox.shrink(),
              data: (monthly) => _MonthlyInsights(
                monthly: monthly,
                exchangeRate: exchangeRateAsync.valueOrNull,
              ),
            ),
            const SizedBox(height: 20),
            // 월별 분배금 차트
            monthlyAsync.when(
              loading: () => const _ChartSkeleton(),
              error: (_, p1) => const SizedBox.shrink(),
              data: (monthly) => _MonthlyChart(data: monthly),
            ),
            const SizedBox(height: 24),
            // Recent Activity
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Recent Activity',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    )),
                TextButton(
                  onPressed: () {},
                  child: const Text('View All',
                      style: TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w600,
                      )),
                ),
              ],
            ),
            recentAsync.when(
              loading: () => const _ActivitySkeleton(),
              error: (e, _) => _ErrorCard(message: e.toString()),
              data: (dividends) => dividends.isEmpty
                  ? const _EmptyActivity()
                  : Column(
                      children: dividends
                          .take(3)
                          .map((d) => _ActivityItem(dividend: d))
                          .toList(),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── 월별 차트 ──────────────────────────────────────────
class _MonthlyChart extends StatefulWidget {
  final List<MonthlyDividend> data;
  const _MonthlyChart({required this.data});

  @override
  State<_MonthlyChart> createState() => _MonthlyChartState();
}

class _MonthlyChartState extends State<_MonthlyChart> {
  int _touchedIndex = -1;

  List<MonthlyDividend> get _recent {
    final sorted = [...widget.data]..sort((a, b) => a.month.compareTo(b.month));
    return sorted.length > 12 ? sorted.sublist(sorted.length - 12) : sorted;
  }

  String _shortMonth(String month) {
    try {
      final dt = DateTime.parse('$month-01');
      return DateFormat('MMM').format(dt);
    } catch (_) {
      return month;
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = _recent;
    if (data.isEmpty) return const SizedBox.shrink();

    final maxVal = data.map((e) => e.totalUsd).reduce((a, b) => a > b ? a : b);
    final touched = _touchedIndex >= 0 && _touchedIndex < data.length
        ? data[_touchedIndex]
        : null;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Monthly Dividends',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              if (touched != null)
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: Text(
                    key: ValueKey(touched.month),
                    '\$${NumberFormat('#,##0.00').format(touched.totalUsd)}',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 150,
            child: BarChart(
              BarChartData(
                maxY: maxVal * 1.3,
                barTouchData: BarTouchData(
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipColor: (_) => Colors.transparent,
                    tooltipPadding: EdgeInsets.zero,
                    getTooltipItem: (_, p1, _, p2) => null,
                  ),
                  touchCallback: (event, response) {
                    if (response?.spot != null &&
                        event is! FlTapUpEvent &&
                        event is! FlPanEndEvent) {
                      setState(() => _touchedIndex = response!.spot!.touchedBarGroupIndex);
                    } else {
                      setState(() => _touchedIndex = -1);
                    }
                  },
                ),
                titlesData: FlTitlesData(
                  leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 28,
                      getTitlesWidget: (value, meta) {
                        final i = value.toInt();
                        if (i < 0 || i >= data.length) return const SizedBox.shrink();
                        final isTouched = i == _touchedIndex;
                        return Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            _shortMonth(data[i].month),
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: isTouched ? FontWeight.w700 : FontWeight.w400,
                              color: isTouched ? AppColors.primary : AppColors.textSecondary,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (_) => const FlLine(
                    color: AppColors.border,
                    strokeWidth: 1,
                  ),
                ),
                borderData: FlBorderData(show: false),
                barGroups: data.asMap().entries.map((e) {
                  final isTouched = e.key == _touchedIndex;
                  return BarChartGroupData(
                    x: e.key,
                    barRods: [
                      BarChartRodData(
                        toY: e.value.totalUsd,
                        color: isTouched ? AppColors.primary : AppColors.primary.withValues(alpha: 0.3),
                        width: 14,
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                      ),
                    ],
                  );
                }).toList(),
              ),
              duration: const Duration(milliseconds: 150),
            ),
          ),
        ],
      ),
    );
  }
}

// ── 기존 위젯들 ───────────────────────────────────────
class _TotalDividendCard extends ConsumerWidget {
  final DividendStats stats;
  final double? exchangeRate;

  const _TotalDividendCard({required this.stats, required this.exchangeRate});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final _showKrw = ref.watch(homeCurrencyProvider);

    final rate = exchangeRate;
    final krwToUsd = rate != null && rate > 0 ? stats.totalDividendsKrw / rate : 0.0;
    final combinedUsd = stats.totalDividendsUsd + krwToUsd;
    final combinedKrw = rate != null
        ? stats.totalDividendsUsd * rate + stats.totalDividendsKrw
        : stats.totalDividendsKrw;

    final usdFmt = NumberFormat('#,##0.00');
    final krwFmt = NumberFormat('#,###');

    final mainLabel = _showKrw
        ? '₩${krwFmt.format(combinedKrw.round())}'
        : '\$${usdFmt.format(combinedUsd)}';
    final subLabel = _showKrw
        ? '\$${usdFmt.format(combinedUsd)}'
        : '₩${krwFmt.format(combinedKrw.round())}';

    return GestureDetector(
      onTap: () => ref.read(homeCurrencyProvider.notifier).state = !_showKrw,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Total Dividends',
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                          )),
                      const SizedBox(height: 6),
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 250),
                        transitionBuilder: (child, anim) => FadeTransition(
                          opacity: anim,
                          child: SlideTransition(
                            position: Tween<Offset>(
                              begin: const Offset(0, 0.15),
                              end: Offset.zero,
                            ).animate(anim),
                            child: child,
                          ),
                        ),
                        child: Text(
                          mainLabel,
                          key: ValueKey(mainLabel),
                          style: const TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: AppColors.primaryDim,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(
                    _showKrw ? Icons.paid_outlined : Icons.attach_money_rounded,
                    color: AppColors.primary,
                    size: 28,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(height: 1, color: AppColors.border),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        subLabel,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          _CurrencyChip(
                            label: '\$${usdFmt.format(stats.totalDividendsUsd)}',
                            color: AppColors.primary,
                            bg: AppColors.primaryDim,
                          ),
                          const SizedBox(width: 6),
                          _CurrencyChip(
                            label: '₩${krwFmt.format(stats.totalDividendsKrw)}',
                            color: AppColors.positive,
                            bg: Color(0x3322C55E),
                          ),
                        ],
                      ),
                      if (rate != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            '환율 ${krwFmt.format(rate)} KRW/USD 기준  •  탭하여 전환',
                            style: const TextStyle(
                              fontSize: 10,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CurrencyChip extends StatelessWidget {
  final String label;
  final Color color;
  final Color bg;
  const _CurrencyChip({required this.label, required this.color, required this.bg});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color),
      ),
    );
  }
}

// ── 월별 인사이트 2×2 그리드 ──────────────────────────────
class _MonthlyInsights extends ConsumerWidget {
  final List<MonthlyDividend> monthly;
  final double? exchangeRate;

  const _MonthlyInsights({required this.monthly, this.exchangeRate});

  double _combined(MonthlyDividend m, double? rate) {
    if (rate == null || rate == 0) return m.totalUsd;
    return m.totalUsd + m.totalKrw / rate;
  }

  String _fmt(double v, bool showKrw, double? rate) {
    if (showKrw) {
      final krw = v * (rate ?? 1300);
      return '₩${NumberFormat('#,###').format(krw.round())}';
    }
    return '\$${NumberFormat('#,##0.00').format(v)}';
  }

  String _shortMonth(String label) {
    try {
      final dt = DateTime.parse('$label-01');
      return DateFormat('yy년도 M월').format(dt);
    } catch (_) {
      return label;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (monthly.isEmpty) return const SizedBox.shrink();

    final showKrw = ref.watch(homeCurrencyProvider);
    final sorted = [...monthly]..sort((a, b) => a.month.compareTo(b.month));
    final now = DateTime.now();
    final thisMonthKey = '${now.year}-${now.month.toString().padLeft(2, '0')}';
    final lastMonthDt = DateTime(now.year, now.month - 1);
    final lastMonthKey = '${lastMonthDt.year}-${lastMonthDt.month.toString().padLeft(2, '0')}';

    final thisMonth = sorted.where((m) => m.month == thisMonthKey).firstOrNull;
    final lastMonth = sorted.where((m) => m.month == lastMonthKey).firstOrNull;
    final best = sorted.reduce((a, b) => _combined(a, exchangeRate) > _combined(b, exchangeRate) ? a : b);

    final avg = sorted.isEmpty
        ? 0.0
        : sorted.map((m) => _combined(m, exchangeRate)).reduce((a, b) => a + b) / sorted.length;

    double? momPct;
    if (thisMonth != null && lastMonth != null && _combined(lastMonth, exchangeRate) > 0) {
      momPct = (_combined(thisMonth, exchangeRate) - _combined(lastMonth, exchangeRate)) /
          _combined(lastMonth, exchangeRate) * 100;
    }

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _InsightCard(
                icon: Icons.today_rounded,
                iconColor: AppColors.primary,
                iconBg: AppColors.primaryDim,
                label: '이번 달',
                value: thisMonth != null ? _fmt(_combined(thisMonth, exchangeRate), showKrw, exchangeRate) : '-',
                badge: momPct != null ? _MomBadge(pct: momPct) : null,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _InsightCard(
                icon: Icons.show_chart_rounded,
                iconColor: AppColors.secondary,
                iconBg: AppColors.secondaryDim,
                label: '월 평균',
                value: _fmt(avg, showKrw, exchangeRate),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _InsightCard(
                icon: Icons.history_rounded,
                iconColor: const Color(0xFFFF9500),
                iconBg: Color(0x33FF9500),
                label: '전월',
                value: lastMonth != null ? _fmt(_combined(lastMonth, exchangeRate), showKrw, exchangeRate) : '-',
                sub: lastMonth != null ? _shortMonth(lastMonth.month) : null,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _InsightCard(
                icon: Icons.emoji_events_rounded,
                iconColor: AppColors.positive,
                iconBg: Color(0x3322C55E),
                label: '최고 달',
                value: _fmt(_combined(best, exchangeRate), showKrw, exchangeRate),
                sub: _shortMonth(best.month),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _InsightCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  final String label;
  final String value;
  final String? sub;
  final Widget? badge;

  const _InsightCard({
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    required this.label,
    required this.value,
    this.sub,
    this.badge,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(icon, color: iconColor, size: 16),
              ),
              const Spacer(),
              if (badge != null) badge!,
            ],
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 2),
          Row(
            children: [
              Text(
                label,
                style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
              ),
              if (sub != null) ...[
                const SizedBox(width: 4),
                Text(
                  '· $sub',
                  style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _MomBadge extends StatelessWidget {
  final double pct;
  const _MomBadge({required this.pct});

  @override
  Widget build(BuildContext context) {
    final isUp = pct >= 0;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: isUp ? const Color(0x3322C55E) : const Color(0x33EF4444),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isUp ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
            size: 10,
            color: isUp ? AppColors.positive : AppColors.negative,
          ),
          Text(
            '${pct.abs().toStringAsFixed(1)}%',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: isUp ? AppColors.positive : AppColors.negative,
            ),
          ),
        ],
      ),
    );
  }
}

class _InsightGridSkeleton extends StatelessWidget {
  const _InsightGridSkeleton();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(children: [
          Expanded(child: Container(height: 90, decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(16)))),
          const SizedBox(width: 10),
          Expanded(child: Container(height: 90, decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(16)))),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: Container(height: 90, decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(16)))),
          const SizedBox(width: 10),
          Expanded(child: Container(height: 90, decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(16)))),
        ]),
      ],
    );
  }
}

class _ActivityItem extends StatelessWidget {
  final Dividend dividend;

  const _ActivityItem({required this.dividend});

  bool get _isKrw => dividend.currency == 'KRW';

  @override
  Widget build(BuildContext context) {
    final name = dividend.assetName ?? 'Unknown';
    final ticker = dividend.ticker ?? '';
    final date = _formatDate(dividend.date);
    final amount = _isKrw
        ? '₩${NumberFormat('#,###').format(dividend.amount)}'
        : '+\$${NumberFormat('#,##0.00').format(dividend.amount)}';
    final broker = dividend.accountBroker ?? '';
    final accName = dividend.accountName ?? '';
    final accountLabel = broker.isNotEmpty && accName.isNotEmpty
        ? '$broker · $accName'
        : broker.isNotEmpty
            ? broker
            : accName;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          // 아이콘
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: _isKrw ? const Color(0x3322C55E) : AppColors.primaryDim,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.payments_rounded,
              color: _isKrw ? AppColors.positive : AppColors.primary,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          // 종목 + 계좌 정보
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
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    if (accountLabel.isNotEmpty) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceHigh,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          accountLabel,
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                    ],
                    Text(
                      date,
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
          const SizedBox(width: 8),
          // 금액
          Text(
            amount,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppColors.positive,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(String date) {
    try {
      final dt = DateTime.parse(date);
      return DateFormat('MMM dd, yyyy').format(dt);
    } catch (_) {
      return date;
    }
  }
}

class _EmptyActivity extends StatelessWidget {
  const _EmptyActivity();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 32),
      child: Center(
        child: Text(
          '배당금 내역이 없습니다',
          style: TextStyle(color: AppColors.textSecondary),
        ),
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  final String message;
  const _ErrorCard({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.negative.withValues(alpha: 0.3)),
      ),
      child: Text('서버 연결 실패\n$message',
          style: const TextStyle(color: AppColors.negative, fontSize: 12)),
    );
  }
}

class _StatCardSkeleton extends StatelessWidget {
  const _StatCardSkeleton();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 140,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
      ),
      child: const Center(child: CircularProgressIndicator()),
    );
  }
}

class _ChartSkeleton extends StatelessWidget {
  const _ChartSkeleton();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 200,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
      ),
      child: const Center(child: CircularProgressIndicator()),
    );
  }
}

// Shimmer 애니메이션 베이스
class _Shimmer extends StatefulWidget {
  final Widget child;
  const _Shimmer({required this.child});

  @override
  State<_Shimmer> createState() => _ShimmerState();
}

class _ShimmerState extends State<_Shimmer> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))
      ..repeat();
    _anim = Tween<double>(begin: -1.5, end: 1.5).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) => ShaderMask(
        blendMode: BlendMode.srcATop,
        shaderCallback: (bounds) => LinearGradient(
          begin: Alignment(_anim.value - 1, 0),
          end: Alignment(_anim.value + 1, 0),
          colors: const [
            Color(0xFF161625),
            Color(0xFF1E1E30),
            Color(0xFF161625),
          ],
          stops: const [0.0, 0.5, 1.0],
        ).createShader(bounds),
        child: widget.child,
      ),
    );
  }
}

class _ActivitySkeleton extends StatelessWidget {
  const _ActivitySkeleton();

  @override
  Widget build(BuildContext context) {
    return _Shimmer(
      child: Column(
        children: List.generate(3, (_) => _SkeletonCard()),
      ),
    );
  }
}

class _SkeletonCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
              color: AppColors.surfaceHigh,
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(height: 13, width: 140, decoration: BoxDecoration(color: AppColors.surfaceHigh, borderRadius: BorderRadius.circular(4))),
                const SizedBox(height: 8),
                Container(height: 10, width: 90, decoration: BoxDecoration(color: AppColors.surfaceHigh, borderRadius: BorderRadius.circular(4))),
              ],
            ),
          ),
          Container(height: 14, width: 60, decoration: BoxDecoration(color: AppColors.surfaceHigh, borderRadius: BorderRadius.circular(4))),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:intl/intl.dart';
import '../../core/format.dart';
import '../../core/theme/palette.dart';
import '../../core/theme/typography.dart';
import '../../models/dividend.dart';
import '../../providers/account_provider.dart';
import '../../providers/dividend_provider.dart';
import '../../providers/portfolio_provider.dart';
import '../../services/api_service.dart';
import '../../widgets/account_picker.dart';
import '../../widgets/error_retry.dart';
import '../../widgets/ui/app_icon.dart';
import '../../widgets/ui/app_shell.dart';
import '../../widgets/ui/controls.dart';
import '../../widgets/ui/logos.dart';
import '../../widgets/ui/surfaces.dart';
import 'add_dividend_sheet.dart';

// 배당 분석의 통화 표시. true: KRW, false: USD (기본 KRW)
final accountDividendCurrencyKrwProvider = StateProvider<bool>((ref) => true);

/// 배당 탭 안의 페이지 (0 = 배당 기록, 1 = 배당 분석)
final dividendsPageProvider = StateProvider<int>((ref) => 0);

/// 배당 기록에서 고른 계좌 (null = 전체 계좌)
final dividendAccountProvider = StateProvider<int?>((ref) => null);

double _toKrw(Dividend d, double rate) =>
    d.currency == 'KRW' ? d.amount : d.amount * rate;

/// 배당 탭: 배당 기록 · 배당 분석 (데스크톱 사이드바의 '배당' 묶음)
class DividendsScreen extends ConsumerWidget {
  const DividendsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final page = ref.watch(dividendsPageProvider);
    final showKrw = ref.watch(accountDividendCurrencyKrwProvider);
    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      appBar: AppTopBar(
        title: const Text('배당'),
        actions: [
          if (page == 0)
            PrimaryPillButton(
              label: '배당',
              icon: Icons.add_rounded,
              onPressed: () => showAddDividendSheet(context),
            )
          else
            GlassSegmented<bool>(
              items: const [(true, 'KRW'), (false, 'USD')],
              selected: showKrw,
              onChanged: (v) =>
                  ref.read(accountDividendCurrencyKrwProvider.notifier).state =
                      v,
            ),
        ],
        bottom: SubPageTabs(
          labels: const ['배당 기록', '배당 분석'],
          index: page,
          onChanged: (i) => ref.read(dividendsPageProvider.notifier).state = i,
        ),
      ),
      body: IndexedStack(
        index: page,
        children: const [_HistoryView(), _AnalysisView()],
      ),
    );
  }
}

Future<void> _refreshDividends(WidgetRef ref) async {
  ref.invalidate(dividendStatsProvider);
  ref.invalidate(allDividendsProvider);
  ref.invalidate(monthlyDividendsProvider);
}

// ─── 배당 기록 ──────────────────────────────────────────────────────────────

class _MonthGroup {
  final String key; // yyyy-MM
  final List<Dividend> items;

  _MonthGroup(this.key, this.items);
}

class _HistoryView extends ConsumerWidget {
  const _HistoryView();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.pal;
    final allAsync = ref.watch(allDividendsProvider);
    final rate = ref.watch(exchangeRateProvider).valueOrNull ?? fallbackUsdKrw;
    final accounts = ref.watch(accountsProvider).valueOrNull ?? const [];

    return RefreshIndicator(
      edgeOffset: MediaQuery.paddingOf(context).top,
      onRefresh: () => _refreshDividends(ref),
      child: allAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorRetry(
          message: e.toString(),
          onRetry: () => _refreshDividends(ref),
        ),
        data: (dividends) {
          final picked = ref.watch(dividendAccountProvider);
          final accountIds = {for (final d in dividends) d.accountId};
          final selectedId = accountIds.contains(picked) ? picked : null;
          final selected = accounts
              .where((a) => a.id == selectedId)
              .firstOrNull;
          final shown = selectedId == null
              ? dividends
              : dividends.where((d) => d.accountId == selectedId).toList();

          final krw = shown
              .where((d) => d.currency == 'KRW')
              .fold(0.0, (s, d) => s + d.amount);
          final usd = shown
              .where((d) => d.currency != 'KRW')
              .fold(0.0, (s, d) => s + d.amount);

          // 월별 묶음 (최근 달부터, 목록은 이미 날짜 내림차순)
          final groups = <_MonthGroup>[];
          for (final d in shown) {
            final key = d.date.length >= 7 ? d.date.substring(0, 7) : d.date;
            if (groups.isEmpty || groups.last.key != key) {
              groups.add(_MonthGroup(key, []));
            }
            groups.last.items.add(d);
          }

          Future<void> pickAccount() async {
            final items = [
              for (final a in accounts)
                if (accountIds.contains(a.id))
                  () {
                    final list = dividends.where((d) => d.accountId == a.id);
                    return AccountPickItem(
                      account: a,
                      value: fmtKrw(
                        list.fold(0.0, (s, d) => s + _toKrw(d, rate)),
                      ),
                      meta: '${list.length}건',
                    );
                  }(),
            ];
            final choice = await showAccountPicker(
              context,
              items: items,
              selectedId: selectedId,
              allMeta: '${items.length}계좌 · ${dividends.length}건',
            );
            if (choice != null) {
              ref.read(dividendAccountProvider.notifier).state = choice.id;
            }
          }

          final header = <Widget>[
            GlassCard(
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    selected == null
                        ? '누적 배당 · 원화 환산'
                        : '${selected.name} · 누적 배당',
                    style: AppText.label(p),
                  ),
                  const SizedBox(height: 6),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      fmtKrw(krw + usd * rate),
                      style: AppText.bigNumber(p, size: 26),
                    ),
                  ),
                  const SizedBox(height: 12),
                  IntrinsicHeight(
                    child: Row(
                      children: [
                        Expanded(
                          child: _CurrencyTotal(
                            label: 'KRW',
                            value: fmtKrw(krw),
                          ),
                        ),
                        VerticalDivider(color: p.w(0.07), width: 1),
                        const SizedBox(width: 14),
                        Expanded(
                          child: _CurrencyTotal(
                            label: 'USD',
                            value: fmtUsd(usd),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: AccountSelectButton(
                    selected: selected,
                    totalCount: accountIds.length,
                    onTap: pickAccount,
                  ),
                ),
                const SizedBox(width: 8),
                Text('${shown.length}건', style: AppText.label(p)),
              ],
            ),
            const SizedBox(height: 8),
          ];

          final pad = listPadding(context);
          // 기록이 수천 건이어도 보이는 줄만 만들도록 달마다 SliverList 로 (카드 바탕은 DecoratedSliver)
          return SlidableAutoCloseBehavior(
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverPadding(
                  padding: EdgeInsets.fromLTRB(pad.left, pad.top, pad.right, 0),
                  sliver: SliverList.list(children: header),
                ),
                if (groups.isEmpty)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 60),
                      child: Center(
                        child: Text(
                          dividends.isEmpty
                              ? '배당금 내역이 없습니다'
                              : '선택한 계좌의 배당 내역이 없습니다',
                          style: AppText.body(p, color: p.zinc.s500),
                        ),
                      ),
                    ),
                  ),
                for (final g in groups) ...[
                  SliverPadding(
                    padding: EdgeInsets.fromLTRB(pad.left, 8, pad.right, 8),
                    sliver: SliverToBoxAdapter(
                      child: _MonthHeader(group: g, rate: rate),
                    ),
                  ),
                  SliverPadding(
                    padding: EdgeInsets.fromLTRB(pad.left, 0, pad.right, 6),
                    sliver: DecoratedSliver(
                      decoration: glassCardDecoration(p),
                      sliver: SliverList.builder(
                        itemCount: g.items.length,
                        itemBuilder: (context, i) {
                          final d = g.items[i];
                          final last = i == g.items.length - 1;
                          return ClipRRect(
                            borderRadius: BorderRadius.vertical(
                              top: Radius.circular(i == 0 ? 24 : 0),
                              bottom: Radius.circular(last ? 24 : 0),
                            ),
                            child: Column(
                              children: [
                                if (i > 0) const RowDivider(),
                                _DividendRow(
                                  dividend: d,
                                  showAccount: selectedId == null,
                                  onEdit: () => showAddDividendSheet(
                                    context,
                                    dividend: d,
                                  ),
                                  onDelete: () =>
                                      _deleteDividend(context, ref, d),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ],
                SliverToBoxAdapter(child: SizedBox(height: pad.bottom)),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _CurrencyTotal extends StatelessWidget {
  final String label;
  final String value;

  const _CurrencyTotal({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppText.label(p)),
        const SizedBox(height: 2),
        Text(value, style: AppText.num(p, size: 15, color: p.zinc.s100)),
      ],
    );
  }
}

Future<void> _deleteDividend(
  BuildContext context,
  WidgetRef ref,
  Dividend d,
) async {
  final p = context.pal;
  final confirm = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('배당금 삭제'),
      content: Text(
        '${d.assetName ?? d.ticker ?? '종목'} ${fmtMoney(d.amount, d.currency)} 기록을 삭제할까요?',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: const Text('취소'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, true),
          child: Text('삭제', style: TextStyle(color: p.rose.s400)),
        ),
      ],
    ),
  );
  if (confirm != true) return;
  try {
    await ref.read(apiServiceProvider).deleteDividend(d.id);
    await _refreshDividends(ref);
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('삭제되었습니다')));
    }
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('삭제 실패: $e'), backgroundColor: p.rose.s700),
      );
    }
  }
}

/// 달 머리: "11월" / "2025년 12월" + 건수 · 원화 환산 합계
class _MonthHeader extends StatelessWidget {
  final _MonthGroup group;
  final double rate;

  const _MonthHeader({required this.group, required this.rate});

  String get _title {
    final parts = group.key.split('-');
    if (parts.length < 2) return group.key;
    final year = int.tryParse(parts[0]);
    final month = int.tryParse(parts[1]);
    if (year == null || month == null) return group.key;
    return year == DateTime.now().year ? '$month월' : '$year년 $month월';
  }

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final sum = group.items.fold(0.0, (s, d) => s + _toKrw(d, rate));
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              _title,
              style: AppText.body(
                p,
                size: 13,
                weight: FontWeight.w600,
                color: p.zinc.s200,
              ),
            ),
          ),
          Text('${group.items.length}건 · ', style: AppText.label(p)),
          Text(
            fmtKrw(sum),
            style: AppText.num(p, size: 11.5, color: p.zinc.s300),
          ),
        ],
      ),
    );
  }
}

class _DividendRow extends StatelessWidget {
  final Dividend dividend;
  final bool showAccount;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _DividendRow({
    required this.dividend,
    required this.showAccount,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final d = dividend;
    final parsed = DateTime.tryParse(d.date);
    final date = parsed == null ? d.date : DateFormat('MM.dd').format(parsed);
    final account = [
      if ((d.accountBroker ?? '').trim().isNotEmpty) d.accountBroker!.trim(),
      if ((d.accountName ?? '').trim().isNotEmpty) d.accountName!.trim(),
    ].join(' · ');
    final name = d.assetName ?? d.ticker ?? '종목';
    final ticker = d.ticker ?? '';

    return Slidable(
      key: ValueKey('dividend-${d.id}'),
      endActionPane: ActionPane(
        motion: const DrawerMotion(),
        extentRatio: 0.42,
        children: [
          SlidableAction(
            onPressed: (_) => onEdit(),
            backgroundColor: p.ink600,
            foregroundColor: p.zinc.s100,
            icon: Icons.edit_outlined,
            label: '수정',
          ),
          SlidableAction(
            onPressed: (_) => onDelete(),
            backgroundColor: p.rose.s600,
            foregroundColor: p.white,
            icon: Icons.delete_outline,
            label: '삭제',
          ),
        ],
      ),
      child: InkWell(
        onTap: onEdit,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 11, 16, 11),
          child: Row(
            children: [
              TickerLogo(ticker: ticker, name: name, logoUrl: d.logoUrl),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.body(p),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      [
                        date,
                        if (showAccount && account.isNotEmpty) account,
                        if (!showAccount && ticker.isNotEmpty) ticker,
                      ].join(' · '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.label(p),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    fmtSignedMoney(d.amount, d.currency),
                    style: AppText.num(p, color: p.mint.s300),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '세금 ${fmtMoney(d.tax, d.currency)}',
                    style: AppText.label(p),
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

// ─── 배당 분석 ──────────────────────────────────────────────────────────────

class _Bucket {
  final String name;
  double usd = 0;
  double krw = 0;

  _Bucket(this.name);

  double totalKrw(double rate) => usd * rate + krw;

  void add(Dividend d) {
    if (d.currency == 'KRW') {
      krw += d.amount;
    } else {
      usd += d.amount;
    }
  }
}

class _AnalysisView extends ConsumerWidget {
  const _AnalysisView();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.pal;
    final allAsync = ref.watch(allDividendsProvider);
    final rate = ref.watch(exchangeRateProvider).valueOrNull ?? fallbackUsdKrw;
    final showKrw = ref.watch(accountDividendCurrencyKrwProvider);

    String money(_Bucket b) => showKrw
        ? fmtKrw(b.totalKrw(rate))
        : fmtUsd(b.usd + (rate > 0 ? b.krw / rate : 0));

    return RefreshIndicator(
      edgeOffset: MediaQuery.paddingOf(context).top,
      onRefresh: () => _refreshDividends(ref),
      child: allAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorRetry(
          message: e.toString(),
          onRetry: () => _refreshDividends(ref),
        ),
        data: (dividends) {
          if (dividends.isEmpty) {
            return ListView(
              padding: listPadding(context),
              children: [
                const SizedBox(height: 120),
                Center(
                  child: Text(
                    '분석할 배당 데이터가 없습니다',
                    style: AppText.body(p, color: p.zinc.s500),
                  ),
                ),
              ],
            );
          }

          final byAsset = <int, _Bucket>{};
          final byAccount = <int, _Bucket>{};
          final byYear = <String, _Bucket>{};
          final total = _Bucket('전체');
          for (final d in dividends) {
            final ticker = (d.ticker ?? '').trim();
            final name = d.assetName ?? 'Unknown';
            byAsset
                .putIfAbsent(
                  d.assetId,
                  () => _Bucket(
                    isKrwTicker(ticker) || ticker.isEmpty
                        ? name
                        : '$ticker · $name',
                  ),
                )
                .add(d);
            byAccount
                .putIfAbsent(d.accountId, () {
                  final broker = (d.accountBroker ?? '').trim();
                  final account = d.accountName ?? 'Unknown';
                  return _Bucket(
                    broker.isEmpty ? account : '$broker · $account',
                  );
                })
                .add(d);
            byYear
                .putIfAbsent(
                  d.date.length >= 4 ? d.date.substring(0, 4) : '기타',
                  () => _Bucket(''),
                )
                .add(d);
            total.add(d);
          }
          int byValue(_Bucket a, _Bucket b) =>
              b.totalKrw(rate).compareTo(a.totalKrw(rate));
          final topAssets = (byAsset.values.toList()..sort(byValue))
              .take(5)
              .toList();
          final accounts = byAccount.values.toList()..sort(byValue);
          final years = byYear.entries.toList()
            ..sort((a, b) => b.key.compareTo(a.key));
          final totalKrw = total.totalKrw(rate);
          double share(_Bucket b) =>
              totalKrw > 0 ? b.totalKrw(rate) / totalKrw : 0;
          double maxOf(Iterable<_Bucket> list) => list.fold<double>(
            0,
            (m, b) => b.totalKrw(rate) > m ? b.totalKrw(rate) : m,
          );

          final maxAsset = maxOf(topAssets);
          final maxAccount = maxOf(accounts);
          final maxYear = maxOf(years.map((e) => e.value));

          return ListView(
            padding: listPadding(context),
            children: [
              GlassCard(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const CardHeader(
                      glyph: AppGlyph.podium,
                      title: '종목별 배당 Top 5',
                    ),
                    const SizedBox(height: 14),
                    for (var i = 0; i < topAssets.length; i++)
                      _RankRow(
                        rank: i + 1,
                        title: topAssets[i].name,
                        amount: money(topAssets[i]),
                        progress: maxAsset > 0
                            ? topAssets[i].totalKrw(rate) / maxAsset
                            : 0,
                        share: share(topAssets[i]),
                        last: i == topAssets.length - 1,
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              GlassCard(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CardHeader(
                      glyph: AppGlyph.wallet,
                      title: '계좌별 배당',
                      trailing: Text(
                        '${accounts.length}계좌',
                        style: AppText.label(p),
                      ),
                    ),
                    const SizedBox(height: 14),
                    for (var i = 0; i < accounts.length; i++)
                      _RankRow(
                        rank: i + 1,
                        title: accounts[i].name,
                        amount: money(accounts[i]),
                        progress: maxAccount > 0
                            ? accounts[i].totalKrw(rate) / maxAccount
                            : 0,
                        share: share(accounts[i]),
                        last: i == accounts.length - 1,
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              GlassCard(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const CardHeader(glyph: AppGlyph.calendar, title: '연도별 배당'),
                    const SizedBox(height: 14),
                    for (var i = 0; i < years.length; i++)
                      _RankRow(
                        title: '${years[i].key}년',
                        amount: money(years[i].value),
                        progress: maxYear > 0
                            ? years[i].value.totalKrw(rate) / maxYear
                            : 0,
                        last: i == years.length - 1,
                      ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _RankRow extends StatelessWidget {
  final int? rank;
  final String title;
  final String amount;
  final double progress;
  final double? share;
  final bool last;

  const _RankRow({
    this.rank,
    required this.title,
    required this.amount,
    required this.progress,
    this.share,
    this.last = false,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final indent = rank == null ? 0.0 : 24.0;
    return Padding(
      padding: EdgeInsets.only(bottom: last ? 0 : 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (rank != null)
                SizedBox(
                  width: indent,
                  child: Text(
                    '$rank',
                    style: AppText.label(
                      p,
                      color: rank == 1 ? p.mint.s300 : p.zinc.s500,
                    ),
                  ),
                ),
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.body(p, size: 13.5),
                ),
              ),
              const SizedBox(width: 8),
              Text(amount, style: AppText.num(p, size: 13.5)),
            ],
          ),
          const SizedBox(height: 7),
          Padding(
            padding: EdgeInsets.only(left: indent),
            child: Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(99),
                    child: SizedBox(
                      height: 5,
                      child: Stack(
                        children: [
                          Positioned.fill(child: ColoredBox(color: p.w(0.06))),
                          FractionallySizedBox(
                            widthFactor: progress.clamp(0.0, 1.0),
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(99),
                                gradient: LinearGradient(
                                  colors: [p.mint.s600, p.mint.s400],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                if (share != null) ...[
                  const SizedBox(width: 10),
                  SizedBox(
                    width: 44,
                    child: Text(
                      '${(share! * 100).toStringAsFixed(1)}%',
                      textAlign: TextAlign.right,
                      style: AppText.label(p),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

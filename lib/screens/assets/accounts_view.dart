import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/format.dart';
import '../../core/theme/palette.dart';
import '../../core/theme/typography.dart';
import '../../models/account.dart';
import '../../providers/account_provider.dart';
import '../../providers/asset_provider.dart';
import '../../providers/dividend_provider.dart';
import '../../providers/portfolio_provider.dart';
import '../../providers/price_provider.dart';
import '../../widgets/error_retry.dart';
import '../../widgets/ui/app_icon.dart';
import '../../widgets/ui/app_shell.dart';
import '../../widgets/ui/controls.dart';
import '../../widgets/ui/logos.dart';
import '../../widgets/ui/surfaces.dart';
import '../accounts/account_sheet.dart';

/// 계좌 한 줄에 보여 줄 값
class _AccountLine {
  final Account account;
  final PortfolioTotals totals;
  final double rate;

  const _AccountLine(this.account, this.totals, this.rate);

  bool get isInternational => account.marketType == 'International';

  /// 정렬용: 평가금액, 현재가가 없으면 원금
  double get sortKrw =>
      totals.pricedCount > 0 ? totals.valueKrw : totals.costKrw;

  String inAccountCurrency(double krw) => account.currency == 'KRW'
      ? fmtKrw(krw)
      : fmtUsd(rate > 0 ? krw / rate : 0);
}

/// 자산 › 계좌: 계좌 합계 + 국내 · 해외 묶음 목록 (평가금액 큰 순)
class AccountsView extends ConsumerWidget {
  const AccountsView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.pal;
    final accountsAsync = ref.watch(accountsProvider);
    final assetsAsync = ref.watch(assetsProvider);
    final pricesAsync = ref.watch(allTickerPricesProvider);
    final rate = ref.watch(exchangeRateProvider).valueOrNull ?? fallbackUsdKrw;

    Future<void> refresh() async {
      ref.invalidate(accountsProvider);
      ref.invalidate(assetsProvider);
      ref.invalidate(allTickerPricesProvider);
    }

    final accounts = accountsAsync.valueOrNull;
    final assets = assetsAsync.valueOrNull;
    if (accounts == null || assets == null) {
      final error = accountsAsync.error ?? assetsAsync.error;
      if (error != null) {
        return ErrorRetry(message: error.toString(), onRetry: refresh);
      }
      return const Center(child: CircularProgressIndicator());
    }

    final prices = pricesAsync.valueOrNull ?? const {};
    final pricesLoading =
        pricesAsync.valueOrNull == null && !pricesAsync.hasError;
    final lines = [
      for (final a in accounts)
        _AccountLine(
          a,
          buildPortfolio(
            assets: assets,
            prices: prices,
            rate: rate,
            accountId: a.id,
          ).totals,
          rate,
        ),
    ]..sort((a, b) => b.sortKrw.compareTo(a.sortKrw));
    final domestic = lines.where((l) => !l.isInternational).toList();
    final international = lines.where((l) => l.isInternational).toList();
    final total = buildPortfolio(
      assets: assets,
      prices: prices,
      rate: rate,
    ).totals;
    final holdingCount = lines.fold<int>(0, (s, l) => s + l.totals.assetCount);

    return RefreshIndicator(
      edgeOffset: MediaQuery.paddingOf(context).top,
      onRefresh: refresh,
      child: ListView(
        padding: listPadding(context),
        children: [
          if (accounts.isEmpty)
            _EmptyAccounts(onAdd: () => showAccountSheet(context))
          else ...[
            GlassCard(
              padding: const EdgeInsets.all(18),
              child: Column(
                children: [
                  Row(
                    children: [
                      const IconTile(AppGlyph.wallet),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('계좌 합계 · 평가금액', style: AppText.label(p)),
                            const SizedBox(height: 2),
                            pricesLoading
                                ? Text(
                                    '현재가를 불러오는 중…',
                                    style: AppText.body(
                                      p,
                                      size: 13,
                                      color: p.zinc.s400,
                                    ),
                                  )
                                : FittedBox(
                                    fit: BoxFit.scaleDown,
                                    alignment: Alignment.centerLeft,
                                    child: Text(
                                      fmtKrw(total.valueKrw),
                                      style: AppText.bigNumber(p, size: 22),
                                    ),
                                  ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  IntrinsicHeight(
                    child: Row(
                      children: [
                        _Stat(value: '${accounts.length}', label: '계좌'),
                        VerticalDivider(color: p.w(0.07), width: 1),
                        _Stat(value: '$holdingCount', label: '보유 종목'),
                        VerticalDivider(color: p.w(0.07), width: 1),
                        _Stat(
                          value: '${domestic.length} / ${international.length}',
                          label: '국내 / 해외',
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (domestic.isNotEmpty) ...[
              const SizedBox(height: 14),
              GroupLabel('국내 · ${domestic.length}'),
              _AccountGroup(lines: domestic, pricesLoading: pricesLoading),
            ],
            if (international.isNotEmpty) ...[
              const SizedBox(height: 14),
              GroupLabel('해외 · ${international.length}'),
              _AccountGroup(lines: international, pricesLoading: pricesLoading),
            ],
          ],
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String value;
  final String label;

  const _Stat({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return Expanded(
      child: Column(
        children: [
          Text(value, style: AppText.num(p, size: 17)),
          const SizedBox(height: 2),
          Text(label, style: AppText.label(p)),
        ],
      ),
    );
  }
}

class _AccountGroup extends StatelessWidget {
  final List<_AccountLine> lines;
  final bool pricesLoading;

  const _AccountGroup({required this.lines, required this.pricesLoading});

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      child: Column(
        children: [
          for (var i = 0; i < lines.length; i++) ...[
            if (i > 0) const RowDivider(),
            _AccountRow(line: lines[i], pricesLoading: pricesLoading),
          ],
        ],
      ),
    );
  }
}

class _AccountRow extends ConsumerWidget {
  final _AccountLine line;
  final bool pricesLoading;

  const _AccountRow({required this.line, required this.pricesLoading});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.pal;
    final a = line.account;
    final t = line.totals;
    final last4 = accountLast4(a.accountNumber);
    final hasValue = t.pricedCount > 0;

    return InkWell(
      onTap: () => showAccountSheet(context, account: a),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 4, 12),
        child: Row(
          children: [
            BrokerLogo(broker: a.broker),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    a.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.body(p, weight: FontWeight.w500),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    [
                      if (a.broker.trim().isNotEmpty) a.broker.trim(),
                      if (last4.isNotEmpty) '••$last4',
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
                  hasValue
                      ? line.inAccountCurrency(t.valueKrw)
                      : (pricesLoading || t.assetCount == 0
                            ? '—'
                            : line.inAccountCurrency(t.costKrw)),
                  style: AppText.num(p),
                ),
                const SizedBox(height: 2),
                Text(
                  '${!hasValue && !pricesLoading && t.assetCount > 0 ? '원금 · ' : ''}${t.assetCount}종목 · ${a.currency}',
                  style: AppText.label(p),
                ),
              ],
            ),
            PopupMenuButton<String>(
              icon: Icon(Icons.more_vert_rounded, size: 18, color: p.zinc.s500),
              tooltip: '계좌 메뉴',
              onSelected: (value) async {
                if (value == 'edit') showAccountSheet(context, account: a);
                if (value == 'delete') await deleteAccount(context, ref, a);
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'edit', child: Text('수정')),
                PopupMenuItem(value: 'delete', child: Text('삭제')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyAccounts extends StatelessWidget {
  final VoidCallback onAdd;

  const _EmptyAccounts({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return Padding(
      padding: const EdgeInsets.only(top: 120),
      child: Column(
        children: [
          const IconTile(AppGlyph.wallet, size: 52),
          const SizedBox(height: 16),
          Text(
            '계좌가 없습니다',
            style: AppText.body(
              p,
              size: 17,
              weight: FontWeight.w600,
              color: p.white,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '자산과 배당을 연결할 계좌를 먼저 추가해 주세요',
            style: AppText.body(p, size: 13, color: p.zinc.s400),
          ),
          const SizedBox(height: 20),
          PrimaryPillButton(
            label: '계좌 추가',
            icon: Icons.add_rounded,
            onPressed: onAdd,
          ),
        ],
      ),
    );
  }
}

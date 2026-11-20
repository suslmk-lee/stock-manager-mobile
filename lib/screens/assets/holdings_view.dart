import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/format.dart';
import '../../core/theme/palette.dart';
import '../../core/theme/typography.dart';
import '../../models/account.dart';
import '../../providers/account_provider.dart';
import '../../providers/asset_provider.dart';
import '../../providers/portfolio_provider.dart';
import '../../providers/price_provider.dart';
import '../../widgets/account_picker.dart';
import '../../widgets/error_retry.dart';
import '../../widgets/ui/app_shell.dart';
import '../../widgets/ui/controls.dart';
import '../../widgets/ui/logos.dart';
import '../../widgets/ui/surfaces.dart';
import '../portfolio/asset_detail_sheet.dart';

/// 종목 목록에서 고른 계좌 (null = 전체 계좌)
final holdingsAccountProvider = StateProvider<int?>((ref) => null);

/// 자산 › 종목: 계좌 고르기 + 합계 + 종목 줄 목록 (평가금액 큰 순)
class HoldingsView extends ConsumerWidget {
  const HoldingsView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.pal;
    final accountsAsync = ref.watch(accountsProvider);
    final accounts = accountsAsync.valueOrNull ?? const <Account>[];
    final picked = ref.watch(holdingsAccountProvider);
    // 계좌가 지워졌으면 전체로 돌아간다
    final selectedId = accounts.any((a) => a.id == picked) ? picked : null;
    final selected = accounts.where((a) => a.id == selectedId).firstOrNull;
    final snapshotAsync = ref.watch(portfolioProvider(selectedId));
    final showKrw = ref.watch(portfolioCurrencyProvider);

    Future<void> refresh() async {
      ref.invalidate(accountsProvider);
      ref.invalidate(assetsProvider);
      ref.invalidate(allTickerPricesProvider);
    }

    Future<void> pickAccount() async {
      final all = ref.read(portfolioProvider(null)).valueOrNull;
      final items = [
        for (final a in accounts)
          _pickItem(
            a,
            buildPortfolio(
              assets: ref.read(assetsProvider).valueOrNull ?? const [],
              prices: ref.read(allTickerPricesProvider).valueOrNull ?? const {},
              fx: ref.read(fxRatesProvider),
              accountId: a.id,
            ),
          ),
      ];
      final choice = await showAccountPicker(
        context,
        items: items,
        selectedId: selectedId,
        allMeta: all == null
            ? null
            : '${accounts.length}계좌 · ${all.totals.assetCount}종목',
      );
      if (choice != null) {
        ref.read(holdingsAccountProvider.notifier).state = choice.id;
      }
    }

    if (accountsAsync.hasError && accountsAsync.valueOrNull == null) {
      return ErrorRetry(
        message: accountsAsync.error.toString(),
        onRetry: refresh,
      );
    }

    return RefreshIndicator(
      edgeOffset: MediaQuery.paddingOf(context).top,
      onRefresh: refresh,
      child: snapshotAsync.when(
        loading: () => ListView(
          padding: listPadding(context),
          children: const [
            SizedBox(height: 160),
            Center(child: CircularProgressIndicator()),
          ],
        ),
        error: (e, _) => ErrorRetry(message: e.toString(), onRetry: refresh),
        data: (snap) {
          final t = snap.totals;
          String total(double krw) => showKrw
              ? fmtKrw(krw)
              : fmtUsd(snap.rate > 0 ? krw / snap.rate : 0);
          final pad = listPadding(context);
          // 종목이 200개가 넘어도 보이는 줄만 만들도록 목록은 SliverList 로,
          // 카드 바탕은 DecoratedSliver 로 목록 전체 뒤에 한 번 그린다.
          return CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverPadding(
                padding: EdgeInsets.fromLTRB(pad.left, pad.top, pad.right, 0),
                sliver: SliverList.list(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Flexible(
                          child: AccountSelectButton(
                            selected: selected,
                            totalCount: accounts.length,
                            onTap: pickAccount,
                          ),
                        ),
                        const SizedBox(width: 8),
                        GlassSegmented<bool>(
                          items: const [(true, 'KRW'), (false, 'USD')],
                          selected: showKrw,
                          onChanged: (v) =>
                              ref
                                      .read(portfolioCurrencyProvider.notifier)
                                      .state =
                                  v,
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    GlassCard(
                      padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${t.assetCount}종목 · 평가금액',
                                  style: AppText.label(p),
                                ),
                                const SizedBox(height: 4),
                                snap.pricesLoading
                                    ? _Placeholder(width: 150, height: 24)
                                    : FittedBox(
                                        fit: BoxFit.scaleDown,
                                        alignment: Alignment.centerLeft,
                                        child: Text(
                                          total(t.valueKrw),
                                          style: AppText.bigNumber(p, size: 22),
                                        ),
                                      ),
                              ],
                            ),
                          ),
                          if (!snap.pricesLoading && t.costKrw > 0)
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text('평가손익', style: AppText.label(p)),
                                const SizedBox(height: 4),
                                Text(
                                  showKrw
                                      ? fmtSignedMoney(t.profitKrw, 'KRW')
                                      : fmtSignedMoney(
                                          t.profitKrw / snap.rate,
                                          'USD',
                                        ),
                                  style: AppText.num(
                                    p,
                                    size: 15,
                                    color: p.trend(t.profitKrw),
                                  ),
                                ),
                                if (t.profitPct != null)
                                  Text(
                                    fmtSignedPct(t.profitPct!),
                                    style: AppText.num(
                                      p,
                                      size: 11,
                                      color: p
                                          .trend(t.profitKrw)
                                          .withValues(alpha: 0.8),
                                    ),
                                  ),
                              ],
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
              if (snap.lines.isEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 60),
                    child: Center(
                      child: Text(
                        '보유 자산이 없습니다',
                        style: AppText.body(p, color: p.zinc.s500),
                      ),
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: EdgeInsets.fromLTRB(
                    pad.left,
                    0,
                    pad.right,
                    pad.bottom,
                  ),
                  sliver: DecoratedSliver(
                    decoration: glassCardDecoration(p),
                    sliver: SliverList.builder(
                      itemCount: snap.lines.length + 1,
                      itemBuilder: (context, i) {
                        if (i == 0) {
                          return Padding(
                            padding: const EdgeInsets.fromLTRB(16, 11, 16, 10),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    '종목',
                                    style: AppText.tableHead(p),
                                  ),
                                ),
                                Text('평가금액 · 수익률', style: AppText.tableHead(p)),
                              ],
                            ),
                          );
                        }
                        final row = Column(
                          children: [
                            const RowDivider(),
                            _HoldingRow(
                              line: snap.lines[i - 1],
                              pricesLoading: snap.pricesLoading,
                            ),
                          ],
                        );
                        return i == snap.lines.length
                            ? ClipRRect(
                                borderRadius: const BorderRadius.vertical(
                                  bottom: Radius.circular(24),
                                ),
                                child: row,
                              )
                            : row;
                      },
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  static AccountPickItem _pickItem(Account a, PortfolioSnapshot s) {
    final t = s.totals;
    String? value;
    if (t.pricedCount > 0) {
      value = a.currency == 'KRW'
          ? fmtKrw(t.valueKrw)
          : fmtUsd(s.rate > 0 ? t.valueKrw / s.rate : 0);
    }
    return AccountPickItem(account: a, value: value, meta: '${t.assetCount}종목');
  }
}

class _HoldingRow extends StatelessWidget {
  final HoldingLine line;
  final bool pricesLoading;

  const _HoldingRow({required this.line, required this.pricesLoading});

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final asset = line.asset;
    final korean = isKrwTicker(asset.ticker);
    final value = line.value;
    final ret = line.returnPct;

    return InkWell(
      onTap: () => showAssetDetailSheet(context, asset),
      onLongPress: () => showAssetDetailSheet(context, asset),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
        child: Row(
          children: [
            TickerLogo(
              ticker: asset.ticker,
              name: asset.name,
              logoUrl: asset.logoUrl,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 국내 종목은 이름, 미국 종목은 티커를 대표로 (데스크톱과 같음)
                  Text(
                    korean ? asset.name : asset.ticker,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.body(
                      p,
                      weight: korean ? FontWeight.w400 : FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${korean ? asset.ticker : asset.name} · ${fmtQty(line.quantity)}주',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.label(p),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            if (value == null && pricesLoading)
              const Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _Placeholder(width: 72, height: 13),
                  SizedBox(height: 5),
                  _Placeholder(width: 40, height: 10),
                ],
              )
            else
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    value == null ? '—' : fmtMoney(value, line.currency),
                    style: AppText.num(p),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    ret == null ? ' ' : fmtSignedPct(ret),
                    style: AppText.num(
                      p,
                      size: 11.5,
                      color: ret == null ? p.zinc.s500 : p.trend(ret),
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

class _Placeholder extends StatelessWidget {
  final double width;
  final double height;

  const _Placeholder({required this.width, required this.height});

  @override
  Widget build(BuildContext context) => Container(
    width: width,
    height: height,
    decoration: BoxDecoration(
      color: context.pal.w(0.07),
      borderRadius: BorderRadius.circular(6),
    ),
  );
}

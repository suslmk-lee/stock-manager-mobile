import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stock_manager/core/theme/app_theme.dart';
import 'package:stock_manager/models/account.dart';
import 'package:stock_manager/models/asset.dart';
import 'package:stock_manager/providers/account_provider.dart';
import 'package:stock_manager/providers/asset_provider.dart';
import 'package:stock_manager/providers/dividend_provider.dart';
import 'package:stock_manager/providers/price_provider.dart';
import 'package:stock_manager/screens/assets/holdings_view.dart';

// 테스트에서 계좌 목록을 바꾸기 위한 상태
final _accountsState = StateProvider<List<Account>>((ref) => []);

Account _account(int id) => Account(
  id: id,
  name: '계좌$id',
  broker: '증권$id',
  accountNumber: '0000-$id',
  marketType: 'Domestic',
  currency: 'KRW',
);

// 계좌 n 에만 있는 종목 '종목n'
Asset _asset(int accountId) => Asset(
  id: accountId,
  ticker: '00000$accountId.KS',
  name: '종목$accountId',
  type: 'Stock',
  logoUrl: '',
  holdings: [
    Holding(
      id: accountId,
      accountId: accountId,
      quantity: 1,
      averagePrice: 1000,
    ),
  ],
);

void main() {
  Future<ProviderContainer> pump(
    WidgetTester tester,
    List<Account> accounts,
  ) async {
    final container = ProviderContainer(
      overrides: [
        // 앱처럼 계좌가 바뀌면 invalidate 로 다시 읽는다
        accountsProvider.overrideWith((ref) async => ref.read(_accountsState)),
        assetsProvider.overrideWith(
          (ref) async => [
            for (final a in ref.read(_accountsState)) _asset(a.id),
          ],
        ),
        allTickerPricesProvider.overrideWith(
          (ref) async => {
            for (final a in ref.read(_accountsState))
              '00000${a.id}.KS': TickerPrice(
                price: 1200,
                currency: 'KRW',
                changePercent: 0,
              ),
          },
        ),
        exchangeRateProvider.overrideWith((ref) async => 1300),
      ],
    );
    addTearDown(container.dispose);
    container.read(_accountsState.notifier).state = accounts;
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AppTheme.dark,
          home: const Scaffold(body: HoldingsView()),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return container;
  }

  Future<void> setAccounts(
    WidgetTester tester,
    ProviderContainer c,
    List<Account> accounts,
  ) async {
    c.read(_accountsState.notifier).state = accounts;
    c.invalidate(accountsProvider);
    c.invalidate(assetsProvider);
    await tester.pumpAndSettle();
  }

  testWidgets('계좌가 0개여도 화면이 열림', (tester) async {
    await pump(tester, []);
    expect(tester.takeException(), isNull);
    expect(find.text('전체 계좌'), findsOneWidget);
    expect(find.text('보유 자산이 없습니다'), findsOneWidget);
  });

  testWidgets('계좌 고르기 시트에서 계좌를 고르면 그 계좌 종목만 보임', (tester) async {
    await pump(tester, [_account(1), _account(2), _account(3)]);
    expect(find.text('종목1'), findsOneWidget);
    expect(find.text('종목3'), findsOneWidget);

    await tester.tap(find.text('전체 계좌'));
    await tester.pumpAndSettle();
    expect(find.text('계좌 고르기'), findsOneWidget);

    await tester.tap(find.text('계좌2'));
    await tester.pumpAndSettle();
    expect(find.text('계좌 고르기'), findsNothing);
    expect(find.text('종목2'), findsOneWidget);
    expect(find.text('종목1'), findsNothing);
    expect(find.text('1종목 · 평가금액'), findsOneWidget);
  });

  testWidgets('보고 있던 계좌가 사라지면 전체 계좌로 돌아감', (tester) async {
    final c = await pump(tester, [_account(1), _account(2)]);
    c.read(holdingsAccountProvider.notifier).state = 2;
    await tester.pumpAndSettle();
    expect(find.text('종목1'), findsNothing);

    await setAccounts(tester, c, [_account(1)]);
    expect(tester.takeException(), isNull);
    expect(find.text('전체 계좌'), findsOneWidget);
    expect(find.text('종목1'), findsOneWidget);

    await setAccounts(tester, c, []);
    expect(tester.takeException(), isNull);
    expect(find.text('보유 자산이 없습니다'), findsOneWidget);
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stock_manager/models/account.dart';
import 'package:stock_manager/models/asset.dart';
import 'package:stock_manager/providers/account_provider.dart';
import 'package:stock_manager/providers/asset_provider.dart';
import 'package:stock_manager/screens/portfolio/portfolio_screen.dart';

// 테스트에서 계좌 목록을 바꾸기 위한 상태
final _accountsState = StateProvider<List<Account>>((ref) => []);

Account _account(int id) => Account(
  id: id,
  name: '계좌$id',
  broker: '증권$id',
  accountNumber: '0000-$id',
  marketType: 'KR',
  currency: 'KRW',
);

void main() {
  Future<ProviderContainer> pumpPortfolio(
    WidgetTester tester,
    List<Account> accounts,
  ) async {
    final container = ProviderContainer(
      overrides: [
        // 앱에서는 계좌 추가/삭제/새로고침 시 ref.invalidate(accountsProvider)로
        // 다시 불러오므로, 테스트도 read + invalidate로 같은 흐름을 재현합니다.
        accountsProvider.overrideWith((ref) async => ref.read(_accountsState)),
        // 보유 종목이 없으면 현재가/환율 조회(네트워크)를 하지 않습니다.
        assetsProvider.overrideWith((ref) async => <Asset>[]),
      ],
    );
    addTearDown(container.dispose);
    container.read(_accountsState.notifier).state = accounts;

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: PortfolioScreen()),
      ),
    );
    await tester.pumpAndSettle();
    return container;
  }

  Future<void> setAccounts(
    WidgetTester tester,
    ProviderContainer container,
    List<Account> accounts,
  ) async {
    container.read(_accountsState.notifier).state = accounts;
    container.invalidate(accountsProvider);
    await tester.pumpAndSettle();
  }

  int selectedTabIndex(WidgetTester tester) =>
      DefaultTabController.of(tester.element(find.byType(TabBarView))).index;

  testWidgets('계좌가 0개여도 화면이 열림 (전체 탭만 표시)', (tester) async {
    await pumpPortfolio(tester, []);

    expect(tester.takeException(), isNull);
    expect(find.text('전체'), findsOneWidget);
    expect(find.byType(Tab), findsOneWidget);
    expect(find.text('보유 자산이 없습니다'), findsOneWidget);
  });

  testWidgets('계좌 수가 늘거나 줄어도 에러 없이 탭이 갱신됨', (tester) async {
    final container = await pumpPortfolio(tester, [_account(1)]);
    expect(find.byType(Tab), findsNWidgets(2));

    await setAccounts(tester, container, [
      _account(1),
      _account(2),
      _account(3),
    ]);
    expect(tester.takeException(), isNull);
    expect(find.byType(Tab), findsNWidgets(4));
    expect(find.text('계좌3'), findsOneWidget);

    await setAccounts(tester, container, [_account(1)]);
    expect(tester.takeException(), isNull);
    expect(find.byType(Tab), findsNWidgets(2));
  });

  testWidgets('마지막 계좌 탭을 보던 중 계좌가 줄면 남은 마지막 탭으로 이동', (tester) async {
    final container = await pumpPortfolio(tester, [
      _account(1),
      _account(2),
      _account(3),
    ]);
    await tester.tap(find.text('계좌3'));
    await tester.pumpAndSettle();
    expect(selectedTabIndex(tester), 3);

    await setAccounts(tester, container, [_account(1)]);
    expect(tester.takeException(), isNull);
    expect(selectedTabIndex(tester), 1);
  });

  testWidgets('계좌가 모두 사라졌다가 다시 생겨도 에러 없음', (tester) async {
    final container = await pumpPortfolio(tester, [_account(1), _account(2)]);

    await setAccounts(tester, container, []);
    expect(tester.takeException(), isNull);
    expect(find.byType(Tab), findsOneWidget);

    await setAccounts(tester, container, [_account(5)]);
    expect(tester.takeException(), isNull);
    expect(find.text('계좌5'), findsOneWidget);
  });
}

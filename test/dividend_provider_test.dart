import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stock_manager/models/account.dart';
import 'package:stock_manager/models/asset.dart';
import 'package:stock_manager/models/dividend.dart';
import 'package:stock_manager/providers/dividend_provider.dart';
import 'package:stock_manager/services/api_service.dart';

class _FakeApi extends ApiService {
  _FakeApi({required this.online});

  final bool online;

  void _ensureOnline() {
    if (!online) throw Exception('offline');
  }

  @override
  Future<List<Account>> getAccounts() async {
    _ensureOnline();
    return [
      Account(
        id: 1,
        name: '미국주식',
        broker: '토스',
        accountNumber: '123-45',
        marketType: 'US',
        currency: 'USD',
      ),
    ];
  }

  @override
  Future<List<Asset>> getAssets() async {
    _ensureOnline();
    return [
      Asset(
        id: 2,
        ticker: 'SCHD',
        name: 'Schwab US Dividend',
        type: 'ETF',
        holdings: [],
      ),
    ];
  }

  @override
  Future<List<Dividend>> getAccountDividends(int accountId) async {
    _ensureOnline();
    return [
      Dividend(
        id: 7,
        accountId: accountId,
        assetId: 2,
        date: '2026-10-15',
        amount: 12,
        tax: 1.8,
        currency: 'USD',
        isReceived: true,
      ),
    ];
  }
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  ProviderContainer makeContainer({required bool online}) {
    final container = ProviderContainer(
      overrides: [
        apiServiceProvider.overrideWithValue(_FakeApi(online: online)),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  group('allDividendsProvider', () {
    test('온라인: 계좌/자산 정보로 배당을 보강', () async {
      final result = await makeContainer(
        online: true,
      ).read(allDividendsProvider.future);

      final d = result.single;
      expect(d.id, 7);
      expect(d.accountName, '미국주식');
      expect(d.accountBroker, '토스');
      expect(d.ticker, 'SCHD');
      expect(d.assetName, 'Schwab US Dividend');
    });

    test('완전 오프라인이어도 캐시된 계좌/자산/배당으로 집계', () async {
      // 온라인 상태에서 한 번 조회해 캐시를 채움
      await makeContainer(online: true).read(allDividendsProvider.future);

      final result = await makeContainer(
        online: false,
      ).read(allDividendsProvider.future);

      final d = result.single;
      expect(d.id, 7);
      expect(d.amount, 12.0);
      expect(d.accountName, '미국주식');
      expect(d.ticker, 'SCHD');
    });

    test('오프라인인데 캐시도 없으면 에러', () async {
      await expectLater(
        makeContainer(online: false).read(allDividendsProvider.future),
        throwsA(isA<Exception>()),
      );
    });
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:stock_manager/models/account.dart';
import 'package:stock_manager/models/asset.dart';
import 'package:stock_manager/models/dividend.dart';

void main() {
  group('Account.fromJson', () {
    test('snake_case / camelCase 키 모두 처리', () {
      final a = Account.fromJson({
        'id': 1,
        'name': '미국주식',
        'broker': '키움',
        'account_number': '123-45',
        'marketType': 'US',
        'currency': 'USD',
      });
      expect(a.accountNumber, '123-45');
      expect(a.marketType, 'US');
      expect(a.description, isNull);
    });
  });

  group('Asset', () {
    test('여러 계좌 보유분의 가중 평균 단가', () {
      final asset = Asset.fromJson({
        'id': 1,
        'ticker': 'SCHD',
        'name': 'Schwab US Dividend',
        'type': 'ETF',
        'holdings': [
          {'id': 1, 'account_id': 1, 'quantity': 10, 'average_price': 70},
          {'id': 2, 'account_id': 2, 'quantity': 30, 'average_price': 80},
        ],
      });
      expect(asset.totalQuantity, 40);
      expect(asset.averagePrice, closeTo(77.5, 1e-9));
    });

    test('보유분이 없으면 평균 단가 0', () {
      final asset = Asset.fromJson({
        'id': 1,
        'ticker': 'O',
        'name': 'Realty Income',
        'type': 'STOCK',
      });
      expect(asset.holdings, isEmpty);
      expect(asset.averagePrice, 0);
    });
  });

  group('Dividend 모델 toJson ↔ fromJson', () {
    test('Dividend', () {
      final d = Dividend.fromJson({
        'id': 7,
        'account_id': 1,
        'asset_id': 2,
        'date': '2026-10-15',
        'amount': 12,
        'tax': 1.8,
        'currency': 'USD',
        'is_received': true,
        'notes': null,
        'asset_name': 'SCHD',
        'ticker': 'SCHD',
      });
      final r = Dividend.fromJson(d.toJson());
      expect(r.id, 7);
      expect(r.amount, 12.0);
      expect(r.tax, 1.8);
      expect(r.isReceived, isTrue);
      expect(r.assetName, 'SCHD');
    });

    test('DividendStats', () {
      final s = DividendStats.fromJson({
        'total_dividends_usd': 100,
        'total_dividends_krw': 50000,
        'total_tax_usd': 15,
        'total_tax_krw': 7000,
        'received_count': 3,
        'pending_count': 1,
      });
      final r = DividendStats.fromJson(s.toJson());
      expect(r.totalDividendsUsd, 100.0);
      expect(r.totalTaxKrw, 7000.0);
      expect(r.pendingCount, 1);
    });

    test('MonthlyDividend: year/month 응답도 label로 변환', () {
      final m = MonthlyDividend.fromJson({
        'year': 2026,
        'month': 3,
        'total_amount': 42.5,
        'count': 2,
      });
      expect(m.month, '2026-03');
      expect(m.totalUsd, 42.5);

      final r = MonthlyDividend.fromJson(m.toJson());
      expect(r.month, '2026-03');
      expect(r.totalUsd, 42.5);
      expect(r.count, 2);
    });
  });
}

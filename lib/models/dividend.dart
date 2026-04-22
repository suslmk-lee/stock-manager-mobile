class Dividend {
  final int id;
  final int accountId;
  final int assetId;
  final String date;
  final double amount;
  final double tax;
  final String currency;
  final bool isReceived;
  final String? notes;
  final String? assetName;
  final String? ticker;
  final String? accountName;
  final String? accountBroker;

  Dividend({
    required this.id,
    required this.accountId,
    required this.assetId,
    required this.date,
    required this.amount,
    required this.tax,
    required this.currency,
    required this.isReceived,
    this.notes,
    this.assetName,
    this.ticker,
    this.accountName,
    this.accountBroker,
  });

  factory Dividend.fromJson(Map<String, dynamic> json) => Dividend(
        id: json['id'],
        accountId: json['account_id'],
        assetId: json['asset_id'],
        date: json['date'],
        amount: (json['amount'] as num).toDouble(),
        tax: (json['tax'] as num).toDouble(),
        currency: json['currency'],
        isReceived: json['is_received'] ?? json['isReceived'] ?? false,
        notes: json['notes'],
        assetName: json['asset_name'] ?? json['assetName'],
        ticker: json['ticker'],
      );
}

class DividendStats {
  final double totalDividendsUsd;
  final double totalDividendsKrw;
  final double totalTaxUsd;
  final double totalTaxKrw;
  final int receivedCount;
  final int pendingCount;

  DividendStats({
    required this.totalDividendsUsd,
    required this.totalDividendsKrw,
    required this.totalTaxUsd,
    required this.totalTaxKrw,
    required this.receivedCount,
    required this.pendingCount,
  });

  factory DividendStats.fromJson(Map<String, dynamic> json) => DividendStats(
        totalDividendsUsd: (json['total_dividends_usd'] as num).toDouble(),
        totalDividendsKrw: (json['total_dividends_krw'] as num).toDouble(),
        totalTaxUsd: (json['total_tax_usd'] as num).toDouble(),
        totalTaxKrw: (json['total_tax_krw'] as num).toDouble(),
        receivedCount: json['received_count'],
        pendingCount: json['pending_count'],
      );
}

class MonthlyDividend {
  final String month; // "2026-01" 형식 (label 필드)
  final double totalUsd;
  final double totalKrw;
  final int count;

  MonthlyDividend({
    required this.month,
    required this.totalUsd,
    required this.totalKrw,
    required this.count,
  });

  factory MonthlyDividend.fromJson(Map<String, dynamic> json) => MonthlyDividend(
        month: json['label'] ?? '${json['year']}-${json['month'].toString().padLeft(2, '0')}',
        totalUsd: ((json['total_usd'] ?? json['total_amount'] ?? 0) as num).toDouble(),
        totalKrw: ((json['total_krw'] ?? 0) as num).toDouble(),
        count: (json['count'] ?? 0) as int,
      );
}

class Holding {
  final int id;
  final int accountId;
  final double quantity;
  final double averagePrice;

  Holding({
    required this.id,
    required this.accountId,
    required this.quantity,
    required this.averagePrice,
  });

  factory Holding.fromJson(Map<String, dynamic> json) => Holding(
        id: json['id'],
        accountId: json['account_id'] ?? json['accountId'] ?? 0,
        quantity: ((json['quantity'] ?? 0) as num).toDouble(),
        averagePrice: ((json['average_price'] ?? json['averagePrice'] ?? 0) as num).toDouble(),
      );
}

class Asset {
  final int id;
  final String ticker;
  final String name;
  final String type;
  final String? sector;
  final List<Holding> holdings;

  Asset({
    required this.id,
    required this.ticker,
    required this.name,
    required this.type,
    this.sector,
    required this.holdings,
  });

  double get totalQuantity =>
      holdings.fold(0, (sum, h) => sum + h.quantity);

  double get averagePrice {
    if (holdings.isEmpty) return 0;
    final totalCost = holdings.fold(0.0, (sum, h) => sum + h.quantity * h.averagePrice);
    return totalQuantity > 0 ? totalCost / totalQuantity : 0;
  }

  factory Asset.fromJson(Map<String, dynamic> json) => Asset(
        id: json['id'],
        ticker: json['ticker'],
        name: json['name'],
        type: json['type'],
        sector: json['sector'],
        holdings: (json['holdings'] as List<dynamic>? ?? [])
            .map((h) => Holding.fromJson(h))
            .toList(),
      );
}

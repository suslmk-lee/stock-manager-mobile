class Transaction {
  final int id;
  final int accountId;
  final int assetId;
  final String type;
  final String date;
  final double price;
  final double quantity;
  final double fee;
  final String? notes;
  final String? ticker;
  final String? assetName;

  Transaction({
    required this.id,
    required this.accountId,
    required this.assetId,
    required this.type,
    required this.date,
    required this.price,
    required this.quantity,
    required this.fee,
    this.notes,
    this.ticker,
    this.assetName,
  });

  double get total => price * quantity + fee;

  factory Transaction.fromJson(Map<String, dynamic> json) => Transaction(
        id: json['id'],
        accountId: json['account_id'],
        assetId: json['asset_id'],
        type: json['type'],
        date: json['date'],
        price: (json['price'] as num).toDouble(),
        quantity: (json['quantity'] as num).toDouble(),
        fee: (json['fee'] as num).toDouble(),
        notes: json['notes'],
        ticker: json['ticker'],
        assetName: json['asset_name'] ?? json['assetName'],
      );
}

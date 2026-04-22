class Account {
  final int id;
  final String name;
  final String broker;
  final String accountNumber;
  final String marketType;
  final String currency;
  final String? description;

  Account({
    required this.id,
    required this.name,
    required this.broker,
    required this.accountNumber,
    required this.marketType,
    required this.currency,
    this.description,
  });

  factory Account.fromJson(Map<String, dynamic> json) => Account(
        id: json['id'],
        name: json['name'],
        broker: json['broker'],
        accountNumber: json['accountNumber'] ?? json['account_number'] ?? '',
        marketType: json['market_type'] ?? json['marketType'] ?? '',
        currency: json['currency'],
        description: json['description'],
      );
}

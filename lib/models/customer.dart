class Customer {
  final int id;
  final String name;
  final String? shopName;
  final String mobile;
  final String? mobileSecondary;
  final String? location;
  final double creditBalance;

  Customer({
    required this.id,
    required this.name,
    required this.mobile,
    this.shopName,
    this.mobileSecondary,
    this.location,
    this.creditBalance = 0,
  });

  factory Customer.fromJson(Map<String, dynamic> json) {
    return Customer(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      mobile: json['mobile'] ?? '',
      shopName: json['shop_name'],
      mobileSecondary: json['mobile_secondary'],
      location: json['location'],
      creditBalance: double.tryParse(json['credit_balance']?.toString() ?? '0') ?? 0,
    );
  }
}

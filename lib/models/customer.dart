class Customer {
  final int id;
  final String name;
  final String? shopName;
  final String mobile;
  final String? mobileSecondary;
  final String? location;
  final double creditBalance;
  final double extraAmount;
  final String? displayName;
  final int? totalBills;
  final double? totalSpent;
  final List<Map<String, dynamic>> recentBills;
  final DateTime? createdAt;

  Customer({
    required this.id,
    required this.name,
    required this.mobile,
    this.shopName,
    this.mobileSecondary,
    this.location,
    this.creditBalance = 0,
    this.extraAmount = 0,
    this.displayName,
    this.totalBills,
    this.totalSpent,
    this.recentBills = const [],
    this.createdAt,
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
      extraAmount: double.tryParse(json['extra_amount']?.toString() ?? '0') ?? 0,
      displayName: json['display_name'],
      totalBills: json['total_bills'],
      totalSpent: json['total_spent'] != null
          ? double.tryParse(json['total_spent'].toString())
          : null,
      recentBills: json['recent_bills'] != null
          ? List<Map<String, dynamic>>.from(json['recent_bills'])
          : [],
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'])
          : null,
    );
  }
}

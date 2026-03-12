class Customer {
  final int id;
  final String name;
  final String? shopName;
  final String mobile;
  final String? mobileSecondary;
  final String? location;
  final double creditBalance;
  final double extraAmount;
<<<<<<< HEAD
  final bool hasCredit;
  final bool hasExtra;
  final String? displayName;
=======
  final String? displayName;
  final int? totalBills;
  final double? totalSpent;
  final List<Map<String, dynamic>> recentBills;
  final DateTime? createdAt;
>>>>>>> 2794856b839bffc7c894d0fa96d70a95b4821349

  Customer({
    required this.id,
    required this.name,
    required this.mobile,
    this.shopName,
    this.mobileSecondary,
    this.location,
    this.creditBalance = 0,
    this.extraAmount = 0,
<<<<<<< HEAD
    this.hasCredit = false,
    this.hasExtra = false,
    this.displayName,
=======
    this.displayName,
    this.totalBills,
    this.totalSpent,
    this.recentBills = const [],
    this.createdAt,
>>>>>>> 2794856b839bffc7c894d0fa96d70a95b4821349
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
<<<<<<< HEAD
      hasCredit: json['has_credit'] ?? false,
      hasExtra: json['has_extra'] ?? false,
      displayName: json['display_name'],
=======
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
>>>>>>> 2794856b839bffc7c894d0fa96d70a95b4821349
    );
  }
}

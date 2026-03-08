class DashboardData {
  final DashboardStats stats;
  final QuickStats quickStats;
  final List<DashboardBill> recentBills;

  DashboardData({
    required this.stats,
    required this.quickStats,
    required this.recentBills,
  });

  factory DashboardData.fromJson(Map<String, dynamic> json) {
    return DashboardData(
      stats: DashboardStats.fromJson(json['stats'] ?? {}),
      quickStats: QuickStats.fromJson(json['quick_stats'] ?? {}),
      recentBills: json['recent_bills'] != null
          ? (json['recent_bills'] as List)
              .map((e) => DashboardBill.fromJson(e))
              .toList()
          : [],
    );
  }
}

class DashboardStats {
  final double totalCreditBalance;
  final double totalExtraAmount;
  final double todaySales;
  final int todayBillCount;

  DashboardStats({
    this.totalCreditBalance = 0,
    this.totalExtraAmount = 0,
    this.todaySales = 0,
    this.todayBillCount = 0,
  });

  factory DashboardStats.fromJson(Map<String, dynamic> json) {
    return DashboardStats(
      totalCreditBalance: double.tryParse(json['total_credit_balance']?.toString() ?? '0') ?? 0,
      totalExtraAmount: double.tryParse(json['total_extra_amount']?.toString() ?? '0') ?? 0,
      todaySales: double.tryParse(json['today_sales']?.toString() ?? '0') ?? 0,
      todayBillCount: int.tryParse(json['today_bill_count']?.toString() ?? '0') ?? 0,
    );
  }
}

class QuickStats {
  final int activeProducts;
  final int totalCustomers;

  QuickStats({this.activeProducts = 0, this.totalCustomers = 0});

  factory QuickStats.fromJson(Map<String, dynamic> json) {
    return QuickStats(
      activeProducts: int.tryParse(json['active_products']?.toString() ?? '0') ?? 0,
      totalCustomers: int.tryParse(json['total_customers']?.toString() ?? '0') ?? 0,
    );
  }
}

class DashboardBill {
  final int id;
  final String billNumber;
  final String customerName;
  final String customerShop;
  final double total;
  final double creditAmount;
  final String status;
  final String timeAgo;
  final DateTime? createdAt;

  DashboardBill({
    required this.id,
    required this.billNumber,
    this.customerName = '',
    this.customerShop = '',
    this.total = 0,
    this.creditAmount = 0,
    this.status = 'completed',
    this.timeAgo = '',
    this.createdAt,
  });

  factory DashboardBill.fromJson(Map<String, dynamic> json) {
    return DashboardBill(
      id: json['id'] ?? 0,
      billNumber: json['bill_number'] ?? '',
      customerName: json['customer_name'] ?? '',
      customerShop: json['customer_shop'] ?? '',
      total: double.tryParse(json['total']?.toString() ?? '0') ?? 0,
      creditAmount: double.tryParse(json['credit_amount']?.toString() ?? '0') ?? 0,
      status: json['status'] ?? 'completed',
      timeAgo: json['time_ago'] ?? '',
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at']) : null,
    );
  }
}

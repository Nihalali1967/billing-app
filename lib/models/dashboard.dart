class DashboardData {
  final TodayData today;
  final TotalsData totals;
  final List<DaySales> last7Days;
  final List<Map<String, dynamic>> recentBills;
  final List<Map<String, dynamic>> topCustomers;

  DashboardData({
    required this.today,
    required this.totals,
    required this.last7Days,
    required this.recentBills,
    required this.topCustomers,
  });

  factory DashboardData.fromJson(Map<String, dynamic> json) {
    return DashboardData(
      today: TodayData.fromJson(json['today'] ?? {}),
      totals: TotalsData.fromJson(json['totals'] ?? {}),
      last7Days: json['last_7_days'] != null
          ? (json['last_7_days'] as List)
              .map((e) => DaySales.fromJson(e))
              .toList()
          : [],
      recentBills: json['recent_bills'] != null
          ? List<Map<String, dynamic>>.from(json['recent_bills'])
          : [],
      topCustomers: json['top_customers'] != null
          ? List<Map<String, dynamic>>.from(json['top_customers'])
          : [],
    );
  }
}

class TodayData {
  final double sales;
  final double collected;
  final double credit;
  final int billCount;

  TodayData({
    this.sales = 0,
    this.collected = 0,
    this.credit = 0,
    this.billCount = 0,
  });

  factory TodayData.fromJson(Map<String, dynamic> json) {
    return TodayData(
      sales: double.tryParse(json['sales']?.toString() ?? '0') ?? 0,
      collected: double.tryParse(json['collected']?.toString() ?? '0') ?? 0,
      credit: double.tryParse(json['credit']?.toString() ?? '0') ?? 0,
      billCount: json['bill_count'] ?? 0,
    );
  }
}

class TotalsData {
  final int customers;
  final int products;
  final double creditBalance;

  TotalsData({
    this.customers = 0,
    this.products = 0,
    this.creditBalance = 0,
  });

  factory TotalsData.fromJson(Map<String, dynamic> json) {
    return TotalsData(
      customers: json['customers'] ?? 0,
      products: json['products'] ?? 0,
      creditBalance: double.tryParse(json['credit_balance']?.toString() ?? '0') ?? 0,
    );
  }
}

class DaySales {
  final String date;
  final String day;
  final double sales;

  DaySales({required this.date, required this.day, required this.sales});

  factory DaySales.fromJson(Map<String, dynamic> json) {
    return DaySales(
      date: json['date'] ?? '',
      day: json['day'] ?? '',
      sales: double.tryParse(json['sales']?.toString() ?? '0') ?? 0,
    );
  }
}

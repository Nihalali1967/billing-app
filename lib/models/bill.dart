class BillItem {
  final int? id;
  final int productId;
  final String? productName;
  final String? unitType;
  final double quantity;
  final double unitPrice;
  final double? customPrice;
  final bool isCustomPrice;
  final double? effectivePriceFromApi;
  final double total;

  BillItem({
    this.id,
    required this.productId,
    this.productName,
    this.unitType,
    required this.quantity,
    required this.unitPrice,
    this.customPrice,
    this.isCustomPrice = false,
    this.effectivePriceFromApi,
    this.total = 0,
  });

  factory BillItem.fromJson(Map<String, dynamic> json) {
    return BillItem(
      id: json['id'],
      productId: json['product_id'] ?? 0,
      productName: json['product'] != null
          ? json['product']['name']
          : json['product_name'],
      unitType: json['unit_type'],
      quantity: double.tryParse(json['quantity']?.toString() ?? '1') ?? 1,
      unitPrice: double.tryParse(json['unit_price']?.toString() ?? '0') ?? 0,
      customPrice: json['custom_price'] != null
          ? double.tryParse(json['custom_price'].toString())
          : null,
      isCustomPrice: json['is_custom_price'] ?? false,
      effectivePriceFromApi: json['effective_price'] != null
          ? double.tryParse(json['effective_price'].toString())
          : null,
      total: double.tryParse(json['total']?.toString() ?? '0') ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'product_id': productId,
      'quantity': quantity,
      'unit_price': unitPrice,
      'custom_price': customPrice,
      'is_custom_price': isCustomPrice,
    };
  }

  double get effectivePrice => isCustomPrice ? (customPrice ?? unitPrice) : unitPrice;
  double get lineTotal => effectivePrice * quantity;
}

class Bill {
  final int id;
  final String billNumber;
  final int customerId;
  final String? customerName;
  final String? customerShop;
  final String? customerMobile;
  final String? customerLocation;
  final double customerCreditBalance;
  final double customerExtraAmount;
  final double subtotal;
  final double discount;
  final double total;
  final double collectedAmount;
  final double creditAmount;
  final double previousCredit;
  final String status;
  final String? notes;
  final String? billedByName;
  final int? billedById;
  final List<BillItem> items;
  final String? date;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Bill({
    required this.id,
    required this.billNumber,
    required this.customerId,
    this.customerName,
    this.customerShop,
    this.customerMobile,
    this.customerLocation,
    this.customerCreditBalance = 0,
    this.customerExtraAmount = 0,
    this.subtotal = 0,
    this.discount = 0,
    required this.total,
    required this.collectedAmount,
    this.creditAmount = 0,
    this.previousCredit = 0,
    this.status = 'completed',
    this.notes,
    this.billedByName,
    this.billedById,
    this.items = const [],
    this.date,
    this.createdAt,
    this.updatedAt,
  });

  factory Bill.fromJson(Map<String, dynamic> json) {
    final customer = json['customer'];
    final billedBy = json['billed_by'];

    String? billedByName;
    int? billedById;
    if (billedBy is Map<String, dynamic>) {
      billedByName = billedBy['name'];
      billedById = billedBy['id'];
    } else if (billedBy is String) {
      billedByName = billedBy;
    }

    return Bill(
      id: json['id'] ?? 0,
      billNumber: json['bill_number'] ?? '',
      customerId: json['customer_id'] ?? customer?['id'] ?? 0,
      customerName: json['customer_name'] ?? customer?['name'],
      customerShop: json['customer_shop'] ?? customer?['shop_name'],
      customerMobile: json['customer_mobile'] ?? customer?['mobile'],
      customerLocation: customer?['location'],
      customerCreditBalance: customer != null
          ? (double.tryParse(customer['credit_balance']?.toString() ?? '0') ?? 0)
          : 0,
      customerExtraAmount: customer != null
          ? (double.tryParse(customer['extra_amount']?.toString() ?? '0') ?? 0)
          : 0,
      subtotal: double.tryParse(json['subtotal']?.toString() ?? '0') ?? 0,
      discount: double.tryParse(json['discount']?.toString() ?? '0') ?? 0,
      total: double.tryParse(json['total']?.toString() ?? '0') ?? 0,
      collectedAmount: double.tryParse(json['collected_amount']?.toString() ?? '0') ?? 0,
      creditAmount: double.tryParse(json['credit_amount']?.toString() ?? '0') ?? 0,
      previousCredit: double.tryParse(json['previous_credit']?.toString() ?? '0') ?? 0,
      status: json['status'] ?? 'completed',
      notes: json['notes'],
      billedByName: billedByName,
      billedById: billedById,
      items: json['items'] != null
          ? (json['items'] as List).map((e) => BillItem.fromJson(e)).toList()
          : [],
      date: json['date'],
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'])
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'])
          : null,
    );
  }
}

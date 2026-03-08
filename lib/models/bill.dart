class BillItem {
  final int? id;
  final int productId;
  final String? productName;
  final String? productUnit;
  final int? index;
  final double quantity;
  final double unitPrice;
  final double? customPrice;
  final bool isCustomPrice;
  final double total;

  BillItem({
    this.id,
    this.productId = 0,
    this.productName,
    this.productUnit,
    this.index,
    required this.quantity,
    required this.unitPrice,
    this.customPrice,
    this.isCustomPrice = false,
    this.total = 0,
  });

  factory BillItem.fromJson(Map<String, dynamic> json) {
    return BillItem(
      id: json['id'],
      productId: json['product_id'] ?? 0,
      productName: json['product_name'] ?? json['product']?['name'],
      productUnit: json['product_unit'],
      index: json['index'],
      quantity: double.tryParse(json['quantity']?.toString() ?? '1') ?? 1,
      unitPrice: double.tryParse(json['unit_price']?.toString() ?? '0') ?? 0,
      customPrice: json['custom_price'] != null
          ? double.tryParse(json['custom_price'].toString())
          : null,
      isCustomPrice: json['is_custom_price'] ?? false,
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
  final double subtotal;
  final double discount;
  final double total;
  final double collectedAmount;
  final double creditAmount;
  final bool hasCredit;
  final double previousCredit;
  final bool hasPreviousCredit;
  final double customerCreditBalance;
  final double customerExtraAmount;
  final String status;
  final String? date;
  final String? time;
  final String? notes;
  final String? billedBy;
  final int? userId;
  final List<BillItem> items;
  final DateTime? createdAt;
  final String? whatsappMessage;
  final String? whatsappUrl;

  Bill({
    required this.id,
    required this.billNumber,
    this.customerId = 0,
    this.customerName,
    this.customerShop,
    this.customerMobile,
    this.customerLocation,
    this.subtotal = 0,
    this.discount = 0,
    this.total = 0,
    this.collectedAmount = 0,
    this.creditAmount = 0,
    this.hasCredit = false,
    this.previousCredit = 0,
    this.hasPreviousCredit = false,
    this.customerCreditBalance = 0,
    this.customerExtraAmount = 0,
    this.status = 'completed',
    this.date,
    this.time,
    this.notes,
    this.billedBy,
    this.userId,
    this.items = const [],
    this.createdAt,
    this.whatsappMessage,
    this.whatsappUrl,
  });

  // Parse from bills list response (flat structure)
  factory Bill.fromListJson(Map<String, dynamic> json) {
    return Bill(
      id: json['id'] ?? 0,
      billNumber: json['bill_number'] ?? '',
      customerName: json['customer_name'],
      customerShop: json['customer_shop'],
      total: double.tryParse(json['total']?.toString() ?? '0') ?? 0,
      collectedAmount: double.tryParse(json['collected_amount']?.toString() ?? '0') ?? 0,
      creditAmount: double.tryParse(json['credit_amount']?.toString() ?? '0') ?? 0,
      hasCredit: json['has_credit'] ?? false,
      billedBy: json['billed_by'],
      date: json['date'],
      time: json['time'],
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at']) : null,
    );
  }

  // Parse from bill detail response (structured with bill, items, customer, payment, whatsapp)
  factory Bill.fromDetailJson(Map<String, dynamic> json) {
    final bill = json['bill'] ?? {};
    final customer = json['customer'];
    final payment = json['payment'] ?? {};
    final whatsapp = json['whatsapp'];
    final itemsList = json['items'] as List? ?? [];

    return Bill(
      id: bill['id'] ?? 0,
      billNumber: bill['bill_number'] ?? '',
      customerId: customer?['id'] ?? 0,
      customerName: customer?['name'],
      customerShop: customer?['shop_name'],
      customerMobile: customer?['mobile'],
      customerLocation: customer?['location'],
      customerCreditBalance: double.tryParse(customer?['credit_balance']?.toString() ?? '0') ?? 0,
      customerExtraAmount: double.tryParse(customer?['extra_amount']?.toString() ?? '0') ?? 0,
      subtotal: double.tryParse(payment['subtotal']?.toString() ?? '0') ?? 0,
      discount: double.tryParse(payment['discount']?.toString() ?? '0') ?? 0,
      total: double.tryParse(payment['total']?.toString() ?? '0') ?? 0,
      collectedAmount: double.tryParse(payment['collected_amount']?.toString() ?? '0') ?? 0,
      creditAmount: double.tryParse(payment['credit_amount']?.toString() ?? '0') ?? 0,
      hasCredit: payment['has_credit'] ?? false,
      previousCredit: double.tryParse(payment['previous_credit']?.toString() ?? '0') ?? 0,
      hasPreviousCredit: payment['has_previous_credit'] ?? false,
      status: bill['status'] ?? 'completed',
      date: bill['date'],
      notes: bill['notes'],
      billedBy: bill['billed_by'],
      items: itemsList.map((e) => BillItem.fromJson(e)).toList(),
      createdAt: bill['created_at'] != null ? DateTime.tryParse(bill['created_at']) : null,
      whatsappMessage: whatsapp?['message'],
      whatsappUrl: whatsapp?['whatsapp_url'],
    );
  }
}

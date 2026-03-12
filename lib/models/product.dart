class Product {
  final int id;
  final String name;
  final double price;
  final String? unitType;
<<<<<<< HEAD
  final double? unitAmount;
  final String? formattedUnit;
  final int stockQty;
  final String? stockStatus;
  final String? barcode;
=======
>>>>>>> 2794856b839bffc7c894d0fa96d70a95b4821349
  final bool isActive;
  final String? imageUrl;
  final String? description;
  final DateTime? createdAt;

  Product({
    required this.id,
    required this.name,
    required this.price,
    this.unitType,
<<<<<<< HEAD
    this.unitAmount,
    this.formattedUnit,
    this.stockQty = 0,
    this.stockStatus,
    this.barcode,
=======
>>>>>>> 2794856b839bffc7c894d0fa96d70a95b4821349
    this.isActive = true,
    this.imageUrl,
    this.description,
    this.createdAt,
  });

  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      price: double.tryParse(json['price']?.toString() ?? '0') ?? 0,
      unitType: json['unit_type'],
<<<<<<< HEAD
      unitAmount: json['unit_amount'] != null
          ? double.tryParse(json['unit_amount'].toString())
          : null,
      formattedUnit: json['formatted_unit'],
      stockQty: int.tryParse(json['stock_qty']?.toString() ?? '0') ?? 0,
      stockStatus: json['stock_status'],
      barcode: json['barcode'],
=======
>>>>>>> 2794856b839bffc7c894d0fa96d70a95b4821349
      isActive: json['is_active'] ?? true,
      imageUrl: json['image_url'],
      description: json['description'],
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'])
          : null,
    );
  }
<<<<<<< HEAD

  String get displayUnit {
    if (formattedUnit != null && formattedUnit!.isNotEmpty) return formattedUnit!;
    if (unitType != null && unitAmount != null) {
      return '${unitAmount!.toStringAsFixed(unitAmount! == unitAmount!.toInt() ? 0 : 1)} $unitType';
    }
    return '';
  }
=======
>>>>>>> 2794856b839bffc7c894d0fa96d70a95b4821349
}

class Product {
  final int id;
  final String name;
  final double price;
  final String? unitType;
  final double? unitAmount;
  final String? formattedUnit;
  final int stockQty;
  final String? stockStatus;
  final String? barcode;
  final bool isActive;
  final String? image;
  final String? description;

  Product({
    required this.id,
    required this.name,
    required this.price,
    this.unitType,
    this.unitAmount,
    this.formattedUnit,
    this.stockQty = 0,
    this.stockStatus,
    this.barcode,
    this.isActive = true,
    this.image,
    this.description,
  });

  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      price: double.tryParse(json['price']?.toString() ?? '0') ?? 0,
      unitType: json['unit_type'],
      unitAmount: json['unit_amount'] != null
          ? double.tryParse(json['unit_amount'].toString())
          : null,
      formattedUnit: json['formatted_unit'],
      stockQty: int.tryParse(json['stock_qty']?.toString() ?? '0') ?? 0,
      stockStatus: json['stock_status'],
      barcode: json['barcode'],
      isActive: json['is_active'] ?? true,
      image: json['image'],
      description: json['description'],
    );
  }

  String get displayUnit {
    if (formattedUnit != null && formattedUnit!.isNotEmpty) return formattedUnit!;
    if (unitType != null && unitAmount != null) {
      return '${unitAmount!.toStringAsFixed(unitAmount! == unitAmount!.toInt() ? 0 : 1)} $unitType';
    }
    return '';
  }
}

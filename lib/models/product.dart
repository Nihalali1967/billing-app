class Product {
  final int id;
  final String name;
  final double price;
  final String? unitType;
  final double? unitAmount;
  final int? stockQty;
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
    this.stockQty,
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
      stockQty: json['stock_qty'],
      barcode: json['barcode'],
      isActive: json['is_active'] ?? true,
      image: json['image'],
      description: json['description'],
    );
  }

  String get displayUnit {
    if (unitType != null && unitAmount != null) {
      return '${unitAmount!.toStringAsFixed(unitAmount! == unitAmount!.toInt() ? 0 : 1)} $unitType';
    }
    return '';
  }
}

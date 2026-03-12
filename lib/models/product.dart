class Product {
  final int id;
  final String name;
  final double price;
  final String? unitType;
  final bool isActive;
  final String? imageUrl;
  final String? description;
  final DateTime? createdAt;

  Product({
    required this.id,
    required this.name,
    required this.price,
    this.unitType,
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
      isActive: json['is_active'] ?? true,
      imageUrl: json['image_url'],
      description: json['description'],
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'])
          : null,
    );
  }
}

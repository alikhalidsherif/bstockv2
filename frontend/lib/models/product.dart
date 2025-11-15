import 'variant.dart';

class Product {
  final String id;
  final String name;
  final String? description;
  final String? category;
  final String? imageUrl;
  final String? vendorId;
  final List<Variant> variants;
  final DateTime? createdAt;

  Product({
    required this.id,
    required this.name,
    this.description,
    this.category,
    this.imageUrl,
    this.vendorId,
    required this.variants,
    this.createdAt,
  });

  // Get the default variant (first one)
  Variant get defaultVariant => variants.isNotEmpty
      ? variants.first
      : Variant(
          id: '',
          productId: id,
          sku: '',
          attributes: {},
          salePrice: 0,
          quantity: 0,
        );

  // Check if any variant is low stock
  bool get hasLowStock => variants.any((v) => v.isLowStock);

  // Total quantity across all variants
  int get totalQuantity => variants.fold(0, (sum, v) => sum + v.quantity);

  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      id: json['id'].toString(),
      name: json['name'] ?? '',
      description: json['description'],
      category: json['category'],
      imageUrl: json['image_url'],
      vendorId: json['vendor_id']?.toString(),
      variants: (json['variants'] as List<dynamic>?)
              ?.map((v) => Variant.fromJson(v))
              .toList() ??
          [],
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'description': description,
      'category': category,
      'image_url': imageUrl,
      'vendor_id': vendorId,
      'variants': variants.map((v) => v.toJson()).toList(),
    };
  }
}

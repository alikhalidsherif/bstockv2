class Variant {
  final String id;
  final String productId;
  final String sku;
  final Map<String, String> attributes;
  final double? purchasePrice;
  final double salePrice;
  final int quantity;
  final int? minStockLevel;
  final DateTime? createdAt;

  Variant({
    required this.id,
    required this.productId,
    required this.sku,
    required this.attributes,
    this.purchasePrice,
    required this.salePrice,
    required this.quantity,
    this.minStockLevel,
    this.createdAt,
  });

  bool get isLowStock {
    if (minStockLevel == null) return false;
    return quantity <= minStockLevel!;
  }

  factory Variant.fromJson(Map<String, dynamic> json) {
    return Variant(
      id: json['id'].toString(),
      productId: json['product_id'].toString(),
      sku: json['sku'] ?? '',
      attributes: Map<String, String>.from(json['attributes'] ?? {}),
      purchasePrice: json['purchase_price']?.toDouble(),
      salePrice: (json['sale_price'] ?? 0).toDouble(),
      quantity: json['quantity'] ?? 0,
      minStockLevel: json['min_stock_level'],
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'sku': sku,
      'attributes': attributes,
      'purchase_price': purchasePrice,
      'sale_price': salePrice,
      'quantity': quantity,
      'min_stock_level': minStockLevel,
    };
  }

  String get displayName {
    if (attributes.isEmpty) return sku;
    return attributes.values.join(' / ');
  }
}

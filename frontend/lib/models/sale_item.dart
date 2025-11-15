import 'variant.dart';

class SaleItem {
  final String? id;
  final String variantId;
  final String productName;
  final String variantSku;
  final String variantDisplayName;
  final double unitPrice;
  final int quantity;
  final double subtotal;
  final Variant? variant; // For UI display purposes

  SaleItem({
    this.id,
    required this.variantId,
    required this.productName,
    required this.variantSku,
    required this.variantDisplayName,
    required this.unitPrice,
    required this.quantity,
    required this.subtotal,
    this.variant,
  });

  // Factory constructor for cart items (before sale is created)
  factory SaleItem.fromVariant({
    required Variant variant,
    required String productName,
    required int quantity,
  }) {
    final subtotal = variant.salePrice * quantity;
    return SaleItem(
      variantId: variant.id,
      productName: productName,
      variantSku: variant.sku,
      variantDisplayName: variant.displayName,
      unitPrice: variant.salePrice,
      quantity: quantity,
      subtotal: subtotal,
      variant: variant,
    );
  }

  factory SaleItem.fromJson(Map<String, dynamic> json) {
    return SaleItem(
      id: json['id']?.toString(),
      variantId: json['variant_id'].toString(),
      productName: json['product_name'] ?? '',
      variantSku: json['variant_sku'] ?? '',
      variantDisplayName: json['variant_display_name'] ?? '',
      unitPrice: (json['unit_price'] ?? 0).toDouble(),
      quantity: json['quantity'] ?? 0,
      subtotal: (json['subtotal'] ?? 0).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'variant_id': variantId,
      'unit_price': unitPrice,
      'quantity': quantity,
    };
  }

  // Create a copy with updated quantity
  SaleItem copyWith({
    String? id,
    String? variantId,
    String? productName,
    String? variantSku,
    String? variantDisplayName,
    double? unitPrice,
    int? quantity,
    double? subtotal,
    Variant? variant,
  }) {
    final newQuantity = quantity ?? this.quantity;
    final newUnitPrice = unitPrice ?? this.unitPrice;
    return SaleItem(
      id: id ?? this.id,
      variantId: variantId ?? this.variantId,
      productName: productName ?? this.productName,
      variantSku: variantSku ?? this.variantSku,
      variantDisplayName: variantDisplayName ?? this.variantDisplayName,
      unitPrice: newUnitPrice,
      quantity: newQuantity,
      subtotal: subtotal ?? (newUnitPrice * newQuantity),
      variant: variant ?? this.variant,
    );
  }
}

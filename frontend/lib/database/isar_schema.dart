import 'package:isar/isar.dart';

part 'isar_schema.g.dart';

/// Local product collection for offline caching
@collection
class LocalProduct {
  Id? id;

  @Index()
  String? serverId; // UUID from server

  String? name;
  String? sku;
  double? salePrice;
  int? quantity;
  String? imageUrl;
  String? categoryId;

  bool isSynced;

  DateTime? lastSyncedAt;

  LocalProduct({
    this.id,
    this.serverId,
    this.name,
    this.sku,
    this.salePrice,
    this.quantity,
    this.imageUrl,
    this.categoryId,
    this.isSynced = true,
    this.lastSyncedAt,
  });
}

/// Local sale item embedded in LocalSale
@embedded
class LocalSaleItem {
  String? variantId;
  String? productName;
  int? quantity;
  double? unitPrice;
  double? subtotal;

  LocalSaleItem({
    this.variantId,
    this.productName,
    this.quantity,
    this.unitPrice,
    this.subtotal,
  });
}

/// Local sale collection for offline queue
@collection
class LocalSale {
  Id? id;

  @Index()
  String? serverId; // UUID from server after sync

  double? totalAmount;
  String? paymentMethod;
  String? paymentProofUrl;

  List<LocalSaleItem> items;

  bool isSynced;

  DateTime? createdAt;
  DateTime? syncedAt;

  // Store any sync errors
  String? syncError;
  int retryCount;

  LocalSale({
    this.id,
    this.serverId,
    this.totalAmount,
    this.paymentMethod,
    this.paymentProofUrl,
    this.items = const [],
    this.isSynced = false,
    this.createdAt,
    this.syncedAt,
    this.syncError,
    this.retryCount = 0,
  });

  // Create from sale items
  factory LocalSale.fromSaleItems({
    required double totalAmount,
    required String paymentMethod,
    required List<Map<String, dynamic>> items,
    String? paymentProofUrl,
  }) {
    return LocalSale(
      totalAmount: totalAmount,
      paymentMethod: paymentMethod,
      paymentProofUrl: paymentProofUrl,
      items: items.map((item) {
        return LocalSaleItem(
          variantId: item['variant_id'] as String?,
          productName: item['product_name'] as String?,
          quantity: item['quantity'] as int?,
          unitPrice: item['unit_price'] as double?,
          subtotal: item['subtotal'] as double?,
        );
      }).toList(),
      createdAt: DateTime.now(),
      isSynced: false,
      retryCount: 0,
    );
  }

  // Convert to JSON for API request
  Map<String, dynamic> toJson() {
    return {
      'total_amount': totalAmount,
      'payment_method': paymentMethod,
      'payment_proof_url': paymentProofUrl,
      'items': items.map((item) {
        return {
          'variant_id': item.variantId,
          'product_name': item.productName,
          'quantity': item.quantity,
          'unit_price': item.unitPrice,
          'subtotal': item.subtotal,
        };
      }).toList(),
    };
  }
}

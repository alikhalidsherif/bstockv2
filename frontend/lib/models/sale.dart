import 'sale_item.dart';

class Sale {
  final String? id;
  final String? organizationId;
  final double totalAmount;
  final String paymentMethod;
  final String? paymentProofUrl;
  final String? receiptUrl;
  final List<SaleItem> items;
  final DateTime? createdAt;

  Sale({
    this.id,
    this.organizationId,
    required this.totalAmount,
    required this.paymentMethod,
    this.paymentProofUrl,
    this.receiptUrl,
    required this.items,
    this.createdAt,
  });

  factory Sale.fromJson(Map<String, dynamic> json) {
    return Sale(
      id: json['id']?.toString(),
      organizationId: json['organization_id']?.toString(),
      totalAmount: (json['total_amount'] ?? 0).toDouble(),
      paymentMethod: json['payment_method'] ?? 'cash',
      paymentProofUrl: json['payment_proof_url'],
      receiptUrl: json['receipt_url'],
      items: (json['items'] as List<dynamic>?)
              ?.map((item) => SaleItem.fromJson(item))
              .toList() ??
          [],
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'total_amount': totalAmount,
      'payment_method': paymentMethod,
      'payment_proof_url': paymentProofUrl,
      'items': items.map((item) => item.toJson()).toList(),
    };
  }

  int get totalItems => items.fold(0, (sum, item) => sum + item.quantity);
}

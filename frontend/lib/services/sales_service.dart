import 'dart:convert';
import '../models/sale.dart';
import '../models/sale_item.dart';
import 'api_service.dart';

class SalesService {
  final ApiService _api = ApiService();

  // Create a new sale
  Future<Sale> createSale({
    required List<SaleItem> items,
    required String paymentMethod,
    String? paymentProofUrl,
  }) async {
    try {
      final totalAmount = items.fold(0.0, (sum, item) => sum + item.subtotal);

      final response = await _api.post(
        '/sales',
        requiresAuth: true,
        body: {
          'total_amount': totalAmount,
          'payment_method': paymentMethod,
          'payment_proof_url': paymentProofUrl,
          'items': items.map((item) => item.toJson()).toList(),
        },
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return Sale.fromJson(data);
      } else {
        final error = jsonDecode(response.body);
        throw Exception(error['error'] ?? 'Failed to create sale');
      }
    } catch (e) {
      throw Exception('Failed to create sale: $e');
    }
  }

  // Get all sales (with optional filters)
  Future<List<Sale>> getSales({
    String? startDate,
    String? endDate,
    int? limit,
  }) async {
    try {
      final queryParams = <String, String>{};
      if (startDate != null) queryParams['start_date'] = startDate;
      if (endDate != null) queryParams['end_date'] = endDate;
      if (limit != null) queryParams['limit'] = limit.toString();

      final response = await _api.get(
        '/sales',
        requiresAuth: true,
        queryParameters: queryParams.isEmpty ? null : queryParams,
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((json) => Sale.fromJson(json)).toList();
      } else {
        final error = jsonDecode(response.body);
        throw Exception(error['error'] ?? 'Failed to fetch sales');
      }
    } catch (e) {
      throw Exception('Failed to fetch sales: $e');
    }
  }

  // Get a single sale by ID
  Future<Sale> getSale(String id) async {
    try {
      final response = await _api.get(
        '/sales/$id',
        requiresAuth: true,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return Sale.fromJson(data);
      } else {
        final error = jsonDecode(response.body);
        throw Exception(error['error'] ?? 'Failed to fetch sale');
      }
    } catch (e) {
      throw Exception('Failed to fetch sale: $e');
    }
  }

  // Get receipt URL for a sale
  String? getReceiptUrl(Sale sale) {
    return sale.receiptUrl;
  }
}

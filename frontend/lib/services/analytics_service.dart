import 'dart:convert';
import '../models/analytics.dart';
import 'api_service.dart';

class AnalyticsService {
  final ApiService _api = ApiService();

  // Get analytics summary
  Future<AnalyticsSummary> getSummary({
    required String startDate,
    required String endDate,
  }) async {
    try {
      final response = await _api.get(
        '/analytics/summary',
        requiresAuth: true,
        queryParameters: {
          'start_date': startDate,
          'end_date': endDate,
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return AnalyticsSummary.fromJson(data['summary']);
      } else {
        final error = jsonDecode(response.body);
        throw Exception(error['error'] ?? 'Failed to fetch analytics summary');
      }
    } catch (e) {
      throw Exception('Failed to fetch analytics summary: $e');
    }
  }

  // Get top products
  Future<List<ProductPerformance>> getTopProducts({
    required String startDate,
    required String endDate,
    String sortBy = 'quantity', // 'quantity' or 'profit'
    int limit = 10,
  }) async {
    try {
      final response = await _api.get(
        '/analytics/top-products',
        requiresAuth: true,
        queryParameters: {
          'start_date': startDate,
          'end_date': endDate,
          'sort_by': sortBy,
          'limit': limit.toString(),
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List<dynamic> products = data['products'] ?? [];
        return products.map((json) => ProductPerformance.fromJson(json)).toList();
      } else {
        final error = jsonDecode(response.body);
        throw Exception(error['error'] ?? 'Failed to fetch top products');
      }
    } catch (e) {
      throw Exception('Failed to fetch top products: $e');
    }
  }

  // Get daily sales data for chart
  Future<List<DailySalesData>> getDailySales({
    required String startDate,
    required String endDate,
  }) async {
    try {
      final response = await _api.get(
        '/analytics/daily-sales',
        requiresAuth: true,
        queryParameters: {
          'start_date': startDate,
          'end_date': endDate,
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List<dynamic> dailySales = data['daily_sales'] ?? [];
        return dailySales.map((json) => DailySalesData.fromJson(json)).toList();
      } else {
        final error = jsonDecode(response.body);
        throw Exception(error['error'] ?? 'Failed to fetch daily sales');
      }
    } catch (e) {
      throw Exception('Failed to fetch daily sales: $e');
    }
  }

  // Get complete analytics data (summary + daily sales)
  Future<AnalyticsResponse> getAnalyticsData({
    required String startDate,
    required String endDate,
  }) async {
    try {
      final summary = await getSummary(
        startDate: startDate,
        endDate: endDate,
      );

      final dailySales = await getDailySales(
        startDate: startDate,
        endDate: endDate,
      );

      return AnalyticsResponse(
        summary: summary,
        dailySales: dailySales,
        startDate: startDate,
        endDate: endDate,
      );
    } catch (e) {
      throw Exception('Failed to fetch analytics data: $e');
    }
  }
}

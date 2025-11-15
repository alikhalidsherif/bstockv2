import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import '../models/analytics.dart';
import '../services/analytics_service.dart';

enum DateRangeOption {
  today,
  last7Days,
  last30Days,
  custom,
}

class AnalyticsProvider with ChangeNotifier {
  final AnalyticsService _analyticsService = AnalyticsService();

  AnalyticsSummary? _summary;
  List<DailySalesData> _dailySales = [];
  List<ProductPerformance> _topProducts = [];

  DateRangeOption _selectedRange = DateRangeOption.last7Days;
  DateTime _startDate = DateTime.now().subtract(const Duration(days: 7));
  DateTime _endDate = DateTime.now();

  bool _isLoading = false;
  String? _error;

  // Getters
  AnalyticsSummary? get summary => _summary;
  List<DailySalesData> get dailySales => _dailySales;
  List<ProductPerformance> get topProducts => _topProducts;
  DateRangeOption get selectedRange => _selectedRange;
  DateTime get startDate => _startDate;
  DateTime get endDate => _endDate;
  bool get isLoading => _isLoading;
  String? get error => _error;

  // Set date range
  void setDateRange(DateRangeOption option, {DateTime? customStart, DateTime? customEnd}) {
    _selectedRange = option;

    final now = DateTime.now();
    switch (option) {
      case DateRangeOption.today:
        _startDate = DateTime(now.year, now.month, now.day);
        _endDate = now;
        break;
      case DateRangeOption.last7Days:
        _startDate = now.subtract(const Duration(days: 7));
        _endDate = now;
        break;
      case DateRangeOption.last30Days:
        _startDate = now.subtract(const Duration(days: 30));
        _endDate = now;
        break;
      case DateRangeOption.custom:
        if (customStart != null && customEnd != null) {
          _startDate = customStart;
          _endDate = customEnd;
        }
        break;
    }

    notifyListeners();
    loadAnalytics();
  }

  // Load analytics data
  Future<void> loadAnalytics() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final startDateStr = DateFormat('yyyy-MM-dd').format(_startDate);
      final endDateStr = DateFormat('yyyy-MM-dd').format(_endDate);

      // Load summary and daily sales
      final response = await _analyticsService.getAnalyticsData(
        startDate: startDateStr,
        endDate: endDateStr,
      );

      _summary = response.summary;
      _dailySales = response.dailySales;

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  // Load top products separately
  Future<void> loadTopProducts({String sortBy = 'quantity', int limit = 10}) async {
    try {
      final startDateStr = DateFormat('yyyy-MM-dd').format(_startDate);
      final endDateStr = DateFormat('yyyy-MM-dd').format(_endDate);

      _topProducts = await _analyticsService.getTopProducts(
        startDate: startDateStr,
        endDate: endDateStr,
        sortBy: sortBy,
        limit: limit,
      );

      notifyListeners();
    } catch (e) {
      debugPrint('Failed to load top products: $e');
    }
  }

  // Refresh all data
  Future<void> refresh() async {
    await loadAnalytics();
    await loadTopProducts();
  }

  // Clear data
  void clear() {
    _summary = null;
    _dailySales = [];
    _topProducts = [];
    _error = null;
    notifyListeners();
  }
}

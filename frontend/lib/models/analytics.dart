class AnalyticsSummary {
  final double totalRevenue;
  final double grossProfit;
  final double profitMargin;
  final int transactionCount;
  final int itemsSold;
  final double averageOrderValue;

  AnalyticsSummary({
    required this.totalRevenue,
    required this.grossProfit,
    required this.profitMargin,
    required this.transactionCount,
    required this.itemsSold,
    required this.averageOrderValue,
  });

  factory AnalyticsSummary.fromJson(Map<String, dynamic> json) {
    return AnalyticsSummary(
      totalRevenue: (json['total_revenue'] ?? 0).toDouble(),
      grossProfit: (json['gross_profit'] ?? 0).toDouble(),
      profitMargin: (json['profit_margin'] ?? 0).toDouble(),
      transactionCount: json['transaction_count'] ?? 0,
      itemsSold: json['items_sold'] ?? 0,
      averageOrderValue: (json['average_order_value'] ?? 0).toDouble(),
    );
  }
}

class ProductPerformance {
  final String productId;
  final String productName;
  final int quantitySold;
  final double revenue;
  final double profit;
  final double profitMargin;

  ProductPerformance({
    required this.productId,
    required this.productName,
    required this.quantitySold,
    required this.revenue,
    required this.profit,
    required this.profitMargin,
  });

  factory ProductPerformance.fromJson(Map<String, dynamic> json) {
    return ProductPerformance(
      productId: json['product_id'] ?? '',
      productName: json['product_name'] ?? '',
      quantitySold: json['quantity_sold'] ?? 0,
      revenue: (json['revenue'] ?? 0).toDouble(),
      profit: (json['profit'] ?? 0).toDouble(),
      profitMargin: (json['profit_margin'] ?? 0).toDouble(),
    );
  }
}

class DailySalesData {
  final String date;
  final double revenue;
  final int transactionCount;
  final int itemsSold;

  DailySalesData({
    required this.date,
    required this.revenue,
    required this.transactionCount,
    required this.itemsSold,
  });

  factory DailySalesData.fromJson(Map<String, dynamic> json) {
    return DailySalesData(
      date: json['date'] ?? '',
      revenue: (json['revenue'] ?? 0).toDouble(),
      transactionCount: json['transaction_count'] ?? 0,
      itemsSold: json['items_sold'] ?? 0,
    );
  }
}

class AnalyticsResponse {
  final AnalyticsSummary? summary;
  final List<ProductPerformance> topProducts;
  final List<DailySalesData> dailySales;
  final String startDate;
  final String endDate;

  AnalyticsResponse({
    this.summary,
    this.topProducts = const [],
    this.dailySales = const [],
    required this.startDate,
    required this.endDate,
  });
}

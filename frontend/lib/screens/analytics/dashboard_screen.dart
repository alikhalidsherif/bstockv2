import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../config/app_config.dart';
import '../../providers/analytics_provider.dart';
import '../../providers/auth_provider.dart';

class AnalyticsDashboardScreen extends StatefulWidget {
  const AnalyticsDashboardScreen({super.key});

  @override
  State<AnalyticsDashboardScreen> createState() => _AnalyticsDashboardScreenState();
}

class _AnalyticsDashboardScreenState extends State<AnalyticsDashboardScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAccessAndLoadData();
    });
  }

  void _checkAccessAndLoadData() {
    final auth = Provider.of<AuthProvider>(context, listen: false);

    // Feature gate: Check if user has access to analytics
    if (auth.user?.subscriptionPlan == 'free') {
      _showUpgradePrompt();
      return;
    }

    // Load analytics data
    Provider.of<AnalyticsProvider>(context, listen: false).loadAnalytics();
  }

  void _showUpgradePrompt() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Premium Feature'),
        content: const Text(
          'Analytics is available on Standard and Premium plans. Upgrade your subscription to access detailed insights and reports.',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              context.go('/home');
            },
            child: const Text('Maybe Later'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              // TODO: Navigate to subscription upgrade screen
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Subscription upgrade coming soon!'),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppConfig.primaryColor,
              foregroundColor: Colors.white,
            ),
            child: const Text('Upgrade Now'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);

    // Block access for free users
    if (auth.user?.subscriptionPlan == 'free') {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Analytics'),
          backgroundColor: AppConfig.primaryColor,
          foregroundColor: Colors.white,
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.lock_outline,
                size: 64,
                color: Colors.grey.shade400,
              ),
              const SizedBox(height: 16),
              const Text(
                'Premium Feature',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 32),
                child: Text(
                  'Upgrade to Standard or Premium to access analytics',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppConfig.subtextColor),
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => context.go('/home'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppConfig.primaryColor,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Back to Home'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Analytics'),
        backgroundColor: AppConfig.primaryColor,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              Provider.of<AnalyticsProvider>(context, listen: false).refresh();
            },
          ),
        ],
      ),
      body: Consumer<AnalyticsProvider>(
        builder: (context, analytics, child) {
          if (analytics.isLoading && analytics.summary == null) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          if (analytics.error != null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.error_outline,
                    size: 64,
                    color: AppConfig.errorColor,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Error loading analytics',
                    style: const TextStyle(fontSize: 18),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    analytics.error!,
                    style: const TextStyle(color: AppConfig.subtextColor),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => analytics.loadAnalytics(),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () => analytics.refresh(),
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Date range picker
                  _buildDateRangePicker(analytics),
                  const SizedBox(height: 24),

                  // Metric cards
                  if (analytics.summary != null) ...[
                    _buildMetricCards(analytics.summary!),
                    const SizedBox(height: 24),
                  ],

                  // Daily sales chart
                  if (analytics.dailySales.isNotEmpty) ...[
                    const Text(
                      'Daily Sales',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildDailySalesChart(analytics.dailySales),
                    const SizedBox(height: 24),
                  ],

                  // Top products button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => context.push('/analytics/top-products'),
                      icon: const Icon(Icons.trending_up),
                      label: const Text('View Top Products'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppConfig.primaryColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.all(16),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildDateRangePicker(AnalyticsProvider analytics) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Date Range',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildDateRangeChip(
                  'Today',
                  DateRangeOption.today,
                  analytics,
                ),
                _buildDateRangeChip(
                  '7 Days',
                  DateRangeOption.last7Days,
                  analytics,
                ),
                _buildDateRangeChip(
                  '30 Days',
                  DateRangeOption.last30Days,
                  analytics,
                ),
                _buildDateRangeChip(
                  'Custom',
                  DateRangeOption.custom,
                  analytics,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDateRangeChip(
    String label,
    DateRangeOption option,
    AnalyticsProvider analytics,
  ) {
    final isSelected = analytics.selectedRange == option;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        if (selected) {
          if (option == DateRangeOption.custom) {
            _showCustomDatePicker(analytics);
          } else {
            analytics.setDateRange(option);
          }
        }
      },
      selectedColor: AppConfig.primaryColor.withOpacity(0.2),
      labelStyle: TextStyle(
        color: isSelected ? AppConfig.primaryColor : Colors.black,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
    );
  }

  Future<void> _showCustomDatePicker(AnalyticsProvider analytics) async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: DateTimeRange(
        start: analytics.startDate,
        end: analytics.endDate,
      ),
    );

    if (picked != null) {
      analytics.setDateRange(
        DateRangeOption.custom,
        customStart: picked.start,
        customEnd: picked.end,
      );
    }
  }

  Widget _buildMetricCards(AnalyticsSummary summary) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildMetricCard(
                'Total Revenue',
                _formatCurrency(summary.totalRevenue),
                Icons.attach_money,
                AppConfig.primaryColor,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildMetricCard(
                'Gross Profit',
                _formatCurrency(summary.grossProfit),
                Icons.trending_up,
                AppConfig.successColor,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildMetricCard(
                'Transactions',
                '${summary.transactionCount}',
                Icons.receipt_long,
                Colors.orange,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildMetricCard(
                'Items Sold',
                '${summary.itemsSold}',
                Icons.shopping_bag,
                Colors.purple,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMetricCard(String label, String value, IconData icon, Color color) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 20),
                const Spacer(),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                color: AppConfig.subtextColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDailySalesChart(List<DailySalesData> data) {
    if (data.isEmpty) {
      return const SizedBox.shrink();
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: SizedBox(
          height: 250,
          child: LineChart(
            LineChartData(
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                horizontalInterval: 1,
                getDrawingHorizontalLine: (value) {
                  return FlLine(
                    color: Colors.grey.shade300,
                    strokeWidth: 1,
                  );
                },
              ),
              titlesData: FlTitlesData(
                show: true,
                rightTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                topTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 30,
                    interval: 1,
                    getTitlesWidget: (value, meta) {
                      if (value.toInt() >= 0 && value.toInt() < data.length) {
                        final date = DateTime.parse(data[value.toInt()].date);
                        return Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Text(
                            DateFormat('MM/dd').format(date),
                            style: const TextStyle(
                              fontSize: 10,
                              color: AppConfig.subtextColor,
                            ),
                          ),
                        );
                      }
                      return const Text('');
                    },
                  ),
                ),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 50,
                    getTitlesWidget: (value, meta) {
                      return Text(
                        _formatShortCurrency(value),
                        style: const TextStyle(
                          fontSize: 10,
                          color: AppConfig.subtextColor,
                        ),
                      );
                    },
                  ),
                ),
              ),
              borderData: FlBorderData(
                show: true,
                border: Border.all(color: Colors.grey.shade300),
              ),
              minX: 0,
              maxX: (data.length - 1).toDouble(),
              minY: 0,
              maxY: data.map((d) => d.revenue).reduce((a, b) => a > b ? a : b) * 1.2,
              lineBarsData: [
                LineChartBarData(
                  spots: data.asMap().entries.map((entry) {
                    return FlSpot(entry.key.toDouble(), entry.value.revenue);
                  }).toList(),
                  isCurved: true,
                  color: AppConfig.primaryColor,
                  barWidth: 3,
                  isStrokeCapRound: true,
                  dotData: const FlDotData(show: true),
                  belowBarData: BarAreaData(
                    show: true,
                    color: AppConfig.primaryColor.withOpacity(0.1),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatCurrency(double amount) {
    final formatter = NumberFormat.currency(symbol: 'GHS ', decimalDigits: 2);
    return formatter.format(amount);
  }

  String _formatShortCurrency(double amount) {
    if (amount >= 1000) {
      return '${(amount / 1000).toStringAsFixed(1)}K';
    }
    return amount.toStringAsFixed(0);
  }
}

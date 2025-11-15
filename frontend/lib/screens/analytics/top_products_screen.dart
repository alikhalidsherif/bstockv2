import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../config/app_config.dart';
import '../../providers/analytics_provider.dart';
import '../../models/analytics.dart';

class TopProductsScreen extends StatefulWidget {
  const TopProductsScreen({super.key});

  @override
  State<TopProductsScreen> createState() => _TopProductsScreenState();
}

class _TopProductsScreenState extends State<TopProductsScreen> {
  String _sortBy = 'quantity'; // 'quantity' or 'profit'

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadTopProducts();
    });
  }

  void _loadTopProducts() {
    Provider.of<AnalyticsProvider>(context, listen: false)
        .loadTopProducts(sortBy: _sortBy);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Top Products'),
        backgroundColor: AppConfig.primaryColor,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // Sort toggle
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            child: SegmentedButton<String>(
              segments: const [
                ButtonSegment(
                  value: 'quantity',
                  label: Text('Top Selling'),
                  icon: Icon(Icons.shopping_bag),
                ),
                ButtonSegment(
                  value: 'profit',
                  label: Text('Most Profitable'),
                  icon: Icon(Icons.trending_up),
                ),
              ],
              selected: {_sortBy},
              onSelectionChanged: (Set<String> newSelection) {
                setState(() {
                  _sortBy = newSelection.first;
                });
                _loadTopProducts();
              },
            ),
          ),

          // Products list
          Expanded(
            child: Consumer<AnalyticsProvider>(
              builder: (context, analytics, child) {
                if (analytics.topProducts.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.inventory_2_outlined,
                          size: 64,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'No product data available',
                          style: TextStyle(fontSize: 16),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Make some sales to see top products',
                          style: TextStyle(color: AppConfig.subtextColor),
                        ),
                      ],
                    ),
                  );
                }

                return RefreshIndicator(
                  onRefresh: () async {
                    await analytics.loadTopProducts(sortBy: _sortBy);
                  },
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: analytics.topProducts.length,
                    itemBuilder: (context, index) {
                      final product = analytics.topProducts[index];
                      return _buildProductCard(product, index + 1);
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductCard(ProductPerformance product, int rank) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // Ranking badge
            _buildRankBadge(rank),
            const SizedBox(width: 16),

            // Product info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.productName,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${product.quantitySold} units sold',
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppConfig.subtextColor,
                    ),
                  ),
                ],
              ),
            ),

            // Metrics
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  _formatCurrency(product.revenue),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppConfig.primaryColor,
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: _sortBy == 'profit'
                        ? AppConfig.successColor.withOpacity(0.1)
                        : Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _sortBy == 'profit'
                        ? _formatCurrency(product.profit)
                        : '${product.profitMargin.toStringAsFixed(1)}%',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: _sortBy == 'profit'
                          ? AppConfig.successColor
                          : AppConfig.subtextColor,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRankBadge(int rank) {
    Color backgroundColor;
    Color textColor;
    IconData? icon;

    if (rank == 1) {
      backgroundColor = const Color(0xFFFFD700); // Gold
      textColor = Colors.white;
      icon = Icons.emoji_events;
    } else if (rank == 2) {
      backgroundColor = const Color(0xFFC0C0C0); // Silver
      textColor = Colors.white;
      icon = Icons.emoji_events;
    } else if (rank == 3) {
      backgroundColor = const Color(0xFFCD7F32); // Bronze
      textColor = Colors.white;
      icon = Icons.emoji_events;
    } else {
      backgroundColor = Colors.grey.shade300;
      textColor = Colors.black87;
    }

    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: backgroundColor,
        shape: BoxShape.circle,
      ),
      child: Center(
        child: icon != null
            ? Icon(icon, color: textColor, size: 24)
            : Text(
                '$rank',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
              ),
      ),
    );
  }

  String _formatCurrency(double amount) {
    final formatter = NumberFormat.currency(symbol: 'GHS ', decimalDigits: 2);
    return formatter.format(amount);
  }
}

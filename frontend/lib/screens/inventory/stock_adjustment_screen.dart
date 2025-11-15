import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../config/app_config.dart';
import '../../providers/inventory_provider.dart';
import '../../models/product.dart';
import '../../models/variant.dart';
import '../../widgets/custom_button.dart';

class StockAdjustmentScreen extends StatefulWidget {
  final String productId;

  const StockAdjustmentScreen({super.key, required this.productId});

  @override
  State<StockAdjustmentScreen> createState() => _StockAdjustmentScreenState();
}

class _StockAdjustmentScreenState extends State<StockAdjustmentScreen> {
  Product? _product;
  bool _isLoading = false;
  final Map<String, int> _adjustments = {};
  final Map<String, TextEditingController> _reasonControllers = {};
  String _bulkReason = '';

  @override
  void initState() {
    super.initState();
    _loadProduct();
  }

  @override
  void dispose() {
    for (var controller in _reasonControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _loadProduct() async {
    setState(() => _isLoading = true);
    final provider = context.read<InventoryProvider>();
    final product = await provider.getProduct(widget.productId);

    if (product != null && mounted) {
      setState(() {
        _product = product;
        // Initialize adjustments and reason controllers
        for (var variant in product.variants) {
          _adjustments[variant.id] = 0;
          _reasonControllers[variant.id] = TextEditingController();
        }
      });
    }

    setState(() => _isLoading = false);
  }

  void _incrementAdjustment(String variantId) {
    setState(() {
      _adjustments[variantId] = (_adjustments[variantId] ?? 0) + 1;
    });
  }

  void _decrementAdjustment(String variantId) {
    setState(() {
      _adjustments[variantId] = (_adjustments[variantId] ?? 0) - 1;
    });
  }

  Future<void> _applyAdjustments() async {
    // Check if any adjustments were made
    final hasAdjustments = _adjustments.values.any((adj) => adj != 0);
    if (!hasAdjustments) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No adjustments to apply'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final provider = context.read<InventoryProvider>();
      bool allSuccess = true;

      for (var entry in _adjustments.entries) {
        final variantId = entry.key;
        final adjustment = entry.value;

        if (adjustment != 0) {
          final reason = _reasonControllers[variantId]?.text.isNotEmpty == true
              ? _reasonControllers[variantId]!.text
              : _bulkReason.isNotEmpty
                  ? _bulkReason
                  : 'Manual adjustment';

          final success = await provider.adjustStock(variantId, adjustment, reason);
          if (!success) {
            allSuccess = false;
          }
        }
      }

      if (allSuccess && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Stock adjusted successfully'),
            backgroundColor: AppConfig.successColor,
          ),
        );
        context.pop();
      } else if (mounted) {
        throw Exception('Some adjustments failed');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: AppConfig.errorColor,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _showBulkAdjustmentDialog() async {
    final reasonController = TextEditingController();
    final adjustmentController = TextEditingController();

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Bulk Adjustment'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: adjustmentController,
                decoration: const InputDecoration(
                  labelText: 'Adjustment Amount',
                  hintText: 'e.g., 10 or -5',
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: reasonController,
                decoration: const InputDecoration(
                  labelText: 'Reason',
                  hintText: 'e.g., Stock count correction',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context, {
                  'adjustment': int.tryParse(adjustmentController.text) ?? 0,
                  'reason': reasonController.text,
                });
              },
              child: const Text('Apply'),
            ),
          ],
        );
      },
    );

    if (result != null && mounted) {
      setState(() {
        final adjustment = result['adjustment'] as int;
        for (var variantId in _adjustments.keys) {
          _adjustments[variantId] = adjustment;
        }
        _bulkReason = result['reason'] as String;
      });
    }

    reasonController.dispose();
    adjustmentController.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Stock Adjustment'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: _showBulkAdjustmentDialog,
            tooltip: 'Bulk Adjustment',
          ),
        ],
      ),
      body: _isLoading && _product == null
          ? const Center(child: CircularProgressIndicator())
          : _product == null
              ? const Center(child: Text('Product not found'))
              : Column(
                  children: [
                    // Product info
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      color: AppConfig.secondaryBackground,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _product!.name,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Total Stock: ${_product!.totalQuantity}',
                            style: TextStyle(
                              fontSize: 14,
                              color: AppConfig.subtextColor,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Variants list
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _product!.variants.length,
                        itemBuilder: (context, index) {
                          final variant = _product!.variants[index];
                          return _VariantAdjustmentCard(
                            variant: variant,
                            adjustment: _adjustments[variant.id] ?? 0,
                            onIncrement: () => _incrementAdjustment(variant.id),
                            onDecrement: () => _decrementAdjustment(variant.id),
                            reasonController: _reasonControllers[variant.id]!,
                          );
                        },
                      ),
                    ),

                    // Bottom section with bulk reason and apply button
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 10,
                            offset: const Offset(0, -5),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          TextField(
                            decoration: const InputDecoration(
                              labelText: 'Reason for all adjustments (optional)',
                              hintText: 'e.g., Stock count correction',
                              border: OutlineInputBorder(),
                            ),
                            onChanged: (value) {
                              setState(() {
                                _bulkReason = value;
                              });
                            },
                          ),
                          const SizedBox(height: 16),
                          CustomButton(
                            text: 'Apply Adjustments',
                            onPressed: _applyAdjustments,
                            isLoading: _isLoading,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
    );
  }
}

class _VariantAdjustmentCard extends StatelessWidget {
  final Variant variant;
  final int adjustment;
  final VoidCallback onIncrement;
  final VoidCallback onDecrement;
  final TextEditingController reasonController;

  const _VariantAdjustmentCard({
    required this.variant,
    required this.adjustment,
    required this.onIncrement,
    required this.onDecrement,
    required this.reasonController,
  });

  @override
  Widget build(BuildContext context) {
    final newQuantity = variant.quantity + adjustment;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Variant info
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        variant.displayName.isNotEmpty
                            ? variant.displayName
                            : variant.sku,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'SKU: ${variant.sku}',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppConfig.subtextColor,
                        ),
                      ),
                    ],
                  ),
                ),
                if (variant.isLowStock)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppConfig.errorColor,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      'LOW',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),

            const SizedBox(height: 16),

            // Current and new quantity
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Current',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppConfig.subtextColor,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        variant.quantity.toString(),
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward,
                  color: AppConfig.subtextColor,
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'New',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppConfig.subtextColor,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        newQuantity.toString(),
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: adjustment > 0
                              ? AppConfig.successColor
                              : adjustment < 0
                                  ? AppConfig.errorColor
                                  : AppConfig.textColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Adjustment controls
            Row(
              children: [
                IconButton(
                  onPressed: onDecrement,
                  icon: const Icon(Icons.remove_circle_outline),
                  color: AppConfig.errorColor,
                  iconSize: 32,
                ),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: AppConfig.secondaryBackground,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      adjustment > 0 ? '+$adjustment' : adjustment.toString(),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                IconButton(
                  onPressed: onIncrement,
                  icon: const Icon(Icons.add_circle_outline),
                  color: AppConfig.successColor,
                  iconSize: 32,
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Reason field
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(
                labelText: 'Reason (optional)',
                hintText: 'e.g., Damaged items',
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                isDense: true,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../config/app_config.dart';
import '../../models/product.dart';
import '../../models/variant.dart';
import '../../providers/inventory_provider.dart';
import '../../providers/cart_provider.dart';
import '../../services/barcode_service.dart';
import '../../widgets/cart_widget.dart';
import '../../widgets/connectivity_indicator.dart';

class POSScreen extends StatefulWidget {
  const POSScreen({super.key});

  @override
  State<POSScreen> createState() => _POSScreenState();
}

class _POSScreenState extends State<POSScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadProducts() async {
    setState(() {
      _isLoading = true;
    });

    try {
      await Provider.of<InventoryProvider>(context, listen: false)
          .fetchProducts();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading products: $e'),
            backgroundColor: AppConfig.errorColor,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _scanBarcode() async {
    final barcode = await BarcodeService.scanBarcode(context);
    if (barcode != null) {
      _searchForBarcode(barcode);
    }
  }

  void _searchForBarcode(String barcode) {
    final inventory = Provider.of<InventoryProvider>(context, listen: false);
    final cart = Provider.of<CartProvider>(context, listen: false);

    // Find product with matching SKU
    Product? foundProduct;
    Variant? foundVariant;

    for (final product in inventory.products) {
      for (final variant in product.variants) {
        if (variant.sku.toLowerCase() == barcode.toLowerCase()) {
          foundProduct = product;
          foundVariant = variant;
          break;
        }
      }
      if (foundProduct != null) break;
    }

    if (foundProduct != null && foundVariant != null) {
      if (foundVariant.quantity > 0) {
        cart.addItem(product: foundProduct, variant: foundVariant);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Added ${foundProduct.name} to cart'),
            backgroundColor: AppConfig.successColor,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Product is out of stock'),
            backgroundColor: AppConfig.errorColor,
          ),
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Product not found'),
          backgroundColor: AppConfig.errorColor,
        ),
      );
    }
  }

  List<Product> _getFilteredProducts(List<Product> products) {
    if (_searchQuery.isEmpty) return products;

    return products.where((product) {
      final nameLower = product.name.toLowerCase();
      final queryLower = _searchQuery.toLowerCase();
      final skuMatch = product.variants.any(
        (v) => v.sku.toLowerCase().contains(queryLower),
      );
      return nameLower.contains(queryLower) || skuMatch;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Point of Sale'),
        backgroundColor: AppConfig.primaryColor,
        foregroundColor: Colors.white,
        actions: [
          const ConnectivityBadge(),
          IconButton(
            icon: const Icon(Icons.qr_code_scanner),
            onPressed: _scanBarcode,
            tooltip: 'Scan Barcode',
          ),
        ],
      ),
      body: Row(
        children: [
          // Left panel - Product grid
          Expanded(
            flex: 2,
            child: Column(
              children: [
                // Search bar
                Container(
                  padding: const EdgeInsets.all(16),
                  color: Colors.white,
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Search products or SKU...',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                _searchController.clear();
                                setState(() {
                                  _searchQuery = '';
                                });
                              },
                            )
                          : null,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                    onChanged: (value) {
                      setState(() {
                        _searchQuery = value;
                      });
                    },
                  ),
                ),

                // Product grid
                Expanded(
                  child: _isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : Consumer<InventoryProvider>(
                          builder: (context, inventory, child) {
                            final filteredProducts =
                                _getFilteredProducts(inventory.products);

                            if (filteredProducts.isEmpty) {
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
                                    Text(
                                      _searchQuery.isEmpty
                                          ? 'No products available'
                                          : 'No products found',
                                      style: TextStyle(
                                        fontSize: 16,
                                        color: Colors.grey.shade600,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }

                            return GridView.builder(
                              padding: const EdgeInsets.all(16),
                              gridDelegate:
                                  const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 3,
                                childAspectRatio: 0.75,
                                crossAxisSpacing: 16,
                                mainAxisSpacing: 16,
                              ),
                              itemCount: filteredProducts.length,
                              itemBuilder: (context, index) {
                                final product = filteredProducts[index];
                                return _buildProductCard(product);
                              },
                            );
                          },
                        ),
                ),
              ],
            ),
          ),

          // Right panel - Cart
          SizedBox(
            width: 350,
            child: CartWidget(
              onCheckout: () {
                context.push('/pos/checkout');
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductCard(Product product) {
    final cart = Provider.of<CartProvider>(context, listen: false);
    final defaultVariant = product.defaultVariant;
    final isOutOfStock = defaultVariant.quantity == 0;

    return Card(
      elevation: 2,
      child: InkWell(
        onTap: isOutOfStock
            ? null
            : () {
                if (product.variants.length > 1) {
                  _showVariantSelector(product);
                } else {
                  cart.addItem(
                    product: product,
                    variant: defaultVariant,
                  );
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Added ${product.name} to cart'),
                      backgroundColor: AppConfig.successColor,
                      duration: const Duration(seconds: 1),
                    ),
                  );
                }
              },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Product image
            Expanded(
              child: Stack(
                children: [
                  Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: AppConfig.secondaryBackground,
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(4),
                      ),
                    ),
                    child: product.imageUrl != null
                        ? ClipRRect(
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(4),
                            ),
                            child: Image.network(
                              product.imageUrl!,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return _buildPlaceholderImage();
                              },
                            ),
                          )
                        : _buildPlaceholderImage(),
                  ),
                  if (isOutOfStock)
                    Container(
                      width: double.infinity,
                      height: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.6),
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(4),
                        ),
                      ),
                      child: const Center(
                        child: Text(
                          'OUT OF STOCK',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // Product details
            Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.name,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'GHS ${defaultVariant.salePrice.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppConfig.primaryColor,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Stock: ${product.totalQuantity}',
                    style: TextStyle(
                      fontSize: 12,
                      color: isOutOfStock
                          ? AppConfig.errorColor
                          : Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaceholderImage() {
    return Center(
      child: Icon(
        Icons.inventory_2_outlined,
        size: 48,
        color: Colors.grey.shade400,
      ),
    );
  }

  void _showVariantSelector(Product product) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Select ${product.name} variant',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            ...product.variants.map((variant) {
              final isOutOfStock = variant.quantity == 0;
              return ListTile(
                title: Text(variant.displayName.isEmpty
                    ? variant.sku
                    : variant.displayName),
                subtitle: Text('GHS ${variant.salePrice.toStringAsFixed(2)}'),
                trailing: Text(
                  isOutOfStock ? 'Out of stock' : 'Stock: ${variant.quantity}',
                  style: TextStyle(
                    color: isOutOfStock
                        ? AppConfig.errorColor
                        : Colors.grey.shade600,
                  ),
                ),
                enabled: !isOutOfStock,
                onTap: isOutOfStock
                    ? null
                    : () {
                        final cart =
                            Provider.of<CartProvider>(context, listen: false);
                        cart.addItem(product: product, variant: variant);
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Added ${product.name} to cart'),
                            backgroundColor: AppConfig.successColor,
                            duration: const Duration(seconds: 1),
                          ),
                        );
                      },
              );
            }),
          ],
        ),
      ),
    );
  }
}

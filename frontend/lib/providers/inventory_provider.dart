import 'package:flutter/foundation.dart';
import '../models/product.dart';
import '../models/vendor.dart';
import '../services/inventory_service.dart';

class InventoryProvider with ChangeNotifier {
  final InventoryService _inventoryService = InventoryService();

  List<Product> _products = [];
  List<Vendor> _vendors = [];
  bool _isLoading = false;
  String? _error;
  String? _searchQuery;
  String? _categoryFilter;

  List<Product> get products => _products;
  List<Vendor> get vendors => _vendors;
  bool get isLoading => _isLoading;
  String? get error => _error;
  String? get searchQuery => _searchQuery;
  String? get categoryFilter => _categoryFilter;

  // Get unique categories from products
  List<String> get categories {
    final cats = _products
        .map((p) => p.category)
        .where((c) => c != null && c.isNotEmpty)
        .toSet()
        .toList();
    cats.sort();
    return cats;
  }

  // Get filtered products
  List<Product> get filteredProducts {
    var filtered = _products;

    if (_searchQuery != null && _searchQuery!.isNotEmpty) {
      filtered = filtered.where((p) {
        return p.name.toLowerCase().contains(_searchQuery!.toLowerCase()) ||
            p.description?.toLowerCase().contains(_searchQuery!.toLowerCase()) ==
                true ||
            p.variants.any((v) => v.sku.toLowerCase().contains(_searchQuery!.toLowerCase()));
      }).toList();
    }

    if (_categoryFilter != null && _categoryFilter!.isNotEmpty) {
      filtered = filtered.where((p) => p.category == _categoryFilter).toList();
    }

    return filtered;
  }

  // ==================== PRODUCTS ====================

  Future<void> loadProducts() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _products = await _inventoryService.getProducts(
        search: _searchQuery,
        category: _categoryFilter,
      );
      _error = null;
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<Product?> getProduct(String id) async {
    try {
      return await _inventoryService.getProduct(id);
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return null;
    }
  }

  Future<bool> createProduct(Product product) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final newProduct = await _inventoryService.createProduct(product);
      _products.insert(0, newProduct);
      _error = null;
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> updateProduct(String id, Product product) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final updatedProduct = await _inventoryService.updateProduct(id, product);
      final index = _products.indexWhere((p) => p.id == id);
      if (index != -1) {
        _products[index] = updatedProduct;
      }
      _error = null;
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> deleteProduct(String id) async {
    try {
      await _inventoryService.deleteProduct(id);
      _products.removeWhere((p) => p.id == id);
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  // ==================== VENDORS ====================

  Future<void> loadVendors() async {
    try {
      _vendors = await _inventoryService.getVendors();
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  Future<bool> createVendor(Vendor vendor) async {
    try {
      final newVendor = await _inventoryService.createVendor(vendor);
      _vendors.insert(0, newVendor);
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> deleteVendor(String id) async {
    try {
      await _inventoryService.deleteVendor(id);
      _vendors.removeWhere((v) => v.id == id);
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  // ==================== STOCK ADJUSTMENT ====================

  Future<bool> adjustStock(String variantId, int adjustment, String reason) async {
    try {
      await _inventoryService.adjustStock(variantId, adjustment, reason);
      // Refresh products to get updated quantities
      await loadProducts();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  // ==================== SEARCH & FILTER ====================

  void setSearchQuery(String? query) {
    _searchQuery = query;
    notifyListeners();
  }

  void setCategoryFilter(String? category) {
    _categoryFilter = category;
    notifyListeners();
  }

  void clearFilters() {
    _searchQuery = null;
    _categoryFilter = null;
    notifyListeners();
  }

  // ==================== IMAGE UPLOAD ====================

  Future<String?> uploadImage(dynamic imageFile) async {
    try {
      return await _inventoryService.uploadProductImage(imageFile);
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return null;
    }
  }
}

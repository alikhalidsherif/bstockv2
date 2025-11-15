import 'package:flutter/foundation.dart';
import '../models/sale_item.dart';
import '../models/product.dart';
import '../models/variant.dart';

class CartProvider with ChangeNotifier {
  final List<SaleItem> _items = [];

  List<SaleItem> get items => List.unmodifiable(_items);

  int get itemCount => _items.length;

  int get totalItemsCount => _items.fold(0, (sum, item) => sum + item.quantity);

  double get totalAmount => _items.fold(0.0, (sum, item) => sum + item.subtotal);

  bool get isEmpty => _items.isEmpty;

  // Add item to cart or increase quantity if already exists
  void addItem({
    required Product product,
    required Variant variant,
  }) {
    // Check if variant already in cart
    final existingIndex = _items.indexWhere(
      (item) => item.variantId == variant.id,
    );

    if (existingIndex != -1) {
      // Increase quantity
      final existingItem = _items[existingIndex];
      _items[existingIndex] = existingItem.copyWith(
        quantity: existingItem.quantity + 1,
      );
    } else {
      // Add new item
      _items.add(SaleItem.fromVariant(
        variant: variant,
        productName: product.name,
        quantity: 1,
      ));
    }

    notifyListeners();
  }

  // Update item quantity
  void updateQuantity(String variantId, int newQuantity) {
    if (newQuantity <= 0) {
      removeItem(variantId);
      return;
    }

    final index = _items.indexWhere((item) => item.variantId == variantId);
    if (index != -1) {
      _items[index] = _items[index].copyWith(quantity: newQuantity);
      notifyListeners();
    }
  }

  // Increase item quantity
  void increaseQuantity(String variantId) {
    final index = _items.indexWhere((item) => item.variantId == variantId);
    if (index != -1) {
      final currentQuantity = _items[index].quantity;
      _items[index] = _items[index].copyWith(quantity: currentQuantity + 1);
      notifyListeners();
    }
  }

  // Decrease item quantity
  void decreaseQuantity(String variantId) {
    final index = _items.indexWhere((item) => item.variantId == variantId);
    if (index != -1) {
      final currentQuantity = _items[index].quantity;
      if (currentQuantity > 1) {
        _items[index] = _items[index].copyWith(quantity: currentQuantity - 1);
        notifyListeners();
      } else {
        removeItem(variantId);
      }
    }
  }

  // Remove item from cart
  void removeItem(String variantId) {
    _items.removeWhere((item) => item.variantId == variantId);
    notifyListeners();
  }

  // Clear entire cart
  void clearCart() {
    _items.clear();
    notifyListeners();
  }

  // Get item by variant ID
  SaleItem? getItem(String variantId) {
    try {
      return _items.firstWhere((item) => item.variantId == variantId);
    } catch (e) {
      return null;
    }
  }

  // Check if variant is in cart
  bool hasItem(String variantId) {
    return _items.any((item) => item.variantId == variantId);
  }

  // Get quantity of a specific variant in cart
  int getItemQuantity(String variantId) {
    final item = getItem(variantId);
    return item?.quantity ?? 0;
  }
}

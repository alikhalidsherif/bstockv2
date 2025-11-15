import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';
import '../models/product.dart';
import '../models/variant.dart';
import '../models/vendor.dart';
import 'api_service.dart';
import 'storage_service.dart';

class InventoryService {
  final ApiService _api = ApiService();
  final StorageService _storage = StorageService();

  // ==================== PRODUCTS ====================

  Future<List<Product>> getProducts({
    String? search,
    String? category,
  }) async {
    try {
      final queryParams = <String, String>{};
      if (search != null && search.isNotEmpty) {
        queryParams['search'] = search;
      }
      if (category != null && category.isNotEmpty) {
        queryParams['category'] = category;
      }

      final response = await _api.get(
        '/products',
        requiresAuth: true,
        queryParameters: queryParams.isNotEmpty ? queryParams : null,
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((json) => Product.fromJson(json)).toList();
      } else {
        throw Exception('Failed to load products: ${response.body}');
      }
    } catch (e) {
      throw Exception('Error loading products: $e');
    }
  }

  Future<Product> getProduct(String id) async {
    try {
      final response = await _api.get(
        '/products/$id',
        requiresAuth: true,
      );

      if (response.statusCode == 200) {
        return Product.fromJson(jsonDecode(response.body));
      } else {
        throw Exception('Failed to load product: ${response.body}');
      }
    } catch (e) {
      throw Exception('Error loading product: $e');
    }
  }

  Future<Product> createProduct(Product product) async {
    try {
      final response = await _api.post(
        '/products',
        body: product.toJson(),
        requiresAuth: true,
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        return Product.fromJson(jsonDecode(response.body));
      } else {
        throw Exception('Failed to create product: ${response.body}');
      }
    } catch (e) {
      throw Exception('Error creating product: $e');
    }
  }

  Future<Product> updateProduct(String id, Product product) async {
    try {
      final response = await _api.put(
        '/products/$id',
        body: product.toJson(),
        requiresAuth: true,
      );

      if (response.statusCode == 200) {
        return Product.fromJson(jsonDecode(response.body));
      } else {
        throw Exception('Failed to update product: ${response.body}');
      }
    } catch (e) {
      throw Exception('Error updating product: $e');
    }
  }

  Future<void> deleteProduct(String id) async {
    try {
      final response = await _api.delete(
        '/products/$id',
        requiresAuth: true,
      );

      if (response.statusCode != 200 && response.statusCode != 204) {
        throw Exception('Failed to delete product: ${response.body}');
      }
    } catch (e) {
      throw Exception('Error deleting product: $e');
    }
  }

  // ==================== VARIANTS ====================

  Future<Variant> createVariant(String productId, Variant variant) async {
    try {
      final response = await _api.post(
        '/products/$productId/variants',
        body: variant.toJson(),
        requiresAuth: true,
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        return Variant.fromJson(jsonDecode(response.body));
      } else {
        throw Exception('Failed to create variant: ${response.body}');
      }
    } catch (e) {
      throw Exception('Error creating variant: $e');
    }
  }

  Future<Variant> updateVariant(String productId, String variantId, Variant variant) async {
    try {
      final response = await _api.put(
        '/products/$productId/variants/$variantId',
        body: variant.toJson(),
        requiresAuth: true,
      );

      if (response.statusCode == 200) {
        return Variant.fromJson(jsonDecode(response.body));
      } else {
        throw Exception('Failed to update variant: ${response.body}');
      }
    } catch (e) {
      throw Exception('Error updating variant: $e');
    }
  }

  Future<void> deleteVariant(String productId, String variantId) async {
    try {
      final response = await _api.delete(
        '/products/$productId/variants/$variantId',
        requiresAuth: true,
      );

      if (response.statusCode != 200 && response.statusCode != 204) {
        throw Exception('Failed to delete variant: ${response.body}');
      }
    } catch (e) {
      throw Exception('Error deleting variant: $e');
    }
  }

  Future<void> adjustStock(String variantId, int adjustment, String reason) async {
    try {
      final response = await _api.post(
        '/variants/$variantId/adjust-stock',
        body: {
          'adjustment': adjustment,
          'reason': reason,
        },
        requiresAuth: true,
      );

      if (response.statusCode != 200 && response.statusCode != 204) {
        throw Exception('Failed to adjust stock: ${response.body}');
      }
    } catch (e) {
      throw Exception('Error adjusting stock: $e');
    }
  }

  // ==================== VENDORS ====================

  Future<List<Vendor>> getVendors() async {
    try {
      final response = await _api.get(
        '/vendors',
        requiresAuth: true,
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((json) => Vendor.fromJson(json)).toList();
      } else {
        throw Exception('Failed to load vendors: ${response.body}');
      }
    } catch (e) {
      throw Exception('Error loading vendors: $e');
    }
  }

  Future<Vendor> createVendor(Vendor vendor) async {
    try {
      final response = await _api.post(
        '/vendors',
        body: vendor.toJson(),
        requiresAuth: true,
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        return Vendor.fromJson(jsonDecode(response.body));
      } else {
        throw Exception('Failed to create vendor: ${response.body}');
      }
    } catch (e) {
      throw Exception('Error creating vendor: $e');
    }
  }

  Future<Vendor> updateVendor(String id, Vendor vendor) async {
    try {
      final response = await _api.put(
        '/vendors/$id',
        body: vendor.toJson(),
        requiresAuth: true,
      );

      if (response.statusCode == 200) {
        return Vendor.fromJson(jsonDecode(response.body));
      } else {
        throw Exception('Failed to update vendor: ${response.body}');
      }
    } catch (e) {
      throw Exception('Error updating vendor: $e');
    }
  }

  Future<void> deleteVendor(String id) async {
    try {
      final response = await _api.delete(
        '/vendors/$id',
        requiresAuth: true,
      );

      if (response.statusCode != 200 && response.statusCode != 204) {
        throw Exception('Failed to delete vendor: ${response.body}');
      }
    } catch (e) {
      throw Exception('Error deleting vendor: $e');
    }
  }

  // ==================== IMAGE UPLOAD ====================

  Future<String> uploadProductImage(File imageFile) async {
    try {
      final token = await _storage.getToken();
      final uri = Uri.parse('${AppConfig.apiBaseUrl}/products/upload-image');

      final request = http.MultipartRequest('POST', uri);
      request.headers['Authorization'] = 'Bearer $token';
      request.files.add(await http.MultipartFile.fromPath('image', imageFile.path));

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['image_url'];
      } else {
        throw Exception('Failed to upload image: ${response.body}');
      }
    } catch (e) {
      throw Exception('Error uploading image: $e');
    }
  }
}

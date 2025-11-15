import 'dart:convert';
import '../models/auth_response.dart';
import 'api_service.dart';
import 'storage_service.dart';

class AuthService {
  final ApiService _api = ApiService();
  final StorageService _storage = StorageService();

  Future<AuthResponse> register({
    required String organizationName,
    required String phoneNumber,
    required String password,
  }) async {
    final response = await _api.post(
      '/auth/register',
      body: {
        'organization_name': organizationName,
        'phone_number': phoneNumber,
        'password': password,
      },
    );

    if (response.statusCode == 201) {
      final authResponse = AuthResponse.fromJson(jsonDecode(response.body));
      await _storage.saveToken(authResponse.token);
      await _storage.saveUser(
        authResponse.user,
        authResponse.organization,
        authResponse.role,
      );
      return authResponse;
    } else {
      final error = jsonDecode(response.body);
      throw Exception(error['error'] ?? 'Registration failed');
    }
  }

  Future<AuthResponse> login({
    required String organizationName,
    required String phoneNumber,
    required String password,
  }) async {
    final response = await _api.post(
      '/auth/login',
      body: {
        'organization_name': organizationName,
        'phone_number': phoneNumber,
        'password': password,
      },
    );

    if (response.statusCode == 200) {
      final authResponse = AuthResponse.fromJson(jsonDecode(response.body));
      await _storage.saveToken(authResponse.token);
      await _storage.saveUser(
        authResponse.user,
        authResponse.organization,
        authResponse.role,
      );
      return authResponse;
    } else {
      final error = jsonDecode(response.body);
      throw Exception(error['error'] ?? 'Login failed');
    }
  }

  Future<void> logout() async {
    await _storage.clearAll();
  }

  Future<bool> isAuthenticated() async {
    final token = await _storage.getToken();
    return token != null;
  }
}

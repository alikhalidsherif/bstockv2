import 'package:flutter/material.dart';
import '../models/user.dart';
import '../models/organization.dart';
import '../services/auth_service.dart';
import '../services/storage_service.dart';

class AuthProvider extends ChangeNotifier {
  final AuthService _authService = AuthService();
  final StorageService _storage = StorageService();

  User? _user;
  Organization? _organization;
  String? _role;
  bool _isAuthenticated = false;
  bool _isLoading = false;

  User? get user => _user;
  Organization? get organization => _organization;
  String? get role => _role;
  bool get isAuthenticated => _isAuthenticated;
  bool get isLoading => _isLoading;
  bool get isOwner => _role == 'owner';

  Future<void> initialize() async {
    _isLoading = true;
    notifyListeners();

    _user = await _storage.getUser();
    _organization = await _storage.getOrganization();
    _role = await _storage.getRole();
    _isAuthenticated = await _authService.isAuthenticated();

    _isLoading = false;
    notifyListeners();
  }

  Future<void> register({
    required String organizationName,
    required String phoneNumber,
    required String password,
  }) async {
    _isLoading = true;
    notifyListeners();

    try {
      final response = await _authService.register(
        organizationName: organizationName,
        phoneNumber: phoneNumber,
        password: password,
      );

      _user = response.user;
      _organization = response.organization;
      _role = response.role;
      _isAuthenticated = true;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> login({
    required String organizationName,
    required String phoneNumber,
    required String password,
  }) async {
    _isLoading = true;
    notifyListeners();

    try {
      final response = await _authService.login(
        organizationName: organizationName,
        phoneNumber: phoneNumber,
        password: password,
      );

      _user = response.user;
      _organization = response.organization;
      _role = response.role;
      _isAuthenticated = true;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> logout() async {
    await _authService.logout();
    _user = null;
    _organization = null;
    _role = null;
    _isAuthenticated = false;
    notifyListeners();
  }
}

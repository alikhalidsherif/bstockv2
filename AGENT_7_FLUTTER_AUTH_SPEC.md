# Agent 7: Flutter - Authentication & Onboarding

## Timeline: Day 1-2 (Can start immediately, parallel with backend agents)
## Dependencies: Agent 2 (auth API)
## Priority: CRITICAL - Foundation for all Flutter work

---

## Mission
Build complete Flutter authentication flow, onboarding wizard, and app foundation with state management.

---

## Deliverables Checklist

### 1. Flutter Project Initialization
**Commands**:
```bash
cd /home/user/bstockv2
flutter create frontend --org com.bstock --platforms android,ios,web
cd frontend
flutter pub add provider http go_router shared_preferences flutter_secure_storage
flutter pub add isar isar_flutter_libs path_provider --dev
flutter pub add isar_generator build_runner --dev
```

### 2. Project Structure
```
frontend/
├── lib/
│   ├── main.dart
│   ├── config/
│   │   ├── app_config.dart
│   │   └── router.dart
│   ├── models/
│   │   ├── user.dart
│   │   ├── organization.dart
│   │   └── auth_response.dart
│   ├── services/
│   │   ├── api_service.dart
│   │   ├── auth_service.dart
│   │   └── storage_service.dart
│   ├── providers/
│   │   └── auth_provider.dart
│   ├── screens/
│   │   ├── auth/
│   │   │   ├── login_screen.dart
│   │   │   ├── register_screen.dart
│   │   │   └── organization_input_screen.dart
│   │   ├── onboarding/
│   │   │   └── onboarding_wizard.dart
│   │   └── home/
│   │       └── home_screen.dart
│   └── widgets/
│       ├── custom_button.dart
│       └── custom_text_field.dart
```

### 3. App Config
**File**: `lib/config/app_config.dart`

```dart
class AppConfig {
  static const String apiBaseUrl = 'http://localhost:8080/api/v1';

  // Colors
  static const primaryColor = Color(0xFF007AFF);
  static const successColor = Color(0xFF34C759);
  static const errorColor = Color(0xFFFF3B30);
  static const backgroundColor = Color(0xFFFFFFFF);
  static const secondaryBackground = Color(0xFFF2F2F7);
  static const textColor = Color(0xFF1C1C1E);
  static const subtextColor = Color(0xFF8A8A8E);
}
```

### 4. Models
**File**: `lib/models/user.dart`

```dart
class User {
  final String id;
  final String phoneNumber;

  User({
    required this.id,
    required this.phoneNumber,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'],
      phoneNumber: json['phone_number'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'phone_number': phoneNumber,
    };
  }
}
```

**File**: `lib/models/organization.dart`

```dart
class Organization {
  final String id;
  final String name;

  Organization({
    required this.id,
    required this.name,
  });

  factory Organization.fromJson(Map<String, dynamic> json) {
    return Organization(
      id: json['id'],
      name: json['name'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
    };
  }
}
```

**File**: `lib/models/auth_response.dart`

```dart
import 'user.dart';
import 'organization.dart';

class AuthResponse {
  final String token;
  final User user;
  final Organization organization;
  final String role;

  AuthResponse({
    required this.token,
    required this.user,
    required this.organization,
    required this.role,
  });

  factory AuthResponse.fromJson(Map<String, dynamic> json) {
    return AuthResponse(
      token: json['token'],
      user: User.fromJson(json['user']),
      organization: Organization.fromJson(json['organization']),
      role: json['role'],
    );
  }
}
```

### 5. API Service
**File**: `lib/services/api_service.dart`

```dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';
import 'storage_service.dart';

class ApiService {
  final StorageService _storage = StorageService();

  Future<Map<String, String>> _getHeaders({bool requiresAuth = false}) async {
    final headers = {
      'Content-Type': 'application/json',
    };

    if (requiresAuth) {
      final token = await _storage.getToken();
      if (token != null) {
        headers['Authorization'] = 'Bearer $token';
      }
    }

    return headers;
  }

  Future<http.Response> post(
    String endpoint, {
    required Map<String, dynamic> body,
    bool requiresAuth = false,
  }) async {
    final url = Uri.parse('${AppConfig.apiBaseUrl}$endpoint');
    final headers = await _getHeaders(requiresAuth: requiresAuth);

    return await http.post(
      url,
      headers: headers,
      body: jsonEncode(body),
    );
  }

  Future<http.Response> get(
    String endpoint, {
    bool requiresAuth = false,
    Map<String, String>? queryParameters,
  }) async {
    final url = Uri.parse('${AppConfig.apiBaseUrl}$endpoint')
        .replace(queryParameters: queryParameters);
    final headers = await _getHeaders(requiresAuth: requiresAuth);

    return await http.get(url, headers: headers);
  }

  Future<http.Response> put(
    String endpoint, {
    required Map<String, dynamic> body,
    bool requiresAuth = false,
  }) async {
    final url = Uri.parse('${AppConfig.apiBaseUrl}$endpoint');
    final headers = await _getHeaders(requiresAuth: requiresAuth);

    return await http.put(
      url,
      headers: headers,
      body: jsonEncode(body),
    );
  }

  Future<http.Response> delete(
    String endpoint, {
    bool requiresAuth = false,
  }) async {
    final url = Uri.parse('${AppConfig.apiBaseUrl}$endpoint');
    final headers = await _getHeaders(requiresAuth: requiresAuth);

    return await http.delete(url, headers: headers);
  }
}
```

### 6. Storage Service
**File**: `lib/services/storage_service.dart`

```dart
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../models/user.dart';
import '../models/organization.dart';

class StorageService {
  final _secureStorage = const FlutterSecureStorage();

  // Token management
  Future<void> saveToken(String token) async {
    await _secureStorage.write(key: 'auth_token', value: token);
  }

  Future<String?> getToken() async {
    return await _secureStorage.read(key: 'auth_token');
  }

  Future<void> deleteToken() async {
    await _secureStorage.delete(key: 'auth_token');
  }

  // User data
  Future<void> saveUser(User user, Organization org, String role) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user', jsonEncode(user.toJson()));
    await prefs.setString('organization', jsonEncode(org.toJson()));
    await prefs.setString('role', role);
  }

  Future<User?> getUser() async {
    final prefs = await SharedPreferences.getInstance();
    final userJson = prefs.getString('user');
    if (userJson != null) {
      return User.fromJson(jsonDecode(userJson));
    }
    return null;
  }

  Future<Organization?> getOrganization() async {
    final prefs = await SharedPreferences.getInstance();
    final orgJson = prefs.getString('organization');
    if (orgJson != null) {
      return Organization.fromJson(jsonDecode(orgJson));
    }
    return null;
  }

  Future<String?> getRole() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('role');
  }

  Future<void> clearAll() async {
    await _secureStorage.deleteAll();
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }

  // Onboarding flag
  Future<void> setOnboardingComplete() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_complete', true);
  }

  Future<bool> isOnboardingComplete() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('onboarding_complete') ?? false;
  }
}
```

### 7. Auth Service
**File**: `lib/services/auth_service.dart`

```dart
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
```

### 8. Auth Provider
**File**: `lib/providers/auth_provider.dart`

```dart
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
```

### 9. Login Screen
**File**: `lib/screens/auth/login_screen.dart`

```dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../providers/auth_provider.dart';
import '../../config/app_config.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/custom_text_field.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _orgController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppConfig.backgroundColor,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Bstock',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: AppConfig.textColor,
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 8),
                Text(
                  'Small Business Operating System',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppConfig.subtextColor,
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 48),
                CustomTextField(
                  controller: _orgController,
                  label: 'Shop Name',
                  hint: 'Enter your shop name',
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Shop name is required';
                    }
                    return null;
                  },
                ),
                SizedBox(height: 16),
                CustomTextField(
                  controller: _phoneController,
                  label: 'Phone Number',
                  hint: '+251911234567',
                  keyboardType: TextInputType.phone,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Phone number is required';
                    }
                    return null;
                  },
                ),
                SizedBox(height: 16),
                CustomTextField(
                  controller: _passwordController,
                  label: 'Password',
                  hint: 'Enter your password',
                  obscureText: true,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Password is required';
                    }
                    return null;
                  },
                ),
                SizedBox(height: 24),
                Consumer<AuthProvider>(
                  builder: (context, auth, _) {
                    return CustomButton(
                      text: 'Login',
                      isLoading: auth.isLoading,
                      onPressed: () async {
                        if (_formKey.currentState!.validate()) {
                          try {
                            await auth.login(
                              organizationName: _orgController.text.trim(),
                              phoneNumber: _phoneController.text.trim(),
                              password: _passwordController.text,
                            );
                            if (mounted) {
                              context.go('/home');
                            }
                          } catch (e) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(e.toString())),
                            );
                          }
                        }
                      },
                    );
                  },
                ),
                SizedBox(height: 16),
                TextButton(
                  onPressed: () => context.go('/register'),
                  child: Text('New shop? Register here'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
```

### 10. Router
**File**: `lib/config/router.dart`

```dart
import 'package:go_router/go_router.dart';
import '../screens/auth/login_screen.dart';
import '../screens/auth/register_screen.dart';
import '../screens/home/home_screen.dart';
import '../screens/onboarding/onboarding_wizard.dart';

final router = GoRouter(
  initialLocation: '/login',
  routes: [
    GoRoute(
      path: '/login',
      builder: (context, state) => const LoginScreen(),
    ),
    GoRoute(
      path: '/register',
      builder: (context, state) => const RegisterScreen(),
    ),
    GoRoute(
      path: '/onboarding',
      builder: (context, state) => const OnboardingWizard(),
    ),
    GoRoute(
      path: '/home',
      builder: (context, state) => const HomeScreen(),
    ),
  ],
);
```

### 11. Main App
**File**: `lib/main.dart`

```dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'config/router.dart';
import 'config/app_config.dart';
import 'providers/auth_provider.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => AuthProvider()..initialize(),
        ),
      ],
      child: MaterialApp.router(
        title: 'Bstock',
        theme: ThemeData(
          primaryColor: AppConfig.primaryColor,
          scaffoldBackgroundColor: AppConfig.backgroundColor,
          fontFamily: 'Roboto',
        ),
        routerConfig: router,
      ),
    );
  }
}
```

---

## Testing Checklist

- [ ] Flutter app builds successfully
- [ ] Login screen displays correctly
- [ ] Registration flow works
- [ ] Token persists after app restart
- [ ] Navigation works
- [ ] Error messages display
- [ ] Loading states show
- [ ] Logout clears data

---

## Success Criteria

1. ✅ Complete authentication flow
2. ✅ Token management
3. ✅ State management foundation
4. ✅ Routing configured
5. ✅ UI follows design specs

**Estimated Completion: 10-12 hours**

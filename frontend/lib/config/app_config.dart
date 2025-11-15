import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

class AppConfig {
  // API Configuration
  // For production: Change this to your domain
  // For development: Use localhost
  static const String _productionApiUrl = 'https://api.ashreef.com/api/v1';
  static const String _developmentApiUrl = 'http://localhost:8080/api/v1';

  // Automatically use production URL in release mode, development URL in debug mode
  static String get apiBaseUrl {
    return kReleaseMode ? _productionApiUrl : _developmentApiUrl;
  }

  // Colors - Following iOS design guidelines
  static const primaryColor = Color(0xFF007AFF);
  static const successColor = Color(0xFF34C759);
  static const errorColor = Color(0xFFFF3B30);
  static const backgroundColor = Color(0xFFFFFFFF);
  static const secondaryBackground = Color(0xFFF2F2F7);
  static const textColor = Color(0xFF1C1C1E);
  static const subtextColor = Color(0xFF8A8A8E);

  // App Info
  static const String appName = 'Bstock';
  static const String appVersion = '1.0.0';
}

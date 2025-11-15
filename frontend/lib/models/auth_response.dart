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

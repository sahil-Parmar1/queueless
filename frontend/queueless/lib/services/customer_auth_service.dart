import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'google_auth_service.dart';

class AuthResult {
  final bool success;
  final String? token;
  final Map<String, dynamic>? user;
  final String? errorMessage;
  final bool isNewUser;

  AuthResult({
    required this.success,
    this.token,
    this.user,
    this.errorMessage,
    this.isNewUser = false,
  });
}

class CustomerAuthService {
  static final CustomerAuthService _instance = CustomerAuthService._internal();
  factory CustomerAuthService() => _instance;
  CustomerAuthService._internal();

  final GoogleAuthService _googleAuthService = GoogleAuthService();
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  static const String _keyJwtToken = 'queueless_customer_jwt';
  static const String _keyUserData = 'queueless_customer_user';

  String get _baseUrl {
    if (kIsWeb) {
      return 'http://localhost:8080/api/auth';
    }
    // Android emulator -> 10.0.2.2, default fallback -> localhost
    return 'http://10.0.2.2:8080/api/auth';
  }

  // ==========================================
  // GOOGLE SIGN IN (AUTO-REGISTER & LOGIN)
  // ==========================================
  Future<AuthResult> signInWithGoogle() async {
    try {
      UserCredential? userCredential;

      if (kIsWeb) {
        GoogleAuthProvider googleProvider = GoogleAuthProvider();
        userCredential = await FirebaseAuth.instance.signInWithPopup(googleProvider);
      } else {
        userCredential = await _googleAuthService.signInWithGoogle();
      }

      if (userCredential == null) {
        return AuthResult(
          success: false,
          errorMessage: 'Google sign-in was canceled or failed.',
        );
      }

      final user = userCredential.user;
      final idToken = await user?.getIdToken(true);

      if (idToken == null) {
        return AuthResult(
          success: false,
          errorMessage: 'Unable to retrieve authentication token from Google.',
        );
      }

      final response = await http.post(
        Uri.parse('$_baseUrl/customer/google'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'idToken': idToken}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final String token = data['token'];
        final Map<String, dynamic> userData = data['user'] != null
            ? Map<String, dynamic>.from(data['user'])
            : {
                'name': user?.displayName ?? 'Valued Customer',
                'email': user?.email ?? '',
                'role': 'CUSTOMER',
              };

        final bool isNewUser = data['isNewUser'] == true;

        await _saveSession(token: token, user: userData);

        return AuthResult(
          success: true,
          token: token,
          user: userData,
          isNewUser: isNewUser,
        );
      } else {
        final errorMsg = _extractErrorMessage(response);
        return AuthResult(
          success: false,
          errorMessage: errorMsg,
        );
      }
    } catch (e) {
      return AuthResult(
        success: false,
        errorMessage: 'An error occurred during Google sign-in: $e',
      );
    }
  }

  // ==========================================
  // EMAIL / PASSWORD LOGIN
  // ==========================================
  Future<AuthResult> loginWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/customer/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email.trim(),
          'password': password,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final String token = data['token'];
        final Map<String, dynamic>? userData = data['user'] != null
            ? Map<String, dynamic>.from(data['user'])
            : null;

        await _saveSession(token: token, user: userData);

        return AuthResult(
          success: true,
          token: token,
          user: userData,
        );
      } else {
        final errorMsg = _extractErrorMessage(response);
        return AuthResult(
          success: false,
          errorMessage: errorMsg,
        );
      }
    } catch (e) {
      return AuthResult(
        success: false,
        errorMessage: 'Network error during login: $e',
      );
    }
  }

  // ==========================================
  // EMAIL / PASSWORD REGISTER
  // ==========================================
  Future<AuthResult> registerWithEmail({
    required String name,
    required String email,
    required String password,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/customer/register'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'name': name.trim(),
          'email': email.trim(),
          'password': password,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final String token = data['token'];
        final Map<String, dynamic>? userData = data['user'] != null
            ? Map<String, dynamic>.from(data['user'])
            : null;

        await _saveSession(token: token, user: userData);

        return AuthResult(
          success: true,
          token: token,
          user: userData,
          isNewUser: true,
        );
      } else {
        final errorMsg = _extractErrorMessage(response);
        return AuthResult(
          success: false,
          errorMessage: errorMsg,
        );
      }
    } catch (e) {
      return AuthResult(
        success: false,
        errorMessage: 'Network error during registration: $e',
      );
    }
  }

  // ==========================================
  // SMART AUTH OR AUTO-REGISTER (Login if registered, Register & Login if not)
  // ==========================================
  Future<AuthResult> authOrRegister({
    required String email,
    required String password,
    String? name,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/customer/auth-or-register'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'name': name?.trim() ?? email.split('@').first,
          'email': email.trim(),
          'password': password,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final String token = data['token'];
        final Map<String, dynamic>? userData = data['user'] != null
            ? Map<String, dynamic>.from(data['user'])
            : null;
        final bool isNew = data['isNewUser'] == true;

        await _saveSession(token: token, user: userData);

        return AuthResult(
          success: true,
          token: token,
          user: userData,
          isNewUser: isNew,
        );
      } else {
        final errorMsg = _extractErrorMessage(response);
        return AuthResult(
          success: false,
          errorMessage: errorMsg,
        );
      }
    } catch (e) {
      return AuthResult(
        success: false,
        errorMessage: 'Network error during authentication: $e',
      );
    }
  }

  // ==========================================
  // SESSION STORAGE & MANAGEMENT
  // ==========================================
  Future<void> _saveSession({
    required String token,
    Map<String, dynamic>? user,
  }) async {
    await _storage.write(key: _keyJwtToken, value: token);
    if (user != null) {
      await _storage.write(key: _keyUserData, value: jsonEncode(user));
    }
  }

  Future<String?> getToken() async {
    return await _storage.read(key: _keyJwtToken);
  }

  Future<Map<String, dynamic>?> getCurrentUser() async {
    final rawUser = await _storage.read(key: _keyUserData);
    if (rawUser != null) {
      try {
        return jsonDecode(rawUser) as Map<String, dynamic>;
      } catch (_) {}
    }
    return null;
  }

  Future<bool> isLoggedIn() async {
    final token = await getToken();
    return token != null && token.isNotEmpty;
  }

  Future<void> logout() async {
    try {
      await FirebaseAuth.instance.signOut();
    } catch (_) {}
    await _storage.delete(key: _keyJwtToken);
    await _storage.delete(key: _keyUserData);
  }

  String _extractErrorMessage(http.Response response) {
    try {
      final errData = jsonDecode(response.body);
      if (errData is Map && errData['message'] != null && errData['message'].toString().isNotEmpty) {
        return errData['message'].toString();
      }
      if (errData is Map && errData['error'] != null) {
        return errData['error'].toString();
      }
    } catch (_) {}
    return response.body.isNotEmpty ? response.body : 'Authentication failed (${response.statusCode})';
  }
}

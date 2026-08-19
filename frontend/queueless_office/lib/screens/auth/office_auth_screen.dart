import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:queueless_office/screens/dashboad/OfficeDashboardScreen.dart';
import 'package:queueless_office/services/google_auth_service.dart';

class OfficeAuthScreen extends StatefulWidget {
  const OfficeAuthScreen({super.key});
  @override
  State<OfficeAuthScreen> createState() => _OfficeAuthScreenState();
}

class _OfficeAuthScreenState extends State<OfficeAuthScreen> {
  final GoogleAuthService _googleAuthService = GoogleAuthService();
  final _storage = const FlutterSecureStorage();
  bool _loading = false;

  String get _backendUrl => kIsWeb
      ? 'http://localhost:8080/api/auth/office/google'
      : 'http://10.0.2.2:8080/api/auth/office/google';

  Future<void> _loginWithGoogle() async {
    setState(() => _loading = true);

    try {
      UserCredential? userCredential;

      if (kIsWeb) {
        // 🌐 FLUTTER WEB: Use Firebase Web Popup
        GoogleAuthProvider googleProvider = GoogleAuthProvider();
        userCredential = await FirebaseAuth.instance.signInWithPopup(googleProvider);
      } else {
        // 📱 ANDROID / IOS: Use GoogleAuthService
        userCredential = await _googleAuthService.signInWithGoogle();
      }

      if (userCredential != null) {
        final user = userCredential.user;
        final idToken = await user?.getIdToken(true);

        if (idToken != null) {
          final response = await http.post(
            Uri.parse(_backendUrl),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'idToken': idToken}),
          );

          if (response.statusCode == 200) {
            final data = jsonDecode(response.body);
            final String token = data['token'];

            // Store token securely
            await _storage.write(key: 'jwt_token', value: token);

            if (mounted) {
              _showSnackBar('Welcome to Office Portal!', isError: false);

              // Navigate to dashboard
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (context) => const OfficeDashboardScreen()),
                (route) => false,
              );
            }
          } else {
            final err = jsonDecode(response.body);
            _showSnackBar(err['message'] ?? 'Authentication failed. Please try again.', isError: true);
          }
        } else {
          _showSnackBar('Could not retrieve Google ID Token', isError: true);
        }
      }
    } catch (e) {
      _showSnackBar('Google Sign-In failed: $e', isError: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showSnackBar(String message, {required bool isError}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError ? Icons.error_outline : Icons.check_circle_outline,
              color: Colors.white,
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(message, style: const TextStyle(fontWeight: FontWeight.w500))),
          ],
        ),
        backgroundColor: isError ? const Color(0xFFEF4444) : const Color(0xFF10B981),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Header Logo & Title
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF4F46E5), Color(0xFF6366F1)],
                      ),
                      borderRadius: BorderRadius.circular(22),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF4F46E5).withValues(alpha: 0.35),
                          blurRadius: 24,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: const Icon(Icons.business_rounded, color: Colors.white, size: 36),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Queueless Office Portal',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0F172A),
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Sign in with your Google account to manage your queues, office details, and documents.',
                    style: TextStyle(fontSize: 14, color: Color(0xFF64748B), height: 1.4),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 36),

                  // Card Container
                  Container(
                    padding: const EdgeInsets.all(32),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF0F172A).withValues(alpha: 0.06),
                          blurRadius: 30,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Google Sign-In Button
                        SizedBox(
                          height: 54,
                          child: OutlinedButton(
                            onPressed: _loading ? null : _loginWithGoogle,
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: Color(0xFFCBD5E1), width: 1.5),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              backgroundColor: Colors.white,
                              elevation: 0,
                            ),
                            child: _loading
                                ? const SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(color: Color(0xFF4F46E5), strokeWidth: 2.5),
                                  )
                                : Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Image.network(
                                        'https://www.gstatic.com/firebasejs/ui/2.0.0/images/auth/google.svg',
                                        width: 22,
                                        height: 22,
                                        errorBuilder: (context, error, stackTrace) => const Icon(
                                          Icons.g_mobiledata_rounded,
                                          size: 28,
                                          color: Color(0xFF4285F4),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      const Text(
                                        'Continue with Google',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w700,
                                          color: Color(0xFF0F172A),
                                        ),
                                      ),
                                    ],
                                  ),
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Security Info Badge
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.shield_outlined, color: Color(0xFF64748B), size: 18),
                              SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'Protected by Queueless Microservices Auth & Google OAuth 2.0',
                                  style: TextStyle(fontSize: 12, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
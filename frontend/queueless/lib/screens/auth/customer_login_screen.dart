import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../services/google_auth_service.dart';

class CustomerLoginScreen extends StatefulWidget {
  const CustomerLoginScreen({super.key});

  @override
  State<CustomerLoginScreen> createState() => _CustomerLoginScreenState();
}

class _CustomerLoginScreenState extends State<CustomerLoginScreen> {
  final GoogleAuthService _googleAuthService = GoogleAuthService();
  bool _loading = false;

  Future<void> _googleLogin() async {
    setState(() {
      _loading = true;
    });

    try {
      final userCredential = await _googleAuthService.signInWithGoogle();

      if (userCredential != null) {
        final user = userCredential.user;

        print("Customer logged into Firebase!");

        // 1. Get fresh Firebase ID Token
        final idToken = await user?.getIdToken(true);
        print("COPY THIS TOKEN TO POSTMAN: $idToken");

        if (idToken != null) {
          // 2. Send Firebase ID token to Spring Boot backend
          // Note: Use 'http://10.0.2.2:8080' for Android Emulator
          // Use 'http://localhost:8080' for Web / iOS Simulator
          final response = await http.post(
            Uri.parse('http://10.0.2.2:8080/api/auth/customer/google'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'idToken': idToken}),
          );

          if (response.statusCode == 200) {
            final data = jsonDecode(response.body);
            final String queuelessJwt = data['token'];

            print("RECEIVED QUEUELESS JWT FROM BACKEND: $queuelessJwt");

            // TODO: Save queuelessJwt to Flutter secure storage and navigate to Customer Home Screen
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Login successful!')),
              );
            }
          } else {
            print("Backend error: ${response.body}");
          }
        }
      }
    } catch (e) {
      print("Login error: $e");
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Customer Login"),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _loading ? null : _googleLogin,
              icon: const Icon(Icons.login),
              label: Text(
                _loading ? "Signing in..." : "Continue with Google",
              ),
            ),
          ),
        ),
      ),
    );
  }
}
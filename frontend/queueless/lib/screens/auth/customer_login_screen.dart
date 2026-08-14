import 'dart:convert';
import 'package:flutter/foundation.dart'; // REQUIRED for kIsWeb
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart'; // REQUIRED for signInWithPopup
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
        print("Customer logged into Firebase!");

        // 1. Get Firebase ID token
        final idToken = await user?.getIdToken(true);
        print("ID TOKEN: $idToken");

        if (idToken != null) {
          // 2. Select host based on Web vs Android Emulator
          final String backendUrl = kIsWeb
              ? 'http://localhost:8080/api/auth/customer/google'
              : 'http://10.0.2.2:8080/api/auth/customer/google';

          // 3. Send token to Spring Boot backend
          final response = await http.post(
            Uri.parse(backendUrl),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'idToken': idToken}),
          );

          if (response.statusCode == 200) {
            final data = jsonDecode(response.body);
            final String queuelessJwt = data['token'];

            print("RECEIVED QUEUELESS JWT FROM BACKEND: $queuelessJwt");

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
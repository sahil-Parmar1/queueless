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

        GoogleAuthProvider googleProvider = GoogleAuthProvider();
        userCredential = await FirebaseAuth.instance.signInWithPopup(googleProvider);
      } else {

        userCredential = await _googleAuthService.signInWithGoogle();
      }

      if (userCredential != null) {
        final user = userCredential.user;
        print("Customer logged into Firebase!");


        final idToken = await user?.getIdToken(true);
        print("ID TOKEN: $idToken");

        if (idToken != null) {

          final String backendUrl = kIsWeb
              ? 'http://localhost:8080/api/auth/customer/google'
              : 'http://10.0.2.2:8080/api/auth/customer/google';


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
                const SnackBar(
                  content: Row(
                    children: [
                      Icon(Icons.check_circle_outline, color: Colors.white),
                      SizedBox(width: 10),
                      Text('Login successful!'),
                    ],
                  ),
                  backgroundColor: Colors.green,
                  behavior: SnackBarBehavior.floating,
                ),
              );
            }
          } else {

            String errorMessage = 'Login failed. Please try again.';
            try {
              final errData = jsonDecode(response.body);
              if (errData['message'] != null && errData['message'].toString().isNotEmpty) {
                errorMessage = errData['message'].toString();
              }
            } catch (_) {
              errorMessage = response.body;
            }


            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Row(
                    children: [
                      const Icon(Icons.error_outline, color: Colors.white),
                      const SizedBox(width: 10),
                      Expanded(child: Text(errorMessage)),
                    ],
                  ),
                  backgroundColor: Colors.red,
                  behavior: SnackBarBehavior.floating,
                ),
              );
            }
          }
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Failed to retrieve Google ID Token'),
                backgroundColor: Colors.red,
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        }
      }
    } catch (e) {
      print("Login error: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.white),
                const SizedBox(width: 10),
                Expanded(child: Text('Google Sign-In Error: $e')),
              ],
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
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
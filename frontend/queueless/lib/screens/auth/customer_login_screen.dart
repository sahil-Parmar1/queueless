import 'package:flutter/material.dart';
import '../../services/google_auth_service.dart';

class CustomerLoginScreen extends StatefulWidget {
  const CustomerLoginScreen({super.key});

  @override
  State<CustomerLoginScreen> createState() =>
      _CustomerLoginScreenState();
}

class _CustomerLoginScreenState
    extends State<CustomerLoginScreen> {

  final GoogleAuthService _googleAuthService =
  GoogleAuthService();

  bool _loading = false;

  Future<void> _googleLogin() async {

    setState(() {
      _loading = true;
    });

    final userCredential =
    await _googleAuthService.signInWithGoogle();

    setState(() {
      _loading = false;
    });

    if (userCredential != null) {

      final user = userCredential.user;

      print("Customer logged in!");
      print("Name: ${user?.displayName}");
      print("Email: ${user?.email}");
      print("UID: ${user?.uid}");

      // NEXT:
      // Send Firebase ID token to Spring Boot
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
                _loading
                    ? "Signing in..."
                    : "Continue with Google",
              ),
            ),
          ),
        ),
      ),
    );
  }
}
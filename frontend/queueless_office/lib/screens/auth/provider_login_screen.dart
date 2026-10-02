import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:queueless_office/screens/provider_dashboard/provider_dashboard_screen.dart';
import 'package:queueless_office/theme/provider_theme.dart';

class ProviderLoginScreen extends StatefulWidget {
  const ProviderLoginScreen({super.key});

  @override
  State<ProviderLoginScreen> createState() => _ProviderLoginScreenState();
}

class _ProviderLoginScreenState extends State<ProviderLoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _officeIdController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();

  final _storage = const FlutterSecureStorage();
  bool _loading = false;
  bool _obscurePassword = true;

  String get _backendUrl => kIsWeb
      ? 'http://localhost:8081/api/provider/login'
      : 'http://10.0.2.2:8081/api/provider/login';

  @override
  void dispose() {
    _officeIdController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _loading = true);

    try {
      final response = await http.post(
        Uri.parse(_backendUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'officeId': _officeIdController.text.trim().toUpperCase(),
          'username': _usernameController.text.trim().toLowerCase(),
          'password': _passwordController.text.trim(),
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final String token = data['token'];
        final provider = data['provider'];

        // Store auth credentials securely
        await _storage.write(key: 'jwt_token', value: token);
        await _storage.write(key: 'user_role', value: 'PROVIDER');
        if (provider != null) {
          await _storage.write(key: 'provider_data', value: jsonEncode(provider));
          if (provider['officeCode'] != null) {
            await _storage.write(key: 'office_id', value: provider['officeCode'].toString());
          }
        }

        if (mounted) {
          _showSnackBar('Welcome, ${provider?['name'] ?? 'Provider'}!', isError: false);
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (context) => const ProviderDashboardScreen()),
            (route) => false,
          );
        }
      } else {
        String errorMessage = 'Login failed. Please check your credentials.';
        try {
          final err = jsonDecode(response.body);
          if (err['message'] != null) {
            errorMessage = err['message'];
          } else if (err['error'] != null) {
            errorMessage = err['error'];
          }
        } catch (_) {}

        if (response.statusCode == 403) {
          errorMessage = 'Account deactivated. Contact your office administrator.';
        } else if (response.statusCode == 401) {
          errorMessage = 'Invalid Office ID, username, or password.';
        }

        _showSnackBar(errorMessage, isError: true);
      }
    } catch (e) {
      _showSnackBar('Connection error: $e', isError: true);
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
            Expanded(child: Text(message, style: const TextStyle(fontWeight: FontWeight.w600))),
          ],
        ),
        backgroundColor: isError ? ProviderColors.error : ProviderColors.success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: ProviderTheme.themeData,
      child: Scaffold(
        backgroundColor: ProviderColors.background,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: ProviderColors.mainText),
            onPressed: () => Navigator.pop(context),
            tooltip: 'Back to Office Login',
          ),
        ),
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 460),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Header Icon
                    Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        gradient: ProviderColors.headerGradient,
                        borderRadius: BorderRadius.circular(22),
                        boxShadow: ProviderColors.primaryGlow,
                      ),
                      child: const Icon(Icons.badge_rounded, color: Colors.white, size: 36),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'Provider Portal',
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        color: ProviderColors.mainText,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Sign in with your office credentials to manage your consultation queue.',
                      style: TextStyle(fontSize: 14, color: ProviderColors.secondaryText, height: 1.4),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 28),

                    // Login Card
                    Container(
                      padding: const EdgeInsets.all(28),
                      decoration: BoxDecoration(
                        color: ProviderColors.card,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: ProviderColors.border),
                        boxShadow: ProviderColors.cardShadow,
                      ),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Office ID Field
                            TextFormField(
                              controller: _officeIdController,
                              textCapitalization: TextCapitalization.characters,
                              decoration: InputDecoration(
                                labelText: 'Office ID',
                                hintText: 'e.g. OFF-QL8392',
                                prefixIcon: const Icon(Icons.domain_outlined, color: ProviderColors.primary),
                                filled: true,
                                fillColor: ProviderColors.background,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: const BorderSide(color: ProviderColors.border),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: const BorderSide(color: ProviderColors.border),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: const BorderSide(color: ProviderColors.primary, width: 1.8),
                                ),
                              ),
                              validator: (val) {
                                if (val == null || val.trim().isEmpty) {
                                  return 'Please enter your Office ID';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 18),

                            // Username Field
                            TextFormField(
                              controller: _usernameController,
                              autocorrect: false,
                              decoration: InputDecoration(
                                labelText: 'Username',
                                hintText: 'e.g. dr.robert',
                                prefixIcon: const Icon(Icons.person_outline, color: ProviderColors.primary),
                                filled: true,
                                fillColor: ProviderColors.background,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: const BorderSide(color: ProviderColors.border),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: const BorderSide(color: ProviderColors.border),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: const BorderSide(color: ProviderColors.primary, width: 1.8),
                                ),
                              ),
                              validator: (val) {
                                if (val == null || val.trim().isEmpty) {
                                  return 'Please enter your username';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 18),

                            // Password Field
                            TextFormField(
                              controller: _passwordController,
                              obscureText: _obscurePassword,
                              decoration: InputDecoration(
                                labelText: 'Password',
                                hintText: '••••••••',
                                prefixIcon: const Icon(Icons.lock_outline, color: ProviderColors.primary),
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                                    color: ProviderColors.mutedText,
                                  ),
                                  onPressed: () {
                                    setState(() => _obscurePassword = !_obscurePassword);
                                  },
                                ),
                                filled: true,
                                fillColor: ProviderColors.background,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: const BorderSide(color: ProviderColors.border),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: const BorderSide(color: ProviderColors.border),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: const BorderSide(color: ProviderColors.primary, width: 1.8),
                                ),
                              ),
                              validator: (val) {
                                if (val == null || val.trim().isEmpty) {
                                  return 'Please enter your password';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 26),

                            // Submit Button
                            SizedBox(
                              height: 52,
                              child: ElevatedButton(
                                onPressed: _loading ? null : _handleLogin,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: ProviderColors.primary,
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                ),
                                child: _loading
                                    ? const SizedBox(
                                        width: 22,
                                        height: 22,
                                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                                      )
                                    : const Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(Icons.login_rounded, size: 20),
                                          SizedBox(width: 8),
                                          Text(
                                            'Sign In',
                                            style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ],
                                      ),
                              ),
                            ),
                            const SizedBox(height: 20),

                            // Helper message
                            Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: ProviderColors.primarySoft,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: const Color(0xFFDDD6FE)),
                              ),
                              child: const Row(
                                children: [
                                  Icon(Icons.info_outline, color: ProviderColors.primaryDark, size: 18),
                                  SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      'Contact your office administrator if you forgot your username or password.',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: ProviderColors.primaryDark,
                                        fontWeight: FontWeight.w500,
                                        height: 1.3,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

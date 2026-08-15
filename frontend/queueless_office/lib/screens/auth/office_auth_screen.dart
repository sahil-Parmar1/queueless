import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:queueless_office/screens/dashboad/OfficeDashboardScreen.dart';
import 'package:queueless_office/screens/dashboad/office_onboarding_screen.dart';


class OfficeAuthScreen extends StatefulWidget {
  const OfficeAuthScreen({super.key});

  @override
  State<OfficeAuthScreen> createState() => _OfficeAuthScreenState();
}

class _OfficeAuthScreenState extends State<OfficeAuthScreen> {
  int _selectedTabIndex = 0; // 0: Register, 1: Login

  final _formKeyRegister = GlobalKey<FormState>();
  final _formKeyLogin = GlobalKey<FormState>();
  final _storage = const FlutterSecureStorage();
  // Controllers - Registration
  final TextEditingController _regNameController = TextEditingController();
  final TextEditingController _regEmailController = TextEditingController();
  final TextEditingController _regPasswordController = TextEditingController();

  // Controllers - Login
  final TextEditingController _loginEmailController = TextEditingController();
  final TextEditingController _loginPasswordController = TextEditingController();

  bool _loading = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _regNameController.dispose();
    _regEmailController.dispose();
    _regPasswordController.dispose();
    _loginEmailController.dispose();
    _loginPasswordController.dispose();
    super.dispose();
  }

  String get _baseUrl => kIsWeb
      ? 'http://localhost:8080/api/auth/office'
      : 'http://10.0.2.2:8080/api/auth/office';

  // REGISTER METHOD
  Future<void> _registerOffice() async {
    if (!_formKeyRegister.currentState!.validate()) return;
    setState(() => _loading = true);

    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/register'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'name': _regNameController.text.trim(),
          'email': _regEmailController.text.trim(),
          'password': _regPasswordController.text,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final String? token = data['token'];

        if (token != null) {
          const storage = FlutterSecureStorage();
          await storage.write(key: 'jwt_token', value: token);
        }

        if (mounted) {
          _showSnackBar('Office registered successfully! Please complete your office setup.', isError: false);
          // Navigate straight to Onboarding to complete their profile & documents
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const OfficeOnboardingScreen()),
          );
        }
      } else {
        final err = jsonDecode(response.body);
        _showSnackBar(err['message'] ?? 'Registration failed', isError: true);
      }
    } catch (e) {
      _showSnackBar('Network error: $e', isError: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // LOGIN METHOD
  Future<void> _loginOffice() async {
    if (!_formKeyLogin.currentState!.validate()) return;
    setState(() => _loading = true);

    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': _loginEmailController.text.trim(),
          'password': _loginPasswordController.text,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final String token = data['token'];

        // 1. Save JWT token securely
        const storage = FlutterSecureStorage();
        await storage.write(key: 'jwt_token', value: token);

        // If your backend also returns office details, you can save them too:
        if (data['office'] != null) {
          await storage.write(key: 'office_id', value: data['office']['id'].toString());
          await storage.write(key: 'office_name', value: data['office']['name'] ?? '');
        }

        if (mounted) {
          _showSnackBar('Login successful! Welcome back.', isError: false);

          // 2. Navigate and remove all previous routes from stack
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(
              builder: (context) => const OfficeDashboardScreen(), // Replace with your dashboard widget
            ),
                (route) => false,
          );
        }
      } else {
        final err = jsonDecode(response.body);
        _showSnackBar(err['message'] ?? 'Invalid office email or password', isError: true);
      }
    } catch (e) {
      _showSnackBar('Network error: $e', isError: true);
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
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF4F46E5), Color(0xFF6366F1)],
                      ),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF4F46E5).withOpacity(0.3),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: const Icon(Icons.business_rounded, color: Colors.white, size: 32),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Office Portal',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0F172A),
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _selectedTabIndex == 0
                        ? 'Create an account to manage your queues'
                        : 'Sign in to access your office dashboard',
                    style: const TextStyle(fontSize: 14, color: Color(0xFF64748B)),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),

                  // Modern Card Container
                  Container(
                    padding: const EdgeInsets.all(28),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF0F172A).withOpacity(0.06),
                          blurRadius: 30,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Pill Segmented Switcher
                        _buildSegmentedTab(),
                        const SizedBox(height: 28),

                        // Form View
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 250),
                          child: _selectedTabIndex == 0
                              ? _buildRegisterForm()
                              : _buildLoginForm(),
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

  // CUSTOM SEGMENTED PILL SWITCHER
  Widget _buildSegmentedTab() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _selectedTabIndex = 0),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: _selectedTabIndex == 0 ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: _selectedTabIndex == 0
                      ? [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                      : [],
                ),
                child: Text(
                  'Register',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: _selectedTabIndex == 0
                        ? const Color(0xFF4F46E5)
                        : const Color(0xFF64748B),
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _selectedTabIndex = 1),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: _selectedTabIndex == 1 ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: _selectedTabIndex == 1
                      ? [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                      : [],
                ),
                child: Text(
                  'Sign In',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: _selectedTabIndex == 1
                        ? const Color(0xFF4F46E5)
                        : const Color(0xFF64748B),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // REGISTER FORM
  Widget _buildRegisterForm() {
    return Form(
      key: _formKeyRegister,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildTextField(
            controller: _regNameController,
            label: 'Office Name',
            hint: 'e.g. City Health Clinic',
            icon: Icons.business_outlined,
            validator: (val) => val == null || val.isEmpty ? 'Please enter office name' : null,
          ),
          const SizedBox(height: 18),
          _buildTextField(
            controller: _regEmailController,
            label: 'Office Email',
            hint: 'office@company.com',
            icon: Icons.email_outlined,
            keyboardType: TextInputType.emailAddress,
            validator: (val) {
              if (val == null || val.isEmpty) return 'Please enter email';
              if (!val.contains('@')) return 'Please enter a valid email';
              return null;
            },
          ),
          const SizedBox(height: 18),
          _buildTextField(
            controller: _regPasswordController,
            label: 'Password',
            hint: '••••••••',
            icon: Icons.lock_outline,
            obscureText: _obscurePassword,
            isPassword: true,
            validator: (val) {
              if (val == null || val.isEmpty) return 'Please enter password';
              if (val.length < 6) return 'Password must be at least 6 characters';
              return null;
            },
          ),
          const SizedBox(height: 28),
          _buildGradientButton(
            label: 'Create Account',
            onPressed: _registerOffice,
          ),
        ],
      ),
    );
  }

  // LOGIN FORM
  Widget _buildLoginForm() {
    return Form(
      key: _formKeyLogin,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildTextField(
            controller: _loginEmailController,
            label: 'Office Email',
            hint: 'office@company.com',
            icon: Icons.email_outlined,
            keyboardType: TextInputType.emailAddress,
            validator: (val) => val == null || val.isEmpty ? 'Please enter email' : null,
          ),
          const SizedBox(height: 18),
          _buildTextField(
            controller: _loginPasswordController,
            label: 'Password',
            hint: '••••••••',
            icon: Icons.lock_outline,
            obscureText: _obscurePassword,
            isPassword: true,
            validator: (val) => val == null || val.isEmpty ? 'Please enter password' : null,
          ),
          const SizedBox(height: 28),
          _buildGradientButton(
            label: 'Sign In to Office',
            onPressed: _loginOffice,
          ),
        ],
      ),
    );
  }

  // REUSABLE MODERN INPUT FIELD
  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    bool obscureText = false,
    bool isPassword = false,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Color(0xFF334155),
          ),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          obscureText: obscureText,
          keyboardType: keyboardType,
          style: const TextStyle(fontSize: 15, color: Color(0xFF0F172A)),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 14),
            prefixIcon: Icon(icon, color: const Color(0xFF64748B), size: 20),
            suffixIcon: isPassword
                ? IconButton(
              icon: Icon(
                _obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                color: const Color(0xFF64748B),
                size: 20,
              ),
              onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
            )
                : null,
            filled: true,
            fillColor: const Color(0xFFF8FAFC),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: Color(0xFFE2E8F0), width: 1),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: Color(0xFF4F46E5), width: 1.8),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: Color(0xFFEF4444), width: 1),
            ),
          ),
          validator: validator,
        ),
      ],
    );
  }

  // REUSABLE GRADIENT BUTTON
  Widget _buildGradientButton({
    required String label,
    required VoidCallback onPressed,
  }) {
    return Container(
      height: 52,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF4F46E5), Color(0xFF6366F1)],
        ),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF4F46E5).withOpacity(0.3),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: _loading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        child: _loading
            ? const SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
        )
            : Text(
          label,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: Colors.white,
            letterSpacing: 0.2,
          ),
        ),
      ),
    );
  }
}
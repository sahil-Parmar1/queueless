import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class OfficeAuthScreen extends StatefulWidget {
  const OfficeAuthScreen({super.key});

  @override
  State<OfficeAuthScreen> createState() => _OfficeAuthScreenState();
}

class _OfficeAuthScreenState extends State<OfficeAuthScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _formKeyRegister = GlobalKey<FormState>();
  final _formKeyLogin = GlobalKey<FormState>();

  // Form Controllers - Registration
  final TextEditingController _regNameController = TextEditingController();
  final TextEditingController _regEmailController = TextEditingController();
  final TextEditingController _regPasswordController = TextEditingController();

  // Form Controllers - Login
  final TextEditingController _loginEmailController = TextEditingController();
  final TextEditingController _loginPasswordController = TextEditingController();

  bool _loading = false;
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _regNameController.dispose();
    _regEmailController.dispose();
    _regPasswordController.dispose();
    _loginEmailController.dispose();
    _loginPasswordController.dispose();
    super.dispose();
  }

  // Get base URL dynamically (Web vs Android Emulator)
  String get _baseUrl => kIsWeb
      ? 'http://localhost:8080/api/auth/office'
      : 'http://10.0.2.2:8080/api/auth/office';

  // ==========================================
  // OFFICE REGISTRATION METHOD
  // ==========================================
  Future<void> _registerOffice() async {
    if (!_formKeyRegister.currentState!.validate()) return;

    setState(() {
      _loading = true;
    });

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
        print("OFFICE REGISTERED SUCCESSFULLY: $data");

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Registration successful! Please login.'),
              backgroundColor: Colors.green,
            ),
          );
          // Switch to Login Tab
          _tabController.animateTo(1);
          _loginEmailController.text = _regEmailController.text;
        }
      } else {
        final err = jsonDecode(response.body);
        _showErrorSnackBar(err['message'] ?? 'Registration failed');
      }
    } catch (e) {
      _showErrorSnackBar('Network error: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ==========================================
  // OFFICE LOGIN METHOD
  // ==========================================
  Future<void> _loginOffice() async {
    if (!_formKeyLogin.currentState!.validate()) return;

    setState(() {
      _loading = true;
    });

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

        print("OFFICE LOGIN SUCCESSFUL! QUEUELESS JWT: $token");

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Login successful!'),
              backgroundColor: Colors.green,
            ),
          );
          // TODO: Save token to FlutterSecureStorage and navigate to Office Dashboard
        }
      } else {
        _showErrorSnackBar('Invalid email or password');
      }
    } catch (e) {
      _showErrorSnackBar('Network error: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showErrorSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.redAccent,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Office Portal'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.app_registration), text: 'Register Office'),
            Tab(icon: Icon(Icons.login), text: 'Office Login'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildRegisterForm(),
          _buildLoginForm(),
        ],
      ),
    );
  }

  // REGISTER FORM WIDGET
  Widget _buildRegisterForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Form(
        key: _formKeyRegister,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Register New Office',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _regNameController,
              decoration: const InputDecoration(
                labelText: 'Office Name',
                prefixIcon: Icon(Icons.business),
                border: OutlineInputBorder(),
              ),
              validator: (val) =>
              val == null || val.isEmpty ? 'Enter office name' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _regEmailController,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'Office Email',
                prefixIcon: Icon(Icons.email),
                border: OutlineInputBorder(),
              ),
              validator: (val) {
                if (val == null || val.isEmpty) return 'Enter email';
                if (!val.contains('@')) return 'Enter valid email';
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _regPasswordController,
              obscureText: _obscurePassword,
              decoration: InputDecoration(
                labelText: 'Password',
                prefixIcon: const Icon(Icons.lock),
                suffixIcon: IconButton(
                  icon: Icon(_obscurePassword
                      ? Icons.visibility_off
                      : Icons.visibility),
                  onPressed: () =>
                      setState(() => _obscurePassword = !_obscurePassword),
                ),
                border: const OutlineInputBorder(),
              ),
              validator: (val) {
                if (val == null || val.isEmpty) return 'Enter password';
                if (val.length < 6) return 'Password must be at least 6 characters';
                return null;
              },
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _loading ? null : _registerOffice,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: _loading
                  ? const CircularProgressIndicator()
                  : const Text('Register Office', style: TextStyle(fontSize: 16)),
            ),
          ],
        ),
      ),
    );
  }

  // LOGIN FORM WIDGET
  Widget _buildLoginForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Form(
        key: _formKeyLogin,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Office Sign In',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _loginEmailController,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'Office Email',
                prefixIcon: Icon(Icons.email),
                border: OutlineInputBorder(),
              ),
              validator: (val) =>
              val == null || val.isEmpty ? 'Enter office email' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _loginPasswordController,
              obscureText: _obscurePassword,
              decoration: InputDecoration(
                labelText: 'Password',
                prefixIcon: const Icon(Icons.lock),
                suffixIcon: IconButton(
                  icon: Icon(_obscurePassword
                      ? Icons.visibility_off
                      : Icons.visibility),
                  onPressed: () =>
                      setState(() => _obscurePassword = !_obscurePassword),
                ),
                border: const OutlineInputBorder(),
              ),
              validator: (val) =>
              val == null || val.isEmpty ? 'Enter password' : null,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _loading ? null : _loginOffice,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: _loading
                  ? const CircularProgressIndicator()
                  : const Text('Login to Office', style: TextStyle(fontSize: 16)),
            ),
          ],
        ),
      ),
    );
  }
}
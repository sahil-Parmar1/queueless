import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:queueless/screens/auth/customer_login_screen.dart';
import 'package:queueless/screens/dashboard/customer_dashboard_screen.dart';
import 'package:queueless/services/customer_auth_service.dart';
import 'package:queueless/services/queue_notification_service.dart';
import 'package:queueless/theme/app_theme.dart';

import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  await QueueNotificationService().initialize();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: QueueNotificationService.navigatorKey,
      title: 'QueueLess - Smart Queue Management',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: const AuthGate(),
    );
  }
}

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  final CustomerAuthService _authService = CustomerAuthService();
  bool _checking = true;
  bool _isAuthenticated = false;
  Map<String, dynamic>? _user;

  @override
  void initState() {
    super.initState();
    _checkAuth();
  }

  Future<void> _checkAuth() async {
    try {
      final isLoggedIn = await _authService.isLoggedIn();
      if (isLoggedIn) {
        final user = await _authService.getCurrentUser();
        if (mounted) {
          setState(() {
            _isAuthenticated = true;
            _user = user;
            _checking = false;
          });
          return;
        }
      }
    } catch (_) {}

    if (mounted) {
      setState(() {
        _isAuthenticated = false;
        _checking = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_checking) {
      return const Scaffold(
        backgroundColor: Color(0xFFF8FAFC),
        body: Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      );
    }

    if (_isAuthenticated) {
      return CustomerDashboardScreen(user: _user);
    }

    return const CustomerLoginScreen();
  }
}

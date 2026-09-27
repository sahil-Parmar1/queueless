import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:queueless_office/firebase_options.dart';
import 'package:queueless_office/screens/auth/office_auth_screen.dart';
import 'package:queueless_office/screens/dashboad/OfficeDashboardScreen.dart';
import 'package:queueless_office/screens/provider_dashboard/provider_dashboard_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  const storage = FlutterSecureStorage();
  final token = await storage.read(key: 'jwt_token');
  final role = await storage.read(key: 'user_role');

  runApp(MyApp(
    isLoggedIn: token != null && token.isNotEmpty,
    userRole: role,
  ));
}

class MyApp extends StatelessWidget {
  final bool isLoggedIn;
  final String? userRole;

  const MyApp({super.key, required this.isLoggedIn, this.userRole});

  @override
  Widget build(BuildContext context) {
    Widget homeScreen;
    if (!isLoggedIn) {
      homeScreen = const OfficeAuthScreen();
    } else if (userRole == 'PROVIDER') {
      homeScreen = const ProviderDashboardScreen();
    } else {
      homeScreen = const OfficeDashboardScreen();
    }

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: homeScreen,
    );
  }
}

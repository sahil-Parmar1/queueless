import 'dart:async';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

/// ============================================================================
/// Centralized Dynamic API Configuration for Office & Provider App (queueless_office)
/// ============================================================================
class ApiConfig {
  static const String defaultIp = '10.81.144.231';
  static const String _storageKey = 'queueless_custom_server_ip';
  static const FlutterSecureStorage _storage = FlutterSecureStorage();

  static String _currentIp = defaultIp;

  static String get serverHost => _currentIp;
  static String get baseApiUrl => 'http://$_currentIp:8081';
  static String get providerStatusWsUrl => 'ws://$_currentIp:8083/ws/provider-status';

  /// Load any saved IP from secure storage on app launch
  static Future<void> init() async {
    try {
      final saved = await _storage.read(key: _storageKey);
      if (saved != null && saved.trim().isNotEmpty) {
        _currentIp = saved.trim();
      }
    } catch (_) {}
  }

  /// Update the active IP and persist to storage
  static Future<void> updateServerIp(String newIp) async {
    _currentIp = newIp.trim();
    try {
      await _storage.write(key: _storageKey, value: _currentIp);
    } catch (_) {}
  }

  /// Reset to default development IP
  static Future<void> resetToDefault() async {
    _currentIp = defaultIp;
    try {
      await _storage.delete(key: _storageKey);
    } catch (_) {}
  }

  /// Test connectivity to backend gateway (Port 8081)
  static Future<bool> testConnection(String testIp) async {
    final ip = testIp.trim();
    if (ip.isEmpty) return false;
    try {
      final uri = Uri.parse('http://$ip:8081/actuator/health');
      final res = await http.get(uri).timeout(const Duration(seconds: 3));
      return res.statusCode >= 200 && res.statusCode < 500;
    } catch (_) {
      try {
        final fallbackUri = Uri.parse('http://$ip:8081/');
        final res = await http.get(fallbackUri).timeout(const Duration(seconds: 3));
        return res.statusCode >= 200 && res.statusCode < 500;
      } catch (_) {
        return false;
      }
    }
  }
}

/// Global dynamic getters ensure 100% backward compatibility with all files
String get serverIp => ApiConfig.serverHost;
String get apiBaseUrl => ApiConfig.baseApiUrl;
String get wsProviderStatusUrl => ApiConfig.providerStatusWsUrl;

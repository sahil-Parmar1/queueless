import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

class OfficeService {
  static final OfficeService _instance = OfficeService._internal();
  factory OfficeService() => _instance;
  OfficeService._internal();

  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  static const String _keyJwtToken = 'queueless_customer_jwt';
  static const String _keyUserData = 'queueless_customer_user';

  String get _baseUrl {
    if (kIsWeb) {
      return 'http://localhost:8080/api';
    }
    return 'http://10.0.2.2:8080/api';
  }

  Future<Map<String, String>> _getHeaders() async {
    final token = await _storage.read(key: _keyJwtToken);
    final headers = {'Content-Type': 'application/json'};
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }

  Future<Map<String, dynamic>?> getCurrentUser() async {
    final rawUser = await _storage.read(key: _keyUserData);
    if (rawUser != null) {
      try {
        return jsonDecode(rawUser) as Map<String, dynamic>;
      } catch (_) {}
    }
    return null;
  }

  /// Search offices by keyword query, category, and city
  Future<List<dynamic>> searchOffices({
    String? query,
    String? category,
    String? city,
  }) async {
    try {
      final queryParams = <String, String>{};
      if (query != null && query.trim().isNotEmpty) {
        queryParams['query'] = query.trim();
      }
      if (category != null && category.trim().isNotEmpty && category != 'ALL') {
        queryParams['category'] = category.trim();
      }
      if (city != null && city.trim().isNotEmpty) {
        queryParams['city'] = city.trim();
      }

      final uri = Uri.parse('$_baseUrl/offices/search')
          .replace(queryParameters: queryParams.isNotEmpty ? queryParams : null);

      final headers = await _getHeaders();
      final response = await http.get(uri, headers: headers);

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as List<dynamic>;
      }
      return [];
    } catch (e) {
      debugPrint('Error searching offices: $e');
      return [];
    }
  }

  /// Get featured / all nearby offices
  Future<List<dynamic>> getFeaturedOffices() async {
    try {
      final uri = Uri.parse('$_baseUrl/offices/featured');
      final headers = await _getHeaders();
      final response = await http.get(uri, headers: headers);

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as List<dynamic>;
      }
      return [];
    } catch (e) {
      debugPrint('Error fetching featured offices: $e');
      return [];
    }
  }

  /// Get detailed office profile
  Future<Map<String, dynamic>?> getOfficeDetails(int officeId) async {
    try {
      final uri = Uri.parse('$_baseUrl/offices/$officeId');
      final headers = await _getHeaders();
      final response = await http.get(uri, headers: headers);

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      debugPrint('Error fetching office details: $e');
      return null;
    }
  }

  /// Get live queue status for an office
  Future<Map<String, dynamic>?> getLiveQueue(int officeId) async {
    try {
      final uri = Uri.parse('$_baseUrl/queue/office/$officeId/live');
      final headers = await _getHeaders();
      final response = await http.get(uri, headers: headers);

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      debugPrint('Error fetching live queue: $e');
      return null;
    }
  }

  /// Book a digital queue token
  Future<Map<String, dynamic>> bookToken({
    required int officeId,
    required String customerName,
    String? customerPhone,
    String? customerEmail,
  }) async {
    try {
      final uri = Uri.parse('$_baseUrl/queue/tokens/book');
      final headers = await _getHeaders();

      final body = {
        'officeId': officeId,
        'customerName': customerName,
        'customerPhone': customerPhone,
        'customerEmail': customerEmail,
      };

      final response = await http.post(
        uri,
        headers: headers,
        body: jsonEncode(body),
      );

      if (response.statusCode == 200) {
        return {
          'success': true,
          'data': jsonDecode(response.body),
        };
      } else {
        return {
          'success': false,
          'errorMessage': 'Booking failed with status ${response.statusCode}',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'errorMessage': 'Network error: $e',
      };
    }
  }

  /// Get currently active token for logged in user
  Future<Map<String, dynamic>?> getMyActiveToken() async {
    try {
      final user = await getCurrentUser();
      String? email = user?['email'];

      String url = '$_baseUrl/queue/tokens/my-active';
      if (email != null && email.isNotEmpty) {
        url += '?email=${Uri.encodeComponent(email)}';
      }

      final uri = Uri.parse(url);
      final headers = await _getHeaders();
      final response = await http.get(uri, headers: headers);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        if (data['hasActiveToken'] == true) {
          return data;
        }
      }
      return null;
    } catch (e) {
      debugPrint('Error fetching active token: $e');
      return null;
    }
  }

  /// Get customer token history
  Future<List<dynamic>> getMyTokenHistory() async {
    try {
      final user = await getCurrentUser();
      String? email = user?['email'];

      String url = '$_baseUrl/queue/tokens/my-history';
      if (email != null && email.isNotEmpty) {
        url += '?email=${Uri.encodeComponent(email)}';
      }

      final uri = Uri.parse(url);
      final headers = await _getHeaders();
      final response = await http.get(uri, headers: headers);

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as List<dynamic>;
      }
      return [];
    } catch (e) {
      debugPrint('Error fetching token history: $e');
      return [];
    }
  }

  /// Cancel an active token
  Future<bool> cancelToken(int tokenId) async {
    try {
      final uri = Uri.parse('$_baseUrl/queue/tokens/$tokenId/cancel');
      final headers = await _getHeaders();
      final response = await http.post(uri, headers: headers);

      return response.statusCode == 200;
    } catch (e) {
      debugPrint('Error cancelling token: $e');
      return false;
    }
  }
}

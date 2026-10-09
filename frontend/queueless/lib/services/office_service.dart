import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:queueless/config/api_config.dart';

class OfficeService {
  static final OfficeService _instance = OfficeService._internal();
  factory OfficeService() => _instance;
  OfficeService._internal();

  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  static const String _keyJwtToken = 'queueless_customer_jwt';
  static const String _keyUserData = 'queueless_customer_user';
  static const String _keyFavoriteIds = 'queueless_customer_favorites';

  final ValueNotifier<Set<int>> favoriteIdsNotifier = ValueNotifier<Set<int>>({});

  Set<int> get favoriteIds => favoriteIdsNotifier.value;
  bool isFavorite(int officeId) => favoriteIdsNotifier.value.contains(officeId);

  String get _baseUrl => '$apiBaseUrl/api';

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

  /// Get active providers for an office
  Future<List<dynamic>> getOfficeProviders(int officeId) async {
    try {
      final uri = Uri.parse('$_baseUrl/offices/$officeId/providers');
      final headers = await _getHeaders();
      final response = await http.get(uri, headers: headers);

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as List<dynamic>;
      }
      return [];
    } catch (e) {
      debugPrint('Error fetching office providers: $e');
      return [];
    }
  }

  /// Book a digital queue token
  Future<Map<String, dynamic>> bookToken({
    required int officeId,
    int? providerId,
    required String customerName,
    String? customerPhone,
    String? customerEmail,
    String? taskDescription,
  }) async {
    try {
      final uri = Uri.parse('$_baseUrl/queue/tokens/book');
      final headers = await _getHeaders();

      final Map<String, dynamic> body = {
        'officeId': officeId,
        'customerName': customerName,
        'customerPhone': customerPhone,
        'customerEmail': customerEmail,
      };
      if (providerId != null) {
        body['providerId'] = providerId;
      }
      if (taskDescription != null && taskDescription.trim().isNotEmpty) {
        final trimmed = taskDescription.trim();
        body['taskDescription'] = trimmed.length > 25 ? trimmed.substring(0, 25) : trimmed;
      }

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
        bool isAuthError = response.statusCode == 401;
        String msg = 'Booking failed with status ${response.statusCode}';
        try {
          final errBody = jsonDecode(response.body);
          if (errBody['error'] != null) {
            msg = errBody['error'];
          } else if (errBody['message'] != null) {
            msg = errBody['message'];
          }
        } catch (_) {}
        if (msg.toLowerCase().contains('authentication') ||
            msg.toLowerCase().contains('logged in') ||
            response.statusCode == 401) {
          isAuthError = true;
        }
        return {
          'success': false,
          'isAuthError': isAuthError,
          'errorMessage': msg,
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

  /// Fetch and cache customer's favorite office IDs
  Future<Set<int>> getFavoriteOfficeIds({bool forceRefresh = false}) async {
    // Load cached favorites from storage first
    if (favoriteIdsNotifier.value.isEmpty || forceRefresh) {
      final cached = await _storage.read(key: _keyFavoriteIds);
      if (cached != null) {
        try {
          final List<dynamic> list = jsonDecode(cached);
          favoriteIdsNotifier.value = list.map((e) => int.parse(e.toString())).toSet();
        } catch (_) {}
      }
    }

    try {
      final user = await getCurrentUser();
      String? email = user?['email'];

      String url = '$_baseUrl/offices/favorite-ids';
      if (email != null && email.isNotEmpty) {
        url += '?email=${Uri.encodeComponent(email)}';
      }

      final uri = Uri.parse(url);
      final headers = await _getHeaders();
      final response = await http.get(uri, headers: headers);

      if (response.statusCode == 200) {
        final List<dynamic> list = jsonDecode(response.body);
        final set = list.map((e) => int.parse(e.toString())).toSet();
        favoriteIdsNotifier.value = set;
        await _storage.write(
          key: _keyFavoriteIds,
          value: jsonEncode(set.toList()),
        );
        return set;
      }
    } catch (e) {
      debugPrint('Error fetching favorite office IDs: $e');
    }

    return favoriteIdsNotifier.value;
  }

  /// Toggle favorite office for current customer
  Future<Map<String, dynamic>> toggleFavoriteOffice(int officeId) async {
    final current = Set<int>.from(favoriteIdsNotifier.value);
    final bool willBeFavorite = !current.contains(officeId);

    // Optimistically update
    if (willBeFavorite) {
      current.add(officeId);
    } else {
      current.remove(officeId);
    }
    favoriteIdsNotifier.value = current;
    await _storage.write(
      key: _keyFavoriteIds,
      value: jsonEncode(current.toList()),
    );

    try {
      final user = await getCurrentUser();
      String? email = user?['email'];

      String url = '$_baseUrl/offices/$officeId/favorite/toggle';
      if (email != null && email.isNotEmpty) {
        url += '?email=${Uri.encodeComponent(email)}';
      }

      final uri = Uri.parse(url);
      final headers = await _getHeaders();
      final response = await http.post(uri, headers: headers);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final bool serverIsFav = data['isFavorite'] == true;
        if (serverIsFav != willBeFavorite) {
          final updated = Set<int>.from(favoriteIdsNotifier.value);
          if (serverIsFav) updated.add(officeId); else updated.remove(officeId);
          favoriteIdsNotifier.value = updated;
          await _storage.write(
            key: _keyFavoriteIds,
            value: jsonEncode(updated.toList()),
          );
        }
        return {
          'success': true,
          'isFavorite': serverIsFav,
        };
      } else if (response.statusCode == 401) {
        // Rollback optimistic update if unauthenticated
        final rollback = Set<int>.from(favoriteIdsNotifier.value);
        if (willBeFavorite) rollback.remove(officeId); else rollback.add(officeId);
        favoriteIdsNotifier.value = rollback;
        await _storage.write(
          key: _keyFavoriteIds,
          value: jsonEncode(rollback.toList()),
        );
        return {
          'success': false,
          'isAuthError': true,
          'message': 'Please sign in to save favorite offices.',
        };
      } else {
        // Rollback optimistic update
        final rollback = Set<int>.from(favoriteIdsNotifier.value);
        if (willBeFavorite) rollback.remove(officeId); else rollback.add(officeId);
        favoriteIdsNotifier.value = rollback;
        await _storage.write(
          key: _keyFavoriteIds,
          value: jsonEncode(rollback.toList()),
        );
        return {
          'success': false,
          'message': 'Failed to update favorite status',
        };
      }
    } catch (e) {
      debugPrint('Error toggling favorite: $e');
      final rollback = Set<int>.from(favoriteIdsNotifier.value);
      if (willBeFavorite) rollback.remove(officeId); else rollback.add(officeId);
      favoriteIdsNotifier.value = rollback;
      await _storage.write(
        key: _keyFavoriteIds,
        value: jsonEncode(rollback.toList()),
      );
      return {
        'success': false,
        'message': 'Network error: $e',
      };
    }
  }

  /// Get list of all favorited offices
  Future<List<dynamic>> getFavoriteOffices() async {
    try {
      final user = await getCurrentUser();
      String? email = user?['email'];

      String url = '$_baseUrl/offices/favorites';
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
      debugPrint('Error fetching favorite offices: $e');
      return [];
    }
  }

  /// Clear cached favorite IDs (e.g. on logout)
  Future<void> clearCachedFavorites() async {
    favoriteIdsNotifier.value = {};
    try {
      await _storage.delete(key: _keyFavoriteIds);
    } catch (_) {}
  }
}

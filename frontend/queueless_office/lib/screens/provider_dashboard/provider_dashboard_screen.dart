import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:queueless_office/screens/auth/office_auth_screen.dart';

class ProviderDashboardScreen extends StatefulWidget {
  const ProviderDashboardScreen({super.key});

  @override
  State<ProviderDashboardScreen> createState() => _ProviderDashboardScreenState();
}

class _ProviderDashboardScreenState extends State<ProviderDashboardScreen> {
  final _storage = const FlutterSecureStorage();
  bool _loading = true;
  Map<String, dynamic>? _providerData;
  String? _officeId;

  // Provider Duty Status state
  bool _isOnDuty = true;
  bool _togglingDuty = false;

  // Provider Queue Settings state
  Map<String, dynamic>? _queueSettings;
  bool _savingLimit = false;
  final TextEditingController _providerLimitController = TextEditingController();

  // Provider Live Queue state
  Map<String, dynamic>? _liveQueueData;
  Timer? _liveQueueTimer;
  bool _queueActionLoading = false;

  String get _backendUrl => kIsWeb
      ? 'http://localhost:8081/api/provider/me'
      : 'http://10.0.2.2:8081/api/provider/me';

  String get _providerDutyStatusUrl => kIsWeb
      ? 'http://localhost:8081/api/provider/duty-status'
      : 'http://10.0.2.2:8081/api/provider/duty-status';

  String get _queueSettingsUrl => kIsWeb
      ? 'http://localhost:8081/api/provider/settings/queue'
      : 'http://10.0.2.2:8081/api/provider/settings/queue';

  String get _providerQueueLiveUrl => kIsWeb
      ? 'http://localhost:8081/api/provider/queue/live'
      : 'http://10.0.2.2:8081/api/provider/queue/live';

  String get _providerQueueCallNextUrl => kIsWeb
      ? 'http://localhost:8081/api/provider/queue/call-next'
      : 'http://10.0.2.2:8081/api/provider/queue/call-next';

  String _providerQueueServeUrl(dynamic id) => kIsWeb
      ? 'http://localhost:8081/api/provider/queue/tokens/$id/serve'
      : 'http://10.0.2.2:8081/api/provider/queue/tokens/$id/serve';

  String get _providerQueueCompleteUrl => kIsWeb
      ? 'http://localhost:8081/api/provider/queue/complete'
      : 'http://10.0.2.2:8081/api/provider/queue/complete';

  String get _providerQueueSkipUrl => kIsWeb
      ? 'http://localhost:8081/api/provider/queue/skip'
      : 'http://10.0.2.2:8081/api/provider/queue/skip';

  @override
  void initState() {
    super.initState();
    _loadProviderProfile();
    _startQueuePolling();
  }

  @override
  void dispose() {
    _providerLimitController.dispose();
    _liveQueueTimer?.cancel();
    super.dispose();
  }

  void _startQueuePolling() {
    _liveQueueTimer?.cancel();
    _liveQueueTimer = Timer.periodic(const Duration(seconds: 4), (timer) {
      if (mounted) {
        _fetchLiveQueue(silent: true);
      }
    });
  }

  Future<void> _fetchLiveQueue({bool silent = false}) async {
    try {
      final token = await _storage.read(key: 'jwt_token');
      if (token == null) return;
      final response = await http.get(
        Uri.parse(_providerQueueLiveUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (mounted) {
          setState(() {
            _liveQueueData = data;
          });
        }
      }
    } catch (e) {
      if (!silent) debugPrint('Error fetching live queue: $e');
    }
  }

  Future<void> _callNextCustomer() async {
    setState(() => _queueActionLoading = true);
    try {
      final token = await _storage.read(key: 'jwt_token');
      final response = await http.post(
        Uri.parse(_providerQueueCallNextUrl),
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (mounted) {
          setState(() {
            _liveQueueData = data;
            _queueActionLoading = false;
          });
          final activeToken = data['activeToken'];
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(activeToken != null ? 'Called next token #$activeToken!' : 'No waiting tokens in line.'),
              backgroundColor: const Color(0xFF10B981),
            ),
          );
        }
      } else {
        throw Exception('Server error: ${response.statusCode}');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _queueActionLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to call next token: $e'), backgroundColor: const Color(0xFFEF4444)),
        );
      }
    }
  }

  Future<void> _serveToken(dynamic tokenId) async {
    setState(() => _queueActionLoading = true);
    try {
      final token = await _storage.read(key: 'jwt_token');
      final response = await http.post(
        Uri.parse(_providerQueueServeUrl(tokenId)),
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (mounted) {
          setState(() {
            _liveQueueData = data;
            _queueActionLoading = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Token is now IN SERVICE! Customer notified.'),
              backgroundColor: Color(0xFF10B981),
            ),
          );
        }
      } else {
        throw Exception('Server error: ${response.statusCode}');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _queueActionLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to serve token: $e'), backgroundColor: const Color(0xFFEF4444)),
        );
      }
    }
  }

  Future<void> _completeToken() async {
    setState(() => _queueActionLoading = true);
    try {
      final token = await _storage.read(key: 'jwt_token');
      final response = await http.post(
        Uri.parse(_providerQueueCompleteUrl),
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (mounted) {
          setState(() {
            _liveQueueData = data;
            _queueActionLoading = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Token completed successfully!'),
              backgroundColor: Color(0xFF10B981),
            ),
          );
        }
      } else {
        throw Exception('Server error: ${response.statusCode}');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _queueActionLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to complete token: $e'), backgroundColor: const Color(0xFFEF4444)),
        );
      }
    }
  }

  Future<void> _skipToken() async {
    setState(() => _queueActionLoading = true);
    try {
      final token = await _storage.read(key: 'jwt_token');
      final response = await http.post(
        Uri.parse(_providerQueueSkipUrl),
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (mounted) {
          setState(() {
            _liveQueueData = data;
            _queueActionLoading = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Token marked as skipped/hold.'),
              backgroundColor: Color(0xFFF59E0B),
            ),
          );
        }
      } else {
        throw Exception('Server error: ${response.statusCode}');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _queueActionLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to skip token: $e'), backgroundColor: const Color(0xFFEF4444)),
        );
      }
    }
  }

  Future<void> _loadQueueSettings() async {
    try {
      final token = await _storage.read(key: 'jwt_token');
      if (token == null) return;
      final response = await http.get(
        Uri.parse(_queueSettingsUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (mounted) {
          setState(() {
            _queueSettings = data;
            final limit = data['providerDailyMaxTokens'] ?? data['providerDailyMax'];
            if (_providerLimitController.text.isEmpty && limit != null) {
              _providerLimitController.text = limit.toString();
            }
          });
        }
      }
    } catch (e) {
      debugPrint('Error loading provider queue settings: $e');
    }
  }

  Future<void> _updateProviderLimit() async {
    final text = _providerLimitController.text.trim();
    final parsed = int.tryParse(text);
    if (parsed == null || parsed <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid positive integer limit.'),
          backgroundColor: Color(0xFFEF4444),
        ),
      );
      return;
    }

    setState(() => _savingLimit = true);
    try {
      final token = await _storage.read(key: 'jwt_token');
      final response = await http.put(
        Uri.parse(_queueSettingsUrl),
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'dailyMaxTokens': parsed}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final updatedLimit = data['providerDailyMaxTokens'] ?? data['providerDailyMax'] ?? parsed;
        if (mounted) {
          setState(() {
            _queueSettings = data;
            _providerLimitController.text = updatedLimit.toString();
            _savingLimit = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Daily token limit updated to $updatedLimit tokens!'),
              backgroundColor: const Color(0xFF10B981),
            ),
          );
        }
        await _loadProviderProfile();
      } else {
        String msg = 'Failed to update provider limit.';
        try {
          final err = jsonDecode(response.body);
          if (err['message'] != null) {
            msg = err['message'];
          } else if (err['error'] != null) {
            msg = err['error'];
          }
        } catch (_) {}
        if (mounted) {
          setState(() => _savingLimit = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(msg), backgroundColor: const Color(0xFFEF4444)),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _savingLimit = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Network error: $e'), backgroundColor: const Color(0xFFEF4444)),
        );
      }
    }
  }

  Future<void> _loadProviderProfile() async {
    setState(() => _loading = true);

    try {
      final token = await _storage.read(key: 'jwt_token');
      final cachedOfficeId = await _storage.read(key: 'office_id');
      final cachedProvider = await _storage.read(key: 'provider_data');

      if (cachedOfficeId != null) {
        _officeId = cachedOfficeId;
      }

      if (cachedProvider != null) {
        try {
          _providerData = jsonDecode(cachedProvider);
          if (_providerData?['onDuty'] != null) {
            _isOnDuty = _providerData!['onDuty'] == true;
          }
        } catch (_) {}
      }

      if (token != null) {
        final response = await http.get(
          Uri.parse(_backendUrl),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
        );

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          setState(() {
            _providerData = data;
            if (data['onDuty'] != null) {
              _isOnDuty = data['onDuty'] == true;
            }
            if (data['officeCode'] != null) {
              _officeId = data['officeCode'];
            }
          });
          await _storage.write(key: 'provider_data', value: jsonEncode(data));
          if (_officeId != null) {
            await _storage.write(key: 'office_id', value: _officeId!);
          }
          await _loadQueueSettings();
          await _fetchLiveQueue(silent: true);
        } else if (response.statusCode == 401 || response.statusCode == 403) {
          _handleLogout(forced: true, message: 'Session expired or account deactivated.');
          return;
        }
      }
    } catch (e) {
      debugPrint('Error loading provider profile: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _updateDutyStatus(bool newStatus) async {
    if (_togglingDuty) return;
    setState(() {
      _togglingDuty = true;
      _isOnDuty = newStatus;
    });

    try {
      final token = await _storage.read(key: 'jwt_token');
      final response = await http.put(
        Uri.parse(_providerDutyStatusUrl),
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'onDuty': newStatus}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final bool confirmedStatus = data['onDuty'] ?? newStatus;
        if (mounted) {
          setState(() {
            _isOnDuty = confirmedStatus;
            _providerData?['onDuty'] = confirmedStatus;
            _togglingDuty = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  Icon(
                    _isOnDuty ? Icons.check_circle_rounded : Icons.pause_circle_outline_rounded,
                    color: Colors.white,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Text(_isOnDuty ? 'You are now ON DUTY' : 'You are now OFF DUTY'),
                ],
              ),
              backgroundColor: _isOnDuty ? const Color(0xFF10B981) : const Color(0xFF64748B),
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      } else {
        throw Exception('Status code: ${response.statusCode}');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isOnDuty = !newStatus; // revert on failure
          _togglingDuty = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update duty status: $e'),
            backgroundColor: const Color(0xFFEF4444),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _handleLogout({bool forced = false, String? message}) async {
    if (!forced) {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Sign Out', style: TextStyle(fontWeight: FontWeight.bold)),
          content: const Text('Are you sure you want to sign out of the Provider Portal?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B))),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFEF4444),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('Sign Out'),
            ),
          ],
        ),
      );
      if (confirm != true) return;
    }

    await _storage.deleteAll();

    if (mounted) {
      if (message != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: const Color(0xFFEF4444),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const OfficeAuthScreen()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = _providerData?['name'] ?? 'Provider';
    final username = _providerData?['username'] ?? '';
    final specialization = _providerData?['specialization'] ?? 'Consultant';
    final isActive = _providerData?['active'] ?? true;
    final officeCode = _officeId ?? _providerData?['officeCode'] ?? '---';
    final startTime = _providerData?['workingStartTime'] ?? '09:00';
    final endTime = _providerData?['workingEndTime'] ?? '17:00';
    final breakStart = _providerData?['breakStartTime'];
    final breakEnd = _providerData?['breakEndTime'];
    final bufferTime = _providerData?['bufferTimeMinutes'] ?? 5;
    final workingDays = _providerData?['workingDays'] as List<dynamic>? ?? [];

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        titleSpacing: 12,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: const Color(0xFF0284C7).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.badge_rounded, color: Color(0xFF0284C7), size: 20),
            ),
            const SizedBox(width: 8),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Provider Portal',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  Text(
                    'Queueless Suite',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 10, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          // ON DUTY / OFF DUTY Switch
          Center(
            child: Container(
              margin: const EdgeInsets.only(right: 4),
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(
                color: _isOnDuty
                    ? const Color(0xFF10B981).withValues(alpha: 0.12)
                    : const Color(0xFF64748B).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: _isOnDuty ? const Color(0xFF10B981) : const Color(0xFF94A3B8),
                  width: 1.2,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _isOnDuty ? const Color(0xFF10B981) : const Color(0xFF94A3B8),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _isOnDuty ? 'ON DUTY' : 'OFF DUTY',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: _isOnDuty ? const Color(0xFF047857) : const Color(0xFF475569),
                      letterSpacing: 0.3,
                    ),
                  ),
                  const SizedBox(width: 2),
                  SizedBox(
                    height: 22,
                    width: 32,
                    child: FittedBox(
                      fit: BoxFit.contain,
                      child: Switch(
                        value: _isOnDuty,
                        activeThumbColor: const Color(0xFF10B981),
                        activeTrackColor: const Color(0xFF10B981).withValues(alpha: 0.35),
                        inactiveThumbColor: const Color(0xFF64748B),
                        inactiveTrackColor: const Color(0xFFCBD5E1),
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        onChanged: _togglingDuty ? null : (val) => _updateDutyStatus(val),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Color(0xFF64748B), size: 19),
            tooltip: 'Refresh Profile',
            padding: const EdgeInsets.all(4),
            constraints: const BoxConstraints(),
            visualDensity: VisualDensity.compact,
            onPressed: _loadProviderProfile,
          ),
          const SizedBox(width: 2),
          IconButton(
            icon: const Icon(Icons.logout_rounded, color: Color(0xFFEF4444), size: 19),
            tooltip: 'Sign Out',
            padding: const EdgeInsets.all(4),
            constraints: const BoxConstraints(),
            visualDensity: VisualDensity.compact,
            onPressed: () => _handleLogout(),
          ),
          const SizedBox(width: 8),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: const Color(0xFFE2E8F0), height: 1),
        ),
      ),
      body: _loading && _providerData == null
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF0284C7)),
            )
          : RefreshIndicator(
              onRefresh: () async {
                await _loadProviderProfile();
                await _loadQueueSettings();
                await _fetchLiveQueue();
              },
              color: const Color(0xFF0284C7),
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 680),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Welcome Banner / Profile Header Card
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF0284C7), Color(0xFF0369A1)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(24),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF0284C7).withValues(alpha: 0.25),
                                blurRadius: 20,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  CircleAvatar(
                                    radius: 32,
                                    backgroundColor: Colors.white.withValues(alpha: 0.2),
                                    child: Text(
                                      name.isNotEmpty ? name[0].toUpperCase() : 'P',
                                      style: const TextStyle(
                                        fontSize: 28,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          name,
                                          style: const TextStyle(
                                            fontSize: 22,
                                            fontWeight: FontWeight.w800,
                                            color: Colors.white,
                                            letterSpacing: -0.3,
                                          ),
                                        ),
                                        if (username.isNotEmpty) ...[
                                          const SizedBox(height: 2),
                                          Text(
                                            '@$username',
                                            style: const TextStyle(
                                              fontSize: 14,
                                              color: Colors.white70,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                        const SizedBox(height: 6),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: Colors.white.withValues(alpha: 0.15),
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          child: Text(
                                            specialization,
                                            style: const TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                              color: Colors.white,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  // Status Badge
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: isActive
                                          ? const Color(0xFF10B981).withValues(alpha: 0.2)
                                          : const Color(0xFFEF4444).withValues(alpha: 0.2),
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(
                                        color: isActive ? const Color(0xFF34D399) : const Color(0xFFF87171),
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          isActive ? Icons.check_circle_rounded : Icons.cancel_rounded,
                                          color: isActive ? const Color(0xFF34D399) : const Color(0xFFF87171),
                                          size: 14,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          isActive ? 'Active' : 'Inactive',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w700,
                                            color: isActive ? Colors.white : const Color(0xFFFCA5A5),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 20),
                              const Divider(color: Colors.white24, height: 1),
                              const SizedBox(height: 14),

                              // Office ID pill inside header
                              Row(
                                children: [
                                  const Icon(Icons.domain_rounded, color: Colors.white70, size: 16),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Office ID: $officeCode',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 13,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  InkWell(
                                    onTap: () {
                                      Clipboard.setData(ClipboardData(text: officeCode));
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                          content: Text('Office ID copied to clipboard!'),
                                          behavior: SnackBarBehavior.floating,
                                        ),
                                      );
                                    },
                                    borderRadius: BorderRadius.circular(6),
                                    child: Container(
                                      padding: const EdgeInsets.all(4),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: const Icon(Icons.copy_rounded, color: Colors.white, size: 14),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Section: Live Queue Counter & Management
                        _buildLiveQueueSection(),
                        const SizedBox(height: 20),

                        // Section: Daily Token & Queue Limit (TASK 2)
                        _buildQueueLimitCard(),
                        const SizedBox(height: 20),

                        // Section 1: Assigned Schedule & Availability
                        _buildCard(
                          title: 'Assigned Schedule & Hours',
                          icon: Icons.access_time_rounded,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildInfoRow(
                                Icons.wb_sunny_outlined,
                                'Working Hours',
                                '$startTime - $endTime',
                              ),
                              const SizedBox(height: 12),
                              if (breakStart != null && breakEnd != null) ...[
                                _buildInfoRow(
                                  Icons.coffee_outlined,
                                  'Break Time',
                                  '$breakStart - $breakEnd',
                                ),
                                const SizedBox(height: 12),
                              ],
                              _buildInfoRow(
                                Icons.timelapse_outlined,
                                'Buffer Time per Token',
                                '$bufferTime mins',
                              ),
                              const SizedBox(height: 16),
                              const Text(
                                'Working Days',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF64748B),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  'MONDAY',
                                  'TUESDAY',
                                  'WEDNESDAY',
                                  'THURSDAY',
                                  'FRIDAY',
                                  'SATURDAY',
                                  'SUNDAY',
                                ].map((day) {
                                  final isWorking = workingDays.contains(day);
                                  return Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: isWorking
                                          ? const Color(0xFF0284C7).withValues(alpha: 0.1)
                                          : const Color(0xFFF1F5F9),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: isWorking
                                            ? const Color(0xFF0284C7).withValues(alpha: 0.3)
                                            : const Color(0xFFE2E8F0),
                                      ),
                                    ),
                                    child: Text(
                                      day.substring(0, 3),
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: isWorking ? const Color(0xFF0284C7) : const Color(0xFF94A3B8),
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Section 2: Contact & Portal Info
                        _buildCard(
                          title: 'Account Information',
                          icon: Icons.person_pin_outlined,
                          child: Column(
                            children: [
                              _buildInfoRow(
                                Icons.badge_outlined,
                                'Username',
                                username.isNotEmpty ? username : 'N/A',
                              ),
                              const SizedBox(height: 12),
                              _buildInfoRow(
                                Icons.email_outlined,
                                'Email',
                                _providerData?['email'] ?? 'Not provided',
                              ),
                              const SizedBox(height: 12),
                              _buildInfoRow(
                                Icons.phone_outlined,
                                'Phone Number',
                                _providerData?['phoneNumber'] ?? 'Not provided',
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 28),

                        // Logout Button
                        SizedBox(
                          height: 50,
                          child: OutlinedButton.icon(
                            onPressed: () => _handleLogout(),
                            icon: const Icon(Icons.logout_rounded, color: Color(0xFFEF4444)),
                            label: const Text(
                              'Sign Out from Provider Portal',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFFEF4444),
                              ),
                            ),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: Color(0xFFFCA5A5), width: 1.5),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              backgroundColor: Colors.white,
                            ),
                          ),
                        ),
                        const SizedBox(height: 32),
                      ],
                    ),
                  ),
                ),
              ),
            ),
    );
  }

  Widget _buildCard({
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: const Color(0xFF0284C7), size: 20),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF0F172A),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 18, color: const Color(0xFF94A3B8)),
        const SizedBox(width: 10),
        Text(
          label,
          style: const TextStyle(fontSize: 13, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
        ),
        const Spacer(),
        Text(
          value,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
        ),
      ],
    );
  }

  Widget _buildQueueLimitCard() {
    final officeMax = _queueSettings?['officeDailyMaxTokens'] ??
        _queueSettings?['officeDailyMax'] ??
        60;
    final providerMax = _queueSettings?['providerDailyMaxTokens'] ??
        _queueSettings?['providerDailyMax'] ??
        _providerData?['dailyMaxTokens'];
    final providerToday = _queueSettings?['providerTodayTokensCount'] ??
        _queueSettings?['providerTodayTokens'] ??
        0;
    final officeToday = _queueSettings?['officeTodayTokensCount'] ??
        _queueSettings?['officeTodayTokens'] ??
        0;
    final remaining = _queueSettings?['effectiveRemainingCapacity'] ??
        _queueSettings?['effectiveRemaining'] ??
        (providerMax != null ? (providerMax - providerToday) : (officeMax - officeToday));
    final providerFull = _queueSettings?['providerFull'] ?? false;
    final officeFull = _queueSettings?['officeFull'] ?? false;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: (providerFull || officeFull) ? const Color(0xFFFCA5A5) : const Color(0xFFE2E8F0),
          width: (providerFull || officeFull) ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0284C7).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.confirmation_number_rounded, color: Color(0xFF0284C7), size: 20),
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    'Queue & Token Limit',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: (providerFull || officeFull)
                      ? const Color(0xFFEF4444).withValues(alpha: 0.1)
                      : const Color(0xFF10B981).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  providerFull
                      ? 'Limit Reached'
                      : (officeFull ? 'Office Full' : 'Available'),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: (providerFull || officeFull) ? const Color(0xFFEF4444) : const Color(0xFF10B981),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          const SizedBox(height: 14),

          // Overview stats
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Your Daily Limit', style: TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w600)),
                          const SizedBox(height: 2),
                          Text(
                            providerMax != null ? '$providerMax tokens' : 'Not set (Office max: $officeMax)',
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                          ),
                        ],
                      ),
                    ),
                    Container(width: 1, height: 32, color: const Color(0xFFCBD5E1)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Your Tokens Today', style: TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w600)),
                          const SizedBox(height: 2),
                          Text(
                            '$providerToday tokens',
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF0284C7)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                const Divider(height: 1, color: Color(0xFFE2E8F0)),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Office Daily Max', style: TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w600)),
                          const SizedBox(height: 2),
                          Text(
                            '$officeMax tokens',
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF475569)),
                          ),
                        ],
                      ),
                    ),
                    Container(width: 1, height: 32, color: const Color(0xFFCBD5E1)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Your Remaining Today', style: TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w600)),
                          const SizedBox(height: 2),
                          Text(
                            '$remaining tokens',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: (providerFull || officeFull) ? const Color(0xFFEF4444) : const Color(0xFF10B981),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Edit Limit Field
          const Text(
            'Configure Your Daily Max Token Limit',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _providerLimitController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: InputDecoration(
                    hintText: 'e.g. 20',
                    prefixIcon: const Icon(Icons.pin_outlined, size: 20),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                onPressed: _savingLimit ? null : _updateProviderLimit,
                icon: _savingLimit
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.check_rounded, size: 18),
                label: Text(_savingLimit ? 'Saving...' : 'Save Limit'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0284C7),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Cannot exceed office maximum of $officeMax tokens. Sum of all providers cannot exceed office limit.',
            style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8), height: 1.3),
          ),
        ],
      ),
    );
  }

  Widget _buildLiveQueueSection() {
    final activeToken = _liveQueueData?['activeToken']?.toString();
    final activeDetails = _liveQueueData?['activeTokenDetails'] as Map<String, dynamic>?;
    final int waitingCount = (_liveQueueData?['waitingCount'] is int)
        ? _liveQueueData!['waitingCount']
        : int.tryParse('${_liveQueueData?['waitingCount']}') ?? 0;
    final int completedCount = (_liveQueueData?['completedCount'] is int)
        ? _liveQueueData!['completedCount']
        : int.tryParse('${_liveQueueData?['completedCount']}') ?? 0;
    final waitingTokens = (_liveQueueData?['waitingTokens'] as List<dynamic>?) ?? [];

    final activeStatus = (activeDetails?['status'] ?? 'CALLED').toString().toUpperCase();
    final isServing = activeStatus == 'IN_SERVICE';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0284C7).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.people_alt_rounded, color: Color(0xFF0284C7), size: 20),
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    'Live Queue Counter',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.circle, color: Color(0xFF10B981), size: 8),
                        SizedBox(width: 4),
                        Text(
                          'LIVE',
                          style: TextStyle(color: Color(0xFF059669), fontSize: 10, fontWeight: FontWeight.w800),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),
                  IconButton(
                    icon: const Icon(Icons.sync_rounded, color: Color(0xFF64748B), size: 20),
                    tooltip: 'Refresh Queue',
                    visualDensity: VisualDensity.compact,
                    onPressed: () => _fetchLiveQueue(),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),

          // 3 Metric Tiles
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    children: [
                      const Text('Serving Now', style: TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w600)),
                      const SizedBox(height: 4),
                      Text(
                        activeToken != null ? '#$activeToken' : '--',
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Color(0xFF0284C7)),
                      ),
                    ],
                  ),
                ),
                Container(width: 1, height: 28, color: const Color(0xFFCBD5E1)),
                Expanded(
                  child: Column(
                    children: [
                      const Text('Waiting in Line', style: TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w600)),
                      const SizedBox(height: 4),
                      Text(
                        '$waitingCount',
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Color(0xFFF59E0B)),
                      ),
                    ],
                  ),
                ),
                Container(width: 1, height: 28, color: const Color(0xFFCBD5E1)),
                Expanded(
                  child: Column(
                    children: [
                      const Text('Done Today', style: TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w600)),
                      const SizedBox(height: 4),
                      Text(
                        '$completedCount',
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Color(0xFF10B981)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Currently Active Token Panel
          if (activeToken != null && activeDetails != null) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isServing ? const Color(0xFFF0FDF4) : const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isServing ? const Color(0xFF86EFAC) : const Color(0xFF93C5FD),
                  width: 1.5,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        isServing ? 'NOW IN SERVICE' : 'CALLED TO COUNTER',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5,
                          color: isServing ? const Color(0xFF15803D) : const Color(0xFF1D4ED8),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: isServing ? const Color(0xFF16A34A) : const Color(0xFF2563EB),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          activeStatus,
                          style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Text(
                        '#$activeToken',
                        style: TextStyle(
                          fontSize: 30,
                          fontWeight: FontWeight.w900,
                          color: isServing ? const Color(0xFF15803D) : const Color(0xFF1E40AF),
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.person_outline_rounded, size: 16, color: Color(0xFF475569)),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    activeDetails['customerName'] ?? 'Customer',
                                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                            if (activeDetails['customerPhone'] != null && activeDetails['customerPhone'].toString().isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  const Icon(Icons.phone_outlined, size: 14, color: Color(0xFF64748B)),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      activeDetails['customerPhone'].toString(),
                                      style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Divider(height: 1, color: Color(0xFFCBD5E1)),
                  const SizedBox(height: 14),

                  // Actions wrap
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      if (!isServing) ...[
                        ElevatedButton.icon(
                          onPressed: _queueActionLoading ? null : () => _serveToken(activeDetails['id']),
                          icon: const Icon(Icons.play_arrow_rounded, size: 18),
                          label: const Text('Start Serving'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF10B981),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ],
                      ElevatedButton.icon(
                        onPressed: _queueActionLoading ? null : _completeToken,
                        icon: const Icon(Icons.check_circle_outline_rounded, size: 18),
                        label: const Text('Complete'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0284C7),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                      OutlinedButton.icon(
                        onPressed: _queueActionLoading ? null : _skipToken,
                        icon: const Icon(Icons.pause_circle_outline_rounded, size: 18, color: Color(0xFFF59E0B)),
                        label: const Text('Skip / Hold', style: TextStyle(color: Color(0xFFD97706))),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Color(0xFFFCD34D)),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                      if (waitingCount > 0) ...[
                        OutlinedButton.icon(
                          onPressed: _queueActionLoading ? null : _callNextCustomer,
                          icon: const Icon(Icons.skip_next_rounded, size: 18, color: Color(0xFF4F46E5)),
                          label: const Text('Call Next', style: TextStyle(color: Color(0xFF4F46E5))),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Color(0xFFC7D2FE)),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ] else ...[
            // Idle State: No Active Token
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                children: [
                  const Icon(Icons.chair_outlined, size: 36, color: Color(0xFF94A3B8)),
                  const SizedBox(height: 8),
                  const Text(
                    'No Customer Currently at Counter',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF334155)),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    waitingCount > 0
                        ? '$waitingCount customer${waitingCount == 1 ? '' : 's'} waiting in line.'
                        : 'No customers currently in your queue.',
                    style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: (_queueActionLoading || waitingCount == 0) ? null : _callNextCustomer,
                      icon: _queueActionLoading
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.campaign_rounded, size: 20),
                      label: Text(
                        waitingCount > 0 ? 'Call Next Customer' : 'No Waiting Customers',
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0284C7),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Upcoming Waiting Tokens List
          if (waitingTokens.isNotEmpty) ...[
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Upcoming Customers ($waitingCount)',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF334155)),
                ),
                Text(
                  'Auto-updates live',
                  style: TextStyle(fontSize: 11, color: Colors.grey[500], fontWeight: FontWeight.w500),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: waitingTokens.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (ctx, index) {
                final item = waitingTokens[index] as Map<String, dynamic>;
                final tokenNum = item['tokenNumber'] ?? '---';
                final custName = item['customerName'] ?? 'Customer';
                final position = item['position'] ?? (index + 1);
                final waitEst = item['estimatedWaitMinutes'] ?? 0;

                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 28,
                        height: 28,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: const Color(0xFF0284C7).withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          '#$position',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF0284C7),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              tokenNum,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                            Text(
                              custName,
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFF64748B),
                                fontWeight: FontWeight.w500,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      if (waitEst > 0) ...[
                        Text(
                          '~$waitEst m',
                          style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8), fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(width: 8),
                      ],
                      ElevatedButton(
                        onPressed: _queueActionLoading ? null : () => _serveToken(item['id']),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: const Color(0xFF0284C7),
                          elevation: 0,
                          side: const BorderSide(color: Color(0xFFBAE6FD)),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          visualDensity: VisualDensity.compact,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        child: const Text('Call', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ],
      ),
    );
  }
}

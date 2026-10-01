import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:queueless_office/screens/auth/office_auth_screen.dart';
import 'package:queueless_office/screens/dashboad/office_onboarding_screen.dart';
import 'package:queueless_office/screens/providers/providers_screen.dart';

class OfficeDashboardScreen extends StatefulWidget {
  const OfficeDashboardScreen({super.key});

  @override
  State<OfficeDashboardScreen> createState() => _OfficeDashboardScreenState();
}

class _OfficeDashboardScreenState extends State<OfficeDashboardScreen> {
  final _storage = const FlutterSecureStorage();
  bool _loading = true;
  String? _error;

  Map<String, dynamic>? _userData;
  Map<String, dynamic>? _profileData;
  List<dynamic> _documents = [];
  Map<String, dynamic>? _liveQueueData;
  bool _queueActionLoading = false;

  // Office Duty/Open Status state
  bool _isOpen = true;
  bool _togglingOpen = false;
  Timer? _liveQueuePollingTimer;

  // Queue Settings state
  Map<String, dynamic>? _officeQueueSettings;
  bool _savingSettings = false;
  final TextEditingController _dailyLimitController = TextEditingController();

  // For Approved state tab switching: 0 -> Queue Dashboard, 1 -> Office Profile Details
  int _approvedSelectedTab = 0;

  String get _baseUrl => kIsWeb
      ? 'http://localhost:8080/api/office/profile'
      : 'http://10.0.2.2:8080/api/office/profile';

  String get _apiBaseUrl => kIsWeb
      ? 'http://localhost:8080/api'
      : 'http://10.0.2.2:8080/api';

  @override
  void initState() {
    super.initState();
    _fetchProfile();
  }

  @override
  void dispose() {
    _dailyLimitController.dispose();
    _liveQueuePollingTimer?.cancel();
    super.dispose();
  }

  void _startQueuePolling() {
    _liveQueuePollingTimer?.cancel();
    _liveQueuePollingTimer = Timer.periodic(const Duration(seconds: 4), (timer) {
      if (mounted && _profileData != null) {
        _fetchLiveQueue(silent: true);
      }
    });
  }

  Future<void> _fetchQueueSettings() async {
    try {
      final token = await _storage.read(key: 'jwt_token');
      if (token == null) return;
      final response = await http.get(
        Uri.parse('$_apiBaseUrl/office/settings/queue'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (mounted) {
          setState(() {
            _officeQueueSettings = data;
            if (_dailyLimitController.text.isEmpty && data['dailyMaxTokens'] != null) {
              _dailyLimitController.text = data['dailyMaxTokens'].toString();
            }
          });
        }
      }
    } catch (e) {
      debugPrint('Error fetching office queue settings: $e');
    }
  }

  Future<void> _saveQueueSettings() async {
    final text = _dailyLimitController.text.trim();
    final parsed = int.tryParse(text);
    if (parsed == null || parsed <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid positive number for daily maximum tokens.'),
          backgroundColor: Color(0xFFEF4444),
        ),
      );
      return;
    }

    setState(() => _savingSettings = true);
    try {
      final token = await _storage.read(key: 'jwt_token');
      final response = await http.put(
        Uri.parse('$_apiBaseUrl/office/settings/queue'),
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'dailyMaxTokens': parsed}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (mounted) {
          setState(() {
            _officeQueueSettings = data;
            _dailyLimitController.text = (data['dailyMaxTokens'] ?? parsed).toString();
            _savingSettings = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Daily token limit updated to ${data['dailyMaxTokens']} tokens!'),
              backgroundColor: const Color(0xFF10B981),
            ),
          );
          _fetchLiveQueue();
        }
      } else {
        String msg = 'Failed to update token limit.';
        try {
          final err = jsonDecode(response.body);
          if (err['message'] != null) {
            msg = err['message'];
          } else if (err['error'] != null) {
            msg = err['error'];
          }
        } catch (_) {}
        if (mounted) {
          setState(() => _savingSettings = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(msg), backgroundColor: const Color(0xFFEF4444)),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _savingSettings = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Network error: $e'), backgroundColor: const Color(0xFFEF4444)),
        );
      }
    }
  }

  Future<void> _fetchProfile() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final token = await _storage.read(key: 'jwt_token');
      if (token == null) {
        _navigateToAuth();
        return;
      }

      final response = await http.get(
        Uri.parse(_baseUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (mounted) {
          setState(() {
            _userData = data['user'];
            _profileData = data['profile'];
            if (_profileData != null) {
              if (_profileData!['documents'] != null) {
                _documents = _profileData!['documents'];
              }
              if (_profileData!['isOpen'] != null) {
                _isOpen = _profileData!['isOpen'] == true;
              }
            }
            _loading = false;
          });
          _fetchLiveQueue();
          _fetchQueueSettings();
          _startQueuePolling();
        }
      } else if (response.statusCode == 401 || response.statusCode == 403) {
        await _logout();
      } else {
        setState(() {
          _error = 'Failed to load details: ${response.statusCode}';
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Network error: $e';
          _loading = false;
        });
      }
    }
  }

  Future<void> _fetchLiveQueue({bool silent = false}) async {
    final officeId = _profileData?['id'];
    if (officeId == null) return;
    try {
      final token = await _storage.read(key: 'jwt_token');
      final response = await http.get(
        Uri.parse('$_apiBaseUrl/queue/office/$officeId/live'),
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
            if (data['isOpen'] != null) {
              _isOpen = data['isOpen'] == true;
            }
          });
        }
      }
    } catch (e) {
      if (!silent) debugPrint('Error fetching live queue: $e');
    }
  }

  Future<void> _updateOfficeOpenStatus(bool newStatus) async {
    setState(() => _togglingOpen = true);
    try {
      final token = await _storage.read(key: 'jwt_token');
      final response = await http.put(
        Uri.parse('$_apiBaseUrl/office/open-status'),
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'isOpen': newStatus}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (mounted) {
          setState(() {
            _isOpen = data['isOpen'] == true;
            _togglingOpen = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(_isOpen
                  ? 'Office is now OPEN for queue bookings.'
                  : 'Office is now CLOSED. Customers cannot book new tokens.'),
              backgroundColor: _isOpen ? const Color(0xFF10B981) : const Color(0xFFEF4444),
              behavior: SnackBarBehavior.floating,
            ),
          );
          _fetchLiveQueue(silent: true);
        }
      } else {
        throw Exception('Status ${response.statusCode}');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _togglingOpen = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update status: $e'), backgroundColor: const Color(0xFFEF4444)),
        );
      }
    }
  }

  Future<void> _forwardTokenToProvider(dynamic tokenId, dynamic providerId, String providerName) async {
    final officeId = _profileData?['id'];
    if (officeId == null) return;
    setState(() => _queueActionLoading = true);
    try {
      final token = await _storage.read(key: 'jwt_token');
      final response = await http.post(
        Uri.parse('$_apiBaseUrl/queue/office/$officeId/tokens/$tokenId/forward'),
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'providerId': providerId}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (mounted) {
          setState(() {
            _liveQueueData = data;
            _queueActionLoading = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Token successfully forwarded to $providerName!'),
              backgroundColor: const Color(0xFF10B981),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } else {
        String err = 'Failed to forward token';
        try {
          final errData = jsonDecode(response.body);
          if (errData['message'] != null) err = errData['message'];
        } catch (_) {}
        throw Exception(err);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _queueActionLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Forward failed: $e'), backgroundColor: const Color(0xFFEF4444)),
        );
      }
    }
  }

  Future<void> _serveTokenAtDesk(dynamic tokenId) async {
    final officeId = _profileData?['id'];
    if (officeId == null) return;
    setState(() => _queueActionLoading = true);
    try {
      final token = await _storage.read(key: 'jwt_token');
      final response = await http.post(
        Uri.parse('$_apiBaseUrl/queue/office/$officeId/tokens/$tokenId/serve'),
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
              content: Text('Token called to Active Desk Counter!'),
              backgroundColor: Color(0xFF10B981),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } else {
        throw Exception('Status ${response.statusCode}');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _queueActionLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: const Color(0xFFEF4444)),
        );
      }
    }
  }

  void _showForwardDialog(Map<String, dynamic> tokenItem) {
    final availableProviders = (_liveQueueData?['availableProviders'] as List<dynamic>?) ?? [];
    final tokenId = tokenItem['id'];
    final tokenNumber = tokenItem['tokenNumber'] ?? '---';
    final customerName = tokenItem['customerName'] ?? 'Customer';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 30),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF4F46E5).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.forward_to_inbox_rounded, color: Color(0xFF4F46E5), size: 22),
                      ),
                      const SizedBox(width: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Forward Token #$tokenNumber', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF0F172A))),
                          Text('Customer: $customerName', style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                        ],
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 20),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Text('Select Available Staff / Doctor', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF334155))),
              const SizedBox(height: 10),
              if (availableProviders.isEmpty)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: const Center(
                    child: Text('No active providers found in this office.\nPlease add providers in "Staff & Providers" tab.', textAlign: TextAlign.center, style: TextStyle(color: Color(0xFF64748B), fontSize: 13)),
                  ),
                )
              else
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: availableProviders.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, idx) {
                      final p = availableProviders[idx] as Map<String, dynamic>;
                      final pId = p['id'];
                      final pName = p['name'] ?? 'Provider';
                      final pDesig = p['designation'] ?? '';
                      final onDuty = p['onDuty'] == true;
                      final isFull = p['isFull'] == true;
                      final remaining = p['remainingCapacity'] ?? 0;

                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 18,
                              backgroundColor: onDuty ? const Color(0xFF10B981).withValues(alpha: 0.15) : const Color(0xFF94A3B8).withValues(alpha: 0.15),
                              child: Icon(Icons.person_rounded, size: 20, color: onDuty ? const Color(0xFF047857) : const Color(0xFF64748B)),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          pName,
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF0F172A)),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: onDuty ? const Color(0xFF10B981).withValues(alpha: 0.1) : const Color(0xFF64748B).withValues(alpha: 0.1),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          onDuty ? 'ON DUTY' : 'OFF DUTY',
                                          style: TextStyle(
                                            fontSize: 9,
                                            fontWeight: FontWeight.bold,
                                            color: onDuty ? const Color(0xFF047857) : const Color(0xFF475569),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    pDesig.isNotEmpty ? pDesig : (onDuty ? 'Available ($remaining left)' : 'Off duty'),
                                    style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 10),
                            ElevatedButton(
                              onPressed: _queueActionLoading
                                  ? null
                                  : () {
                                      Navigator.pop(ctx);
                                      _forwardTokenToProvider(tokenId, pId, pName);
                                    },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: onDuty ? const Color(0xFF4F46E5) : const Color(0xFF64748B),
                                foregroundColor: Colors.white,
                                elevation: 0,
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              child: const Text('Assign', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _handleCallNext() async {
    final officeId = _profileData?['id'];
    if (officeId == null) return;
    setState(() => _queueActionLoading = true);
    try {
      final token = await _storage.read(key: 'jwt_token');
      final response = await http.post(
        Uri.parse('$_apiBaseUrl/queue/office/$officeId/call-next'),
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
            SnackBar(
              content: Text(data['activeToken'] != null
                  ? 'Calling Token #${data['activeToken']}'
                  : 'No waiting customers in queue.'),
              backgroundColor: const Color(0xFF10B981),
            ),
          );
        }
      } else {
        if (mounted) setState(() => _queueActionLoading = false);
      }
    } catch (e) {
      if (mounted) setState(() => _queueActionLoading = false);
    }
  }

  Future<void> _handleCompleteService() async {
    final officeId = _profileData?['id'];
    if (officeId == null) return;
    setState(() => _queueActionLoading = true);
    try {
      final token = await _storage.read(key: 'jwt_token');
      final response = await http.post(
        Uri.parse('$_apiBaseUrl/queue/office/$officeId/complete'),
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
              content: Text('Customer marked as Completed!'),
              backgroundColor: Color(0xFF3B82F6),
            ),
          );
        }
      } else {
        if (mounted) setState(() => _queueActionLoading = false);
      }
    } catch (e) {
      if (mounted) setState(() => _queueActionLoading = false);
    }
  }

  Future<void> _handleSkipToken() async {
    final officeId = _profileData?['id'];
    if (officeId == null) return;
    setState(() => _queueActionLoading = true);
    try {
      final token = await _storage.read(key: 'jwt_token');
      final response = await http.post(
        Uri.parse('$_apiBaseUrl/queue/office/$officeId/skip'),
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
            const SnackBar(content: Text('Token marked as Skipped.')),
          );
        }
      } else {
        if (mounted) setState(() => _queueActionLoading = false);
      }
    } catch (e) {
      if (mounted) setState(() => _queueActionLoading = false);
    }
  }

  void _showOfficeQrDialog() {
    final officeName = _userData?['name'] ?? 'Office';
    final officeId = _profileData?['id'] ?? '---';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.qr_code_2_rounded, color: Color(0xFF4F46E5)),
            SizedBox(width: 10),
            Text('Reception QR Stand', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                children: [
                  const Icon(Icons.qr_code_scanner_rounded, size: 100, color: Color(0xFF4F46E5)),
                  const SizedBox(height: 12),
                  Text(
                    officeName,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Office ID: #$officeId',
                    style: const TextStyle(color: Color(0xFF64748B), fontSize: 13),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            const Text(
              'Print and place this QR Code at your entrance. Walk-in customers scanning this with QueueLess will instantly join your queue.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: Color(0xFF64748B), height: 1.4),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _logout() async {
    await _storage.delete(key: 'jwt_token');
    if (mounted) {
      _navigateToAuth();
    }
  }

  void _navigateToAuth() {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const OfficeAuthScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final status = _profileData?['verificationStatus'] ?? 'PENDING';
    final isApproved = status == 'APPROVED';

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(
          isApproved
              ? (_approvedSelectedTab == 0
                  ? 'Queue Operations'
                  : (_approvedSelectedTab == 1 ? 'Staff & Providers' : 'Office Details'))
              : 'Office Verification Status',
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
        ),
        backgroundColor: const Color(0xFF4F46E5),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          if (isApproved)
            Center(
              child: Container(
                margin: const EdgeInsets.only(right: 6),
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: _isOpen
                      ? const Color(0xFF10B981).withValues(alpha: 0.22)
                      : const Color(0xFFEF4444).withValues(alpha: 0.22),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: _isOpen ? const Color(0xFF34D399) : const Color(0xFFFCA5A5),
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
                        color: _isOpen ? const Color(0xFF34D399) : const Color(0xFFEF4444),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _isOpen ? 'OPEN' : 'CLOSED',
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: 0.4,
                      ),
                    ),
                    const SizedBox(width: 3),
                    SizedBox(
                      height: 22,
                      width: 32,
                      child: FittedBox(
                        fit: BoxFit.contain,
                        child: Switch(
                          value: _isOpen,
                          activeThumbColor: const Color(0xFF10B981),
                          activeTrackColor: const Color(0xFF10B981).withValues(alpha: 0.45),
                          inactiveThumbColor: const Color(0xFFEF4444),
                          inactiveTrackColor: const Color(0xFFFCA5A5),
                          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          onChanged: _togglingOpen ? null : (val) => _updateOfficeOpenStatus(val),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh',
            onPressed: _fetchProfile,
          ),
          IconButton(
            icon: const Icon(Icons.logout_rounded),
            tooltip: 'Logout',
            onPressed: _logout,
          ),
        ],
      ),
      body: _buildBody(),
      bottomNavigationBar: (isApproved && _profileData != null)
          ? BottomNavigationBar(
              currentIndex: _approvedSelectedTab,
              selectedItemColor: const Color(0xFF4F46E5),
              unselectedItemColor: const Color(0xFF94A3B8),
              onTap: (index) => setState(() => _approvedSelectedTab = index),
              items: const [
                BottomNavigationBarItem(
                  icon: Icon(Icons.dashboard_rounded),
                  label: 'Queue Ops',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.people_alt_rounded),
                  label: 'Providers',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.business_rounded),
                  label: 'Office Details',
                ),
              ],
            )
          : null,
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Color(0xFF4F46E5)),
            SizedBox(height: 16),
            Text('Loading office details...', style: TextStyle(color: Color(0xFF64748B))),
          ],
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline_rounded, color: Color(0xFFEF4444), size: 48),
              const SizedBox(height: 12),
              Text(_error!, textAlign: TextAlign.center, style: const TextStyle(fontSize: 15, color: Color(0xFF334155))),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _fetchProfile,
                icon: const Icon(Icons.refresh),
                label: const Text('Try Again'),
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF4F46E5), foregroundColor: Colors.white),
              ),
            ],
          ),
        ),
      );
    }

    // Profile not yet created
    if (_profileData == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: const Color(0xFF4F46E5).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Icon(Icons.business_outlined, color: Color(0xFF4F46E5), size: 40),
              ),
              const SizedBox(height: 20),
              Text(
                'Welcome, ${_userData?['name'] ?? 'Office'}!',
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
              ),
              const SizedBox(height: 8),
              const Text(
                'You haven’t completed your office onboarding yet.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: Color(0xFF64748B)),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const OfficeOnboardingScreen()),
                  ).then((_) => _fetchProfile());
                },
                icon: const Icon(Icons.arrow_forward_rounded),
                label: const Text('Complete Office Setup'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4F46E5),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final status = _profileData?['verificationStatus'] ?? 'PENDING';

    // 1. APPROVED STATE: Show Queue Dashboard Screen, Providers Screen, or Office Details Tab
    if (status == 'APPROVED') {
      if (_approvedSelectedTab == 0) {
        return _buildApprovedDashboardView();
      } else if (_approvedSelectedTab == 1) {
        return ProvidersScreen(officeProfile: _profileData);
      } else {
        return _buildDetailsOnlyView(status);
      }
    }

    // 2. PENDING / REJECTED STATE: Just show Details view with banner
    return _buildDetailsOnlyView(status);
  }

  // ==========================================
  // VIEW 1: APPROVED OPERATIONAL DASHBOARD
  // ==========================================
  Widget _buildApprovedDashboardView() {
    final officeName = _userData?['name'] ?? 'Office';
    final category = _profileData?['category'] ?? 'OFFICE';
    final officeId = (_profileData?['officeId'] ?? _userData?['officeId'] ?? '').toString();
    final activeToken = _liveQueueData?['activeToken'];
    final waitingCount = _liveQueueData?['waitingCount'] ?? 0;
    final completedCount = _liveQueueData?['completedCount'] ?? 0;
    final avgWait = _liveQueueData?['avgWaitTimeMinutes'] ?? 12;
    final activeDetails = _liveQueueData?['activeTokenDetails'];
    final custName = activeDetails != null ? (activeDetails['customerName'] ?? 'Customer') : 'No Active Customer';
    final custPhone = activeDetails != null ? (activeDetails['customerPhone'] ?? '') : '';

    return RefreshIndicator(
      onRefresh: () async {
        await _fetchProfile();
        await _fetchLiveQueue();
        await _fetchQueueSettings();
      },
      color: const Color(0xFF4F46E5),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (!_isOpen) ...[
              _buildClosedWarningBanner(),
              const SizedBox(height: 16),
            ],
            // Welcome Header Card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF4F46E5), Color(0xFF6366F1)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF4F46E5).withValues(alpha: 0.3),
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
                          Icon(_getCategoryIcon(category), color: Colors.white, size: 24),
                          const SizedBox(width: 8),
                          Text(
                            category,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.verified_rounded, color: Colors.white, size: 14),
                            SizedBox(width: 4),
                            Text(
                              'Verified',
                              style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    officeName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Operating Hours: ${_profileData?['openingTime'] ?? '09:00 AM'} - ${_profileData?['closingTime'] ?? '08:00 PM'}',
                    style: const TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                  if (officeId.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.vpn_key_outlined, color: Colors.white, size: 14),
                          const SizedBox(width: 6),
                          Text(
                            'Office ID: $officeId',
                            style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                          ),
                          const SizedBox(width: 8),
                          GestureDetector(
                            onTap: () {
                              Clipboard.setData(ClipboardData(text: officeId));
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Office ID copied to clipboard! Share with your staff.')),
                              );
                            },
                            child: const Icon(Icons.copy_rounded, color: Colors.white, size: 14),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 14),
                  ElevatedButton.icon(
                    onPressed: _showOfficeQrDialog,
                    icon: const Icon(Icons.qr_code_2_rounded, size: 18),
                    label: const Text('View Desk QR Stand'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: const Color(0xFF4F46E5),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      elevation: 0,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Live Queue Metrics
            const Text(
              'Live Queue Overview',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _buildMetricCard('Serving Token', activeToken != null ? '#$activeToken' : 'None', Icons.play_circle_fill_rounded, const Color(0xFF10B981))),
                const SizedBox(width: 12),
                Expanded(child: _buildMetricCard('Waiting in Queue', '$waitingCount', Icons.people_alt_rounded, const Color(0xFFF59E0B))),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _buildMetricCard('Total Served', '$completedCount', Icons.check_circle_rounded, const Color(0xFF3B82F6))),
                const SizedBox(width: 12),
                Expanded(child: _buildMetricCard('Avg. Wait Time', '$avgWait min', Icons.timer_rounded, const Color(0xFF8B5CF6))),
              ],
            ),
            const SizedBox(height: 24),

            // Queue Action Controller
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Active Desk Counter #1',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                      ),
                      Text('Status: Active', style: TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.w600, fontSize: 12)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Column(
                      children: [
                        const Text('CURRENT TOKEN', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF64748B))),
                        const SizedBox(height: 6),
                        Text(
                          activeToken != null ? '$activeToken' : '---',
                          style: const TextStyle(fontSize: 36, fontWeight: FontWeight.w900, color: Color(0xFF4F46E5), letterSpacing: 1),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          activeToken != null ? 'Customer: $custName ${custPhone.isNotEmpty ? '($custPhone)' : ''}' : 'No active token currently being served',
                          style: const TextStyle(fontSize: 13, color: Color(0xFF334155)),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _queueActionLoading ? null : _handleSkipToken,
                          icon: const Icon(Icons.pause_circle_outline, size: 18),
                          label: const Text('Hold / Skip'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF64748B),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _queueActionLoading ? null : _handleCompleteService,
                          icon: const Icon(Icons.check_circle_outline, size: 18),
                          label: const Text('Complete'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF10B981),
                            side: const BorderSide(color: Color(0xFFA7F3D0)),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _queueActionLoading ? null : _handleCallNext,
                          icon: const Icon(Icons.skip_next_rounded, size: 20),
                          label: const Text('Call Next'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF4F46E5),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Section: Unassigned Tokens to Forward
            _buildUnassignedQueueSection(),
            const SizedBox(height: 20),

            // Section: All Waiting Tokens in Line
            _buildAllWaitingTokensSection(),
            const SizedBox(height: 20),

            // Office Daily Token Limit Settings Card (TASK 1)
            _buildQueueSettingsCard(),
            const SizedBox(height: 20),

            // Quick Navigation Buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => setState(() => _approvedSelectedTab = 1),
                    icon: const Icon(Icons.people_alt_rounded),
                    label: const Text('Manage Providers'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF4F46E5),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => setState(() => _approvedSelectedTab = 2),
                    icon: const Icon(Icons.info_outline_rounded),
                    label: const Text('Office Details'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF64748B),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildClosedWarningBanner() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFCA5A5), width: 1.2),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: const BoxDecoration(
              color: Color(0xFFEF4444),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.lock_clock_rounded, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Office Queue is CLOSED',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF991B1B)),
                ),
                const SizedBox(height: 2),
                const Text(
                  'Customers cannot book new queue tokens right now. Existing tokens in line can still be served.',
                  style: TextStyle(fontSize: 12, color: Color(0xFF7F1D1D)),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: _togglingOpen ? null : () => _updateOfficeOpenStatus(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF10B981),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              elevation: 0,
            ),
            child: const Text('Open Now', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildUnassignedQueueSection() {
    final unassignedTokens = (_liveQueueData?['unassignedTokens'] as List<dynamic>?) ?? [];
    final unassignedCount = _liveQueueData?['unassignedCount'] ?? unassignedTokens.length;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: unassignedCount > 0 ? const Color(0xFFC7D2FE) : const Color(0xFFE2E8F0),
          width: unassignedCount > 0 ? 1.5 : 1,
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
          // Section Title
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF4F46E5).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.assignment_ind_rounded, color: Color(0xFF4F46E5), size: 20),
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    'Tokens to Assign',
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
                  color: unassignedCount > 0
                      ? const Color(0xFF4F46E5).withValues(alpha: 0.1)
                      : const Color(0xFF10B981).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  unassignedCount > 0 ? '$unassignedCount Unassigned' : 'All Assigned',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: unassignedCount > 0 ? const Color(0xFF4F46E5) : const Color(0xFF10B981),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Tokens booked with "Any Available Staff". Forward them to an on-duty provider or call them directly at the desk.',
            style: TextStyle(fontSize: 12, color: Color(0xFF64748B), height: 1.3),
          ),
          const SizedBox(height: 14),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          const SizedBox(height: 14),

          if (unassignedTokens.isEmpty)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 20),
              alignment: Alignment.center,
              child: Column(
                children: [
                  Icon(Icons.check_circle_outline_rounded, size: 36, color: Colors.green[400]),
                  const SizedBox(height: 8),
                  const Text(
                    'No Unassigned Tokens',
                    style: TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF334155), fontSize: 14),
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    'Every waiting customer has an assigned provider, or no one is in line.',
                    style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                  ),
                ],
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: unassignedTokens.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (ctx, idx) {
                final item = unassignedTokens[idx] as Map<String, dynamic>;
                final tokenId = item['id'];
                final tokenNumber = item['tokenNumber'] ?? '---';
                final custName = item['customerName'] ?? 'Customer';
                final custPhone = (item['customerPhone'] ?? '').toString();
                final position = item['position'] ?? (idx + 1);
                final waitEst = item['estimatedWaitMinutes'] ?? 0;

                return Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 32,
                            height: 32,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: const Color(0xFF4F46E5).withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '#$position',
                              style: const TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF4F46E5), fontSize: 12),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      tokenNumber,
                                      style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: Color(0xFF0F172A)),
                                    ),
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFFEF3C7),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: const Text(
                                        'Unassigned',
                                        style: TextStyle(color: Color(0xFFB45309), fontSize: 10, fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  custPhone.isNotEmpty ? '$custName ($custPhone)' : custName,
                                  style: const TextStyle(fontSize: 13, color: Color(0xFF475569), fontWeight: FontWeight.w500),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          if (waitEst > 0)
                            Text(
                              '~$waitEst min',
                              style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8), fontWeight: FontWeight.w600),
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _queueActionLoading ? null : () => _serveTokenAtDesk(tokenId),
                              icon: const Icon(Icons.campaign_rounded, size: 16),
                              label: const Text('Call to Desk', style: TextStyle(fontSize: 12)),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: const Color(0xFF4F46E5),
                                padding: const EdgeInsets.symmetric(vertical: 8),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: _queueActionLoading ? null : () => _showForwardDialog(item),
                              icon: const Icon(Icons.person_add_alt_1_rounded, size: 16),
                              label: const Text('Forward to Staff', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF4F46E5),
                                foregroundColor: Colors.white,
                                elevation: 0,
                                padding: const EdgeInsets.symmetric(vertical: 8),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildAllWaitingTokensSection() {
    final waitingTokens = (_liveQueueData?['waitingTokens'] as List<dynamic>?) ?? [];
    if (waitingTokens.isEmpty) return const SizedBox.shrink();

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
                  Text(
                    'All Waiting in Line (${waitingTokens.length})',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                ],
              ),
              const Text('Live', style: TextStyle(fontSize: 11, color: Color(0xFF10B981), fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 12),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: waitingTokens.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (ctx, idx) {
              final item = waitingTokens[idx] as Map<String, dynamic>;
              final tokenNumber = item['tokenNumber'] ?? '---';
              final custName = item['customerName'] ?? 'Customer';
              final providerName = item['providerName'] ?? 'Unassigned';
              final isUnassigned = item['providerId'] == null;
              final position = item['position'] ?? (idx + 1);

              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  children: [
                    Text(
                      '#$position',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF64748B)),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      tokenNumber,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF0F172A)),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        custName,
                        style: const TextStyle(fontSize: 13, color: Color(0xFF334155)),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: isUnassigned
                            ? const Color(0xFFFEF3C7)
                            : const Color(0xFF0284C7).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        isUnassigned ? 'Unassigned' : providerName,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: isUnassigned ? const Color(0xFFB45309) : const Color(0xFF0284C7),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildQueueSettingsCard() {
    final dailyMax = _officeQueueSettings?['dailyMaxTokens'] ?? _officeQueueSettings?['dailyMax'] ?? _liveQueueData?['dailyMaxTokens'] ?? 60;
    final todayTokens = _officeQueueSettings?['todayTokensCount'] ?? _officeQueueSettings?['todayTokens'] ?? _liveQueueData?['todayTokensCount'] ?? 0;
    final remaining = _officeQueueSettings?['remainingCapacity'] ?? _officeQueueSettings?['remaining'] ?? _liveQueueData?['remainingCapacity'] ?? (dailyMax - todayTokens);
    final allocated = _officeQueueSettings?['allocatedProviderLimits'] ?? 0;
    final isFull = _officeQueueSettings?['officeFull'] ?? _officeQueueSettings?['isFull'] ?? _liveQueueData?['isOfficeFull'] ?? false;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isFull ? const Color(0xFFFCA5A5) : const Color(0xFFE2E8F0),
          width: isFull ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF4F46E5).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.tune_rounded, color: Color(0xFF4F46E5), size: 20),
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    'Office Daily Token Limit',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: isFull
                      ? const Color(0xFFEF4444).withValues(alpha: 0.1)
                      : const Color(0xFF10B981).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  isFull ? 'Limit Reached' : 'Open',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: isFull ? const Color(0xFFEF4444) : const Color(0xFF10B981),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Metrics summary
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Saved Limit', style: TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w600)),
                      const SizedBox(height: 2),
                      Text('$dailyMax / day', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                    ],
                  ),
                ),
                Container(width: 1, height: 28, color: const Color(0xFFCBD5E1)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Tokens Issued', style: TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w600)),
                      const SizedBox(height: 2),
                      Text('$todayTokens today', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF4F46E5))),
                    ],
                  ),
                ),
                Container(width: 1, height: 28, color: const Color(0xFFCBD5E1)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Remaining', style: TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w600)),
                      const SizedBox(height: 2),
                      Text(
                        '$remaining left',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: isFull ? const Color(0xFFEF4444) : const Color(0xFF10B981),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (allocated > 0) ...[
            const SizedBox(height: 8),
            Text(
              'Assigned to Provider Limits: $allocated / $dailyMax tokens',
              style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
            ),
          ],
          const SizedBox(height: 16),
          // Input and Save button
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: TextField(
                  controller: _dailyLimitController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: InputDecoration(
                    labelText: 'Maximum Tokens / Day',
                    hintText: 'e.g. 60',
                    prefixIcon: const Icon(Icons.confirmation_number_outlined, size: 20),
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
                onPressed: _savingSettings ? null : _saveQueueSettings,
                icon: _savingSettings
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.save_rounded, size: 18),
                label: Text(_savingSettings ? 'Saving...' : 'Save Limit'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4F46E5),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Text(
            'Enforced across all providers. Customer app will block new tokens once today\'s total reaches this limit.',
            style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8), height: 1.3),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B), fontWeight: FontWeight.w600)),
              Icon(icon, color: color, size: 20),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: color),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // VIEW 2: DETAILS ONLY (FOR PENDING / REJECTED)
  // ==========================================
  Widget _buildDetailsOnlyView(String status) {
    final category = _profileData?['category'] ?? 'OFFICE';

    return RefreshIndicator(
      onRefresh: _fetchProfile,
      color: const Color(0xFF4F46E5),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Status Alert Banner (PENDING / REJECTED)
            _buildStatusAlertBanner(status),
            const SizedBox(height: 16),

            // Header Profile Card
            _buildHeaderCard(category, status),
            const SizedBox(height: 16),

            // Category-Specific Details
            _buildCategoryDetailsCard(category),
            const SizedBox(height: 16),

            // Location & Timings
            _buildLocationAndTimingsCard(),
            const SizedBox(height: 16),

            // Uploaded Documents
            _buildDocumentsCard(),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  // STATUS BANNER FOR PENDING OR REJECTED
  Widget _buildStatusAlertBanner(String status) {
    if (status == 'PENDING') {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFFFFBEB),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFFDE68A)),
        ),
        child: const Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.hourglass_top_rounded, color: Color(0xFFD97706), size: 24),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Application Under Review',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF92400E)),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Your office profile and documents are currently being verified by the admin team. Once approved, the live queue dashboard will automatically unlock.',
                    style: TextStyle(fontSize: 12, color: Color(0xFFB45309), height: 1.4),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    } else if (status == 'REJECTED') {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFFEF2F2),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFFECACA)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.cancel_rounded, color: Color(0xFFDC2626), size: 24),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Verification Rejected',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF991B1B)),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Your submitted verification documents could not be approved. Please review your details and re-upload clear documents.',
                        style: TextStyle(fontSize: 12, color: Color(0xFFB91C1C), height: 1.4),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const OfficeOnboardingScreen()),
                ).then((_) => _fetchProfile());
              },
              icon: const Icon(Icons.edit_document, size: 16),
              label: const Text('Update & Resubmit Documents'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFDC2626),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
      );
    }

    return const SizedBox.shrink();
  }

  // HEADER CARD
  Widget _buildHeaderCard(String category, String status) {
    Color statusColor;
    IconData statusIcon;
    String statusText;

    switch (status) {
      case 'APPROVED':
        statusColor = const Color(0xFF10B981);
        statusIcon = Icons.verified_rounded;
        statusText = 'Verified & Active';
        break;
      case 'REJECTED':
        statusColor = const Color(0xFFEF4444);
        statusIcon = Icons.cancel_outlined;
        statusText = 'Rejected';
        break;
      default:
        statusColor = const Color(0xFFF59E0B);
        statusIcon = Icons.hourglass_top_rounded;
        statusText = 'Under Verification';
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.05),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF4F46E5), Color(0xFF6366F1)],
                  ),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(_getCategoryIcon(category), color: Colors.white, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _userData?['name'] ?? 'Office Name',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF4F46E5).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        category,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF4F46E5),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(height: 1),
          const SizedBox(height: 16),

          // Status & Contact Info
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: statusColor.withValues(alpha: 0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(statusIcon, color: statusColor, size: 16),
                    const SizedBox(width: 6),
                    Text(
                      statusText,
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: statusColor),
                    ),
                  ],
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _profileData?['officeId'] != null 
                        ? 'Office Code: ${_profileData!['officeId']}'
                        : 'ID: #${_profileData?['id'] ?? '---'}',
                    style: const TextStyle(fontSize: 13, color: Color(0xFF64748B), fontWeight: FontWeight.w600),
                  ),
                  if (_profileData?['officeId'] != null) ...[
                    const SizedBox(width: 6),
                    InkWell(
                      onTap: () {
                        Clipboard.setData(ClipboardData(text: _profileData!['officeId'].toString()));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Office ID copied to clipboard!')),
                        );
                      },
                      child: const Icon(Icons.copy, size: 14, color: Color(0xFF64748B)),
                    ),
                  ],
                ],
              ),
            ],
          ),
          if (_profileData?['description'] != null && (_profileData?['description'] as String).isNotEmpty) ...[
            const SizedBox(height: 14),
            Text(
              _profileData!['description'],
              style: const TextStyle(fontSize: 13, color: Color(0xFF64748B), height: 1.4),
            ),
          ],
        ],
      ),
    );
  }

  // CATEGORY DETAILS CARD
  Widget _buildCategoryDetailsCard(String category) {
    List<Widget> items = [];

    if (category == 'CLINIC') {
      items = [
        _buildInfoRow(Icons.person_outline, 'Clinic Name', _profileData?['doctorName'] ?? 'N/A'),
        _buildInfoRow(Icons.medical_services_outlined, 'Specialization', _profileData?['specialization'] ?? 'General'),
        _buildInfoRow(Icons.badge_outlined, 'Medical Reg. No.', _profileData?['medicalRegistrationNumber'] ?? 'N/A'),
      ];
    } else if (category == 'SALON') {
      items = [
        _buildInfoRow(Icons.content_cut_outlined, 'Salon Type', _profileData?['salonType'] ?? 'Unisex'),
        _buildInfoRow(Icons.assignment_outlined, 'Trade License / GST', _profileData?['tradeLicenseNumber'] ?? 'N/A'),
      ];
    } else {
      items = [
        _buildInfoRow(Icons.domain_outlined, 'Business Type / Industry', _profileData?['specialization'] ?? 'General Business'),
        _buildInfoRow(Icons.assignment_outlined, 'License / Reg. Number', _profileData?['tradeLicenseNumber'] ?? 'N/A'),
      ];
    }

    return _buildSectionCard(
      title: '$category Information',
      icon: Icons.info_outline,
      children: items,
    );
  }

  // LOCATION & TIMINGS CARD
  Widget _buildLocationAndTimingsCard() {
    final address = '${_profileData?['address'] ?? ''}, ${_profileData?['city'] ?? ''}, ${_profileData?['state'] ?? ''} - ${_profileData?['pincode'] ?? ''}';
    final timings = '${_profileData?['openingTime'] ?? '09:00 AM'} - ${_profileData?['closingTime'] ?? '08:00 PM'}';

    return _buildSectionCard(
      title: 'Location & Working Hours',
      icon: Icons.location_on_outlined,
      children: [
        _buildInfoRow(Icons.email_outlined, 'Email', _userData?['email'] ?? 'N/A'),
        _buildInfoRow(Icons.phone_outlined, 'Phone', _profileData?['phone'] ?? 'N/A'),
        _buildInfoRow(Icons.map_outlined, 'Address', address),
        _buildInfoRow(Icons.access_time_rounded, 'Working Hours', timings),
      ],
    );
  }

  // DOCUMENTS CARD
  Widget _buildDocumentsCard() {
    return _buildSectionCard(
      title: 'Uploaded Verification Documents',
      icon: Icons.folder_shared_outlined,
      children: [
        if (_documents.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text('No documents uploaded yet.', style: TextStyle(fontSize: 13, color: Color(0xFF94A3B8))),
          )
        else
          ..._documents.map((doc) {
            final docType = doc['documentType'] ?? 'Document';
            final fileName = doc['originalFileName'] ?? 'document.pdf';
            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.picture_as_pdf_outlined, color: Color(0xFFEF4444), size: 28),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _formatDocType(docType),
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Color(0xFF1E293B)),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          fileName,
                          style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 20),
                ],
              ),
            );
          }),
      ],
    );
  }

  // HELPER CARD CONTAINER
  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.04),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: const Color(0xFF4F46E5)),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(height: 1),
          const SizedBox(height: 14),
          ...children,
        ],
      ),
    );
  }

  // HELPER INFO ROW
  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: const Color(0xFF94A3B8)),
          const SizedBox(width: 10),
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(fontSize: 13, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 13, color: Color(0xFF0F172A), fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  IconData _getCategoryIcon(String category) {
    switch (category) {
      case 'CLINIC':
        return Icons.local_hospital_rounded;
      case 'SALON':
        return Icons.content_cut_rounded;
      default:
        return Icons.business_rounded;
    }
  }

  String _formatDocType(String type) {
    switch (type) {
      case 'CLINIC_REGISTRATION':
        return 'Clinic Registration Certificate';
      case 'DOCTOR_DEGREE':
        return 'Doctor Degree / Certificate';
      case 'TRADE_LICENSE':
        return 'Trade / Business License';
      case 'OWNER_ID_PROOF':
        return 'Owner / Representative ID';
      case 'BUSINESS_REGISTRATION':
        return 'Business Registration';
      default:
        return type.replaceAll('_', ' ');
    }
  }
}
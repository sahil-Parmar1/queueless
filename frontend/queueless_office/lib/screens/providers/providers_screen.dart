import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:queueless_office/screens/providers/add_edit_provider_dialog.dart';

class ProvidersScreen extends StatefulWidget {
  final Map<String, dynamic>? officeProfile;

  const ProvidersScreen({super.key, this.officeProfile});

  @override
  State<ProvidersScreen> createState() => _ProvidersScreenState();
}

class _ProvidersScreenState extends State<ProvidersScreen> {
  final _storage = const FlutterSecureStorage();

  bool _loading = true;
  String? _error;
  List<dynamic> _providers = [];
  final Map<int, bool> _togglingStatus = {};

  String get _apiBaseUrl => kIsWeb
      ? 'http://localhost:8080/api/office/providers'
      : 'http://10.0.2.2:8080/api/office/providers';

  @override
  void initState() {
    super.initState();
    _fetchProviders();
  }

  Future<void> _fetchProviders() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final token = await _storage.read(key: 'jwt_token');
      if (token == null) {
        setState(() {
          _error = 'Not authenticated. Please log in.';
          _loading = false;
        });
        return;
      }

      final response = await http.get(
        Uri.parse(_apiBaseUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final List data = jsonDecode(response.body);
        if (mounted) {
          setState(() {
            _providers = data;
            _loading = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _error = 'Failed to load providers (${response.statusCode})';
            _loading = false;
          });
        }
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

  Future<void> _toggleActive(Map<String, dynamic> provider, bool newStatus) async {
    final id = provider['id'] as int;
    setState(() => _togglingStatus[id] = true);

    try {
      final token = await _storage.read(key: 'jwt_token');
      final response = await http.patch(
        Uri.parse('$_apiBaseUrl/$id/status?active=$newStatus'),
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final updated = jsonDecode(response.body);
        if (mounted) {
          setState(() {
            final idx = _providers.indexWhere((p) => p['id'] == id);
            if (idx != -1) {
              _providers[idx] = updated;
            }
            _togglingStatus.remove(id);
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(newStatus
                  ? '${provider['name']} is now ACTIVE'
                  : '${provider['name']} is now INACTIVE'),
              backgroundColor: newStatus ? const Color(0xFF10B981) : const Color(0xFF64748B),
              duration: const Duration(seconds: 2),
            ),
          );
        }
      } else {
        if (mounted) {
          setState(() => _togglingStatus.remove(id));
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to update status: ${response.statusCode}'),
              backgroundColor: const Color(0xFFEF4444),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _togglingStatus.remove(id));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: const Color(0xFFEF4444),
          ),
        );
      }
    }
  }

  Future<void> _confirmDelete(Map<String, dynamic> provider) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Color(0xFFEF4444)),
            SizedBox(width: 8),
            Text('Delete Provider?'),
          ],
        ),
        content: Text(
          'Are you sure you want to delete "${provider['name']}"? '
          'Past queue history will be retained, but new tokens will no longer be assigned to this provider.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final token = await _storage.read(key: 'jwt_token');
      final id = provider['id'];
      final response = await http.delete(
        Uri.parse('$_apiBaseUrl/$id'),
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Provider "${provider['name']}" removed successfully'),
              backgroundColor: const Color(0xFF10B981),
            ),
          );
          _fetchProviders();
        }
      } else {
        final body = jsonDecode(response.body);
        final errMsg = body['error'] ?? body['message'] ?? 'Could not delete provider (${response.statusCode})';
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(errMsg),
              backgroundColor: const Color(0xFFEF4444),
              duration: const Duration(seconds: 4),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Delete failed: $e'),
            backgroundColor: const Color(0xFFEF4444),
          ),
        );
      }
    }
  }

  void _openAddEditDialog([Map<String, dynamic>? provider]) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AddEditProviderDialog(
        provider: provider,
        onSaved: _fetchProviders,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Color(0xFF4F46E5)),
            SizedBox(height: 16),
            Text('Loading staff & providers...', style: TextStyle(color: Color(0xFF64748B))),
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
                onPressed: _fetchProviders,
                icon: const Icon(Icons.refresh),
                label: const Text('Try Again'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4F46E5),
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final totalCount = _providers.length;
    final activeCount = _providers.where((p) => p['active'] == true).length;
    final availableNowCount = _providers.where((p) => p['availableNow'] == true).length;
    final officeId = (widget.officeProfile?['officeId'] ?? widget.officeProfile?['user']?['officeId'] ?? '').toString();

    return RefreshIndicator(
      onRefresh: _fetchProviders,
      color: const Color(0xFF4F46E5),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Top Action Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Provider Management',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Manage staff, hours & availability',
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: () => _openAddEditDialog(),
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: const Text('Add Provider'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4F46E5),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),

            // Statistics Row (Overflow-proof)
            Row(
              children: [
                Expanded(
                  child: _buildStatCard('Total', '$totalCount', Icons.people_outline, const Color(0xFF4F46E5)),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildStatCard('Active', '$activeCount', Icons.check_circle_outline, const Color(0xFF10B981)),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildStatCard('Available', '$availableNowCount', Icons.schedule_rounded, const Color(0xFF0EA5E9)),
                ),
              ],
            ),

            // Office ID sharing banner
            if (officeId.isNotEmpty) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFEEF2FF),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFC7D2FE)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.vpn_key_outlined, color: Color(0xFF4F46E5), size: 18),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'OFFICE ID (FOR PROVIDER LOGIN)',
                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF4338CA)),
                          ),
                          Text(
                            officeId,
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Color(0xFF1E1B4B), letterSpacing: 0.5),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.copy_rounded, size: 18, color: Color(0xFF4F46E5)),
                      tooltip: 'Copy Office ID',
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: officeId));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Office ID copied to clipboard!')),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 20),

            // Provider Cards List or Empty State
            if (_providers.isEmpty)
              _buildEmptyState()
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _providers.length,
                separatorBuilder: (context, index) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final p = _providers[index] as Map<String, dynamic>;
                  return _buildProviderCard(p);
                },
              ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 15, color: color),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: color),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProviderCard(Map<String, dynamic> p) {
    final int id = p['id'];
    final String name = p['name'] ?? 'Provider';
    final String? designation = p['designation'];
    final String? username = p['username'];
    final String? contactNumber = p['contactNumber'];
    final String? email = p['email'];
    final bool active = p['active'] ?? false;
    final bool availableNow = p['availableNow'] ?? false;
    final String todayWorkingHours = p['todayWorkingHours'] ?? 'Today: Off';
    final String workingDaysSummary = p['workingDaysSummary'] ?? 'No schedule';
    final List schedules = p['schedules'] ?? [];
    final bool isToggling = _togglingStatus[id] == true;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: active ? const Color(0xFFE2E8F0) : const Color(0xFFF1F5F9),
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Top Bar
          Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Avatar with initials
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: active
                        ? const Color(0xFF4F46E5).withValues(alpha: 0.1)
                        : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Text(
                      name.isNotEmpty ? name.substring(0, 1).toUpperCase() : 'P',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: active ? const Color(0xFF4F46E5) : const Color(0xFF94A3B8),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),

                // Name & Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: active ? const Color(0xFF0F172A) : const Color(0xFF64748B),
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          // Availability Status Chip
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                            decoration: BoxDecoration(
                              color: availableNow
                                  ? const Color(0xFF10B981).withValues(alpha: 0.1)
                                  : (active
                                      ? const Color(0xFFF59E0B).withValues(alpha: 0.1)
                                      : const Color(0xFF64748B).withValues(alpha: 0.1)),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 6,
                                  height: 6,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: availableNow
                                        ? const Color(0xFF10B981)
                                        : (active ? const Color(0xFFF59E0B) : const Color(0xFF64748B)),
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  availableNow ? 'Available' : (active ? 'Off Hours' : 'Inactive'),
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: availableNow
                                        ? const Color(0xFF10B981)
                                        : (active ? const Color(0xFFD97706) : const Color(0xFF64748B)),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      if (designation != null && designation.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          designation,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 13,
                            color: Color(0xFF4F46E5),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                      if (username != null && username.isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.alternate_email_rounded, size: 12, color: Color(0xFF64748B)),
                            const SizedBox(width: 2),
                            Text(
                              username,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ),
                      ],
                      if (contactNumber != null || email != null) ...[
                        const SizedBox(height: 4),
                        Wrap(
                          spacing: 10,
                          runSpacing: 2,
                          children: [
                            if (contactNumber != null && contactNumber.isNotEmpty)
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.phone_outlined, size: 12, color: Color(0xFF94A3B8)),
                                  const SizedBox(width: 4),
                                  Text(contactNumber, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                                ],
                              ),
                            if (email != null && email.isNotEmpty)
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.email_outlined, size: 12, color: Color(0xFF94A3B8)),
                                  const SizedBox(width: 4),
                                  Text(
                                    email,
                                    style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                                  ),
                                ],
                              ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Working Hours & Schedule Summary Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: const BoxDecoration(
              color: Color(0xFFF8FAFC),
              border: Border(
                top: BorderSide(color: Color(0xFFF1F5F9)),
                bottom: BorderSide(color: Color(0xFFF1F5F9)),
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.schedule_rounded, size: 14, color: Color(0xFF4F46E5)),
                const SizedBox(width: 5),
                Text(
                  todayWorkingHours,
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Days: $workingDaysSummary',
                    style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (schedules.isNotEmpty) ...[
                  const SizedBox(width: 6),
                  InkWell(
                    onTap: () => _showScheduleDetailsDialog(name, schedules),
                    child: const Text(
                      'Schedule',
                      style: TextStyle(
                        fontSize: 11,
                        color: Color(0xFF4F46E5),
                        fontWeight: FontWeight.bold,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),

          // Action Footer
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Active Switch
                Flexible(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (isToggling)
                        const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF4F46E5)),
                        )
                      else
                        Switch(
                          value: active,
                          activeThumbColor: const Color(0xFF10B981),
                          onChanged: (val) => _toggleActive(p, val),
                        ),
                      Flexible(
                        child: Text(
                          active ? 'Accepting' : 'Inactive',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: active ? const Color(0xFF0F172A) : const Color(0xFF94A3B8),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Edit & Delete Buttons
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit_outlined, size: 18, color: Color(0xFF4F46E5)),
                      tooltip: 'Edit details & schedule',
                      onPressed: () => _openAddEditDialog(p),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline_rounded, size: 18, color: Color(0xFFEF4444)),
                      tooltip: 'Delete provider',
                      onPressed: () => _confirmDelete(p),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: const Color(0xFF4F46E5).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Icon(Icons.badge_outlined, color: Color(0xFF4F46E5), size: 36),
          ),
          const SizedBox(height: 16),
          const Text(
            'No Providers or Staff Yet',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
          ),
          const SizedBox(height: 6),
          const Text(
            'Add doctors, specialists, or desk officers to manage their individual queues and availability schedules.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: Color(0xFF64748B), height: 1.4),
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: () => _openAddEditDialog(),
            icon: const Icon(Icons.add_rounded),
            label: const Text('Add First Provider'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4F46E5),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ],
      ),
    );
  }

  void _showScheduleDetailsDialog(String providerName, List schedules) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.calendar_month_rounded, color: Color(0xFF4F46E5)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '$providerName\'s Weekly Schedule',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: 320,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: schedules.map((s) {
              final day = s['dayOfWeek'] ?? '';
              final start = s['startTime'] ?? '';
              final end = s['endTime'] ?? '';
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(day, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '$start - $end',
                        style: const TextStyle(fontSize: 12, color: Color(0xFF1E293B), fontWeight: FontWeight.w500),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

class AddEditProviderDialog extends StatefulWidget {
  final Map<String, dynamic>? provider; // null if adding new
  final VoidCallback onSaved;

  const AddEditProviderDialog({
    super.key,
    this.provider,
    required this.onSaved,
  });

  @override
  State<AddEditProviderDialog> createState() => _AddEditProviderDialogState();
}

class _DayScheduleEntry {
  final String dayOfWeek;
  final String label;
  bool isWorking = false;
  TimeOfDay startTime = const TimeOfDay(hour: 9, minute: 0);
  TimeOfDay endTime = const TimeOfDay(hour: 17, minute: 0);

  _DayScheduleEntry({
    required this.dayOfWeek,
    required this.label,
  });
}

class _AddEditProviderDialogState extends State<AddEditProviderDialog> {
  final _formKey = GlobalKey<FormState>();
  final _storage = const FlutterSecureStorage();

  late TextEditingController _nameController;
  late TextEditingController _usernameController;
  late TextEditingController _passwordController;
  late TextEditingController _designationController;
  late TextEditingController _phoneController;
  late TextEditingController _emailController;

  bool _active = true;
  bool _saving = false;
  bool _obscurePassword = true;
  String? _errorMessage;

  final List<_DayScheduleEntry> _days = [
    _DayScheduleEntry(dayOfWeek: 'MONDAY', label: 'Monday'),
    _DayScheduleEntry(dayOfWeek: 'TUESDAY', label: 'Tuesday'),
    _DayScheduleEntry(dayOfWeek: 'WEDNESDAY', label: 'Wednesday'),
    _DayScheduleEntry(dayOfWeek: 'THURSDAY', label: 'Thursday'),
    _DayScheduleEntry(dayOfWeek: 'FRIDAY', label: 'Friday'),
    _DayScheduleEntry(dayOfWeek: 'SATURDAY', label: 'Saturday'),
    _DayScheduleEntry(dayOfWeek: 'SUNDAY', label: 'Sunday'),
  ];

  String get _apiBaseUrl => kIsWeb
      ? 'http://localhost:8081/api/office/providers'
      : 'http://10.0.2.2:8081/api/office/providers';

  @override
  void initState() {
    super.initState();
    final p = widget.provider;

    _nameController = TextEditingController(text: p?['name'] ?? '');
    _usernameController = TextEditingController(text: p?['username'] ?? '');
    _passwordController = TextEditingController();
    _designationController = TextEditingController(text: p?['designation'] ?? '');
    _phoneController = TextEditingController(text: p?['contactNumber'] ?? '');
    _emailController = TextEditingController(text: p?['email'] ?? '');
    _active = p?['active'] ?? true;

    // Load existing schedules if editing
    if (p != null && p['schedules'] != null) {
      final List existingSchedules = p['schedules'];
      for (var s in existingSchedules) {
        final dayStr = s['dayOfWeek']?.toString().toUpperCase();
        final match = _days.where((d) => d.dayOfWeek == dayStr).firstOrNull;
        if (match != null) {
          match.isWorking = true;
          match.startTime = _parseTimeString(s['startTime']?.toString()) ?? const TimeOfDay(hour: 9, minute: 0);
          match.endTime = _parseTimeString(s['endTime']?.toString()) ?? const TimeOfDay(hour: 17, minute: 0);
        }
      }
    } else {
      // Default: Monday through Friday 09:00 - 17:00
      for (int i = 0; i < 5; i++) {
        _days[i].isWorking = true;
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _designationController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  TimeOfDay? _parseTimeString(String? timeStr) {
    if (timeStr == null || !timeStr.contains(':')) return null;
    final parts = timeStr.split(':');
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) return null;
    return TimeOfDay(hour: hour, minute: minute);
  }

  String _formatTimeOfDay(TimeOfDay tod) {
    final h = tod.hour.toString().padLeft(2, '0');
    final m = tod.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  void _applyStandardWeekdays() {
    setState(() {
      for (var d in _days) {
        if (d.dayOfWeek == 'SATURDAY' || d.dayOfWeek == 'SUNDAY') {
          d.isWorking = false;
        } else {
          d.isWorking = true;
          d.startTime = const TimeOfDay(hour: 9, minute: 0);
          d.endTime = const TimeOfDay(hour: 17, minute: 0);
        }
      }
    });
  }

  Future<void> _pickTime(BuildContext context, _DayScheduleEntry day, bool isStart) async {
    final initial = isStart ? day.startTime : day.endTime;
    final picked = await showTimePicker(
      context: context,
      initialTime: initial,
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
          child: Theme(
            data: Theme.of(context).copyWith(
              colorScheme: const ColorScheme.light(
                primary: Color(0xFF4F46E5),
                onPrimary: Colors.white,
                surface: Colors.white,
                onSurface: Color(0xFF0F172A),
              ),
            ),
            child: child!,
          ),
        );
      },
    );

    if (picked != null) {
      setState(() {
        if (isStart) {
          day.startTime = picked;
        } else {
          day.endTime = picked;
        }
      });
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    // Validate schedules
    final activeSchedules = <Map<String, String>>[];
    for (var d in _days) {
      if (d.isWorking) {
        final startMinutes = d.startTime.hour * 60 + d.startTime.minute;
        final endMinutes = d.endTime.hour * 60 + d.endTime.minute;
        if (endMinutes <= startMinutes) {
          setState(() {
            _errorMessage = 'On ${d.label}, end time (${_formatTimeOfDay(d.endTime)}) must be after start time (${_formatTimeOfDay(d.startTime)}).';
          });
          return;
        }
        activeSchedules.add({
          'dayOfWeek': d.dayOfWeek,
          'startTime': _formatTimeOfDay(d.startTime),
          'endTime': _formatTimeOfDay(d.endTime),
        });
      }
    }

    setState(() {
      _saving = true;
      _errorMessage = null;
    });

    try {
      final token = await _storage.read(key: 'jwt_token');
      if (token == null) {
        setState(() {
          _saving = false;
          _errorMessage = 'Session expired. Please log in again.';
        });
        return;
      }

      final isEditing = widget.provider != null;
      final providerId = widget.provider?['id'];
      final url = isEditing ? '$_apiBaseUrl/$providerId' : _apiBaseUrl;

      final payload = {
        'name': _nameController.text.trim(),
        'username': _usernameController.text.trim().toLowerCase(),
        if (!isEditing || _passwordController.text.trim().isNotEmpty)
          'password': _passwordController.text.trim(),
        'designation': _designationController.text.trim().isEmpty ? null : _designationController.text.trim(),
        'contactNumber': _phoneController.text.trim().isEmpty ? null : _phoneController.text.trim(),
        'email': _emailController.text.trim().isEmpty ? null : _emailController.text.trim(),
        'active': _active,
        'schedules': activeSchedules,
      };

      final response = isEditing
          ? await http.put(
              Uri.parse(url),
              headers: {
                'Content-Type': 'application/json',
                'Authorization': 'Bearer $token',
              },
              body: jsonEncode(payload),
            )
          : await http.post(
              Uri.parse(url),
              headers: {
                'Content-Type': 'application/json',
                'Authorization': 'Bearer $token',
              },
              body: jsonEncode(payload),
            );

      if (response.statusCode == 200 || response.statusCode == 201) {
        if (mounted) {
          Navigator.pop(context);
          widget.onSaved();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(isEditing
                  ? 'Provider "${_nameController.text.trim()}" updated successfully'
                  : 'Provider "${_nameController.text.trim()}" added successfully'),
              backgroundColor: const Color(0xFF10B981),
            ),
          );
        }
      } else {
        String msg = 'Request failed (${response.statusCode})';
        try {
          final body = jsonDecode(response.body);
          if (body is Map) {
            msg = body['error'] ?? body['message'] ?? msg;
          }
        } catch (_) {
          if (response.body.isNotEmpty) {
            msg = response.body;
          }
        }
        setState(() {
          _errorMessage = msg;
          _saving = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Network error: $e';
          _saving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.provider != null;
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 500;

    return Dialog(
      insetPadding: EdgeInsets.symmetric(
        horizontal: isMobile ? 12 : 24,
        vertical: isMobile ? 16 : 24,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      backgroundColor: Colors.white,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 580, maxHeight: 720),
        child: Column(
          children: [
            // Header
            Container(
              padding: EdgeInsets.symmetric(horizontal: isMobile ? 16 : 24, vertical: 14),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF4F46E5).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      isEditing ? Icons.edit_rounded : Icons.person_add_rounded,
                      color: const Color(0xFF4F46E5),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      isEditing ? 'Edit Provider & Schedule' : 'Add New Provider',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Color(0xFF94A3B8)),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            // Scrollable Form
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.all(isMobile ? 16 : 24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (_errorMessage != null) ...[
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEF2F2),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFFFECACA)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.error_outline_rounded, color: Color(0xFFDC2626), size: 20),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  _errorMessage!,
                                  style: const TextStyle(color: Color(0xFFB91C1C), fontSize: 13),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],

                      // Basic Details
                      const Text(
                        'BASIC INFORMATION',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF64748B),
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Full Name
                      TextFormField(
                        controller: _nameController,
                        decoration: _inputDecoration(
                          label: 'Full Name *',
                          hint: 'e.g. Dr. Sarah Jenkins, Jane Doe',
                          icon: Icons.person_outline_rounded,
                        ),
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) {
                            return 'Please enter provider name';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 14),

                      // Designation
                      TextFormField(
                        controller: _designationController,
                        decoration: _inputDecoration(
                          label: 'Designation / Specialty',
                          hint: 'e.g. Cardiologist, Senior Stylist, Loan Officer',
                          icon: Icons.badge_outlined,
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Contact Phone & Email (Responsive: stacked on mobile, row on tablet/desktop)
                      if (isMobile) ...[
                        TextFormField(
                          controller: _phoneController,
                          keyboardType: TextInputType.phone,
                          decoration: _inputDecoration(
                            label: 'Contact Phone',
                            hint: '+1 234 567 8900',
                            icon: Icons.phone_outlined,
                          ),
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          decoration: _inputDecoration(
                            label: 'Email',
                            hint: 'doctor@clinic.com',
                            icon: Icons.email_outlined,
                          ),
                        ),
                      ] else ...[
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _phoneController,
                                keyboardType: TextInputType.phone,
                                decoration: _inputDecoration(
                                  label: 'Contact Phone',
                                  hint: '+1 234 567 8900',
                                  icon: Icons.phone_outlined,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextFormField(
                                controller: _emailController,
                                keyboardType: TextInputType.emailAddress,
                                decoration: _inputDecoration(
                                  label: 'Email',
                                  hint: 'doctor@clinic.com',
                                  icon: Icons.email_outlined,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 14),

                      // Provider Portal Login Credentials
                      const Text(
                        'PROVIDER PORTAL CREDENTIALS',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF64748B),
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Username
                      TextFormField(
                        controller: _usernameController,
                        decoration: _inputDecoration(
                          label: 'Username *',
                          hint: 'e.g. dr.robert, desk.sarah',
                          icon: Icons.alternate_email_rounded,
                        ),
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) {
                            return 'Please enter a provider username';
                          }
                          if (val.trim().length < 3) {
                            return 'Username must be at least 3 characters';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 14),

                      // Password
                      TextFormField(
                        controller: _passwordController,
                        obscureText: _obscurePassword,
                        decoration: _inputDecoration(
                          label: widget.provider != null
                              ? 'Password (Leave blank to keep unchanged)'
                              : 'Password *',
                          hint: widget.provider != null ? '••••••••' : 'Min. 4 characters',
                          icon: Icons.lock_outline_rounded,
                        ).copyWith(
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                              size: 18,
                              color: const Color(0xFF94A3B8),
                            ),
                            onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                          ),
                        ),
                        validator: (val) {
                          if (widget.provider == null && (val == null || val.trim().isEmpty)) {
                            return 'Please set a password for this provider';
                          }
                          if (val != null && val.trim().isNotEmpty && val.trim().length < 4) {
                            return 'Password must be at least 4 characters';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 14),

                      // Active Status Toggle
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: isMobile ? 12 : 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Provider Active Status',
                                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Color(0xFF0F172A)),
                                  ),
                                  Text(
                                    _active ? 'Currently active & accepting queue' : 'Deactivated',
                                    style: TextStyle(fontSize: 12, color: _active ? const Color(0xFF10B981) : const Color(0xFF94A3B8)),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Switch(
                              value: _active,
                              activeThumbColor: const Color(0xFF10B981),
                              onChanged: (val) => setState(() => _active = val),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Schedule Section Header
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'WORKING HOURS & SCHEDULE',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF64748B),
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                SizedBox(height: 2),
                                Text(
                                  'Tokens can only be booked during set hours',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          TextButton.icon(
                            onPressed: _applyStandardWeekdays,
                            icon: const Icon(Icons.flash_on_rounded, size: 14),
                            label: const Text('Mon-Fri 9-5', style: TextStyle(fontSize: 12)),
                            style: TextButton.styleFrom(
                              foregroundColor: const Color(0xFF4F46E5),
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Day Schedule Rows
                      ..._days.map((day) => _buildDayScheduleRow(day)),
                    ],
                  ),
                ),
              ),
            ),

            // Footer Actions
            Container(
              padding: EdgeInsets.symmetric(horizontal: isMobile ? 16 : 24, vertical: 14),
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    onPressed: _saving ? null : () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF64748B),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      padding: EdgeInsets.symmetric(horizontal: isMobile ? 14 : 18, vertical: 12),
                    ),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    onPressed: _saving ? null : _submit,
                    icon: _saving
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : Icon(isEditing ? Icons.check_rounded : Icons.save_rounded, size: 18),
                    label: Text(isEditing ? 'Save Changes' : 'Create Provider'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4F46E5),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      padding: EdgeInsets.symmetric(horizontal: isMobile ? 16 : 22, vertical: 12),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDayScheduleRow(_DayScheduleEntry day) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: day.isWorking ? Colors.white : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: day.isWorking ? const Color(0xFFCBD5E1) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Row(
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Checkbox(
                value: day.isWorking,
                activeColor: const Color(0xFF4F46E5),
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                visualDensity: VisualDensity.compact,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                onChanged: (val) {
                  setState(() => day.isWorking = val ?? false);
                },
              ),
              const SizedBox(width: 4),
              SizedBox(
                width: 36,
                child: Text(
                  day.label.substring(0, 3),
                  style: TextStyle(
                    fontWeight: day.isWorking ? FontWeight.bold : FontWeight.w500,
                    fontSize: 13,
                    color: day.isWorking ? const Color(0xFF0F172A) : const Color(0xFF94A3B8),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 6),
          if (day.isWorking) ...[
            Expanded(
              child: Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () => _pickTime(context, day, true),
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 7),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.access_time_rounded, size: 13, color: Color(0xFF64748B)),
                              const SizedBox(width: 4),
                              Text(
                                _formatTimeOfDay(day.startTime),
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF1E293B)),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 4),
                    child: Text('to', style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
                  ),
                  Expanded(
                    child: InkWell(
                      onTap: () => _pickTime(context, day, false),
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 7),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.access_time_rounded, size: 13, color: Color(0xFF64748B)),
                              const SizedBox(width: 4),
                              Text(
                                _formatTimeOfDay(day.endTime),
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF1E293B)),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ] else ...[
            const Expanded(
              child: Text(
                'Day Off / Unavailable',
                style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8), fontStyle: FontStyle.italic),
              ),
            ),
          ],
        ],
      ),
    );
  }

  InputDecoration _inputDecoration({
    required String label,
    required String hint,
    required IconData icon,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: Icon(icon, color: const Color(0xFF94A3B8), size: 20),
      labelStyle: const TextStyle(color: Color(0xFF64748B), fontSize: 13),
      hintStyle: const TextStyle(color: Color(0xFFCBD5E1), fontSize: 12),
      filled: true,
      fillColor: const Color(0xFFF8FAFC),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFF4F46E5), width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFFEF4444)),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFFEF4444), width: 1.5),
      ),
    );
  }
}

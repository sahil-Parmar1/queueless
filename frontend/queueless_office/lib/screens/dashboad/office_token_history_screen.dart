import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import '../../config/api_config.dart';

class OfficeTokenHistoryScreen extends StatefulWidget {
  final dynamic officeId;
  final Map<String, dynamic>? officeProfile;

  const OfficeTokenHistoryScreen({
    super.key,
    required this.officeId,
    this.officeProfile,
  });

  @override
  State<OfficeTokenHistoryScreen> createState() => _OfficeTokenHistoryScreenState();
}

class _OfficeTokenHistoryScreenState extends State<OfficeTokenHistoryScreen> {
  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  Timer? _searchDebounce;

  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = false;
  int _currentPage = 0;
  final int _pageSize = 20;

  List<dynamic> _history = [];
  int _totalElements = 0;

  // Provider Filter List
  List<dynamic> _providersList = [];
  bool _loadingProviders = false;
  dynamic _selectedProviderId; // null = all, 0 = unassigned / front desk, or int providerId

  // Status Filter
  String _selectedStatus = 'COMPLETED'; // Default to COMPLETED for history
  final List<Map<String, String>> _statusOptions = [
    {'label': 'Completed', 'value': 'COMPLETED'},
    {'label': 'All Statuses', 'value': 'ALL'},
    {'label': 'Cancelled', 'value': 'CANCELLED'},
    {'label': 'Skipped', 'value': 'SKIPPED'},
  ];

  // Date Filter
  String _selectedDateFilter = 'all'; // all, today, yesterday, 7_days, this_month, custom
  DateTimeRange? _customDateRange;

  final List<Map<String, String>> _dateOptions = [
    {'label': 'All Time', 'value': 'all'},
    {'label': 'Today', 'value': 'today'},
    {'label': 'Yesterday', 'value': 'yesterday'},
    {'label': 'Last 7 Days', 'value': '7_days'},
    {'label': 'This Month', 'value': 'this_month'},
    {'label': 'Custom Range', 'value': 'custom'},
  ];

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _fetchProviders();
    _loadHistory(reset: true);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    _searchDebounce?.cancel();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      if (!_loading && !_loadingMore && _hasMore) {
        _loadHistory(reset: false);
      }
    }
  }

  void _onSearchChanged(String value) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 400), () {
      if (mounted) {
        _loadHistory(reset: true);
      }
    });
  }

  Future<void> _fetchProviders() async {
    setState(() => _loadingProviders = true);
    try {
      final token = await _storage.read(key: 'jwt_token');
      if (token == null) return;
      final response = await http.get(
        Uri.parse('${ApiConfig.baseApiUrl}/api/office/providers'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (mounted && data is List) {
          setState(() {
            _providersList = data;
            _loadingProviders = false;
          });
        }
      }
    } catch (e) {
      debugPrint('Error fetching providers for filter: $e');
    } finally {
      if (mounted) setState(() => _loadingProviders = false);
    }
  }

  Future<void> _loadHistory({bool reset = false}) async {
    if (reset) {
      setState(() {
        _loading = true;
        _currentPage = 0;
      });
    } else {
      setState(() {
        _loadingMore = true;
      });
    }

    final pageToLoad = reset ? 0 : _currentPage + 1;

    try {
      final token = await _storage.read(key: 'jwt_token');
      if (token == null) {
        if (mounted) {
          setState(() {
            _loading = false;
            _loadingMore = false;
          });
        }
        return;
      }

      final queryParams = <String, String>{
        'page': pageToLoad.toString(),
        'size': _pageSize.toString(),
      };

      if (_searchController.text.trim().isNotEmpty) {
        queryParams['search'] = _searchController.text.trim();
      }
      if (_selectedStatus != 'ALL') {
        queryParams['status'] = _selectedStatus;
      }
      if (_selectedProviderId != null) {
        queryParams['providerId'] = _selectedProviderId.toString();
      }
      if (_selectedDateFilter != 'all' && _selectedDateFilter != 'custom') {
        queryParams['date'] = _selectedDateFilter;
      }
      if (_selectedDateFilter == 'custom' && _customDateRange != null) {
        queryParams['startDate'] = _customDateRange!.start.toIso8601String().split('T').first;
        queryParams['endDate'] = _customDateRange!.end.toIso8601String().split('T').first;
      }

      final effectiveOfficeId = (widget.officeId != null && widget.officeId.toString().trim().isNotEmpty)
          ? widget.officeId.toString().trim()
          : (widget.officeProfile?['id']?.toString() ?? widget.officeProfile?['officeId']?.toString() ?? '');

      if (effectiveOfficeId.isEmpty) {
        if (mounted) {
          setState(() {
            _loading = false;
            _loadingMore = false;
          });
        }
        return;
      }

      final uri = Uri.parse('${ApiConfig.baseApiUrl}/api/queue/office/$effectiveOfficeId/tokens/history')
          .replace(queryParameters: queryParams);

      final response = await http.get(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        List<dynamic> content = [];
        int total = 0;
        bool hasMore = false;

        if (decoded is Map<String, dynamic>) {
          content = (decoded['content'] as List?) ?? [];
          total = (decoded['totalElements'] as num?)?.toInt() ?? content.length;
          hasMore = decoded['hasMore'] == true;
        } else if (decoded is List) {
          content = decoded;
          total = decoded.length;
          hasMore = false;
        }

        if (mounted) {
          setState(() {
            if (reset) {
              _history = content;
              _currentPage = 0;
            } else {
              _history.addAll(content);
              _currentPage = pageToLoad;
            }
            _totalElements = total;
            _hasMore = hasMore;
            _loading = false;
            _loadingMore = false;
          });
        }
      } else {
        debugPrint('Office history API returned status: ${response.statusCode} body: ${response.body}');
        if (mounted) {
          setState(() {
            _loading = false;
            _loadingMore = false;
          });
        }
      }
    } catch (e) {
      debugPrint('Error loading office token history: $e');
      if (mounted) {
        setState(() {
          _loading = false;
          _loadingMore = false;
        });
      }
    }
  }

  Future<void> _pickCustomDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2023, 1, 1),
      lastDate: DateTime.now().add(const Duration(days: 1)),
      initialDateRange: _customDateRange ??
          DateTimeRange(
            start: DateTime.now().subtract(const Duration(days: 7)),
            end: DateTime.now(),
          ),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF4F46E5),
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Color(0xFF0F172A),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _customDateRange = picked;
        _selectedDateFilter = 'custom';
      });
      _loadHistory(reset: true);
    }
  }

  void _resetAllFilters() {
    setState(() {
      _searchController.clear();
      _selectedStatus = 'COMPLETED';
      _selectedProviderId = null;
      _selectedDateFilter = 'all';
      _customDateRange = null;
    });
    _loadHistory(reset: true);
  }

  bool get _hasActiveFilters =>
      _searchController.text.trim().isNotEmpty ||
      _selectedStatus != 'COMPLETED' ||
      _selectedProviderId != null ||
      _selectedDateFilter != 'all';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Column(
        children: [
          _buildFilterHeader(),
          Expanded(
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(color: Color(0xFF4F46E5)),
                  )
                : RefreshIndicator(
                    onRefresh: () => _loadHistory(reset: true),
                    color: const Color(0xFF4F46E5),
                    child: _history.isEmpty
                        ? _buildEmptyState()
                        : ListView.separated(
                            controller: _scrollController,
                            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                            itemCount: _history.length + (_loadingMore ? 1 : 0),
                            separatorBuilder: (_, _) => const SizedBox(height: 12),
                            itemBuilder: (context, index) {
                              if (index >= _history.length) {
                                return const Center(
                                  child: Padding(
                                    padding: EdgeInsets.symmetric(vertical: 16),
                                    child: SizedBox(
                                      width: 24,
                                      height: 24,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2.2,
                                        color: Color(0xFF4F46E5),
                                      ),
                                    ),
                                  ),
                                );
                              }
                              final item = _history[index];
                              return _buildTokenCard(item);
                            },
                          ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterHeader() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Search Box & Reset Action
          Row(
            children: [
              Expanded(
                child: Container(
                  height: 44,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: TextField(
                    controller: _searchController,
                    onChanged: _onSearchChanged,
                    textInputAction: TextInputAction.search,
                    decoration: InputDecoration(
                      hintText: 'Search token #, customer, phone, or service...',
                      hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                      prefixIcon: const Icon(Icons.search_rounded, size: 20, color: Color(0xFF94A3B8)),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.close_rounded, size: 18, color: Color(0xFF94A3B8)),
                              onPressed: () {
                                _searchController.clear();
                                _loadHistory(reset: true);
                              },
                            )
                          : null,
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    style: const TextStyle(fontSize: 14, color: Color(0xFF0F172A)),
                  ),
                ),
              ),
              if (_hasActiveFilters) ...[
                const SizedBox(width: 8),
                TextButton.icon(
                  onPressed: _resetAllFilters,
                  icon: const Icon(Icons.clear_all_rounded, size: 18, color: Color(0xFF4F46E5)),
                  label: const Text(
                    'Reset',
                    style: TextStyle(
                      color: Color(0xFF4F46E5),
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                  style: TextButton.styleFrom(
                    backgroundColor: const Color(0xFFEEF2FF),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 10),

          // Provider Filter Dropdown / Selector
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFEEF2FF),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.badge_rounded, size: 14, color: Color(0xFF4F46E5)),
                    SizedBox(width: 4),
                    Text(
                      'Provider:',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF4F46E5),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Container(
                  height: 38,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<dynamic>(
                      value: _selectedProviderId,
                      isExpanded: true,
                      icon: _loadingProviders
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(strokeWidth: 1.5, color: Color(0xFF4F46E5)),
                            )
                          : const Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: Color(0xFF64748B)),
                      style: const TextStyle(fontSize: 13, color: Color(0xFF0F172A), fontWeight: FontWeight.w600),
                      items: [
                        const DropdownMenuItem<dynamic>(
                          value: null,
                          child: Text('All Staff & Desks', maxLines: 1, overflow: TextOverflow.ellipsis),
                        ),
                        const DropdownMenuItem<dynamic>(
                          value: 0,
                          child: Text('Front Desk Counter (Unassigned)', maxLines: 1, overflow: TextOverflow.ellipsis),
                        ),
                        ..._providersList.map((p) {
                          final name = p['name'] ?? 'Provider';
                          final spec = p['specialization'] ?? '';
                          final label = spec.isNotEmpty ? '$name ($spec)' : name;
                          return DropdownMenuItem<dynamic>(
                            value: p['id'],
                            child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
                          );
                        }),
                      ],
                      onChanged: (val) {
                        setState(() => _selectedProviderId = val);
                        _loadHistory(reset: true);
                      },
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Status Filter Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _statusOptions.map((opt) {
                final isSelected = _selectedStatus == opt['value'];
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(opt['label']!),
                    labelStyle: TextStyle(
                      fontSize: 12,
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                      color: isSelected ? Colors.white : const Color(0xFF475569),
                    ),
                    selected: isSelected,
                    selectedColor: const Color(0xFF4F46E5),
                    backgroundColor: const Color(0xFFF1F5F9),
                    side: BorderSide(
                      color: isSelected ? const Color(0xFF4F46E5) : const Color(0xFFE2E8F0),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
                    visualDensity: VisualDensity.compact,
                    onSelected: (selected) {
                      if (selected) {
                        setState(() => _selectedStatus = opt['value']!);
                        _loadHistory(reset: true);
                      }
                    },
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 8),

          // Date Filter Selector Row
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                const Icon(Icons.calendar_today_rounded, size: 14, color: Color(0xFF64748B)),
                const SizedBox(width: 6),
                ..._dateOptions.map((opt) {
                  final isSelected = _selectedDateFilter == opt['value'];
                  String label = opt['label']!;
                  if (opt['value'] == 'custom' && _customDateRange != null) {
                    final s = _customDateRange!.start;
                    final e = _customDateRange!.end;
                    label = '${s.day}/${s.month} - ${e.day}/${e.month}';
                  }

                  return Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(20),
                      onTap: () {
                        if (opt['value'] == 'custom') {
                          _pickCustomDateRange();
                        } else {
                          setState(() {
                            _selectedDateFilter = opt['value']!;
                            _customDateRange = null;
                          });
                          _loadHistory(reset: true);
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: isSelected ? const Color(0xFFEEF2FF) : Colors.transparent,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isSelected ? const Color(0xFF4F46E5) : const Color(0xFFE2E8F0),
                            width: 1,
                          ),
                        ),
                        child: Text(
                          label,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                            color: isSelected ? const Color(0xFF4F46E5) : const Color(0xFF475569),
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),

          // Count Info Bar
          if (!_loading) ...[
            const SizedBox(height: 6),
            Text(
              'Showing ${_history.length} of $_totalElements ${_totalElements == 1 ? "record" : "records"}',
              style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return ListView(
      padding: const EdgeInsets.all(32),
      children: [
        const SizedBox(height: 48),
        Icon(
          _hasActiveFilters ? Icons.filter_alt_off_rounded : Icons.history_toggle_off_rounded,
          size: 64,
          color: const Color(0xFF94A3B8).withValues(alpha: 0.4),
        ),
        const SizedBox(height: 16),
        Text(
          _hasActiveFilters ? 'No Matching Tokens Found' : 'No Completed Token History',
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Color(0xFF0F172A),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          _hasActiveFilters
              ? 'Try modifying your search query, provider selection, status, or date range.'
              : 'Tokens called, served, and completed by your providers will be archived here.',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 14, color: Color(0xFF475569), height: 1.4),
        ),
        if (_hasActiveFilters) ...[
          const SizedBox(height: 20),
          Center(
            child: OutlinedButton.icon(
              onPressed: _resetAllFilters,
              icon: const Icon(Icons.clear_all_rounded, size: 18),
              label: const Text('Reset All Filters'),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF4F46E5),
                side: const BorderSide(color: Color(0xFF4F46E5)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildTokenCard(dynamic item) {
    final tokenNumber = item['tokenNumber'] ?? '---';
    final status = (item['status'] ?? 'COMPLETED').toString().toUpperCase();
    final customerName = item['customerName'] ?? 'Customer';
    final customerPhone = item['customerPhone'] ?? '';
    final isPriority = item['priority'] == true;
    final taskDescription = item['taskDescription'] ?? item['reason'] ?? '';
    final createdAt = item['createdAt'] ?? item['bookedAt'];
    final calledAt = item['calledAt'] ?? item['servingStartedAt'];
    final completedAt = item['completedAt'];
    final serviceDurationMinutes = item['serviceDurationMinutes'];
    final serviceDurationSeconds = item['serviceDurationSeconds'];
    final providerName = item['providerName'];
    final providerSpecialization = item['providerSpecialization'];
    final isCompleted = status == 'COMPLETED';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Row: Token # + Customer Info + Status Badge
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: isPriority ? const Color(0xFFFEE2E2) : const Color(0xFFEEF2FF),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isPriority ? const Color(0xFFFCA5A5) : const Color(0xFFC7D2FE),
                  ),
                ),
                child: Column(
                  children: [
                    Text(
                      tokenNumber,
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                        color: isPriority ? const Color(0xFFDC2626) : const Color(0xFF4338CA),
                      ),
                    ),
                    if (isPriority) ...[
                      const SizedBox(height: 2),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(
                          color: const Color(0xFFDC2626),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'PRIORITY',
                          style: TextStyle(
                            fontSize: 8,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      customerName,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0F172A),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (customerPhone.toString().trim().isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          const Icon(Icons.phone_rounded, size: 12, color: Color(0xFF64748B)),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              customerPhone.toString(),
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFF475569),
                                fontWeight: FontWeight.w500,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        const Icon(Icons.calendar_today_rounded, size: 12, color: Color(0xFF94A3B8)),
                        const SizedBox(width: 4),
                        Text(
                          _formatDate(createdAt),
                          style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _buildStatusBadge(status),
            ],
          ),

          // Provider Attribution Badge
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: providerName != null ? const Color(0xFFF5F3FF) : const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: providerName != null ? const Color(0xFFDDD6FE) : const Color(0xFFE2E8F0),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  providerName != null ? Icons.person_rounded : Icons.desktop_windows_rounded,
                  size: 15,
                  color: providerName != null ? const Color(0xFF7C3AED) : const Color(0xFF475569),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    providerName != null
                        ? 'Served by $providerName${(providerSpecialization != null && providerSpecialization.toString().isNotEmpty) ? " ($providerSpecialization)" : ""}'
                        : 'Served at Front Desk Counter',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: providerName != null ? const Color(0xFF6D28D9) : const Color(0xFF334155),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),

          // Task description / service requested
          if (taskDescription.toString().trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.notes_rounded, size: 14, color: Color(0xFF94A3B8)),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      taskDescription.toString().trim(),
                      style: const TextStyle(fontSize: 12, color: Color(0xFF475569)),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Timestamps & Service Duration
          if (isCompleted || calledAt != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildTimeColumn(
                        label: 'Serving Started',
                        time: _formatTime(calledAt),
                        icon: Icons.play_arrow_rounded,
                        iconColor: const Color(0xFF3B82F6),
                      ),
                      Container(
                        width: 1,
                        height: 30,
                        color: const Color(0xFFCBD5E1),
                      ),
                      const SizedBox(width: 8),
                      _buildTimeColumn(
                        label: 'Completed At',
                        time: _formatTime(completedAt),
                        icon: Icons.check_circle_outline_rounded,
                        iconColor: const Color(0xFF10B981),
                      ),
                    ],
                  ),
                  if (serviceDurationMinutes != null || serviceDurationSeconds != null) ...[
                    const SizedBox(height: 10),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFECFDF5),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFA7F3D0)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.timer_outlined,
                            size: 16,
                            color: Color(0xFF059669),
                          ),
                          const SizedBox(width: 6),
                          const Text(
                            'Total Service Time: ',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                          Flexible(
                            child: Text(
                              _formatTotalServiceTime(serviceDurationMinutes, serviceDurationSeconds),
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF059669),
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTimeColumn({
    required String label,
    required String time,
    required IconData icon,
    required Color iconColor,
  }) {
    return Expanded(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: iconColor),
          const SizedBox(width: 8),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF64748B),
                    fontWeight: FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  time,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0F172A),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(dynamic timestamp) {
    if (timestamp == null) return '--';
    try {
      final str = timestamp.toString();
      return str.split('T').first;
    } catch (_) {
      return '--';
    }
  }

  String _formatTime(dynamic timestamp) {
    if (timestamp == null) return '--:--';
    try {
      final dt = timestamp is DateTime ? timestamp : DateTime.parse(timestamp.toString());
      final hour = dt.hour;
      final minute = dt.minute.toString().padLeft(2, '0');
      final period = hour >= 12 ? 'PM' : 'AM';
      final formattedHour = hour % 12 == 0 ? 12 : hour % 12;
      return '$formattedHour:$minute $period';
    } catch (_) {
      return timestamp.toString();
    }
  }

  String _formatTotalServiceTime(dynamic minutes, dynamic seconds) {
    if (minutes != null) {
      final m = int.tryParse(minutes.toString()) ?? 0;
      if (m > 0) {
        return '$m ${m == 1 ? "minute" : "minutes"}';
      }
    }
    if (seconds != null) {
      final totalSec = int.tryParse(seconds.toString()) ?? 0;
      if (totalSec >= 60) {
        final m = (totalSec / 60.0).round();
        return '$m ${m == 1 ? "minute" : "minutes"}';
      } else if (totalSec > 0) {
        return '$totalSec seconds';
      }
    }
    if (minutes != null && minutes.toString() == '0') {
      return 'Less than 1 minute';
    }
    return '--';
  }

  Widget _buildStatusBadge(String status) {
    Color bg;
    Color fg;
    switch (status) {
      case 'COMPLETED':
        bg = const Color(0xFFECFDF5);
        fg = const Color(0xFF059669);
        break;
      case 'CANCELLED':
        bg = const Color(0xFFFEF2F2);
        fg = const Color(0xFFDC2626);
        break;
      case 'SKIPPED':
        bg = const Color(0xFFFFFBEB);
        fg = const Color(0xFFD97706);
        break;
      case 'SERVING':
      case 'CALLED':
        bg = const Color(0xFFEFF6FF);
        fg = const Color(0xFF2563EB);
        break;
      default:
        bg = const Color(0xFFEEF2FF);
        fg = const Color(0xFF4F46E5);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        status,
        style: TextStyle(color: fg, fontSize: 11, fontWeight: FontWeight.w700),
      ),
    );
  }
}

import 'dart:async';
import 'package:flutter/material.dart';
import '../../services/office_service.dart';
import '../../theme/app_theme.dart';

class TokenHistoryScreen extends StatefulWidget {
  const TokenHistoryScreen({super.key});

  @override
  State<TokenHistoryScreen> createState() => _TokenHistoryScreenState();
}

class _TokenHistoryScreenState extends State<TokenHistoryScreen> {
  final OfficeService _officeService = OfficeService();
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

  // Filter state
  String _selectedStatus = 'ALL';
  String _selectedDateFilter = 'all'; // all, today, yesterday, 7_days, this_month, custom
  DateTimeRange? _customDateRange;

  final List<Map<String, String>> _statusOptions = [
    {'label': 'All', 'value': 'ALL'},
    {'label': 'Completed', 'value': 'COMPLETED'},
    {'label': 'Waiting', 'value': 'WAITING'},
    {'label': 'Cancelled', 'value': 'CANCELLED'},
    {'label': 'Skipped', 'value': 'SKIPPED'},
  ];

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

    String? startDateStr;
    String? endDateStr;
    if (_selectedDateFilter == 'custom' && _customDateRange != null) {
      startDateStr = _customDateRange!.start.toIso8601String().split('T').first;
      endDateStr = _customDateRange!.end.toIso8601String().split('T').first;
    }

    final res = await _officeService.getMyTokenHistoryPaginated(
      page: pageToLoad,
      size: _pageSize,
      search: _searchController.text.trim().isEmpty ? null : _searchController.text.trim(),
      status: _selectedStatus,
      date: _selectedDateFilter == 'custom' ? null : _selectedDateFilter,
      startDate: startDateStr,
      endDate: endDateStr,
    );

    if (mounted) {
      final List<dynamic> content = (res['content'] as List?) ?? [];
      final total = (res['totalElements'] as num?)?.toInt() ?? content.length;
      final hasMore = res['hasMore'] == true;

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
              primary: AppColors.primary,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: AppColors.mainText,
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
      _selectedStatus = 'ALL';
      _selectedDateFilter = 'all';
      _customDateRange = null;
    });
    _loadHistory(reset: true);
  }

  bool get _hasActiveFilters =>
      _searchController.text.trim().isNotEmpty ||
      _selectedStatus != 'ALL' ||
      _selectedDateFilter != 'all';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        foregroundColor: AppColors.mainText,
        title: const Text(
          'Queue History',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18, color: AppColors.mainText),
        ),
        actions: [
          if (_hasActiveFilters)
            TextButton(
              onPressed: _resetAllFilters,
              child: const Text(
                'Reset',
                style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600, fontSize: 13),
              ),
            ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh',
            onPressed: () => _loadHistory(reset: true),
          ),
        ],
      ),
      body: Column(
        children: [
          _buildFilterHeader(),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                : RefreshIndicator(
                    onRefresh: () => _loadHistory(reset: true),
                    color: AppColors.primary,
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
                                        color: AppColors.primary,
                                      ),
                                    ),
                                  ),
                                );
                              }
                              final item = _history[index];
                              return _buildHistoryCard(item);
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
          // Search Input
          Container(
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
                hintText: 'Search token, office, or service...',
                hintStyle: const TextStyle(fontSize: 13, color: AppColors.mutedText),
                prefixIcon: const Icon(Icons.search_rounded, size: 20, color: AppColors.mutedText),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.close_rounded, size: 18, color: AppColors.mutedText),
                        onPressed: () {
                          _searchController.clear();
                          _loadHistory(reset: true);
                        },
                      )
                    : null,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
              style: const TextStyle(fontSize: 14, color: AppColors.mainText),
            ),
          ),
          const SizedBox(height: 10),

          // Horizontal Status Chips Row
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
                      color: isSelected ? Colors.white : AppColors.secondaryText,
                    ),
                    selected: isSelected,
                    selectedColor: AppColors.primary,
                    backgroundColor: const Color(0xFFF1F5F9),
                    side: BorderSide(
                      color: isSelected ? AppColors.primary : const Color(0xFFE2E8F0),
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
                const Icon(Icons.calendar_today_rounded, size: 14, color: AppColors.mutedText),
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
                          color: isSelected ? AppColors.primarySoft : Colors.transparent,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isSelected ? AppColors.primary : const Color(0xFFE2E8F0),
                            width: 1,
                          ),
                        ),
                        child: Text(
                          label,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                            color: isSelected ? AppColors.primaryDark : AppColors.secondaryText,
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),

          // Count info bar
          if (!_loading) ...[
            const SizedBox(height: 6),
            Text(
              'Showing ${_history.length} of $_totalElements ${_totalElements == 1 ? "token" : "tokens"}',
              style: const TextStyle(fontSize: 11, color: AppColors.mutedText),
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
          color: AppColors.mutedText.withValues(alpha: 0.4),
        ),
        const SizedBox(height: 16),
        Text(
          _hasActiveFilters ? 'No Matching Tokens Found' : 'No Queue History',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.mainText),
        ),
        const SizedBox(height: 8),
        Text(
          _hasActiveFilters
              ? 'Try modifying your search query, status, or date range filter.'
              : 'When you book tokens and complete your visits, your history will be recorded here.',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 14, color: AppColors.secondaryText, height: 1.4),
        ),
        if (_hasActiveFilters) ...[
          const SizedBox(height: 20),
          Center(
            child: OutlinedButton.icon(
              onPressed: _resetAllFilters,
              icon: const Icon(Icons.clear_all_rounded, size: 18),
              label: const Text('Reset All Filters'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primary,
                side: const BorderSide(color: AppColors.primary),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildHistoryCard(dynamic item) {
    final tokenNumber = item['tokenNumber'] ?? '---';
    final status = (item['status'] ?? 'COMPLETED').toString().toUpperCase();
    final office = item['office'];
    final officeName = item['officeName'] ??
        (office != null && office['user'] != null ? office['user']['name'] : 'Office');
    final category = item['category'] ?? (office != null ? office['category'] ?? 'OFFICE' : 'OFFICE');
    final bookedAt = item['bookedAt'] != null
        ? item['bookedAt'].toString().split('T').first
        : (item['createdAt'] != null ? item['createdAt'].toString().split('T').first : '');
    final isCompleted = status == 'COMPLETED';
    final servingStartedAt = item['servingStartedAt'] ?? item['calledAt'];
    final completedAt = item['completedAt'];
    final serviceDurationMinutes = item['serviceDurationMinutes'];
    final serviceDurationSeconds = item['serviceDurationSeconds'];
    final taskDescription = item['taskDescription'] ?? item['reason'];
    final providerName = item['providerName'] ??
        (item['provider'] != null ? item['provider']['name'] : null);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryDark.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
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
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: AppColors.primarySoft,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  tokenNumber,
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                    color: AppColors.primaryDark,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      officeName,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: AppColors.mainText,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$category • $bookedAt',
                      style: const TextStyle(fontSize: 12, color: AppColors.mutedText),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (providerName != null && providerName.toString().trim().isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          const Icon(Icons.person_pin_rounded, size: 13, color: AppColors.primary),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              'Served by $providerName',
                              style: const TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                                color: AppColors.primaryDark,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _buildStatusBadge(status),
            ],
          ),

          // Task description / service request
          if (taskDescription != null && taskDescription.toString().trim().isNotEmpty) ...[
            const SizedBox(height: 10),
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
                  const Icon(Icons.notes_rounded, size: 14, color: AppColors.mutedText),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      taskDescription.toString().trim(),
                      style: const TextStyle(fontSize: 12, color: AppColors.secondaryText),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ],

          if (isCompleted) ...[
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
                        time: _formatTime(servingStartedAt),
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
                        label: 'Completed',
                        time: _formatTime(completedAt),
                        icon: Icons.check_circle_outline_rounded,
                        iconColor: const Color(0xFF10B981),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.successSoft,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.success.withValues(alpha: 0.2)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.timer_outlined,
                          size: 16,
                          color: AppColors.success,
                        ),
                        const SizedBox(width: 6),
                        const Text(
                          'Total Service Time: ',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.mainText,
                          ),
                        ),
                        Flexible(
                          child: Text(
                            _formatTotalServiceTime(serviceDurationMinutes, serviceDurationSeconds),
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: AppColors.success,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
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
                    color: AppColors.mutedText,
                    fontWeight: FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  time,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.mainText,
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
        bg = AppColors.successSoft;
        fg = AppColors.success;
        break;
      case 'CANCELLED':
        bg = AppColors.errorSoft;
        fg = AppColors.error;
        break;
      case 'SKIPPED':
        bg = AppColors.warningSoft;
        fg = AppColors.warning;
        break;
      case 'SERVING':
      case 'CALLED':
        bg = const Color(0xFFDBEAFE);
        fg = const Color(0xFF1D4ED8);
        break;
      default:
        bg = AppColors.primarySoft;
        fg = AppColors.primaryDark;
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

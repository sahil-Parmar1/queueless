import 'dart:async';
import 'package:flutter/material.dart';
import '../../services/office_service.dart';
import '../../services/provider_status_websocket_service.dart';
import '../../theme/app_theme.dart';
import '../office_details/office_details_screen.dart';

class OfficeSearchScreen extends StatefulWidget {
  final String? initialQuery;
  final String? initialCategory;

  const OfficeSearchScreen({
    super.key,
    this.initialQuery,
    this.initialCategory,
  });

  @override
  State<OfficeSearchScreen> createState() => _OfficeSearchScreenState();
}

class _OfficeSearchScreenState extends State<OfficeSearchScreen> {
  final OfficeService _officeService = OfficeService();
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounceTimer;
  ProviderStatusWebSocketService? _webSocketService;

  bool _loading = true;
  List<dynamic> _offices = [];
  String _selectedCategory = 'ALL';

  final List<Map<String, String>> _categories = [
    {'key': 'ALL', 'label': 'All Places'},
    {'key': 'CLINIC', 'label': 'Clinics & Doctors'},
    {'key': 'SALON', 'label': 'Salons & Spas'},
    {'key': 'BANK', 'label': 'Banks'},
    {'key': 'OTHER', 'label': 'Offices & Gov'},
  ];

  @override
  void initState() {
    super.initState();
    if (widget.initialQuery != null) {
      _searchController.text = widget.initialQuery!;
    }
    if (widget.initialCategory != null) {
      _selectedCategory = widget.initialCategory!;
    }
    _loadOffices();
    _initWebSocket();
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.dispose();
    _webSocketService?.dispose();
    super.dispose();
  }

  void _initWebSocket() {
    _webSocketService = ProviderStatusWebSocketService(
      onStatusChange: (data) {
        if (!mounted) return;
        if (data['event'] == 'OFFICE_STATUS_CHANGED') {
          final dynamic oId = data['officeId'];
          final bool isOpen = data['isOpen'] == true;
          setState(() {
            for (var office in _offices) {
              if (office is Map && office['id'] == oId) {
                office['isOpen'] = isOpen;
              }
            }
          });
        }
      },
    );
    _webSocketService?.connect();
  }

  void _onSearchChanged(String value) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 400), () {
      _loadOffices();
    });
  }

  Future<void> _loadOffices() async {
    setState(() => _loading = true);

    final results = await _officeService.searchOffices(
      query: _searchController.text.trim(),
      category: _selectedCategory,
    );

    if (mounted) {
      setState(() {
        _offices = results;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        foregroundColor: AppColors.mainText,
        title: const Text(
          'Find Offices & Queues',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18, color: AppColors.mainText),
        ),
      ),
      body: Column(
        children: [
          // Search Box & Category Filters
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Column(
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: TextField(
                    controller: _searchController,
                    onChanged: _onSearchChanged,
                    textInputAction: TextInputAction.search,
                    onSubmitted: (_) => _loadOffices(),
                    decoration: InputDecoration(
                      hintText: 'Search by clinic, doctor, salon, city...',
                      hintStyle: const TextStyle(color: AppColors.mutedText, fontSize: 14),
                      prefixIcon: const Icon(Icons.search_rounded, color: AppColors.primary),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear_rounded, size: 20, color: AppColors.mutedText),
                              onPressed: () {
                                _searchController.clear();
                                _loadOffices();
                              },
                            )
                          : null,
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Category Chips
                SizedBox(
                  height: 38,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _categories.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 8),
                    itemBuilder: (context, index) {
                      final cat = _categories[index];
                      final isSelected = _selectedCategory == cat['key'];
                      return ChoiceChip(
                        label: Text(cat['label']!),
                        selected: isSelected,
                        onSelected: (selected) {
                          if (selected) {
                            setState(() => _selectedCategory = cat['key']!);
                            _loadOffices();
                          }
                        },
                        selectedColor: AppColors.primary,
                        backgroundColor: Colors.white,
                        labelStyle: TextStyle(
                          color: isSelected ? Colors.white : AppColors.secondaryText,
                          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                          fontSize: 13,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                          side: BorderSide(
                            color: isSelected ? AppColors.primary : AppColors.border,
                            width: 1,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),

          // Search Results
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                : RefreshIndicator(
                    onRefresh: _loadOffices,
                    color: AppColors.primary,
                    child: _offices.isEmpty
                        ? _buildEmptyState()
                        : ListView.separated(
                            padding: const EdgeInsets.all(16),
                            itemCount: _offices.length,
                            separatorBuilder: (_, _) => const SizedBox(height: 12),
                            itemBuilder: (context, index) {
                              final office = _offices[index];
                              return _buildOfficeCard(office);
                            },
                          ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return ListView(
      padding: const EdgeInsets.all(32),
      children: [
        const SizedBox(height: 40),
        Icon(Icons.search_off_rounded, size: 64, color: AppColors.mutedText.withValues(alpha: 0.4)),
        const SizedBox(height: 16),
        const Text(
          'No Places Found',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.mainText),
        ),
        const SizedBox(height: 8),
        const Text(
          'We couldn\'t find any registered offices matching your search. Try adjusting the category or search keywords.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 14, color: AppColors.secondaryText, height: 1.4),
        ),
      ],
    );
  }

  Widget _buildOfficeCard(dynamic office) {
    final name = office['name'] ?? 'Office';
    final category = office['category'] ?? 'OTHER';
    final address = office['address'] ?? '';
    final city = office['city'] ?? '';
    final doctorName = office['doctorName'];
    final specialization = office['specialization'];
    final salonType = office['salonType'];
    final openingTime = office['openingTime'] ?? '09:00 AM';
    final closingTime = office['closingTime'] ?? '08:00 PM';
    final waitingCount = office['waitingCount'] ?? 0;
    final activeToken = office['activeToken'];
    final bool isOpen = office['isOpen'] != false;

    String subInfo = '';
    if (doctorName != null && doctorName.toString().isNotEmpty) {
      subInfo = '👨‍⚕️ $doctorName ${specialization != null ? '($specialization)' : ''}';
    } else if (salonType != null && salonType.toString().isNotEmpty) {
      subInfo = '✂️ $salonType Salon';
    } else if (specialization != null && specialization.toString().isNotEmpty) {
      subInfo = specialization;
    }

    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => OfficeDetailsScreen(officeId: office['id']),
          ),
        ).then((_) => _loadOffices());
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
          boxShadow: [
            BoxShadow(
              color: AppColors.primaryDark.withValues(alpha: 0.04),
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
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _getCategoryColor(category).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(_getCategoryIcon(category), color: _getCategoryColor(category), size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              name,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: AppColors.mainText,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: isOpen ? AppColors.successSoft : AppColors.errorSoft,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: isOpen
                                    ? AppColors.success.withValues(alpha: 0.3)
                                    : AppColors.error.withValues(alpha: 0.3),
                                width: 0.8,
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
                                    color: isOpen ? AppColors.success : AppColors.error,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  isOpen ? 'Open' : 'Closed',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: isOpen ? AppColors.success : AppColors.error,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      if (subInfo.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          subInfo,
                          style: const TextStyle(fontSize: 13, color: AppColors.primaryDark, fontWeight: FontWeight.w600),
                        ),
                      ],
                      const SizedBox(height: 4),
                      Text(
                        [address, city].where((e) => e.toString().isNotEmpty).join(', '),
                        style: const TextStyle(fontSize: 12, color: AppColors.mutedText),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(height: 1, color: AppColors.borderLight),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.access_time_rounded, size: 14, color: AppColors.mutedText),
                    const SizedBox(width: 4),
                    Text(
                      '$openingTime - $closingTime',
                      style: const TextStyle(fontSize: 12, color: AppColors.secondaryText),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: isOpen ? AppColors.primarySoft : AppColors.errorSoft,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isOpen
                          ? AppColors.primaryLight.withValues(alpha: 0.4)
                          : AppColors.error.withValues(alpha: 0.3),
                      width: 0.8,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isOpen ? Icons.people_alt_rounded : Icons.lock_clock_rounded,
                        size: 13,
                        color: isOpen ? AppColors.primaryDark : AppColors.error,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        isOpen
                            ? '$waitingCount waiting ${activeToken != null ? "• Now #$activeToken" : ""}'
                            : 'Queue Closed',
                        style: TextStyle(
                          fontSize: 12,
                          color: isOpen ? AppColors.primaryDark : AppColors.error,
                          fontWeight: FontWeight.w700,
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
    );
  }

  Color _getCategoryColor(String category) {
    switch (category) {
      case 'CLINIC':
        return AppColors.primary;
      case 'SALON':
        return AppColors.cyanDark;
      case 'BANK':
        return AppColors.primaryDark;
      case 'RESTAURANT':
        return const Color(0xFFEA580C);
      default:
        return AppColors.primary;
    }
  }

  IconData _getCategoryIcon(String category) {
    switch (category) {
      case 'CLINIC':
        return Icons.medical_services_rounded;
      case 'SALON':
        return Icons.content_cut_rounded;
      case 'BANK':
        return Icons.account_balance_rounded;
      case 'RESTAURANT':
        return Icons.restaurant_rounded;
      default:
        return Icons.business_rounded;
    }
  }
}

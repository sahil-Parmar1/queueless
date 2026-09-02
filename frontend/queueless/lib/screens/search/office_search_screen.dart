import 'dart:async';
import 'package:flutter/material.dart';
import '../../services/office_service.dart';
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
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.dispose();
    super.dispose();
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
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        foregroundColor: const Color(0xFF0F172A),
        title: const Text(
          'Find Offices & Queues',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
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
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: TextField(
                    controller: _searchController,
                    onChanged: _onSearchChanged,
                    textInputAction: TextInputAction.search,
                    onSubmitted: (_) => _loadOffices(),
                    decoration: InputDecoration(
                      hintText: 'Search by clinic, doctor, salon, city...',
                      hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 14),
                      prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF64748B)),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear_rounded, size: 20, color: Color(0xFF94A3B8)),
                              onPressed: () {
                                _searchController.clear();
                                _loadOffices();
                              },
                            )
                          : null,
                      border: InputBorder.none,
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
                        selectedColor: const Color(0xFF4F46E5),
                        backgroundColor: const Color(0xFFF1F5F9),
                        labelStyle: TextStyle(
                          color: isSelected ? Colors.white : const Color(0xFF475569),
                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                          fontSize: 13,
                        ),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        side: BorderSide.none,
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
                ? const Center(child: CircularProgressIndicator(color: Color(0xFF4F46E5)))
                : RefreshIndicator(
                    onRefresh: _loadOffices,
                    color: const Color(0xFF4F46E5),
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
        Icon(Icons.search_off_rounded, size: 64, color: Colors.grey.shade400),
        const SizedBox(height: 16),
        const Text(
          'No Places Found',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
        ),
        const SizedBox(height: 8),
        const Text(
          'We couldn\'t find any registered offices matching your search. Try adjusting the category or search keywords.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 14, color: Color(0xFF64748B), height: 1.4),
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
        );
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE2E8F0)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
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
                                color: Color(0xFF0F172A),
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFFECFDF5),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              'Open',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF059669),
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (subInfo.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          subInfo,
                          style: const TextStyle(fontSize: 13, color: Color(0xFF475569), fontWeight: FontWeight.w500),
                        ),
                      ],
                      const SizedBox(height: 4),
                      Text(
                        [address, city].where((e) => e.toString().isNotEmpty).join(', '),
                        style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(height: 1, color: Color(0xFFF1F5F9)),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.access_time_rounded, size: 14, color: Color(0xFF64748B)),
                    const SizedBox(width: 4),
                    Text(
                      '$openingTime - $closingTime',
                      style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEEF2FF),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.people_alt_rounded, size: 13, color: Color(0xFF4F46E5)),
                      const SizedBox(width: 4),
                      Text(
                        '$waitingCount waiting ${activeToken != null ? "• Now #$activeToken" : ""}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF4F46E5),
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
        return const Color(0xFF0284C7);
      case 'SALON':
        return const Color(0xFFD946EF);
      case 'BANK':
        return const Color(0xFF059669);
      case 'RESTAURANT':
        return const Color(0xFFEA580C);
      default:
        return const Color(0xFF4F46E5);
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

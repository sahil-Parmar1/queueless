import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../../services/location_service.dart';
import '../../services/office_service.dart';
import '../../services/provider_status_websocket_service.dart';
import '../../theme/app_theme.dart';
import '../auth/customer_login_screen.dart';
import '../map/nearby_offices_map_screen.dart';
import '../office_details/office_details_screen.dart';

class OfficeSearchScreen extends StatefulWidget {
  final String? initialQuery;
  final String? initialCategory;
  final bool initialFilterNearest;

  const OfficeSearchScreen({
    super.key,
    this.initialQuery,
    this.initialCategory,
    this.initialFilterNearest = false,
  });

  @override
  State<OfficeSearchScreen> createState() => _OfficeSearchScreenState();
}

class _OfficeSearchScreenState extends State<OfficeSearchScreen> {
  final OfficeService _officeService = OfficeService();
  final LocationService _locationService = LocationService();
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounceTimer;
  ProviderStatusWebSocketService? _webSocketService;

  bool _loading = true;
  bool _locating = false;
  bool _filterNearest = false;
  bool _filterFavorites = false;
  Position? _userPosition;
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
    _filterNearest = widget.initialFilterNearest;
    _initData();
    _initWebSocket();
  }

  Future<void> _initData() async {
    _officeService.getFavoriteOfficeIds();
    if (_filterNearest) {
      _userPosition = await _locationService.getCurrentLocation(requestPermission: true);
    } else {
      _userPosition = _locationService.lastKnownPosition;
    }
    _loadOffices();
  }

  void _toggleFavoritesFilter() {
    setState(() {
      _filterFavorites = !_filterFavorites;
    });
    _loadOffices();
  }

  Future<void> _handleToggleFavorite(int officeId) async {
    final res = await _officeService.toggleFavoriteOffice(officeId);
    if (!mounted) return;
    if (res['isAuthError'] == true) {
      _showSignInDialog();
      return;
    }
    if (res['success'] == true) {
      final isFav = res['isFavorite'] == true;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(
                isFav ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                color: isFav ? const Color(0xFFEF4444) : Colors.white,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(isFav ? 'Added to favorites' : 'Removed from favorites'),
            ],
          ),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
      if (_filterFavorites && !isFav) {
        setState(() {
          _offices.removeWhere((o) => o['id'] == officeId);
        });
      }
    }
  }

  void _showSignInDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Sign In Required'),
        content: const Text('Please sign in to save and manage your favorite offices.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const CustomerLoginScreen()),
              );
            },
            child: const Text('Sign In'),
          ),
        ],
      ),
    );
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

  Future<void> _toggleNearestFilter() async {
    final nextState = !_filterNearest;
    setState(() {
      _filterNearest = nextState;
      if (nextState) _locating = true;
    });

    if (nextState && _userPosition == null) {
      final pos = await _locationService.getCurrentLocation(requestPermission: true);
      if (mounted) {
        setState(() {
          _userPosition = pos;
          _locating = false;
        });
      }
    } else {
      if (mounted) setState(() => _locating = false);
    }

    _loadOffices();
  }

  Future<void> _loadOffices() async {
    setState(() => _loading = true);

    if (_filterNearest && _userPosition == null) {
      _userPosition = await _locationService.getCurrentLocation(requestPermission: true);
    }

    var results = await _officeService.searchOffices(
      query: _searchController.text.trim(),
      category: _selectedCategory,
    );

    if (_filterFavorites) {
      results = results.where((o) => _officeService.isFavorite(o['id'] as int)).toList();
    }

    if (_userPosition != null) {
      for (var office in results) {
        if (office is Map && office['latitude'] != null && office['longitude'] != null) {
          try {
            final double lat = (office['latitude'] as num).toDouble();
            final double lng = (office['longitude'] as num).toDouble();
            final dist = _locationService.calculateDistance(
              _userPosition!.latitude,
              _userPosition!.longitude,
              lat,
              lng,
            );
            office['distanceMeters'] = dist;
            office['distanceFormatted'] = _locationService.formatDistance(dist);
          } catch (_) {}
        }
      }

      if (_filterNearest) {
        results.sort((a, b) {
          final aDist = a['distanceMeters'] as num? ?? double.infinity;
          final bDist = b['distanceMeters'] as num? ?? double.infinity;
          return aDist.compareTo(bDist);
        });
      }
    }

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
        actions: [
          TextButton.icon(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => NearbyOfficesMapScreen(
                    initialOffices: _offices,
                    initialUserPosition: _userPosition,
                    initialCategory: _selectedCategory,
                  ),
                ),
              ).then((_) => _loadOffices());
            },
            icon: const Icon(Icons.map_rounded, size: 18, color: AppColors.primary),
            label: const Text(
              'View on Map',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: AppColors.primary,
              ),
            ),
          ),
          const SizedBox(width: 4),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => NearbyOfficesMapScreen(
                initialOffices: _offices,
                initialUserPosition: _userPosition,
                initialCategory: _selectedCategory,
              ),
            ),
          ).then((_) => _loadOffices());
        },
        backgroundColor: const Color(0xFF0F172A),
        foregroundColor: Colors.white,
        elevation: 4,
        icon: const Icon(Icons.map_rounded, size: 20, color: Colors.amberAccent),
        label: const Text(
          'View on Map',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
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

                // Filter & Category Chips
                SizedBox(
                  height: 38,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      // Nearest Filter Chip
                      FilterChip(
                        avatar: _locating
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : Icon(
                                Icons.near_me_rounded,
                                size: 15,
                                color: _filterNearest ? Colors.white : AppColors.primary,
                              ),
                        label: Text(_filterNearest ? 'Nearest Offices' : 'Nearest Offices'),
                        selected: _filterNearest,
                        onSelected: (_) => _toggleNearestFilter(),
                        selectedColor: const Color(0xFF0F172A),
                        backgroundColor: const Color(0xFFEEF2FF),
                        elevation: _filterNearest ? 2 : 0,
                        labelStyle: TextStyle(
                          color: _filterNearest ? Colors.white : AppColors.primary,
                          fontWeight: FontWeight.w700,
                          fontSize: 12.5,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                          side: BorderSide(
                            color: _filterNearest
                                ? const Color(0xFF0F172A)
                                : AppColors.primary.withValues(alpha: 0.3),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),

                      // Favorites Filter Chip
                      FilterChip(
                        avatar: Icon(
                          _filterFavorites ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                          size: 15,
                          color: _filterFavorites ? Colors.white : const Color(0xFFEF4444),
                        ),
                        label: const Text('Favorites'),
                        selected: _filterFavorites,
                        onSelected: (_) => _toggleFavoritesFilter(),
                        selectedColor: const Color(0xFFEF4444),
                        backgroundColor: const Color(0xFFFEF2F2),
                        elevation: _filterFavorites ? 2 : 0,
                        labelStyle: TextStyle(
                          color: _filterFavorites ? Colors.white : const Color(0xFFEF4444),
                          fontWeight: FontWeight.w700,
                          fontSize: 12.5,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                          side: BorderSide(
                            color: _filterFavorites
                                ? const Color(0xFFEF4444)
                                : const Color(0xFFEF4444).withValues(alpha: 0.3),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),

                      // Category Chips
                      ..._categories.map((cat) {
                        final isSelected = _selectedCategory == cat['key'];
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
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
                              fontSize: 12.5,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                              side: BorderSide(
                                color: isSelected ? AppColors.primary : AppColors.border,
                                width: 1,
                              ),
                            ),
                          ),
                        );
                      }),
                    ],
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
    if (_filterFavorites) {
      return ListView(
        padding: const EdgeInsets.all(32),
        children: [
          const SizedBox(height: 40),
          Icon(Icons.favorite_border_rounded, size: 64, color: const Color(0xFFEF4444).withValues(alpha: 0.4)),
          const SizedBox(height: 16),
          const Text(
            'No Favorite Places Yet',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.mainText),
          ),
          const SizedBox(height: 8),
          const Text(
            'You haven\'t added any places to your favorites. Tap the heart icon on any office to save it here for quick access.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: AppColors.secondaryText, height: 1.4),
          ),
        ],
      );
    }

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
    final category = (office['category'] ?? 'OTHER').toString().toUpperCase();
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
    if (category == 'CLINIC' && doctorName != null && doctorName.toString().isNotEmpty) {
      subInfo = '👨‍⚕️ $doctorName ${specialization != null ? '($specialization)' : ''}';
    } else if (salonType != null && salonType.toString().isNotEmpty) {
      subInfo = '✂️ $salonType Salon';
    } else if (category == 'SALON') {
      subInfo = '✂️ Salon';
    } else if (category == 'CLINIC' && specialization != null && specialization.toString().isNotEmpty) {
      subInfo = '👨‍⚕️ $specialization';
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
                          const SizedBox(width: 8),
                          ValueListenableBuilder<Set<int>>(
                            valueListenable: _officeService.favoriteIdsNotifier,
                            builder: (context, favIds, _) {
                              final dynamic rawId = office['id'];
                              final officeId = rawId is int ? rawId : int.tryParse(rawId?.toString() ?? '');
                              final isFav = officeId != null && favIds.contains(officeId);
                              return GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onTap: () {
                                  if (officeId != null) {
                                    _handleToggleFavorite(officeId);
                                  }
                                },
                                child: Padding(
                                  padding: const EdgeInsets.all(4.0),
                                  child: Icon(
                                    isFav ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                                    color: isFav ? const Color(0xFFEF4444) : AppColors.mutedText,
                                    size: 22,
                                  ),
                                ),
                              );
                            },
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
                      if (office['distanceFormatted'] != null) ...[
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                              decoration: BoxDecoration(
                                color: const Color(0xFFEEF2FF),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.near_me_rounded, size: 11, color: AppColors.primary),
                                  const SizedBox(width: 4),
                                  Text(
                                    '${office['distanceFormatted']} away',
                                    style: const TextStyle(
                                      color: AppColors.primary,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (office['latitude'] != null && office['longitude'] != null) ...[
                              const SizedBox(width: 8),
                              const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.pin_drop_rounded, size: 12, color: Color(0xFF10B981)),
                                  SizedBox(width: 2),
                                  Text(
                                    'On Map',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Color(0xFF10B981),
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ],
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

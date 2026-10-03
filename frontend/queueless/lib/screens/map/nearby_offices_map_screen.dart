import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart' hide Path;
import '../../services/location_service.dart';
import '../../services/office_service.dart';
import '../../theme/app_theme.dart';
import '../office_details/office_details_screen.dart';

class NearbyOfficesMapScreen extends StatefulWidget {
  final List<dynamic>? initialOffices;
  final Position? initialUserPosition;
  final String? initialCategory;

  const NearbyOfficesMapScreen({
    super.key,
    this.initialOffices,
    this.initialUserPosition,
    this.initialCategory,
  });

  @override
  State<NearbyOfficesMapScreen> createState() => _NearbyOfficesMapScreenState();
}

class _NearbyOfficesMapScreenState extends State<NearbyOfficesMapScreen> {
  final OfficeService _officeService = OfficeService();
  final LocationService _locationService = LocationService();
  final MapController _mapController = MapController();

  bool _loading = true;
  bool _locating = false;
  Position? _userPosition;
  List<dynamic> _offices = [];
  String _selectedCategory = 'ALL';
  dynamic _selectedOffice;
  double _currentZoom = 14.0;
  double _visibleRadiusMeters = 0.0;
  int _officesInRadiusCount = 0;

  final List<Map<String, String>> _categories = [
    {'key': 'ALL', 'label': 'All Places'},
    {'key': 'CLINIC', 'label': 'Clinics'},
    {'key': 'SALON', 'label': 'Salons'},
    {'key': 'BANK', 'label': 'Banks'},
    {'key': 'OTHER', 'label': 'Offices'},
  ];

  @override
  void initState() {
    super.initState();
    if (widget.initialCategory != null) {
      _selectedCategory = widget.initialCategory!;
    }
    _userPosition = widget.initialUserPosition ?? _locationService.lastKnownPosition;
    _initMapData();
  }

  Future<void> _initMapData() async {
    setState(() => _loading = true);

    // 1. Get user GPS location if not yet fetched
    _userPosition ??= await _locationService.getCurrentLocation(requestPermission: true);

    // 2. Load offices if not supplied or load fresh
    if (widget.initialOffices != null && widget.initialOffices!.isNotEmpty) {
      _processOffices(widget.initialOffices!);
    } else {
      await _fetchOffices();
    }

    if (mounted) {
      setState(() => _loading = false);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _fitAllOffices();
      });
    }
  }

  Future<void> _fetchOffices() async {
    final list = await _officeService.searchOffices(
      category: _selectedCategory,
    );
    if (mounted) {
      _processOffices(list);
    }
  }

  void _processOffices(List<dynamic> rawList) {
    final list = List<dynamic>.from(rawList);
    if (_userPosition != null) {
      for (var o in list) {
        if (o is Map && o['latitude'] != null && o['longitude'] != null) {
          try {
            final double lat = (o['latitude'] as num).toDouble();
            final double lng = (o['longitude'] as num).toDouble();
            final distanceMeters = _locationService.calculateDistance(
              _userPosition!.latitude,
              _userPosition!.longitude,
              lat,
              lng,
            );
            o['distanceMeters'] = distanceMeters;
            o['distanceFormatted'] = _locationService.formatDistance(distanceMeters);
          } catch (_) {}
        }
      }
      // Sort by distance
      list.sort((a, b) {
        final aDist = a['distanceMeters'] as num? ?? double.infinity;
        final bDist = b['distanceMeters'] as num? ?? double.infinity;
        return aDist.compareTo(bDist);
      });
    }

    setState(() {
      _offices = list;
      if (_selectedOffice != null) {
        final exists = _offices.firstWhere(
          (o) => o['id'] == _selectedOffice['id'],
          orElse: () => null,
        );
        _selectedOffice = exists;
      }
    });
  }

  /// Fits camera to show all registered offices on the map
  void _fitAllOffices() {
    final officesWithCoords = _offices
        .where((o) => o['latitude'] != null && o['longitude'] != null)
        .toList();

    if (officesWithCoords.isNotEmpty) {
      final points = officesWithCoords.map((o) {
        final double lat = (o['latitude'] as num).toDouble();
        final double lng = (o['longitude'] as num).toDouble();
        return LatLng(lat, lng);
      }).toList();

      if (points.length == 1) {
        _mapController.move(points.first, 15.0);
        _currentZoom = 15.0;
        return;
      }

      final bounds = LatLngBounds.fromPoints(points);
      _mapController.fitCamera(
        CameraFit.bounds(
          bounds: bounds,
          padding: const EdgeInsets.fromLTRB(50, 160, 50, 200),
          maxZoom: 16.0,
        ),
      );
      return;
    }

    if (_userPosition != null) {
      _mapController.move(LatLng(_userPosition!.latitude, _userPosition!.longitude), 14.5);
      _currentZoom = 14.5;
    } else {
      _mapController.move(const LatLng(20.5937, 78.9629), 5.0);
      _currentZoom = 5.0;
    }
  }

  Future<void> _recenterOnUser() async {
    setState(() => _locating = true);
    final pos = await _locationService.getCurrentLocation(requestPermission: true);
    if (mounted) {
      setState(() {
        _userPosition = pos;
        _locating = false;
      });
      if (pos != null) {
        _mapController.move(LatLng(pos.latitude, pos.longitude), 15.5);
        _currentZoom = 15.5;
        _processOffices(_offices);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.location_off_rounded, color: Colors.white, size: 18),
                SizedBox(width: 8),
                Expanded(child: Text('Could not access current GPS location.')),
              ],
            ),
            backgroundColor: Color(0xFFEF4444),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _onCategorySelected(String catKey) {
    setState(() {
      _selectedCategory = catKey;
      _selectedOffice = null;
    });
    _fetchOffices().then((_) {
      _fitAllOffices();
    });
  }

  void _onCameraPositionChanged(MapCamera camera) {
    _currentZoom = camera.zoom;
    final visibleRadius = _locationService.calculateDistance(
      camera.center.latitude,
      camera.center.longitude,
      camera.visibleBounds.northEast.latitude,
      camera.visibleBounds.northEast.longitude,
    );

    final officesWithCoords = _offices
        .where((o) => o['latitude'] != null && o['longitude'] != null)
        .toList();

    final count = officesWithCoords.where((o) {
      final lat = (o['latitude'] as num).toDouble();
      final lng = (o['longitude'] as num).toDouble();
      return camera.visibleBounds.contains(LatLng(lat, lng));
    }).length;

    setState(() {
      _visibleRadiusMeters = visibleRadius;
      _officesInRadiusCount = count;
    });
  }

  Color _getCategoryColor(String category) {
    switch (category.toUpperCase()) {
      case 'CLINIC':
        return const Color(0xFF0284C7); // Sky/Blue
      case 'SALON':
        return const Color(0xFFD946EF); // Fuchsia/Purple
      case 'BANK':
        return const Color(0xFF059669); // Emerald
      case 'OTHER':
      default:
        return const Color(0xFF4F46E5); // Indigo
    }
  }

  IconData _getCategoryIcon(String category) {
    switch (category.toUpperCase()) {
      case 'CLINIC':
        return Icons.local_hospital_rounded;
      case 'SALON':
        return Icons.content_cut_rounded;
      case 'BANK':
        return Icons.account_balance_rounded;
      case 'OTHER':
      default:
        return Icons.storefront_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final officesWithCoords = _offices.where((o) =>
        o['latitude'] != null && o['longitude'] != null).toList();

    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // 1. OpenStreetMap Layer
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _userPosition != null
                  ? LatLng(_userPosition!.latitude, _userPosition!.longitude)
                  : const LatLng(20.5937, 78.9629),
              initialZoom: _currentZoom,
              minZoom: 3,
              maxZoom: 19,
              onPositionChanged: (camera, hasGesture) => _onCameraPositionChanged(camera),
              onTap: (tapPosition, point) {
                if (_selectedOffice != null) {
                  setState(() => _selectedOffice = null);
                }
              },
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.queueless.app',
              ),

              // Markers Layer
              MarkerLayer(
                markers: [
                  // User Location Marker
                  if (_userPosition != null)
                    Marker(
                      point: LatLng(_userPosition!.latitude, _userPosition!.longitude),
                      width: 50,
                      height: 50,
                      child: _buildUserLocationMarker(),
                    ),

                  // Office Markers
                  ...officesWithCoords.map((office) {
                    final double lat = (office['latitude'] as num).toDouble();
                    final double lng = (office['longitude'] as num).toDouble();
                    final isSelected = _selectedOffice != null &&
                        _selectedOffice['id'] == office['id'];
                    final category = (office['category'] ?? 'OTHER').toString();
                    final color = _getCategoryColor(category);

                    return Marker(
                      point: LatLng(lat, lng),
                      width: isSelected ? 66 : 54,
                      height: isSelected ? 66 : 54,
                      alignment: Alignment.topCenter,
                      child: GestureDetector(
                        onTap: () {
                          setState(() => _selectedOffice = office);
                          _mapController.move(LatLng(lat, lng), math.max(_currentZoom, 15.0));
                        },
                        child: _buildOfficeMarker(office, color, isSelected),
                      ),
                    );
                  }),
                ],
              ),
            ],
          ),

          // 2. Top Header & Category Filters Overlay
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header Row with Back Button, Title, and List Switch
                  Row(
                    children: [
                      _buildGlassButton(
                        icon: Icons.arrow_back_rounded,
                        onTap: () => Navigator.pop(context),
                        tooltip: 'Back to List',
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.95),
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.08),
                                blurRadius: 12,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.explore_rounded, color: AppColors.primary, size: 20),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  '${officesWithCoords.length} Places on Map',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                    color: Color(0xFF0F172A),
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (_loading)
                                const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                                ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      _buildGlassButton(
                        icon: Icons.view_list_rounded,
                        onTap: () => Navigator.pop(context),
                        tooltip: 'Switch to List View',
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Horizontal Category Filter Chips
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
                              _onCategorySelected(cat['key']!);
                            }
                          },
                          selectedColor: AppColors.primary,
                          backgroundColor: Colors.white.withValues(alpha: 0.95),
                          elevation: 2,
                          pressElevation: 4,
                          labelStyle: TextStyle(
                            color: isSelected ? Colors.white : const Color(0xFF334155),
                            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                            fontSize: 12,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                            side: BorderSide(
                              color: isSelected ? AppColors.primary : Colors.transparent,
                            ),
                          ),
                        );
                      },
                    ),
                  ),

                  // Dynamic Visible Radius & Offices in View Indicator Pill
                  if (_visibleRadiusMeters > 0) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F172A).withValues(alpha: 0.88),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.15),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.radar_rounded, size: 14, color: Colors.cyanAccent),
                          const SizedBox(width: 6),
                          Text(
                            'Visible Radius: ~${_locationService.formatDistance(_visibleRadiusMeters)} • $_officesInRadiusCount in view',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),

          // 3. Map Controls (Zoom In/Out, Fit All Offices, My Location)
          Positioned(
            right: 16,
            bottom: _selectedOffice != null ? 240 : 130,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildMapControlBtn(
                  icon: Icons.zoom_out_map_rounded,
                  onTap: _fitAllOffices,
                  tooltip: 'Show All Offices in View',
                  color: const Color(0xFF0F172A),
                ),
                const SizedBox(height: 8),
                _buildMapControlBtn(
                  icon: Icons.my_location_rounded,
                  onTap: _recenterOnUser,
                  tooltip: 'My Location',
                  isLoading: _locating,
                  color: AppColors.primary,
                ),
                const SizedBox(height: 8),
                _buildMapControlBtn(
                  icon: Icons.add_rounded,
                  onTap: () {
                    _currentZoom = (_currentZoom + 1).clamp(3.0, 19.0);
                    _mapController.move(_mapController.camera.center, _currentZoom);
                  },
                  tooltip: 'Zoom In',
                ),
                const SizedBox(height: 6),
                _buildMapControlBtn(
                  icon: Icons.remove_rounded,
                  onTap: () {
                    _currentZoom = (_currentZoom - 1).clamp(3.0, 19.0);
                    _mapController.move(_mapController.camera.center, _currentZoom);
                  },
                  tooltip: 'Zoom Out',
                ),
              ],
            ),
          ),

          // 4. Bottom Section: Selected Office Card OR Horizontal Carousel of All Offices
          Positioned(
            left: 16,
            right: 16,
            bottom: 24,
            child: _selectedOffice != null
                ? _buildOfficeBottomCard(_selectedOffice)
                : _buildBottomOfficeCarousel(officesWithCoords),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomOfficeCarousel(List<dynamic> offices) {
    if (offices.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.95),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: const Row(
          children: [
            Icon(Icons.info_outline_rounded, color: AppColors.primary, size: 20),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'No offices with GPS locations found for this category.',
                style: TextStyle(fontSize: 12, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
      );
    }

    return SizedBox(
      height: 94,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: offices.length,
        separatorBuilder: (_, _) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final office = offices[index];
          final name = office['name'] ?? 'Office';
          final category = (office['category'] ?? 'OTHER').toString().toUpperCase();
          final doctorName = office['doctorName'];
          final salonType = office['salonType'];
          final color = _getCategoryColor(category);
          final distanceFormatted = office['distanceFormatted'] as String?;
          final lat = (office['latitude'] as num).toDouble();
          final lng = (office['longitude'] as num).toDouble();

          String subtitle = category;
          if (doctorName != null && doctorName.toString().isNotEmpty) {
            subtitle = 'Dr. $doctorName';
          } else if (salonType != null) {
            subtitle = '$salonType Salon';
          }

          return InkWell(
            onTap: () {
              setState(() => _selectedOffice = office);
              _mapController.move(LatLng(lat, lng), 16.0);
            },
            borderRadius: BorderRadius.circular(16),
            child: Container(
              width: 230,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2E8F0)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(_getCategoryIcon(category), color: color, size: 20),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          name,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F172A)),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          subtitle,
                          style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 3),
                        Row(
                          children: [
                            if (distanceFormatted != null) ...[
                              const Icon(Icons.near_me_rounded, size: 10, color: AppColors.primary),
                              const SizedBox(width: 2),
                              Text(
                                distanceFormatted,
                                style: const TextStyle(fontSize: 10, color: AppColors.primary, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(width: 6),
                            ],
                            const Text('• Tap to view', style: TextStyle(fontSize: 10, color: Color(0xFF94A3B8))),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildUserLocationMarker() {
    return Stack(
      alignment: Alignment.center,
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: const Color(0xFF3B82F6).withValues(alpha: 0.25),
          ),
        ),
        Container(
          width: 22,
          height: 22,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: const Color(0xFF2563EB),
            border: Border.all(color: Colors.white, width: 3),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.25),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildOfficeMarker(dynamic office, Color color, bool isSelected) {
    final category = (office['category'] ?? 'OTHER').toString();
    final icon = _getCategoryIcon(category);

    return AnimatedScale(
      scale: isSelected ? 1.15 : 1.0,
      duration: const Duration(milliseconds: 200),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: EdgeInsets.all(isSelected ? 9 : 7),
            decoration: BoxDecoration(
              color: isSelected ? const Color(0xFF0F172A) : color,
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white,
                width: isSelected ? 3.0 : 2.0,
              ),
              boxShadow: [
                BoxShadow(
                  color: (isSelected ? Colors.black : color).withValues(alpha: 0.4),
                  blurRadius: isSelected ? 12 : 6,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Icon(icon, color: Colors.white, size: isSelected ? 22 : 18),
          ),
          CustomPaint(
            size: const Size(10, 6),
            painter: _MarkerPointerPainter(
              color: isSelected ? const Color(0xFF0F172A) : color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOfficeBottomCard(dynamic office) {
    final name = office['name'] ?? 'Office';
    final category = (office['category'] ?? 'OTHER').toString().toUpperCase();
    final address = office['address'] ?? '';
    final city = office['city'] ?? '';
    final doctorName = office['doctorName'];
    final specialization = office['specialization'];
    final salonType = office['salonType'];
    final waitingCount = office['waitingCount'] ?? 0;
    final bool isOpen = office['isOpen'] != false;
    final distanceFormatted = office['distanceFormatted'] as String?;
    final color = _getCategoryColor(category);

    String subInfo = '';
    if (category == 'CLINIC' && doctorName != null && doctorName.toString().isNotEmpty) {
      subInfo = '👨‍⚕️ $doctorName ${specialization != null ? '($specialization)' : ''}';
    } else if (salonType != null && salonType.toString().isNotEmpty) {
      subInfo = '✂️ $salonType Salon';
    } else if (specialization != null && specialization.toString().isNotEmpty) {
      subInfo = specialization.toString();
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.14),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top row: Badges and Close button
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  category,
                  style: TextStyle(
                    color: color,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: (isOpen ? const Color(0xFF10B981) : const Color(0xFF94A3B8)).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isOpen ? const Color(0xFF10B981) : const Color(0xFF94A3B8),
                      ),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      isOpen ? 'Open Now' : 'Closed',
                      style: TextStyle(
                        color: isOpen ? const Color(0xFF059669) : const Color(0xFF64748B),
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              if (distanceFormatted != null) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEEF2FF),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.near_me_rounded, size: 11, color: AppColors.primary),
                      const SizedBox(width: 4),
                      Text(
                        distanceFormatted,
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const Spacer(),
              InkWell(
                onTap: () => setState(() => _selectedOffice = null),
                borderRadius: BorderRadius.circular(20),
                child: const Padding(
                  padding: EdgeInsets.all(4),
                  child: Icon(Icons.close_rounded, size: 20, color: Color(0xFF94A3B8)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Office Title & Sub-info
          Text(
            name,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: Color(0xFF0F172A),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          if (subInfo.isNotEmpty) ...[
            const SizedBox(height: 3),
            Text(
              subInfo,
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF475569),
                fontWeight: FontWeight.w500,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          if (address.isNotEmpty || city.isNotEmpty) ...[
            const SizedBox(height: 3),
            Row(
              children: [
                const Icon(Icons.location_on_outlined, size: 13, color: Color(0xFF94A3B8)),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    [address, city].where((e) => e.toString().isNotEmpty).join(', '),
                    style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 14),

          // Live Queue Info & Navigation Button
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.people_alt_rounded, size: 16, color: AppColors.primary),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '$waitingCount Waiting',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF0F172A)),
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              '~${waitingCount * 12} min est.',
                              style: const TextStyle(fontSize: 10, color: Color(0xFF64748B)),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => OfficeDetailsScreen(officeId: office['id']),
                    ),
                  ).then((_) => _fetchOffices());
                },
                icon: const Icon(Icons.login_rounded, size: 16),
                label: const Text('View Office'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                  textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildGlassButton({
    required IconData icon,
    required VoidCallback onTap,
    required String tooltip,
  }) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.white.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(16),
        elevation: 3,
        shadowColor: Colors.black.withValues(alpha: 0.15),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Icon(icon, color: const Color(0xFF1E293B), size: 20),
          ),
        ),
      ),
    );
  }

  Widget _buildMapControlBtn({
    required IconData icon,
    required VoidCallback onTap,
    required String tooltip,
    bool isLoading = false,
    Color? color,
  }) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        elevation: 3,
        shadowColor: Colors.black.withValues(alpha: 0.18),
        child: InkWell(
          onTap: isLoading ? null : onTap,
          borderRadius: BorderRadius.circular(14),
          child: SizedBox(
            width: 44,
            height: 44,
            child: isLoading
                ? const Center(
                    child: SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                    ),
                  )
                : Icon(icon, size: 20, color: color ?? const Color(0xFF334155)),
          ),
        ),
      ),
    );
  }
}

class _MarkerPointerPainter extends CustomPainter {
  final Color color;
  _MarkerPointerPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width / 2, size.height)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

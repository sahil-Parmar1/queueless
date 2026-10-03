import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart' hide Path;
import 'package:queueless_office/config/api_config.dart';

class OfficeLocationPickerDialog extends StatefulWidget {
  final double? initialLatitude;
  final double? initialLongitude;
  final String officeName;
  final String? address;

  const OfficeLocationPickerDialog({
    super.key,
    this.initialLatitude,
    this.initialLongitude,
    required this.officeName,
    this.address,
  });

  @override
  State<OfficeLocationPickerDialog> createState() => _OfficeLocationPickerDialogState();
}

class _OfficeLocationPickerDialogState extends State<OfficeLocationPickerDialog> {
  final MapController _mapController = MapController();
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  late LatLng _selectedLocation;
  bool _isLocating = false;
  bool _isSaving = false;
  double _currentZoom = 15.0;

  // Default fallback coordinates (e.g. Mumbai, India or center) if none provided
  static const LatLng _defaultCoords = LatLng(19.0760, 72.8777);

  @override
  void initState() {
    super.initState();
    if (widget.initialLatitude != null && widget.initialLongitude != null) {
      _selectedLocation = LatLng(widget.initialLatitude!, widget.initialLongitude!);
    } else {
      _selectedLocation = _defaultCoords;
      // Proactively detect GPS if no location was set
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _detectCurrentLocation(silentFail: true);
      });
    }
  }

  Future<void> _detectCurrentLocation({bool silentFail = false}) async {
    setState(() => _isLocating = true);

    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (!silentFail && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Location services (GPS) are disabled. Please enable GPS in device settings.'),
              backgroundColor: Color(0xFFEF4444),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        setState(() => _isLocating = false);
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (!silentFail && mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Location permission was denied.'),
                backgroundColor: Color(0xFFEF4444),
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
          setState(() => _isLocating = false);
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        if (!silentFail && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Location permission is permanently denied. Please enable in App Settings.'),
              backgroundColor: Color(0xFFEF4444),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        setState(() => _isLocating = false);
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 12),
        ),
      );

      final newLocation = LatLng(position.latitude, position.longitude);

      if (mounted) {
        setState(() {
          _selectedLocation = newLocation;
          _isLocating = false;
        });
        _mapController.move(newLocation, 16.0);
        _currentZoom = 16.0;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
                SizedBox(width: 8),
                Expanded(
                  child: Text('Location pinpointed from your device GPS!'),
                ),
              ],
            ),
            backgroundColor: Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLocating = false);
        if (!silentFail) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Could not fetch location: $e'),
              backgroundColor: const Color(0xFFEF4444),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    }
  }

  Future<void> _saveLocation() async {
    setState(() => _isSaving = true);

    try {
      final token = await _storage.read(key: 'jwt_token');
      final response = await http.put(
        Uri.parse('$apiBaseUrl/api/office/location'),
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'latitude': _selectedLocation.latitude,
          'longitude': _selectedLocation.longitude,
        }),
      );

      if (response.statusCode == 200) {
        if (mounted) {
          setState(() => _isSaving = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Row(
                children: [
                  Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text('Shop location saved on map successfully!'),
                  ),
                ],
              ),
              backgroundColor: Color(0xFF10B981),
              behavior: SnackBarBehavior.floating,
            ),
          );
          Navigator.pop(context, _selectedLocation);
        }
      } else {
        String msg = 'Failed to save location';
        try {
          final data = jsonDecode(response.body);
          if (data['error'] != null) msg = data['error'];
          if (data['message'] != null) msg = data['message'];
        } catch (_) {}
        throw Exception(msg);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving location: $e'),
            backgroundColor: const Color(0xFFEF4444),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _zoomIn() {
    setState(() => _currentZoom = (_currentZoom + 1).clamp(3.0, 19.0));
    _mapController.move(_selectedLocation, _currentZoom);
  }

  void _zoomOut() {
    setState(() => _currentZoom = (_currentZoom - 1).clamp(3.0, 19.0));
    _mapController.move(_selectedLocation, _currentZoom);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: SizedBox(
          width: 720,
          height: 640,
          child: Column(
            children: [
              // Header
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEEF2FF),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.location_on_rounded, color: Color(0xFF4F46E5), size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.officeName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: Color(0xFF0F172A)),
                          ),
                          const Text(
                            'Tap anywhere on map or drag pin to adjust shop location',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: Color(0xFF64748B)),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),

              // Map Area with Overlays
              Expanded(
                child: Stack(
                  children: [
                    FlutterMap(
                      mapController: _mapController,
                      options: MapOptions(
                        initialCenter: _selectedLocation,
                        initialZoom: _currentZoom,
                        onTap: (tapPosition, point) {
                          setState(() {
                            _selectedLocation = point;
                          });
                        },
                      ),
                      children: [
                        TileLayer(
                          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                          userAgentPackageName: 'com.queueless.office',
                          maxZoom: 19,
                        ),
                        MarkerLayer(
                          markers: [
                            Marker(
                              point: _selectedLocation,
                              width: 52,
                              height: 52,
                              alignment: Alignment.topCenter,
                              child: _buildPinMarker(),
                            ),
                          ],
                        ),
                      ],
                    ),

                    // Top GPS Action Pill
                    Positioned(
                      top: 14,
                      left: 14,
                      right: 14,
                      child: Row(
                        children: [
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(14),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.1),
                                    blurRadius: 10,
                                    offset: const Offset(0, 3),
                                  ),
                                ],
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.gps_fixed_rounded, size: 16, color: Color(0xFF4F46E5)),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'Lat: ${_selectedLocation.latitude.toStringAsFixed(5)}, Lng: ${_selectedLocation.longitude.toStringAsFixed(5)}',
                                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF1E293B)),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          ElevatedButton.icon(
                            onPressed: _isLocating ? null : () => _detectCurrentLocation(),
                            icon: _isLocating
                                ? const SizedBox(
                                    width: 14,
                                    height: 14,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                  )
                                : const Icon(Icons.my_location_rounded, size: 16),
                            label: const Text('My GPS'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF4F46E5),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              elevation: 3,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Map Zoom Controls (Right Side)
                    Positioned(
                      right: 14,
                      bottom: 20,
                      child: Column(
                        children: [
                          _buildMapControlBtn(
                            icon: Icons.add_rounded,
                            onTap: _zoomIn,
                            tooltip: 'Zoom In',
                          ),
                          const SizedBox(height: 8),
                          _buildMapControlBtn(
                            icon: Icons.remove_rounded,
                            onTap: _zoomOut,
                            tooltip: 'Zoom Out',
                          ),
                          const SizedBox(height: 8),
                          _buildMapControlBtn(
                            icon: Icons.center_focus_strong_rounded,
                            onTap: () {
                              _mapController.move(_selectedLocation, _currentZoom);
                            },
                            tooltip: 'Recenter Pin',
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Bottom Actions Bar
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
                ),
                child: Row(
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      style: TextButton.styleFrom(
                        foregroundColor: const Color(0xFF64748B),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      ),
                      child: const Text('Cancel', style: TextStyle(fontWeight: FontWeight.w600)),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _isSaving ? null : _saveLocation,
                        icon: _isSaving
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : const Icon(Icons.check_circle_rounded, size: 18),
                        label: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            _isSaving ? 'Saving...' : 'Confirm & Save Location',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF10B981),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          elevation: 0,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPinMarker() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            color: const Color(0xFF4F46E5),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2.5),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF4F46E5).withValues(alpha: 0.4),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: const Icon(Icons.storefront_rounded, color: Colors.white, size: 20),
        ),
        CustomPaint(
          size: const Size(10, 6),
          painter: _TrianglePainter(color: const Color(0xFF4F46E5)),
        ),
      ],
    );
  }

  Widget _buildMapControlBtn({
    required IconData icon,
    required VoidCallback onTap,
    required String tooltip,
  }) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        elevation: 3,
        shadowColor: Colors.black.withValues(alpha: 0.2),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: SizedBox(
            width: 38,
            height: 38,
            child: Icon(icon, size: 20, color: const Color(0xFF334155)),
          ),
        ),
      ),
    );
  }
}

class _TrianglePainter extends CustomPainter {
  final Color color;
  _TrianglePainter({required this.color});

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

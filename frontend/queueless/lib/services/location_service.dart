import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

class LocationService {
  static final LocationService _instance = LocationService._internal();
  factory LocationService() => _instance;
  LocationService._internal();

  Position? _lastKnownPosition;
  Position? get lastKnownPosition => _lastKnownPosition;

  /// Check permissions and get current user GPS position
  Future<Position?> getCurrentLocation({bool requestPermission = true}) async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return null;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied && requestPermission) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return null;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        ),
      );

      _lastKnownPosition = position;
      return position;
    } catch (_) {
      return _lastKnownPosition;
    }
  }

  /// Calculates distance in meters between two lat/lng coordinates
  double calculateDistance(double startLat, double startLng, double endLat, double endLng) {
    return Geolocator.distanceBetween(startLat, startLng, endLat, endLng);
  }

  /// Formats distance into a human-friendly string (e.g. "450 m" or "2.3 km")
  String formatDistance(double meters) {
    if (meters < 1000) {
      return '${meters.round()} m';
    } else {
      final km = meters / 1000;
      if (km < 10) {
        return '${km.toStringAsFixed(1)} km';
      } else {
        return '${km.round()} km';
      }
    }
  }

  /// Convert position to LatLng
  LatLng? get currentLatLng {
    if (_lastKnownPosition == null) return null;
    return LatLng(_lastKnownPosition!.latitude, _lastKnownPosition!.longitude);
  }
}

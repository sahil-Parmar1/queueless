/// ============================================================================
/// Centralized API Configuration for Office & Provider Flutter App (queueless_office)
/// ============================================================================
/// Change the [serverIp] below to your PC's local network IP (e.g. '192.168.1.100')
/// whenever your PC connects to a different Wi-Fi or network.
///
/// Both [apiBaseUrl] and [wsProviderStatusUrl] will automatically use this IP.
/// ============================================================================
library;

/// Change this single IP address when your PC connects to another Wi-Fi or network.
const String serverIp = '10.81.144.231';

/// The central API Gateway base URL for all HTTP REST API endpoints (Port 8081).
const String apiBaseUrl = 'http://$serverIp:8081';

/// Central WebSocket URL for real-time provider status updates (Port 8083).
const String wsProviderStatusUrl = 'ws://$serverIp:8083/ws/provider-status';

/// Class wrapper for convenient organized access if preferred.
class ApiConfig {
  static const String serverHost = serverIp;
  static const String baseApiUrl = apiBaseUrl;
  static const String providerStatusWsUrl = wsProviderStatusUrl;
}

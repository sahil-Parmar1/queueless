import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'office_service.dart';
import '../screens/queue/active_token_screen.dart';

class QueueNotificationService with WidgetsBindingObserver {
  static final QueueNotificationService _instance = QueueNotificationService._internal();
  factory QueueNotificationService() => _instance;

  QueueNotificationService._internal();

  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  final FlutterLocalNotificationsPlugin _notificationsPlugin = FlutterLocalNotificationsPlugin();
  final OfficeService _officeService = OfficeService();

  Timer? _pollingTimer;
  bool _isMonitoring = false;
  bool _isShowingDialog = false;
  bool _isAppInBackground = false;

  int? _currentTrackedTokenId;
  bool _alertedTwoAhead = false;
  bool _alertedTurnArrived = false;

  static const String _turnChannelId = 'queueless_turn_alerts_custom_sound';
  static const String _turnChannelName = 'Customer Turn Arrived Alerts';
  static const String _turnChannelDescription = 'Plays custom voice alert when your turn arrives in queue';

  static const String _proximityChannelId = 'queueless_proximity_alerts_custom_sound';
  static const String _proximityChannelName = 'Queue Proximity Alerts';
  static const String _proximityChannelDescription = 'Plays voice alert when you are almost next in queue';

  /// Initialize the notification plugin, channel, permissions, and app lifecycle observer
  Future<void> initialize() async {
    WidgetsBinding.instance.addObserver(this);

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidSettings);

    try {
      await _notificationsPlugin.initialize(
        settings: initSettings,
        onDidReceiveNotificationResponse: _onNotificationTapped,
      );

      final androidImpl = _notificationsPlugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      if (androidImpl != null) {
        await androidImpl.requestNotificationsPermission();

        const turnChannel = AndroidNotificationChannel(
          _turnChannelId,
          _turnChannelName,
          description: _turnChannelDescription,
          importance: Importance.max,
          sound: RawResourceAndroidNotificationSound('its_your_turn'),
          playSound: true,
          enableVibration: true,
        );

        const proximityChannel = AndroidNotificationChannel(
          _proximityChannelId,
          _proximityChannelName,
          description: _proximityChannelDescription,
          importance: Importance.high,
          sound: RawResourceAndroidNotificationSound('next_will_be_you'),
          playSound: true,
          enableVibration: true,
        );

        await androidImpl.createNotificationChannel(turnChannel);
        await androidImpl.createNotificationChannel(proximityChannel);
      }
    } catch (e) {
      debugPrint('Local notifications initialization error (may run in fallback): $e');
    }

    startMonitoring();
  }

  void _onNotificationTapped(NotificationResponse response) {
    final context = navigatorKey.currentContext;
    if (context != null) {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const ActiveTokenScreen()),
      );
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.hidden) {
      _isAppInBackground = true;
    } else if (state == AppLifecycleState.resumed) {
      _isAppInBackground = false;
    }
  }

  /// Start polling queue status every 4 seconds globally
  void startMonitoring() {
    if (_isMonitoring) return;
    _isMonitoring = true;
    _pollingTimer?.cancel();
    _pollingTimer = Timer.periodic(const Duration(seconds: 4), (timer) {
      checkQueueStatus();
    });
    // Immediate check
    checkQueueStatus();
  }

  /// Stop polling (e.g. on logout)
  void stopMonitoring() {
    _pollingTimer?.cancel();
    _isMonitoring = false;
    _currentTrackedTokenId = null;
    _alertedTwoAhead = false;
    _alertedTurnArrived = false;
  }

  /// Single check of active token status
  Future<void> checkQueueStatus() async {
    try {
      final data = await _officeService.getMyActiveToken();
      if (data == null || data['hasActiveToken'] != true) {
        // Reset tracking when no active token exists
        _currentTrackedTokenId = null;
        _alertedTwoAhead = false;
        _alertedTurnArrived = false;
        return;
      }

      final rawTokenId = data['id'] ?? data['token']?['id'];
      final int? tokenId = rawTokenId is int ? rawTokenId : int.tryParse('$rawTokenId');

      // If token changed, reset alert flags for the new token
      if (tokenId != null && tokenId != _currentTrackedTokenId) {
        _currentTrackedTokenId = tokenId;
        _alertedTwoAhead = false;
        _alertedTurnArrived = false;
      }

      final status = (data['status'] ?? data['token']?['status'] ?? 'WAITING').toString().toUpperCase();
      final dynamic rawPeopleAhead = data['peopleAhead'];
      final int peopleAhead = (rawPeopleAhead is int)
          ? rawPeopleAhead
          : int.tryParse('$rawPeopleAhead') ?? 0;
      final tokenNumber = (data['tokenNumber'] ?? data['token']?['tokenNumber'] ?? '---').toString();
      final String destination = (data['providerName'] ?? data['officeName'] ?? 'the counter').toString();

      // Situation 1: Only 2 people ahead
      if (peopleAhead <= 2 && peopleAhead > 0 && status == 'WAITING' && !_alertedTwoAhead) {
        _alertedTwoAhead = true;
        _triggerTwoAheadAlert(
          peopleAhead: peopleAhead,
          tokenNumber: tokenNumber,
          destination: destination,
          tokenData: data,
        );
      }

      // Situation 2: Turn arrived!
      if ((status == 'CALLED' || status == 'IN_SERVICE') && !_alertedTurnArrived) {
        _alertedTurnArrived = true;
        _triggerTurnArrivedAlert(
          tokenNumber: tokenNumber,
          destination: destination,
          tokenData: data,
        );
      }
    } catch (e) {
      debugPrint('QueueNotificationService checkQueueStatus error: $e');
    }
  }

  /// Trigger Situation 1 alerts (System Notification + In-App Dialog across ANY screen)
  Future<void> _triggerTwoAheadAlert({
    required int peopleAhead,
    required String tokenNumber,
    required String destination,
    required Map<String, dynamic> tokenData,
  }) async {
    // 1. Post System Notification to notification area/bar
    await _showSystemNotification(
      id: 101,
      title: '⏰ Almost Your Turn! (Token #$tokenNumber)',
      body: 'Only $peopleAhead person${peopleAhead == 1 ? '' : 's'} ahead of you in line for $destination. Please proceed towards the waiting area!',
    );

    // 2. Show In-App Alert Dialog on current screen
    _showInAppTwoAheadDialog(
      peopleAhead: peopleAhead,
      tokenNumber: tokenNumber,
      destination: destination,
      tokenData: tokenData,
    );
  }

  /// Trigger Situation 2 alerts (Urgent System Notification + In-App Dialog across ANY screen)
  Future<void> _triggerTurnArrivedAlert({
    required String tokenNumber,
    required String destination,
    required Map<String, dynamic> tokenData,
  }) async {
    // 1. Post Urgent System Notification to notification area/bar
    await _showSystemNotification(
      id: 102,
      title: '🎉 It\'s Your Turn Now! (Token #$tokenNumber)',
      body: 'Token #$tokenNumber is now being called by $destination! Please proceed immediately.',
      urgent: true,
    );

    // 2. Show In-App Alert Dialog on current screen
    _showInAppTurnArrivedDialog(
      tokenNumber: tokenNumber,
      destination: destination,
      tokenData: tokenData,
    );
  }

  /// Post Android System Notification to status bar / notification shade
  Future<void> _showSystemNotification({
    required int id,
    required String title,
    required String body,
    bool urgent = false,
  }) async {
    try {
      final channelId = urgent ? _turnChannelId : _proximityChannelId;
      final channelName = urgent ? _turnChannelName : _proximityChannelName;
      final channelDesc = urgent ? _turnChannelDescription : _proximityChannelDescription;
      final soundName = urgent ? 'its_your_turn' : 'next_will_be_you';

      final androidDetails = AndroidNotificationDetails(
        channelId,
        channelName,
        channelDescription: channelDesc,
        importance: urgent ? Importance.max : Importance.high,
        priority: urgent ? Priority.max : Priority.high,
        sound: RawResourceAndroidNotificationSound(soundName),
        playSound: true,
        enableVibration: true,
        category: urgent ? AndroidNotificationCategory.call : AndroidNotificationCategory.reminder,
        visibility: NotificationVisibility.public,
        styleInformation: BigTextStyleInformation(
          body,
          contentTitle: title,
          summaryText: 'QueueLess Live Notification',
        ),
      );

      final notificationDetails = NotificationDetails(android: androidDetails);
      await _notificationsPlugin.show(
        id: id,
        title: title,
        body: body,
        notificationDetails: notificationDetails,
      );
    } catch (e) {
      debugPrint('Failed to display system notification: $e');
    }
  }

  /// Show modal dialog for 2 people ahead on ANY active screen within the app
  void _showInAppTwoAheadDialog({
    required int peopleAhead,
    required String tokenNumber,
    required String destination,
    required Map<String, dynamic> tokenData,
  }) {
    final context = navigatorKey.currentContext;
    if (context == null) return;
    if (_isShowingDialog) return;

    _isShowingDialog = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final currentCtx = navigatorKey.currentContext;
      if (currentCtx == null || !currentCtx.mounted) {
        _isShowingDialog = false;
        return;
      }

      showDialog(
        context: currentCtx,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          backgroundColor: Colors.white,
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.timer_rounded, color: Color(0xFFD97706), size: 26),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Almost Your Turn!',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: Color(0xFF0F172A)),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFFCD34D)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.confirmation_number_rounded, color: Color(0xFFB45309), size: 18),
                    const SizedBox(width: 8),
                    Text(
                      'Token #$tokenNumber',
                      style: const TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF92400E)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Text(
                'Only $peopleAhead person${peopleAhead == 1 ? '' : 's'} ahead of you in line. Please proceed towards the waiting area or counter for $destination.',
                style: const TextStyle(fontSize: 14, color: Color(0xFF334155), height: 1.4),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Dismiss', style: TextStyle(color: Color(0xFF64748B))),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                Navigator.of(ctx).push(
                  MaterialPageRoute(builder: (_) => ActiveTokenScreen(initialTokenData: tokenData)),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4F46E5),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('View Token Pass'),
            ),
          ],
        ),
      ).then((_) {
        _isShowingDialog = false;
      });
    });
  }

  /// Show modal dialog for Turn Arrived on ANY active screen within the app
  void _showInAppTurnArrivedDialog({
    required String tokenNumber,
    required String destination,
    required Map<String, dynamic> tokenData,
  }) {
    final context = navigatorKey.currentContext;
    if (context == null) return;
    if (_isShowingDialog) {
      // Pop previous dialog if any
      try {
        Navigator.of(context, rootNavigator: true).pop();
      } catch (_) {}
    }

    _isShowingDialog = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final currentCtx = navigatorKey.currentContext;
      if (currentCtx == null || !currentCtx.mounted) {
        _isShowingDialog = false;
        return;
      }

      showDialog(
        context: currentCtx,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          backgroundColor: Colors.white,
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.campaign_rounded, color: Color(0xFF10B981), size: 28),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  '🎉 It\'s Your Turn Now!',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: Color(0xFF0F172A)),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFFD1FAE5),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF6EE7B7)),
                ),
                child: Column(
                  children: [
                    const Text('CALLING TOKEN', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF065F46))),
                    const SizedBox(height: 2),
                    Text(
                      tokenNumber,
                      style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: Color(0xFF047857)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Text(
                'Your token is now being called by $destination! Please proceed immediately.',
                style: const TextStyle(fontSize: 14, color: Color(0xFF1E293B), height: 1.4, fontWeight: FontWeight.w500),
              ),
            ],
          ),
          actions: [
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                Navigator.of(ctx).push(
                  MaterialPageRoute(builder: (_) => ActiveTokenScreen(initialTokenData: tokenData)),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF10B981),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('Proceed to Counter', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ).then((_) {
        _isShowingDialog = false;
      });
    });
  }
}

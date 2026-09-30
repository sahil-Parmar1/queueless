import 'dart:async';
import 'package:flutter/material.dart';
import '../../services/office_service.dart';

class ActiveTokenScreen extends StatefulWidget {
  final Map<String, dynamic>? initialTokenData;

  const ActiveTokenScreen({
    super.key,
    this.initialTokenData,
  });

  @override
  State<ActiveTokenScreen> createState() => _ActiveTokenScreenState();
}

class _ActiveTokenScreenState extends State<ActiveTokenScreen> {
  final OfficeService _officeService = OfficeService();
  bool _loading = true;
  Map<String, dynamic>? _tokenData;
  Timer? _pollingTimer;
  bool _alertedTwoAhead = false;
  bool _alertedTurnArrived = false;
  bool _isShowingDialog = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialTokenData != null) {
      _tokenData = widget.initialTokenData;
      _loading = false;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _checkAlerts(_tokenData);
        }
      });
    } else {
      _fetchActiveToken();
    }
    _startPolling();
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    super.dispose();
  }

  void _startPolling() {
    _pollingTimer?.cancel();
    _pollingTimer = Timer.periodic(const Duration(seconds: 4), (timer) {
      if (mounted) {
        _fetchActiveToken(silent: true);
      }
    });
  }

  Future<void> _fetchActiveToken({bool silent = false}) async {
    if (!silent) {
      setState(() => _loading = true);
    }
    final data = await _officeService.getMyActiveToken();
    if (mounted) {
      setState(() {
        _tokenData = data;
        _loading = false;
      });
      _checkAlerts(data);
    }
  }

  void _checkAlerts(Map<String, dynamic>? data) {
    if (data == null || data['hasActiveToken'] != true) return;

    final status = (data['status'] ?? data['token']?['status'] ?? 'WAITING').toString().toUpperCase();
    final dynamic rawPeopleAhead = data['peopleAhead'];
    final int peopleAhead = (rawPeopleAhead is int)
        ? rawPeopleAhead
        : int.tryParse('$rawPeopleAhead') ?? 0;
    final tokenNumber = (data['tokenNumber'] ?? data['token']?['tokenNumber'] ?? '---').toString();
    final String destination = (data['providerName'] ?? data['officeName'] ?? 'the counter').toString();

    // Alert 1: Only 2 people ahead
    if (peopleAhead <= 2 && peopleAhead > 0 && status == 'WAITING' && !_alertedTwoAhead) {
      _alertedTwoAhead = true;
      _showTwoAheadAlert(peopleAhead, tokenNumber, destination);
    }

    // Alert 2: Turn arrived!
    if ((status == 'CALLED' || status == 'IN_SERVICE') && !_alertedTurnArrived) {
      _alertedTurnArrived = true;
      _showTurnArrivedAlert(tokenNumber, destination);
    }
  }

  void _showTwoAheadAlert(int peopleAhead, String tokenNumber, String destination) {
    if (_isShowingDialog) return;
    _isShowingDialog = true;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        _isShowingDialog = false;
        return;
      }

      showDialog(
        context: context,
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
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4F46E5),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('Got It, I\'m Ready!'),
            ),
          ],
        ),
      ).then((_) {
        if (mounted) {
          _isShowingDialog = false;
        }
      });
    });
  }

  void _showTurnArrivedAlert(String tokenNumber, String destination) {
    if (_isShowingDialog) return;
    _isShowingDialog = true;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        _isShowingDialog = false;
        return;
      }

      showDialog(
        context: context,
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
              onPressed: () => Navigator.pop(ctx),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF10B981),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('Proceed Now', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ).then((_) {
        if (mounted) {
          _isShowingDialog = false;
        }
      });
    });
  }

  Future<void> _handleCancelToken() async {
    final token = _tokenData?['token'];
    final tokenId = token?['id'] ?? _tokenData?['id'];
    if (tokenId == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Color(0xFFEF4444)),
            SizedBox(width: 8),
            Text('Cancel Token?'),
          ],
        ),
        content: const Text(
          'Are you sure you want to cancel your digital token? You will lose your current spot in the queue.',
          style: TextStyle(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep Token', style: TextStyle(color: Color(0xFF64748B))),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Yes, Cancel'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final success = await _officeService.cancelToken(tokenId);
      if (mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Token cancelled successfully.')),
          );
          Navigator.pop(context, true);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to cancel token. Please try again.')),
          );
        }
      }
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
          'My Digital Token',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh queue status',
            onPressed: _fetchActiveToken,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF4F46E5)))
          : _tokenData == null
              ? _buildNoActiveTokenView()
              : _buildActiveTokenContent(),
    );
  }

  Widget _buildNoActiveTokenView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF4F46E5).withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.confirmation_number_outlined, size: 50, color: Color(0xFF4F46E5)),
            ),
            const SizedBox(height: 20),
            const Text(
              'No Active Token',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
            ),
            const SizedBox(height: 8),
            const Text(
              'You don\'t currently have any active queue booking. Search for a clinic, salon, or office to join a queue.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Color(0xFF64748B), height: 1.4),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.search_rounded),
              label: const Text('Browse Offices'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4F46E5),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActiveTokenContent() {
    final tokenNumber = _tokenData?['tokenNumber'] ?? _tokenData?['token']?['tokenNumber'] ?? '---';
    final officeName = _tokenData?['officeName'] ?? 'Office';
    final category = _tokenData?['category'] ?? 'OFFICE';
    final status = _tokenData?['status'] ?? 'WAITING';
    final peopleAhead = _tokenData?['peopleAhead'] ?? 0;
    final waitMins = _tokenData?['estimatedWaitMinutes'] ?? (peopleAhead * 12);
    final currentlyServing = _tokenData?['currentlyServing'] ?? 'None';
    final address = _tokenData?['address'] ?? '';
    final city = _tokenData?['city'] ?? '';
    final providerName = _tokenData?['providerName'] ?? '';
    final providerDesignation = _tokenData?['providerDesignation'] ?? '';

    final isTurnNow = status == 'CALLED' || status == 'IN_SERVICE';
    final isAlmostTurn = peopleAhead <= 2 && peopleAhead > 0 && status == 'WAITING';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // Live Alert Banner
          if (isTurnNow) ...[
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFDCFCE7),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFF22C55E), width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF22C55E).withValues(alpha: 0.15),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: const BoxDecoration(
                      color: Color(0xFF16A34A),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.campaign_rounded, color: Colors.white, size: 24),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'IT\'S YOUR TURN NOW!',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: Color(0xFF14532D)),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Please proceed to ${providerName.isNotEmpty ? providerName : officeName} immediately.',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF166534)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ] else if (isAlmostTurn) ...[
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF3C7),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFF59E0B), width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: const BoxDecoration(
                      color: Color(0xFFD97706),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.timer_rounded, color: Colors.white, size: 24),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'GET READY! ONLY 2 AHEAD',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: Color(0xFF78350F)),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Only $peopleAhead person${peopleAhead == 1 ? '' : 's'} ahead of you in line. Please head towards the waiting area.',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF92400E)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Digital Boarding / Token Pass Card
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF4F46E5).withValues(alpha: 0.12),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              children: [
                // Card Top Banner
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFF4F46E5), Color(0xFF6366F1)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(24),
                      topRight: Radius.circular(24),
                    ),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              category,
                              style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                            ),
                          ),
                          _buildStatusBadge(status),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        officeName,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      if (providerName.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.25),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.badge_outlined, color: Colors.white, size: 14),
                              const SizedBox(width: 6),
                              Flexible(
                                child: Text(
                                  'Staff: $providerName${providerDesignation.isNotEmpty ? ' ($providerDesignation)' : ''}',
                                  style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      if (address.isNotEmpty || city.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.location_on_outlined, color: Colors.white70, size: 13),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                [address, city].where((e) => e.toString().isNotEmpty).join(', '),
                                style: const TextStyle(color: Colors.white70, fontSize: 12),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),

                // Digital Token Big Display
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
                  child: Column(
                    children: [
                      const Text(
                        'YOUR TOKEN NUMBER',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF94A3B8),
                          letterSpacing: 1.5,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        tokenNumber,
                        style: const TextStyle(
                          fontSize: 54,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF4F46E5),
                          letterSpacing: 2,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          peopleAhead == 0
                              ? '🎉 It\'s your turn next!'
                              : '$peopleAhead person${peopleAhead == 1 ? '' : 's'} ahead of you',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: peopleAhead == 0 ? const Color(0xFF10B981) : const Color(0xFF334155),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Dashed Cut Divider
                Row(
                  children: List.generate(
                    24,
                    (index) => Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 2),
                        child: Container(height: 2, color: const Color(0xFFE2E8F0)),
                      ),
                    ),
                  ),
                ),

                // Metrics Grid
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    children: [
                      Expanded(
                        child: _buildMetricTile(
                          label: 'Est. Wait',
                          value: '$waitMins min',
                          icon: Icons.timer_outlined,
                          color: const Color(0xFFF59E0B),
                        ),
                      ),
                      Container(width: 1, height: 40, color: const Color(0xFFE2E8F0)),
                      Expanded(
                        child: _buildMetricTile(
                          label: 'Now Serving',
                          value: currentlyServing != 'None' ? '#$currentlyServing' : '--',
                          icon: Icons.notifications_active_outlined,
                          color: const Color(0xFF10B981),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Smart Info Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFF0FDF4),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFBBF7D0)),
            ),
            child: const Row(
              children: [
                Icon(Icons.check_circle_outline_rounded, color: Color(0xFF16A34A), size: 24),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Stay relaxed! You don\'t have to stand in line. We\'ll notify you when only 2 people are ahead.',
                    style: TextStyle(fontSize: 13, color: Color(0xFF166534), height: 1.4),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Action Buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _handleCancelToken,
                  icon: const Icon(Icons.close_rounded, color: Color(0xFFEF4444), size: 18),
                  label: const Text('Cancel Token', style: TextStyle(color: Color(0xFFEF4444))),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFFFECACA)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _fetchActiveToken,
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  label: const Text('Refresh Status'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4F46E5),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color bg;
    Color fg;
    String label;

    switch (status) {
      case 'CALLED':
      case 'IN_SERVICE':
        bg = const Color(0xFF10B981);
        fg = Colors.white;
        label = 'CALLED / TURN READY';
        break;
      case 'COMPLETED':
        bg = const Color(0xFF3B82F6);
        fg = Colors.white;
        label = 'COMPLETED';
        break;
      case 'CANCELLED':
        bg = const Color(0xFFEF4444);
        fg = Colors.white;
        label = 'CANCELLED';
        break;
      default:
        bg = Colors.white;
        fg = const Color(0xFF4F46E5);
        label = 'IN QUEUE';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: TextStyle(color: fg, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 0.5),
      ),
    );
  }

  Widget _buildMetricTile({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 6),
            Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B), fontWeight: FontWeight.w500)),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          value,
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: color),
        ),
      ],
    );
  }
}

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

  @override
  void initState() {
    super.initState();
    if (widget.initialTokenData != null) {
      _tokenData = widget.initialTokenData;
      _loading = false;
    } else {
      _fetchActiveToken();
    }
  }

  Future<void> _fetchActiveToken() async {
    setState(() => _loading = true);
    final data = await _officeService.getMyActiveToken();
    if (mounted) {
      setState(() {
        _tokenData = data;
        _loading = false;
      });
    }
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

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
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
                      if (address.isNotEmpty || city.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          [address, city].where((e) => e.toString().isNotEmpty).join(', '),
                          style: const TextStyle(color: Colors.white70, fontSize: 12),
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

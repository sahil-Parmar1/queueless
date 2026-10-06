import 'package:flutter/material.dart';
import '../../services/office_service.dart';
import '../../theme/app_theme.dart';

class TokenHistoryScreen extends StatefulWidget {
  const TokenHistoryScreen({super.key});

  @override
  State<TokenHistoryScreen> createState() => _TokenHistoryScreenState();
}

class _TokenHistoryScreenState extends State<TokenHistoryScreen> {
  final OfficeService _officeService = OfficeService();
  bool _loading = true;
  List<dynamic> _history = [];

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    setState(() => _loading = true);
    final list = await _officeService.getMyTokenHistory();
    if (mounted) {
      setState(() {
        _history = list;
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
          'Queue History',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18, color: AppColors.mainText),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : RefreshIndicator(
              onRefresh: _loadHistory,
              color: AppColors.primary,
              child: _history.isEmpty
                  ? _buildEmptyState()
                  : ListView.separated(
                      padding: const EdgeInsets.all(20),
                      itemCount: _history.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final item = _history[index];
                        return _buildHistoryCard(item);
                      },
                    ),
            ),
    );
  }

  Widget _buildEmptyState() {
    return ListView(
      padding: const EdgeInsets.all(32),
      children: [
        const SizedBox(height: 60),
        Icon(Icons.history_toggle_off_rounded, size: 64, color: AppColors.mutedText.withValues(alpha: 0.4)),
        const SizedBox(height: 16),
        const Text(
          'No Queue History',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.mainText),
        ),
        const SizedBox(height: 8),
        const Text(
          'When you book tokens and complete your visits, your history will be recorded here.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 14, color: AppColors.secondaryText, height: 1.4),
        ),
      ],
    );
  }

  Widget _buildHistoryCard(dynamic item) {
    final tokenNumber = item['tokenNumber'] ?? '---';
    final status = item['status'] ?? 'COMPLETED';
    final office = item['office'];
    final officeName = item['officeName'] ??
        (office != null && office['user'] != null
            ? office['user']['name']
            : 'Office');
    final category = item['category'] ??
        (office != null ? office['category'] ?? 'OFFICE' : 'OFFICE');
    final bookedAt = item['bookedAt'] != null ? item['bookedAt'].toString().split('T').first : '';
    final isCompleted = status == 'COMPLETED';
    final servingStartedAt = item['servingStartedAt'] ?? item['calledAt'];
    final completedAt = item['completedAt'];
    final serviceDurationMinutes = item['serviceDurationMinutes'];
    final serviceDurationSeconds = item['serviceDurationSeconds'];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryDark.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: AppColors.primarySoft,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  tokenNumber,
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                    color: AppColors.primaryDark,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      officeName,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: AppColors.mainText,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$category • $bookedAt',
                      style: const TextStyle(fontSize: 12, color: AppColors.mutedText),
                    ),
                  ],
                ),
              ),
              _buildStatusBadge(status),
            ],
          ),
          if (isCompleted) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildTimeColumn(
                        label: 'Serving Started',
                        time: _formatTime(servingStartedAt),
                        icon: Icons.play_arrow_rounded,
                        iconColor: const Color(0xFF3B82F6),
                      ),
                      Container(
                        width: 1,
                        height: 30,
                        color: const Color(0xFFCBD5E1),
                      ),
                      const SizedBox(width: 8),
                      _buildTimeColumn(
                        label: 'Completed',
                        time: _formatTime(completedAt),
                        icon: Icons.check_circle_outline_rounded,
                        iconColor: const Color(0xFF10B981),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.successSoft,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.success.withValues(alpha: 0.2)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.timer_outlined,
                          size: 16,
                          color: AppColors.success,
                        ),
                        const SizedBox(width: 6),
                        const Text(
                          'Total Service Time: ',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.mainText,
                          ),
                        ),
                        Text(
                          _formatTotalServiceTime(serviceDurationMinutes, serviceDurationSeconds),
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: AppColors.success,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTimeColumn({
    required String label,
    required String time,
    required IconData icon,
    required Color iconColor,
  }) {
    return Expanded(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: iconColor),
          const SizedBox(width: 8),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.mutedText,
                    fontWeight: FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  time,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.mainText,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(dynamic timestamp) {
    if (timestamp == null) return '--:--';
    try {
      final dt = timestamp is DateTime ? timestamp : DateTime.parse(timestamp.toString());
      final hour = dt.hour;
      final minute = dt.minute.toString().padLeft(2, '0');
      final period = hour >= 12 ? 'PM' : 'AM';
      final formattedHour = hour % 12 == 0 ? 12 : hour % 12;
      return '$formattedHour:$minute $period';
    } catch (_) {
      return timestamp.toString();
    }
  }

  String _formatTotalServiceTime(dynamic minutes, dynamic seconds) {
    if (minutes != null) {
      final m = int.tryParse(minutes.toString()) ?? 0;
      if (m > 0) {
        return '$m ${m == 1 ? "minute" : "minutes"}';
      }
    }
    if (seconds != null) {
      final totalSec = int.tryParse(seconds.toString()) ?? 0;
      if (totalSec >= 60) {
        final m = (totalSec / 60.0).round();
        return '$m ${m == 1 ? "minute" : "minutes"}';
      } else if (totalSec > 0) {
        return '$totalSec seconds';
      }
    }
    if (minutes != null && minutes.toString() == '0') {
      return 'Less than 1 minute';
    }
    return '--';
  }

  Widget _buildStatusBadge(String status) {
    Color bg;
    Color fg;
    switch (status) {
      case 'COMPLETED':
        bg = AppColors.successSoft;
        fg = AppColors.success;
        break;
      case 'CANCELLED':
        bg = AppColors.errorSoft;
        fg = AppColors.error;
        break;
      case 'SKIPPED':
        bg = AppColors.warningSoft;
        fg = AppColors.warning;
        break;
      default:
        bg = AppColors.primarySoft;
        fg = AppColors.primaryDark;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        status,
        style: TextStyle(color: fg, fontSize: 11, fontWeight: FontWeight.w700),
      ),
    );
  }
}

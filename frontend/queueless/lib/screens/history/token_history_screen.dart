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
    final officeName = office != null && office['user'] != null
        ? office['user']['name']
        : 'Office';
    final category = office != null ? office['category'] ?? 'OFFICE' : 'OFFICE';
    final bookedAt = item['bookedAt'] != null ? item['bookedAt'].toString().split('T').first : '';

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
      child: Row(
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
    );
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

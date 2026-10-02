import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../theme/provider_theme.dart';

class QrStandDialog extends StatelessWidget {
  final String title;
  final String officeName;
  final dynamic officeId;
  final String? officeCode;
  final dynamic providerId;
  final String? providerName;
  final String? designation;

  const QrStandDialog({
    super.key,
    required this.title,
    required this.officeName,
    required this.officeId,
    this.officeCode,
    this.providerId,
    this.providerName,
    this.designation,
  });

  String get _qrPayload {
    final Map<String, dynamic> payload = {
      'type': 'JOIN_QUEUE',
      'officeId': int.tryParse(officeId.toString()) ?? officeId,
      'officeName': officeName,
    };

    if (providerId != null) {
      payload['providerId'] = int.tryParse(providerId.toString()) ?? providerId;
    }
    if (providerName != null && providerName!.isNotEmpty) {
      payload['providerName'] = providerName;
    }

    return jsonEncode(payload);
  }

  @override
  Widget build(BuildContext context) {
    final bool isProviderQr = providerId != null;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: ProviderColors.primarySoft,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.qr_code_2_rounded,
                          color: ProviderColors.primary,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
                              color: ProviderColors.mainText,
                            ),
                          ),
                          const Text(
                            'QueueLess Instant Check-in',
                            style: TextStyle(
                              fontSize: 11,
                              color: ProviderColors.mutedText,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: ProviderColors.secondaryText),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 18),

              // Stand Preview Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
                decoration: BoxDecoration(
                  color: const Color(0xFFFAF5FF),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFE9D5FF), width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: ProviderColors.primary.withValues(alpha: 0.06),
                      blurRadius: 18,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    // Brand pill
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: ProviderColors.primary,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.bolt_rounded, size: 14, color: Colors.white),
                          SizedBox(width: 4),
                          Text(
                            'SCAN TO JOIN QUEUE',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.6,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Office / Provider Name
                    Text(
                      isProviderQr && providerName != null ? providerName! : officeName,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: ProviderColors.mainText,
                        letterSpacing: -0.3,
                      ),
                    ),

                    if (isProviderQr && designation != null && designation!.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        designation!,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: ProviderColors.primary,
                        ),
                      ),
                    ],

                    const SizedBox(height: 4),
                    Text(
                      isProviderQr ? 'At: $officeName' : 'Office ID: #$officeId',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 12,
                        color: ProviderColors.secondaryText,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 14),

                    // QR Code Image
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.04),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: QrImageView(
                        data: _qrPayload,
                        version: QrVersions.auto,
                        size: 190.0,
                        backgroundColor: Colors.white,
                        padding: const EdgeInsets.all(4),
                        errorCorrectionLevel: QrErrorCorrectLevel.M,
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Badges row
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      alignment: WrapAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Text(
                            officeCode != null && officeCode!.isNotEmpty ? 'Code: $officeCode' : 'Office #$officeId',
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: ProviderColors.secondaryText),
                          ),
                        ),
                        if (isProviderQr)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: ProviderColors.primarySoft,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              'Provider #$providerId',
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: ProviderColors.primaryDark),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // Instructional Text
              const Text(
                'Display or print this QR stand. Walk-in customers scanning this with the QueueLess customer app will immediately open your screen and book a token.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  color: ProviderColors.mutedText,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 18),

              // Action buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: _qrPayload));
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: const Row(
                              children: [
                                Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
                                SizedBox(width: 8),
                                Expanded(child: Text('QR Code payload copied to clipboard!')),
                              ],
                            ),
                            backgroundColor: ProviderColors.success,
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        );
                      },
                      icon: const Icon(Icons.copy_rounded, size: 16),
                      label: const Text('Copy QR Data'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: ProviderColors.primary,
                        side: const BorderSide(color: ProviderColors.primaryLight),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: ProviderColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                      child: const Text('Close', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

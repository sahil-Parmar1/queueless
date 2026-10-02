import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../services/office_service.dart';
import '../../theme/app_theme.dart';
import '../office_details/office_details_screen.dart';

class QRScannerScreen extends StatefulWidget {
  const QRScannerScreen({super.key});

  @override
  State<QRScannerScreen> createState() => _QRScannerScreenState();
}

class _QRScannerScreenState extends State<QRScannerScreen> with SingleTickerProviderStateMixin {
  late final MobileScannerController _controller;
  late final AnimationController _animController;
  late final Animation<double> _scanAnimation;

  bool _isProcessing = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _controller = MobileScannerController(
      detectionSpeed: DetectionSpeed.noDuplicates,
      facing: CameraFacing.back,
    );

    _animController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _scanAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _animController.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _handleBarcode(BarcodeCapture capture) {
    if (_isProcessing) return;

    final List<Barcode> barcodes = capture.barcodes;
    if (barcodes.isEmpty) return;

    final String? rawValue = barcodes.first.rawValue;
    if (rawValue == null || rawValue.trim().isEmpty) return;

    _processRawData(rawValue.trim());
  }

  Future<void> _processRawData(String raw) async {
    setState(() {
      _isProcessing = true;
      _errorMessage = null;
    });

    int? officeId;
    int? providerId;
    String? officeCodeCandidate;

    // 1. Try parsing JSON format: {"officeId": 1, "providerId": 2} or {"type": "JOIN_QUEUE", ...}
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map) {
        final rawOffice = decoded['officeId'] ?? decoded['office_id'] ?? decoded['id'];
        final rawProvider = decoded['providerId'] ?? decoded['provider_id'];
        final rawCode = decoded['officeCode'] ?? decoded['office_code'];

        if (rawOffice != null) {
          officeId = int.tryParse(rawOffice.toString());
          if (officeId == null) {
            officeCodeCandidate = rawOffice.toString();
          }
        }
        if (officeCodeCandidate == null && rawCode != null) {
          officeCodeCandidate = rawCode.toString();
        }
        if (rawProvider != null) {
          providerId = int.tryParse(rawProvider.toString());
        }
      }
    } catch (_) {}

    // 2. Try parsing URL / Deep-link format: https://.../office/12 or queueless://office/12?providerId=5
    if (officeId == null) {
      try {
        final uri = Uri.tryParse(raw);
        if (uri != null) {
          final queryOffice = uri.queryParameters['officeId'] ?? uri.queryParameters['office_id'] ?? uri.queryParameters['id'];
          final queryProvider = uri.queryParameters['providerId'] ?? uri.queryParameters['provider_id'];
          if (queryOffice != null) {
            officeId = int.tryParse(queryOffice);
            if (officeId == null) officeCodeCandidate = queryOffice;
          }
          if (queryProvider != null) {
            providerId = int.tryParse(queryProvider);
          }

          if (officeId == null && uri.pathSegments.isNotEmpty) {
            for (int i = 0; i < uri.pathSegments.length; i++) {
              final seg = uri.pathSegments[i].toLowerCase();
              if (seg == 'office' && i + 1 < uri.pathSegments.length) {
                officeId = int.tryParse(uri.pathSegments[i + 1]);
                if (officeId == null) officeCodeCandidate = uri.pathSegments[i + 1];
                break;
              }
            }
            officeId ??= int.tryParse(uri.pathSegments.last);
            if (officeId == null && uri.pathSegments.last.isNotEmpty) {
              officeCodeCandidate ??= uri.pathSegments.last;
            }
          }
        }
      } catch (_) {}
    }

    // 3. Try parsing simple text / ID: "OFFICE:12", "12"
    if (officeId == null && officeCodeCandidate == null) {
      final trimmed = raw.trim();
      if (trimmed.toUpperCase().startsWith('OFF-') || trimmed.toUpperCase().startsWith('OFFICE-')) {
        officeCodeCandidate = trimmed;
      } else {
        final match = RegExp(r'^(?:office[:\s\-_]*)?(\d+)$', caseSensitive: false).firstMatch(trimmed);
        if (match != null) {
          officeId = int.tryParse(match.group(1)!);
        } else {
          officeCodeCandidate = trimmed;
        }
      }
    }

    // 4. Fallback: Search office by code if candidate exists
    if (officeId == null && officeCodeCandidate != null && officeCodeCandidate.isNotEmpty) {
      try {
        final results = await OfficeService().searchOffices(query: officeCodeCandidate);
        if (results.isNotEmpty) {
          final first = results.first;
          officeId = int.tryParse(first['id']?.toString() ?? '');
        }
      } catch (_) {}
    }

    if (!mounted) return;

    if (officeId != null && officeId > 0) {
      _navigateToOffice(officeId, providerId);
    } else {
      setState(() {
        _errorMessage = 'Unrecognized QR code. Please scan a valid Queueless office QR.';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_errorMessage!),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) {
          setState(() {
            _isProcessing = false;
            _errorMessage = null;
          });
        }
      });
    }
  }

  void _navigateToOffice(int officeId, int? providerId) {
    _controller.stop();
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => OfficeDetailsScreen(
          officeId: officeId,
          initialProviderId: providerId,
        ),
      ),
    );
  }

  void _showManualEntryDialog() {
    final officeIdController = TextEditingController();
    final providerIdController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (bottomSheetContext) {
        return Padding(
          padding: EdgeInsets.only(
            left: 24,
            right: 24,
            top: 24,
            bottom: MediaQuery.of(bottomSheetContext).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Enter Office Code',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.mainText,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: AppColors.secondaryText),
                    onPressed: () => Navigator.pop(bottomSheetContext),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Text(
                'Enter the Office ID number or paste raw QR text if your camera is unable to scan.',
                style: TextStyle(fontSize: 13, color: AppColors.secondaryText),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: officeIdController,
                keyboardType: TextInputType.text,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: 'Office ID or QR Code Text',
                  hintText: 'e.g. 1 or {"officeId":1}',
                  prefixIcon: const Icon(Icons.business_rounded, color: AppColors.primary),
                  filled: true,
                  fillColor: AppColors.background,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.primary, width: 2),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: providerIdController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Provider / Staff ID (Optional)',
                  hintText: 'e.g. 2',
                  prefixIcon: const Icon(Icons.person_outline_rounded, color: AppColors.secondaryText),
                  filled: true,
                  fillColor: AppColors.background,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.primary, width: 2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    final text = officeIdController.text.trim();
                    if (text.isEmpty) return;

                    Navigator.pop(bottomSheetContext);

                    // If numeric provider ID provided
                    final manualProvider = int.tryParse(providerIdController.text.trim());
                    final manualOffice = int.tryParse(text);

                    if (manualOffice != null && manualOffice > 0) {
                      _navigateToOffice(manualOffice, manualProvider);
                    } else {
                      _processRawData(text);
                    }
                  },
                  icon: const Icon(Icons.arrow_forward_rounded),
                  label: const Text('Proceed to Office', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    const double scanAreaSize = 260.0;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Camera scanner
          MobileScanner(
            controller: _controller,
            onDetect: _handleBarcode,
            errorBuilder: (context, error) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(28.0),
                  child: Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppColors.primarySoft,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.videocam_off_rounded, size: 40, color: AppColors.primaryDark),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Camera Unavailable',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppColors.mainText,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Camera access could not be initialized (${error.errorCode.name}). You can still enter the Office ID manually.',
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 13, color: AppColors.secondaryText),
                        ),
                        const SizedBox(height: 20),
                        ElevatedButton.icon(
                          onPressed: _showManualEntryDialog,
                          icon: const Icon(Icons.edit_note_rounded),
                          label: const Text('Enter Office Code Manually'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            elevation: 0,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),

          // Dark overlay with transparent center cutout
          ColorFiltered(
            colorFilter: ColorFilter.mode(
              Colors.black.withValues(alpha: 0.55),
              BlendMode.srcOut,
            ),
            child: Stack(
              fit: StackFit.expand,
              children: [
                Container(
                  decoration: const BoxDecoration(
                    color: Colors.black,
                    backgroundBlendMode: BlendMode.dstOut,
                  ),
                ),
                Align(
                  alignment: Alignment.center,
                  child: Container(
                    height: scanAreaSize,
                    width: scanAreaSize,
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Scanner Reticle with Teal Corners and animated scan line
          Align(
            alignment: Alignment.center,
            child: SizedBox(
              width: scanAreaSize,
              height: scanAreaSize,
              child: Stack(
                children: [
                  // Corner brackets
                  CustomPaint(
                    size: const Size(scanAreaSize, scanAreaSize),
                    painter: _ReticlePainter(color: AppColors.primary, cornerLength: 28, strokeWidth: 4),
                  ),

                  // Animated scanning line
                  AnimatedBuilder(
                    animation: _scanAnimation,
                    builder: (context, child) {
                      return Positioned(
                        top: _scanAnimation.value * (scanAreaSize - 20) + 10,
                        left: 10,
                        right: 10,
                        child: Container(
                          height: 3,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [
                                Colors.transparent,
                                AppColors.cyanLight,
                                AppColors.primaryLight,
                                AppColors.cyanLight,
                                Colors.transparent,
                              ],
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.primaryLight.withValues(alpha: 0.8),
                                blurRadius: 8,
                                spreadRadius: 1,
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),

          // Processing Indicator
          if (_isProcessing)
            Container(
              color: Colors.black54,
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: AppColors.primaryLight),
                    SizedBox(height: 16),
                    Text(
                      'Opening Office Details...',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // Top Header / Navigation Controls
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  CircleAvatar(
                    backgroundColor: Colors.black.withValues(alpha: 0.5),
                    child: IconButton(
                      icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.qr_code_scanner_rounded, size: 16, color: AppColors.primaryLight),
                        SizedBox(width: 8),
                        Text(
                          'Scan Office QR',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Row(
                    children: [
                      // Torch toggle
                      ValueListenableBuilder<MobileScannerState>(
                        valueListenable: _controller,
                        builder: (context, state, child) {
                          final isOn = state.torchState == TorchState.on;
                          return CircleAvatar(
                            backgroundColor: Colors.black.withValues(alpha: 0.5),
                            child: IconButton(
                              icon: Icon(
                                isOn ? Icons.flash_on_rounded : Icons.flash_off_rounded,
                                color: isOn ? Colors.amber : Colors.white,
                              ),
                              onPressed: () => _controller.toggleTorch(),
                            ),
                          );
                        },
                      ),
                      const SizedBox(width: 8),
                      // Camera flip
                      CircleAvatar(
                        backgroundColor: Colors.black.withValues(alpha: 0.5),
                        child: IconButton(
                          icon: const Icon(Icons.flip_camera_ios_rounded, color: Colors.white),
                          onPressed: () => _controller.switchCamera(),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Bottom instruction and Manual entry action
          SafeArea(
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.65),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.white12),
                      ),
                      child: const Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Align QR Code within the frame',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Scan the QR at the office counter or provider desk to view info & book a token',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _showManualEntryDialog,
                        icon: const Icon(Icons.keyboard_rounded, color: Colors.white),
                        label: const Text(
                          'Enter Office Code Manually',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          backgroundColor: Colors.black.withValues(alpha: 0.4),
                          side: const BorderSide(color: AppColors.primaryLight, width: 1.5),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReticlePainter extends CustomPainter {
  final Color color;
  final double cornerLength;
  final double strokeWidth;

  _ReticlePainter({
    required this.color,
    required this.cornerLength,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final w = size.width;
    final h = size.height;
    const r = 16.0;

    // Top Left
    final pathTL = Path()
      ..moveTo(0, cornerLength)
      ..lineTo(0, r)
      ..quadraticBezierTo(0, 0, r, 0)
      ..lineTo(cornerLength, 0);
    canvas.drawPath(pathTL, paint);

    // Top Right
    final pathTR = Path()
      ..moveTo(w - cornerLength, 0)
      ..lineTo(w - r, 0)
      ..quadraticBezierTo(w, 0, w, r)
      ..lineTo(w, cornerLength);
    canvas.drawPath(pathTR, paint);

    // Bottom Left
    final pathBL = Path()
      ..moveTo(0, h - cornerLength)
      ..lineTo(0, h - r)
      ..quadraticBezierTo(0, h, r, h)
      ..lineTo(cornerLength, h);
    canvas.drawPath(pathBL, paint);

    // Bottom Right
    final pathBR = Path()
      ..moveTo(w - cornerLength, h)
      ..lineTo(w - r, h)
      ..quadraticBezierTo(w, h, w, h - r)
      ..lineTo(w, h - cornerLength);
    canvas.drawPath(pathBR, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

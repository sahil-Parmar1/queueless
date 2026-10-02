import 'package:flutter/material.dart';
import '../../services/customer_auth_service.dart';
import '../../services/office_service.dart';
import '../../services/provider_status_websocket_service.dart';
import '../../theme/app_theme.dart';
import '../auth/customer_login_screen.dart';
import '../queue/active_token_screen.dart';

class OfficeDetailsScreen extends StatefulWidget {
  final int officeId;

  const OfficeDetailsScreen({
    super.key,
    required this.officeId,
  });

  @override
  State<OfficeDetailsScreen> createState() => _OfficeDetailsScreenState();
}

class _OfficeDetailsScreenState extends State<OfficeDetailsScreen> {
  final OfficeService _officeService = OfficeService();
  bool _loading = true;
  bool _booking = false;

  Map<String, dynamic>? _officeDetails;
  Map<String, dynamic>? _liveQueue;
  List<dynamic> _providers = [];
  ProviderStatusWebSocketService? _webSocketService;

  @override
  void initState() {
    super.initState();
    _loadDetails();
    _initWebSocket();
  }

  @override
  void dispose() {
    _webSocketService?.dispose();
    super.dispose();
  }

  void _initWebSocket() {
    _webSocketService = ProviderStatusWebSocketService(
      onStatusChange: (data) {
        if (!mounted) return;
        if (data['event'] == 'PROVIDER_STATUS_CHANGED') {
          final dynamic pOfficeId = data['officeId'];
          final dynamic pId = data['providerId'];
          final bool onDuty = data['onDuty'] == true;
          final bool availableNow = data['availableNow'] == true;

          if (pOfficeId == widget.officeId || _providers.any((p) => p['id'] == pId)) {
            setState(() {
              final idx = _providers.indexWhere((p) => p['id'] == pId);
              if (idx != -1) {
                _providers[idx]['onDuty'] = onDuty;
                _providers[idx]['availableNow'] = availableNow;
              }
            });
          }
        } else if (data['event'] == 'OFFICE_STATUS_CHANGED') {
          final dynamic oId = data['officeId'];
          if (oId == widget.officeId) {
            final bool isOpen = data['isOpen'] == true;
            setState(() {
              if (_officeDetails != null) {
                _officeDetails!['isOpen'] = isOpen;
              }
              if (_liveQueue != null) {
                _liveQueue!['isOpen'] = isOpen;
              }
            });
          }
        }
      },
    );
    _webSocketService?.connect();
  }

  Future<void> _loadDetails() async {
    setState(() => _loading = true);

    final details = await _officeService.getOfficeDetails(widget.officeId);
    final queue = await _officeService.getLiveQueue(widget.officeId);
    final providers = await _officeService.getOfficeProviders(widget.officeId);

    if (mounted) {
      setState(() {
        _officeDetails = details;
        _liveQueue = queue;
        _providers = providers;
        _loading = false;
      });
    }
  }

  Future<void> _promptSignInDialog({required String title, required String message}) async {
    final bool? goToLogin = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: const BoxDecoration(
                color: AppColors.primarySoft,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.lock_clock_outlined, color: AppColors.primary, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: AppColors.mainText),
              ),
            ),
          ],
        ),
        content: Text(
          message,
          style: const TextStyle(fontSize: 14, color: AppColors.secondaryText, height: 1.4),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: AppColors.mutedText, fontWeight: FontWeight.w600)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              elevation: 0,
            ),
            child: const Text('Sign In Now'),
          ),
        ],
      ),
    );

    if (goToLogin == true && mounted) {
      await CustomerAuthService().logout();
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const CustomerLoginScreen()),
        );
      }
    }
  }

  Future<void> _showBookingSheet([int? preselectedProviderId]) async {
    final isAuth = await CustomerAuthService().isLoggedIn();
    if (!mounted) return;
    if (!isAuth) {
      await _promptSignInDialog(
        title: 'Sign In Required',
        message: 'Your login session has expired or you are not signed in. Please sign in to join the queue and book a token.',
      );
      return;
    }

    final dailyMaxTokens = _liveQueue?['dailyMaxTokens'] ?? 60;
    final isOfficeFull = _liveQueue?['isOfficeFull'] == true;
    final bool isOpen = (_officeDetails?['isOpen'] ?? _liveQueue?['isOpen'] ?? true) == true;

    if (!isOpen) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Office is currently closed. Cannot book token at this time.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    if (isOfficeFull) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Office has reached its daily maximum limit of $dailyMaxTokens tokens. Queue is closed for today.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    final user = await _officeService.getCurrentUser();
    final nameController = TextEditingController(text: user?['name'] ?? '');
    final phoneController = TextEditingController();

    // Reset preselected provider if that provider is marked full or off duty
    final preselectedProvider = _providers.firstWhere(
      (p) => p['id'] == preselectedProviderId,
      orElse: () => null,
    );
    int? selectedProviderId = (preselectedProvider != null &&
            (preselectedProvider['providerFull'] == true ||
                preselectedProvider['availableNow'] == false ||
                preselectedProvider['onDuty'] == false))
        ? null
        : preselectedProviderId;

    final String category = (_officeDetails?['category'] ?? 'OTHER').toString().toUpperCase();
    final bool isClinic = category == 'CLINIC';

    if (!mounted) return;

    final booked = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
                top: 24,
                left: 24,
                right: 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Confirm Queue Token',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.mainText),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, size: 20, color: AppColors.mutedText),
                        onPressed: () => Navigator.pop(context, false),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'You will receive a live digital token for ${_officeDetails?['name'] ?? 'this office'}.',
                    style: const TextStyle(fontSize: 13, color: AppColors.secondaryText),
                  ),
                  const SizedBox(height: 20),

                  // Provider Selection (if office has providers configured)
                  if (_providers.isNotEmpty) ...[
                    Text(
                      isClinic ? 'Select Doctor / Staff' : 'Select Staff',
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.secondaryText),
                    ),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<int?>(
                      initialValue: selectedProviderId,
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.badge_outlined, size: 20, color: AppColors.primary),
                        filled: true,
                        fillColor: AppColors.background,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: AppColors.border),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: AppColors.border),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
                        ),
                      ),
                      items: [
                        DropdownMenuItem<int?>(
                          value: null,
                          child: Text(
                            isClinic ? 'Any Available Staff / Doctor' : 'Any Available Staff',
                            style: const TextStyle(fontSize: 14),
                          ),
                        ),
                        ..._providers.map((p) {
                          final name = p['name'] ?? 'Provider';
                          final desig = p['designation'] != null ? ' (${p['designation']})' : '';
                          final isFull = p['providerFull'] == true;
                          final isOnDuty = p['onDuty'] ?? true;
                          final isAvailable = (p['availableNow'] == true) && isOnDuty;
                          final bool canSelect = !isFull && isAvailable;
                          String statusSuffix = '';
                          if (!isOnDuty) {
                            statusSuffix = ' - Off duty';
                          } else if (!isAvailable) {
                            statusSuffix = ' - Off hours';
                          } else if (isFull) {
                            statusSuffix = ' - Limit reached';
                          } else if (p['dailyMaxTokens'] != null) {
                            statusSuffix = ' (${p['remainingCapacity']} left)';
                          }
                          return DropdownMenuItem<int?>(
                            value: p['id'] as int?,
                            enabled: canSelect,
                            child: Text(
                              '$name$desig$statusSuffix',
                              style: TextStyle(
                                fontSize: 14,
                                color: canSelect ? AppColors.mainText : AppColors.mutedText,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          );
                        }),
                      ],
                      onChanged: (val) {
                        setModalState(() {
                          selectedProviderId = val;
                        });
                      },
                    ),
                    const SizedBox(height: 14),
                  ],

                  // Name Field
                  const Text('Full Name', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.secondaryText)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: nameController,
                    decoration: InputDecoration(
                      hintText: 'Enter your name',
                      prefixIcon: const Icon(Icons.person_outline, size: 20, color: AppColors.primary),
                      filled: true,
                      fillColor: AppColors.background,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppColors.border),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppColors.border),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Phone Field
                  const Text('Phone Number (Optional)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.secondaryText)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: phoneController,
                    keyboardType: TextInputType.phone,
                    decoration: InputDecoration(
                      hintText: '+91 9876543210',
                      prefixIcon: const Icon(Icons.phone_outlined, size: 20, color: AppColors.primary),
                      filled: true,
                      fillColor: AppColors.background,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppColors.border),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppColors.border),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  ElevatedButton(
                    onPressed: () {
                      if (nameController.text.trim().isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Please enter your name')),
                        );
                        return;
                      }
                      Navigator.pop(context, true);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      elevation: 0,
                    ),
                    child: const Text('Get My Token Now', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            );
          },
        );
      },
    );

    if (booked == true) {
      setState(() => _booking = true);

      final result = await _officeService.bookToken(
        officeId: widget.officeId,
        providerId: selectedProviderId,
        customerName: nameController.text.trim(),
        customerPhone: phoneController.text.trim().isNotEmpty ? phoneController.text.trim() : null,
        customerEmail: user?['email'],
      );

      if (mounted) {
        setState(() => _booking = false);

        if (result['success'] == true) {
          final tokenData = result['data'];
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Token ${tokenData['tokenNumber']} booked successfully!'),
              backgroundColor: AppColors.primaryDark,
            ),
          );

          // Navigate to Active Token Screen
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => ActiveTokenScreen(initialTokenData: tokenData),
            ),
          );
        } else {
          final isAuthError = result['isAuthError'] == true ||
              (result['errorMessage'] != null &&
                  result['errorMessage'].toString().toLowerCase().contains('authentication'));
          if (isAuthError) {
            await _promptSignInDialog(
              title: 'Session Expired',
              message: 'Your login session has expired. Please sign in again to book your token.',
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(result['errorMessage'] ?? 'Failed to book token'),
                backgroundColor: AppColors.error,
              ),
            );
          }
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(child: CircularProgressIndicator(color: AppColors.primary)),
      );
    }

    if (_officeDetails == null) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(title: const Text('Office Details')),
        body: const Center(child: Text('Office details could not be found.')),
      );
    }

    final name = _officeDetails?['name'] ?? 'Office';
    final category = (_officeDetails?['category'] ?? 'OTHER').toString().toUpperCase();
    final bool isClinic = category == 'CLINIC';
    final address = _officeDetails?['address'] ?? '';
    final city = _officeDetails?['city'] ?? '';
    final state = _officeDetails?['state'] ?? '';
    final pincode = _officeDetails?['pincode'] ?? '';
    final openingTime = _officeDetails?['openingTime'] ?? '09:00 AM';
    final closingTime = _officeDetails?['closingTime'] ?? '08:00 PM';
    final description = _officeDetails?['description'] ?? '';

    final doctorName = _officeDetails?['doctorName'];
    final specialization = _officeDetails?['specialization'];
    final salonType = _officeDetails?['salonType'];

    final waitingCount = _liveQueue?['waitingCount'] ?? _officeDetails?['waitingCount'] ?? 0;
    final activeToken = _liveQueue?['activeToken'] ?? _officeDetails?['activeToken'];
    final estWait = waitingCount * 12;

    final int dailyMaxTokens = _liveQueue?['dailyMaxTokens'] ?? 60;
    final int todayTokensCount = _liveQueue?['todayTokensCount'] ?? 0;
    final int remainingCapacity = _liveQueue?['remainingCapacity'] ?? (dailyMaxTokens - todayTokensCount);
    final bool isOfficeFull = _liveQueue?['isOfficeFull'] == true || remainingCapacity <= 0;
    final bool isOfficeOpen = (_officeDetails?['isOpen'] ?? _liveQueue?['isOpen'] ?? true) == true;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: AppColors.mainText,
        elevation: 0.5,
        title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17, color: AppColors.mainText)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: AppColors.primary),
            tooltip: 'Refresh queue status',
            onPressed: _loadDetails,
          ),
        ],
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          border: const Border(top: BorderSide(color: AppColors.borderLight, width: 1)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, -3),
            ),
          ],
        ),
        child: SafeArea(
          child: Builder(
            builder: (context) {
              final bool canJoinQueue = !_booking && !isOfficeFull && isOfficeOpen;
              String joinButtonText = 'Join Queue / Book Token';
              IconData joinButtonIcon = Icons.confirmation_number_rounded;
              Color joinButtonColor = AppColors.primary;

              if (_booking) {
                joinButtonText = 'Booking...';
              } else if (!isOfficeOpen) {
                joinButtonText = 'Office is Closed';
                joinButtonIcon = Icons.lock_clock_rounded;
                joinButtonColor = AppColors.border;
              } else if (isOfficeFull) {
                joinButtonText = 'Daily Limit Reached (Queue Closed)';
                joinButtonIcon = Icons.block_rounded;
                joinButtonColor = AppColors.border;
              }

              return ElevatedButton.icon(
                onPressed: canJoinQueue ? _showBookingSheet : null,
                icon: _booking
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : Icon(joinButtonIcon),
                label: Text(
                  joinButtonText,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: canJoinQueue ? Colors.white : AppColors.mutedText,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: joinButtonColor,
                  foregroundColor: canJoinQueue ? Colors.white : AppColors.mutedText,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
              );
            },
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Top Profile Card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: AppColors.primaryGradient,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primaryDark.withValues(alpha: 0.25),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
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
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: isOfficeOpen ? AppColors.success : AppColors.error,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 6,
                                  height: 6,
                                  decoration: const BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  isOfficeOpen ? 'OPEN' : 'CLOSED',
                                  style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.25),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.verified_rounded, color: Colors.white, size: 14),
                                SizedBox(width: 4),
                                Text('Verified', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    [address, city, state, pincode].where((e) => e.toString().isNotEmpty).join(', '),
                    style: const TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Office Closed Warning Banner
            if (!isOfficeOpen) ...[
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.errorSoft,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.error.withValues(alpha: 0.4)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.lock_clock_rounded, color: AppColors.error, size: 22),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'This office is currently closed / offline. Queue booking is temporarily disabled.',
                        style: TextStyle(
                          color: AppColors.error,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          height: 1.3,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // Office Full Warning Banner
            if (isOfficeFull) ...[
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.errorSoft,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.error.withValues(alpha: 0.4)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline_rounded, color: AppColors.error, size: 22),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'This office has reached its maximum daily limit of $dailyMaxTokens tokens. New queue tokens are blocked for today.',
                        style: const TextStyle(
                          color: AppColors.error,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          height: 1.3,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // Live Queue Status Box
            const Text(
              'Live Queue Overview',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.mainText),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: isOfficeFull ? AppColors.error.withValues(alpha: 0.4) : AppColors.border,
                ),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Now Serving', style: TextStyle(fontSize: 12, color: AppColors.mutedText, fontWeight: FontWeight.w600)),
                            const SizedBox(height: 4),
                            Text(
                              activeToken != null ? '#$activeToken' : 'None',
                              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: AppColors.primary),
                            ),
                          ],
                        ),
                      ),
                      Container(width: 1, height: 44, color: AppColors.border),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Waiting in Line', style: TextStyle(fontSize: 12, color: AppColors.mutedText, fontWeight: FontWeight.w600)),
                            const SizedBox(height: 4),
                            Text(
                              '$waitingCount people',
                              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: AppColors.cyanDark),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Divider(height: 1, color: AppColors.borderLight),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      const Icon(Icons.timer_outlined, color: AppColors.warning, size: 18),
                      const SizedBox(width: 8),
                      Text(
                        'Estimated wait time: ~${estWait > 0 ? estWait : 5} minutes',
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.secondaryText),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Icon(
                        isOfficeFull ? Icons.warning_amber_rounded : Icons.offline_pin_outlined,
                        color: isOfficeFull ? AppColors.error : AppColors.primary,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          isOfficeFull
                              ? 'Daily capacity reached ($todayTokensCount/$dailyMaxTokens tokens generated today)'
                              : 'Daily capacity: $remainingCapacity of $dailyMaxTokens tokens remaining today',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: isOfficeFull ? AppColors.error : AppColors.primaryDark,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Providers & Staff Section
            if (_providers.isNotEmpty) ...[
              Text(
                isClinic ? 'Available Doctors & Staff' : 'Available Staff',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.mainText),
              ),
              const SizedBox(height: 12),
              ..._providers.map((p) => _buildProviderCard(p)),
              const SizedBox(height: 20),
            ],

            // Category Details
            if (isClinic) ...[
              _buildSectionCard(
                title: 'Doctor Information',
                icon: Icons.medical_services_outlined,
                items: [
                  {'label': 'Doctor Name', 'value': doctorName ?? 'Available on site'},
                  if (specialization != null) {'label': 'Specialization', 'value': specialization},
                ],
              ),
              const SizedBox(height: 16),
            ],

            if (category == 'SALON' || salonType != null) ...[
              _buildSectionCard(
                title: 'Salon Information',
                icon: Icons.content_cut_outlined,
                items: [
                  {'label': 'Salon Type', 'value': salonType ?? 'Unisex Salon'},
                ],
              ),
              const SizedBox(height: 16),
            ],

            // Operating Hours
            _buildSectionCard(
              title: 'Operating Timings',
              icon: Icons.access_time_rounded,
              items: [
                {'label': 'Opening Time', 'value': openingTime},
                {'label': 'Closing Time', 'value': closingTime},
                {'label': 'Queue Generation', 'value': 'Enabled Today'},
              ],
            ),
            const SizedBox(height: 16),

            // Description if present
            if (description.isNotEmpty) ...[
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('About', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.mainText)),
                    const SizedBox(height: 6),
                    Text(description, style: const TextStyle(fontSize: 13, color: AppColors.secondaryText, height: 1.4)),
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required List<Map<String, String>> items,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: AppColors.primary),
              const SizedBox(width: 8),
              Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.mainText)),
            ],
          ),
          const SizedBox(height: 14),
          ...items.map((item) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(item['label']!, style: const TextStyle(fontSize: 13, color: AppColors.mutedText)),
                    Text(item['value']!, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.mainText)),
                  ],
                ),
              )),
        ],
      ),
    );
  }

  Widget _buildProviderCard(Map<String, dynamic> p) {
    final int? id = p['id'] as int?;
    final name = p['name'] ?? 'Provider';
    final desig = p['designation'] ?? 'Specialist';
    final bool onDuty = p['onDuty'] ?? true;
    final bool availableNow = (p['availableNow'] ?? false) && onDuty;
    final todayHours = p['todayWorkingHours'] ?? 'Today: Off';
    final bool isProviderFull = p['providerFull'] == true;
    final int? dailyLimit = p['dailyMaxTokens'] as int?;
    final remainingCapacity = p['remainingCapacity'];

    String capacityText = '';
    if (dailyLimit != null) {
      if (isProviderFull) {
        capacityText = 'Daily limit reached (Full)';
      } else {
        capacityText = 'Capacity: $remainingCapacity / $dailyLimit left today';
      }
    }

    final bool isOfficeOpen = _officeDetails?['isOpen'] != false;
    final bool canBook = isOfficeOpen && availableNow && !isProviderFull;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isProviderFull ? AppColors.error.withValues(alpha: 0.3) : AppColors.border,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: const BoxDecoration(
              color: AppColors.primarySoft,
              borderRadius: BorderRadius.all(Radius.circular(10)),
            ),
            child: const Icon(Icons.person_outline_rounded, color: AppColors.primary, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.mainText)),
                const SizedBox(height: 3),
                Row(
                  children: [
                    Text(desig, style: const TextStyle(fontSize: 12, color: AppColors.primaryDark, fontWeight: FontWeight.w600)),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: onDuty
                            ? AppColors.successSoft
                            : AppColors.borderLight,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 5,
                            height: 5,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: onDuty ? AppColors.success : AppColors.mutedText,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            onDuty ? 'ON DUTY' : 'OFF DUTY',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              color: onDuty ? AppColors.success : AppColors.secondaryText,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(todayHours, style: const TextStyle(fontSize: 11, color: AppColors.mutedText)),
                if (capacityText.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    capacityText,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: isProviderFull ? AppColors.error : AppColors.primaryDark,
                    ),
                  ),
                ],
              ],
            ),
          ),
          InkWell(
            onTap: canBook ? () => _showBookingSheet(id) : null,
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: canBook
                    ? AppColors.primarySoft
                    : (!isOfficeOpen || isProviderFull
                        ? AppColors.errorSoft
                        : AppColors.borderLight),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    canBook
                        ? 'Book'
                        : (!isOfficeOpen
                            ? 'Closed'
                            : (isProviderFull ? 'Full' : (!onDuty ? 'Off duty' : 'Off hours'))),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: canBook
                          ? AppColors.primaryDark
                          : (!isOfficeOpen || isProviderFull
                              ? AppColors.error
                              : AppColors.secondaryText),
                    ),
                  ),
                  if (canBook) ...[
                    const SizedBox(width: 4),
                    const Icon(Icons.arrow_forward_rounded, size: 12, color: AppColors.primaryDark),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

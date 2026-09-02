import 'package:flutter/material.dart';
import '../../services/office_service.dart';
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

  @override
  void initState() {
    super.initState();
    _loadDetails();
  }

  Future<void> _loadDetails() async {
    setState(() => _loading = true);

    final details = await _officeService.getOfficeDetails(widget.officeId);
    final queue = await _officeService.getLiveQueue(widget.officeId);

    if (mounted) {
      setState(() {
        _officeDetails = details;
        _liveQueue = queue;
        _loading = false;
      });
    }
  }

  Future<void> _showBookingSheet() async {
    final user = await _officeService.getCurrentUser();
    final nameController = TextEditingController(text: user?['name'] ?? '');
    final phoneController = TextEditingController();

    if (!mounted) return;

    final booked = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
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
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 20),
                    onPressed: () => Navigator.pop(context, false),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'You will receive a live digital token for ${_officeDetails?['name'] ?? 'this office'}.',
                style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
              ),
              const SizedBox(height: 20),

              // Name Field
              const Text('Full Name', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF334155))),
              const SizedBox(height: 6),
              TextField(
                controller: nameController,
                decoration: InputDecoration(
                  hintText: 'Enter your name',
                  prefixIcon: const Icon(Icons.person_outline, size: 20),
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // Phone Field
              const Text('Phone Number (Optional)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF334155))),
              const SizedBox(height: 6),
              TextField(
                controller: phoneController,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  hintText: '+91 9876543210',
                  prefixIcon: const Icon(Icons.phone_outlined, size: 20),
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
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
                  backgroundColor: const Color(0xFF4F46E5),
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

    if (booked == true) {
      setState(() => _booking = true);

      final result = await _officeService.bookToken(
        officeId: widget.officeId,
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
              backgroundColor: const Color(0xFF10B981),
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
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result['errorMessage'] ?? 'Failed to book token'),
              backgroundColor: const Color(0xFFEF4444),
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: Color(0xFFF8FAFC),
        body: Center(child: CircularProgressIndicator(color: Color(0xFF4F46E5))),
      );
    }

    if (_officeDetails == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Office Details')),
        body: const Center(child: Text('Office details could not be found.')),
      );
    }

    final name = _officeDetails?['name'] ?? 'Office';
    final category = _officeDetails?['category'] ?? 'OTHER';
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

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF0F172A),
        elevation: 0.5,
        title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh queue status',
            onPressed: _loadDetails,
          ),
        ],
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, -3),
            ),
          ],
        ),
        child: SafeArea(
          child: ElevatedButton.icon(
            onPressed: _booking ? null : _showBookingSheet,
            icon: _booking
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.confirmation_number_rounded),
            label: Text(
              _booking ? 'Booking...' : 'Join Queue / Book Token',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4F46E5),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              elevation: 0,
            ),
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
                gradient: const LinearGradient(
                  colors: [Color(0xFF4F46E5), Color(0xFF6366F1)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF4F46E5).withValues(alpha: 0.25),
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
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981),
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

            // Live Queue Status Box
            const Text(
              'Live Queue Overview',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Now Serving', style: TextStyle(fontSize: 12, color: Color(0xFF64748B), fontWeight: FontWeight.w600)),
                            const SizedBox(height: 4),
                            Text(
                              activeToken != null ? '#$activeToken' : 'None',
                              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Color(0xFF10B981)),
                            ),
                          ],
                        ),
                      ),
                      Container(width: 1, height: 44, color: const Color(0xFFE2E8F0)),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Waiting in Line', style: TextStyle(fontSize: 12, color: Color(0xFF64748B), fontWeight: FontWeight.w600)),
                            const SizedBox(height: 4),
                            Text(
                              '$waitingCount people',
                              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Color(0xFF4F46E5)),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Divider(height: 1),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      const Icon(Icons.timer_outlined, color: Color(0xFFF59E0B), size: 18),
                      const SizedBox(width: 8),
                      Text(
                        'Estimated wait time: ~${estWait > 0 ? estWait : 5} minutes',
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Category Details
            if (category == 'CLINIC' || doctorName != null) ...[
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
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('About', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                    const SizedBox(height: 6),
                    Text(description, style: const TextStyle(fontSize: 13, color: Color(0xFF64748B), height: 1.4)),
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
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: const Color(0xFF4F46E5)),
              const SizedBox(width: 8),
              Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
            ],
          ),
          const SizedBox(height: 14),
          ...items.map((item) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(item['label']!, style: const TextStyle(fontSize: 13, color: Color(0xFF64748B))),
                    Text(item['value']!, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF1E293B))),
                  ],
                ),
              )),
        ],
      ),
    );
  }
}

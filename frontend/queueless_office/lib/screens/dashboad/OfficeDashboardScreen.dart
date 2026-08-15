import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:queueless_office/screens/auth/office_auth_screen.dart';
import 'package:queueless_office/screens/dashboad/office_onboarding_screen.dart';

class OfficeDashboardScreen extends StatefulWidget {
  const OfficeDashboardScreen({super.key});

  @override
  State<OfficeDashboardScreen> createState() => _OfficeDashboardScreenState();
}

class _OfficeDashboardScreenState extends State<OfficeDashboardScreen> {
  final _storage = const FlutterSecureStorage();
  bool _loading = true;
  String? _error;

  Map<String, dynamic>? _userData;
  Map<String, dynamic>? _profileData;
  List<dynamic> _documents = [];

  // For Approved state tab switching: 0 -> Queue Dashboard, 1 -> Office Profile Details
  int _approvedSelectedTab = 0;

  String get _baseUrl => kIsWeb
      ? 'http://localhost:8080/api/office/profile'
      : 'http://10.0.2.2:8080/api/office/profile';

  @override
  void initState() {
    super.initState();
    _fetchProfile();
  }

  Future<void> _fetchProfile() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final token = await _storage.read(key: 'jwt_token');
      if (token == null) {
        _navigateToAuth();
        return;
      }

      final response = await http.get(
        Uri.parse(_baseUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (mounted) {
          setState(() {
            _userData = data['user'];
            _profileData = data['profile'];
            if (_profileData != null && _profileData!['documents'] != null) {
              _documents = _profileData!['documents'];
            }
            _loading = false;
          });
        }
      } else if (response.statusCode == 401 || response.statusCode == 403) {
        await _logout();
      } else {
        setState(() {
          _error = 'Failed to load details: ${response.statusCode}';
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Network error: $e';
          _loading = false;
        });
      }
    }
  }

  Future<void> _logout() async {
    await _storage.delete(key: 'jwt_token');
    if (mounted) {
      _navigateToAuth();
    }
  }

  void _navigateToAuth() {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const OfficeAuthScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final status = _profileData?['verificationStatus'] ?? 'PENDING';
    final isApproved = status == 'APPROVED';

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(
          isApproved ? 'Office Queue Dashboard' : 'Office Verification Status',
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
        ),
        backgroundColor: const Color(0xFF4F46E5),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh',
            onPressed: _fetchProfile,
          ),
          IconButton(
            icon: const Icon(Icons.logout_rounded),
            tooltip: 'Logout',
            onPressed: _logout,
          ),
        ],
      ),
      body: _buildBody(),
      bottomNavigationBar: (isApproved && _profileData != null)
          ? BottomNavigationBar(
              currentIndex: _approvedSelectedTab,
              selectedItemColor: const Color(0xFF4F46E5),
              unselectedItemColor: const Color(0xFF94A3B8),
              onTap: (index) => setState(() => _approvedSelectedTab = index),
              items: const [
                BottomNavigationBarItem(
                  icon: Icon(Icons.dashboard_rounded),
                  label: 'Queue Ops',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.business_rounded),
                  label: 'Office Details',
                ),
              ],
            )
          : null,
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Color(0xFF4F46E5)),
            SizedBox(height: 16),
            Text('Loading office details...', style: TextStyle(color: Color(0xFF64748B))),
          ],
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline_rounded, color: Color(0xFFEF4444), size: 48),
              const SizedBox(height: 12),
              Text(_error!, textAlign: TextAlign.center, style: const TextStyle(fontSize: 15, color: Color(0xFF334155))),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _fetchProfile,
                icon: const Icon(Icons.refresh),
                label: const Text('Try Again'),
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF4F46E5), foregroundColor: Colors.white),
              ),
            ],
          ),
        ),
      );
    }

    // Profile not yet created
    if (_profileData == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: const Color(0xFF4F46E5).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Icon(Icons.business_outlined, color: Color(0xFF4F46E5), size: 40),
              ),
              const SizedBox(height: 20),
              Text(
                'Welcome, ${_userData?['name'] ?? 'Office'}!',
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
              ),
              const SizedBox(height: 8),
              const Text(
                'You haven’t completed your office onboarding yet.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: Color(0xFF64748B)),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const OfficeOnboardingScreen()),
                  ).then((_) => _fetchProfile());
                },
                icon: const Icon(Icons.arrow_forward_rounded),
                label: const Text('Complete Office Setup'),
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

    final status = _profileData?['verificationStatus'] ?? 'PENDING';

    // 1. APPROVED STATE: Show Queue Dashboard Screen (or Profile Tab if switched)
    if (status == 'APPROVED') {
      if (_approvedSelectedTab == 0) {
        return _buildApprovedDashboardView();
      } else {
        return _buildDetailsOnlyView(status);
      }
    }

    // 2. PENDING / REJECTED STATE: Just show Details view with banner
    return _buildDetailsOnlyView(status);
  }

  // ==========================================
  // VIEW 1: APPROVED OPERATIONAL DASHBOARD
  // ==========================================
  Widget _buildApprovedDashboardView() {
    final officeName = _userData?['name'] ?? 'Office';
    final category = _profileData?['category'] ?? 'OFFICE';

    return RefreshIndicator(
      onRefresh: _fetchProfile,
      color: const Color(0xFF4F46E5),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Welcome Header Card
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
                    color: const Color(0xFF4F46E5).withValues(alpha: 0.3),
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
                      Row(
                        children: [
                          Icon(_getCategoryIcon(category), color: Colors.white, size: 24),
                          const SizedBox(width: 8),
                          Text(
                            category,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
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
                            Text(
                              'Verified',
                              style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    officeName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Operating Hours: ${_profileData?['openingTime'] ?? '09:00 AM'} - ${_profileData?['closingTime'] ?? '08:00 PM'}',
                    style: const TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Live Queue Metrics
            const Text(
              'Live Queue Overview',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _buildMetricCard('Serving Token', '#12', Icons.play_circle_fill_rounded, const Color(0xFF10B981))),
                const SizedBox(width: 12),
                Expanded(child: _buildMetricCard('Waiting in Queue', '8', Icons.people_alt_rounded, const Color(0xFFF59E0B))),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _buildMetricCard('Total Served', '45', Icons.check_circle_rounded, const Color(0xFF3B82F6))),
                const SizedBox(width: 12),
                Expanded(child: _buildMetricCard('Avg. Wait Time', '12 min', Icons.timer_rounded, const Color(0xFF8B5CF6))),
              ],
            ),
            const SizedBox(height: 24),

            // Queue Action Controller
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Active Desk Counter #1',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                      ),
                      Text('Status: Active', style: TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.w600, fontSize: 12)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Column(
                      children: [
                        Text('CURRENT TOKEN', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF64748B))),
                        SizedBox(height: 6),
                        Text(
                          'A-012',
                          style: TextStyle(fontSize: 36, fontWeight: FontWeight.w900, color: Color(0xFF4F46E5), letterSpacing: 1),
                        ),
                        SizedBox(height: 4),
                        Text('Customer: John Doe (+91 9876543210)', style: TextStyle(fontSize: 13, color: Color(0xFF334155))),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Token A-012 marked as Hold/Skipped')),
                            );
                          },
                          icon: const Icon(Icons.pause_circle_outline, size: 18),
                          label: const Text('Hold / Skip'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF64748B),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Calling next token: A-013')),
                            );
                          },
                          icon: const Icon(Icons.skip_next_rounded, size: 20),
                          label: const Text('Call Next'),
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
            ),
            const SizedBox(height: 20),

            // Button to View Office Details
            OutlinedButton.icon(
              onPressed: () => setState(() => _approvedSelectedTab = 1),
              icon: const Icon(Icons.info_outline_rounded),
              label: const Text('View Full Office Details & Documents'),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF4F46E5),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B), fontWeight: FontWeight.w600)),
              Icon(icon, color: color, size: 20),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: color),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // VIEW 2: DETAILS ONLY (FOR PENDING / REJECTED)
  // ==========================================
  Widget _buildDetailsOnlyView(String status) {
    final category = _profileData?['category'] ?? 'OFFICE';

    return RefreshIndicator(
      onRefresh: _fetchProfile,
      color: const Color(0xFF4F46E5),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Status Alert Banner (PENDING / REJECTED)
            _buildStatusAlertBanner(status),
            const SizedBox(height: 16),

            // Header Profile Card
            _buildHeaderCard(category, status),
            const SizedBox(height: 16),

            // Category-Specific Details
            _buildCategoryDetailsCard(category),
            const SizedBox(height: 16),

            // Location & Timings
            _buildLocationAndTimingsCard(),
            const SizedBox(height: 16),

            // Uploaded Documents
            _buildDocumentsCard(),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  // STATUS BANNER FOR PENDING OR REJECTED
  Widget _buildStatusAlertBanner(String status) {
    if (status == 'PENDING') {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFFFFBEB),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFFDE68A)),
        ),
        child: const Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.hourglass_top_rounded, color: Color(0xFFD97706), size: 24),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Application Under Review',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF92400E)),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Your office profile and documents are currently being verified by the admin team. Once approved, the live queue dashboard will automatically unlock.',
                    style: TextStyle(fontSize: 12, color: Color(0xFFB45309), height: 1.4),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    } else if (status == 'REJECTED') {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFFEF2F2),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFFECACA)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.cancel_rounded, color: Color(0xFFDC2626), size: 24),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Verification Rejected',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF991B1B)),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Your submitted verification documents could not be approved. Please review your details and re-upload clear documents.',
                        style: TextStyle(fontSize: 12, color: Color(0xFFB91C1C), height: 1.4),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const OfficeOnboardingScreen()),
                ).then((_) => _fetchProfile());
              },
              icon: const Icon(Icons.edit_document, size: 16),
              label: const Text('Update & Resubmit Documents'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFDC2626),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
      );
    }

    return const SizedBox.shrink();
  }

  // HEADER CARD
  Widget _buildHeaderCard(String category, String status) {
    Color statusColor;
    IconData statusIcon;
    String statusText;

    switch (status) {
      case 'APPROVED':
        statusColor = const Color(0xFF10B981);
        statusIcon = Icons.verified_rounded;
        statusText = 'Verified & Active';
        break;
      case 'REJECTED':
        statusColor = const Color(0xFFEF4444);
        statusIcon = Icons.cancel_outlined;
        statusText = 'Rejected';
        break;
      default:
        statusColor = const Color(0xFFF59E0B);
        statusIcon = Icons.hourglass_top_rounded;
        statusText = 'Under Verification';
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.05),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF4F46E5), Color(0xFF6366F1)],
                  ),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(_getCategoryIcon(category), color: Colors.white, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _userData?['name'] ?? 'Office Name',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF4F46E5).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        category,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF4F46E5),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(height: 1),
          const SizedBox(height: 16),

          // Status & Contact Info
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: statusColor.withValues(alpha: 0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(statusIcon, color: statusColor, size: 16),
                    const SizedBox(width: 6),
                    Text(
                      statusText,
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: statusColor),
                    ),
                  ],
                ),
              ),
              Text(
                'ID: #${_profileData?['id'] ?? '---'}',
                style: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8), fontWeight: FontWeight.w600),
              ),
            ],
          ),
          if (_profileData?['description'] != null && (_profileData?['description'] as String).isNotEmpty) ...[
            const SizedBox(height: 14),
            Text(
              _profileData!['description'],
              style: const TextStyle(fontSize: 13, color: Color(0xFF64748B), height: 1.4),
            ),
          ],
        ],
      ),
    );
  }

  // CATEGORY DETAILS CARD
  Widget _buildCategoryDetailsCard(String category) {
    List<Widget> items = [];

    if (category == 'CLINIC') {
      items = [
        _buildInfoRow(Icons.person_outline, 'Doctor / Specialist', _profileData?['doctorName'] ?? 'N/A'),
        _buildInfoRow(Icons.medical_services_outlined, 'Specialization', _profileData?['specialization'] ?? 'General'),
        _buildInfoRow(Icons.badge_outlined, 'Medical Reg. No.', _profileData?['medicalRegistrationNumber'] ?? 'N/A'),
      ];
    } else if (category == 'SALON') {
      items = [
        _buildInfoRow(Icons.content_cut_outlined, 'Salon Type', _profileData?['salonType'] ?? 'Unisex'),
        _buildInfoRow(Icons.assignment_outlined, 'Trade License / GST', _profileData?['tradeLicenseNumber'] ?? 'N/A'),
      ];
    } else {
      items = [
        _buildInfoRow(Icons.domain_outlined, 'Business Type / Industry', _profileData?['specialization'] ?? 'General Business'),
        _buildInfoRow(Icons.assignment_outlined, 'License / Reg. Number', _profileData?['tradeLicenseNumber'] ?? 'N/A'),
      ];
    }

    return _buildSectionCard(
      title: '$category Information',
      icon: Icons.info_outline,
      children: items,
    );
  }

  // LOCATION & TIMINGS CARD
  Widget _buildLocationAndTimingsCard() {
    final address = '${_profileData?['address'] ?? ''}, ${_profileData?['city'] ?? ''}, ${_profileData?['state'] ?? ''} - ${_profileData?['pincode'] ?? ''}';
    final timings = '${_profileData?['openingTime'] ?? '09:00 AM'} - ${_profileData?['closingTime'] ?? '08:00 PM'}';

    return _buildSectionCard(
      title: 'Location & Working Hours',
      icon: Icons.location_on_outlined,
      children: [
        _buildInfoRow(Icons.email_outlined, 'Email', _userData?['email'] ?? 'N/A'),
        _buildInfoRow(Icons.phone_outlined, 'Phone', _profileData?['phone'] ?? 'N/A'),
        _buildInfoRow(Icons.map_outlined, 'Address', address),
        _buildInfoRow(Icons.access_time_rounded, 'Working Hours', timings),
      ],
    );
  }

  // DOCUMENTS CARD
  Widget _buildDocumentsCard() {
    return _buildSectionCard(
      title: 'Uploaded Verification Documents',
      icon: Icons.folder_shared_outlined,
      children: [
        if (_documents.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text('No documents uploaded yet.', style: TextStyle(fontSize: 13, color: Color(0xFF94A3B8))),
          )
        else
          ..._documents.map((doc) {
            final docType = doc['documentType'] ?? 'Document';
            final fileName = doc['originalFileName'] ?? 'document.pdf';
            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.picture_as_pdf_outlined, color: Color(0xFFEF4444), size: 28),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _formatDocType(docType),
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Color(0xFF1E293B)),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          fileName,
                          style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 20),
                ],
              ),
            );
          }),
      ],
    );
  }

  // HELPER CARD CONTAINER
  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.04),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: const Color(0xFF4F46E5)),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(height: 1),
          const SizedBox(height: 14),
          ...children,
        ],
      ),
    );
  }

  // HELPER INFO ROW
  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: const Color(0xFF94A3B8)),
          const SizedBox(width: 10),
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(fontSize: 13, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 13, color: Color(0xFF0F172A), fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  IconData _getCategoryIcon(String category) {
    switch (category) {
      case 'CLINIC':
        return Icons.local_hospital_rounded;
      case 'SALON':
        return Icons.content_cut_rounded;
      default:
        return Icons.business_rounded;
    }
  }

  String _formatDocType(String type) {
    switch (type) {
      case 'CLINIC_REGISTRATION':
        return 'Clinic Registration Certificate';
      case 'DOCTOR_DEGREE':
        return 'Doctor Degree / Certificate';
      case 'TRADE_LICENSE':
        return 'Trade / Business License';
      case 'OWNER_ID_PROOF':
        return 'Owner / Representative ID';
      case 'BUSINESS_REGISTRATION':
        return 'Business Registration';
      default:
        return type.replaceAll('_', ' ');
    }
  }
}
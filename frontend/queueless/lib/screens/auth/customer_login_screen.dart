import 'package:flutter/material.dart';
import '../../services/customer_auth_service.dart';
import '../dashboard/customer_dashboard_screen.dart';

class CustomerLoginScreen extends StatefulWidget {
  const CustomerLoginScreen({super.key});

  @override
  State<CustomerLoginScreen> createState() => _CustomerLoginScreenState();
}

class _CustomerLoginScreenState extends State<CustomerLoginScreen> {
  final CustomerAuthService _authService = CustomerAuthService();
  bool _loading = false;

  Future<void> _handleGoogleSignIn() async {
    setState(() => _loading = true);

    try {
      final result = await _authService.signInWithGoogle();

      if (result.success) {
        if (!mounted) return;

        if (result.isNewUser) {
          // New Customer: Prompt for Terms & Conditions confirmation
          final accepted = await _showTermsAndConditionsDialog();
          if (accepted == true) {
            _showSnackBar(
              'Account created & confirmed! Welcome to QueueLess! 🎉',
              isError: false,
            );
            _navigateToHome(result.user);
          } else {
            // User declined terms -> sign out & cancel
            await _authService.logout();
            _showSnackBar(
              'Terms & Conditions declined. Registration canceled.',
              isError: true,
            );
          }
        } else {
          // Existing customer -> welcome back
          _showSnackBar(
            'Welcome back to QueueLess! 👋',
            isError: false,
          );
          _navigateToHome(result.user);
        }
      } else {
        _showSnackBar(
          result.errorMessage ?? 'Google sign-in was canceled or failed.',
          isError: true,
        );
      }
    } catch (e) {
      _showSnackBar('Authentication error: $e', isError: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ========================================================
  // TERMS AND CONDITIONS CONFIRMATION DIALOG FOR NEW USERS
  // ========================================================
  Future<bool?> _showTermsAndConditionsDialog() {
    bool agreed = true;

    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
              titlePadding: const EdgeInsets.fromLTRB(22, 22, 22, 10),
              contentPadding: const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
              actionsPadding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF4F46E5).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.gavel_rounded, color: Color(0xFF4F46E5), size: 22),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Terms & Conditions',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                  ),
                ],
              ),
              content: SizedBox(
                width: 440,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Welcome! Please review and confirm our terms to complete your customer account setup:',
                      style: TextStyle(fontSize: 13, color: Color(0xFF64748B), height: 1.4),
                    ),
                    const SizedBox(height: 14),

                    // Scrollable terms summary
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildTermItem(
                            icon: Icons.confirmation_number_outlined,
                            title: 'Virtual Tokens',
                            desc: 'Digital queue tokens are valid for the booked date & business hours only.',
                          ),
                          const SizedBox(height: 10),
                          _buildTermItem(
                            icon: Icons.notifications_active_outlined,
                            title: 'Timely Turn Arrival',
                            desc: 'Arrive when your estimated turn is called to avoid token cancellation.',
                          ),
                          const SizedBox(height: 10),
                          _buildTermItem(
                            icon: Icons.privacy_tip_outlined,
                            title: 'Privacy & Data Protection',
                            desc: 'Your Google profile (name & email) is securely encrypted and stored.',
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Consent checkbox
                    InkWell(
                      onTap: () {
                        setModalState(() {
                          agreed = !agreed;
                        });
                      },
                      borderRadius: BorderRadius.circular(8),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 24,
                              height: 24,
                              child: Checkbox(
                                value: agreed,
                                activeColor: const Color(0xFF4F46E5),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                                onChanged: (val) {
                                  setModalState(() {
                                    agreed = val ?? false;
                                  });
                                },
                              ),
                            ),
                            const SizedBox(width: 10),
                            const Expanded(
                              child: Text(
                                'I agree to the Terms of Service & Privacy Policy',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF1E293B),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Decline', style: TextStyle(color: Color(0xFF64748B))),
                ),
                ElevatedButton(
                  onPressed: agreed ? () => Navigator.pop(context, true) : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4F46E5),
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: const Color(0xFFCBD5E1),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    elevation: 0,
                  ),
                  child: const Text('Agree & Continue'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  static Widget _buildTermItem({
    required IconData icon,
    required String title,
    required String desc,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: const Color(0xFF4F46E5)),
        const SizedBox(width: 8),
        Expanded(
          child: RichText(
            text: TextSpan(
              style: const TextStyle(fontSize: 12, color: Color(0xFF334155), height: 1.3),
              children: [
                TextSpan(
                  text: '$title: ',
                  style: const TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                ),
                TextSpan(text: desc),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _navigateToHome(Map<String, dynamic>? user) {
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        builder: (context) => CustomerDashboardScreen(user: user),
      ),
      (route) => false,
    );
  }

  void _showSnackBar(String message, {required bool isError}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError ? Icons.error_outline_rounded : Icons.check_circle_rounded,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
              ),
            ),
          ],
        ),
        backgroundColor: isError ? const Color(0xFFEF4444) : const Color(0xFF10B981),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // App Logo with gradient background and glow
                  Container(
                    width: 76,
                    height: 76,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF4F46E5), Color(0xFF7C3AED)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF4F46E5).withValues(alpha: 0.35),
                          blurRadius: 24,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.access_time_filled_rounded,
                      color: Colors.white,
                      size: 40,
                    ),
                  ),
                  const SizedBox(height: 22),

                  // Brand Title
                  const Text(
                    'QueueLess',
                    style: TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0F172A),
                      letterSpacing: -0.6,
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Subtitle
                  const Text(
                    'Smart Queue Management • Skip physical lines & save your time.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: Color(0xFF64748B),
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 36),

                  // Main Interactive Card
                  Container(
                    padding: const EdgeInsets.all(28),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF0F172A).withValues(alpha: 0.06),
                          blurRadius: 30,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Feature Pills
                        _buildFeatureRow(
                          icon: Icons.confirmation_number_outlined,
                          color: const Color(0xFF4F46E5),
                          title: 'Digital Queue Tokens',
                          subtitle: 'Book tokens remotely without standing in line',
                        ),
                        const SizedBox(height: 14),
                        _buildFeatureRow(
                          icon: Icons.notifications_active_outlined,
                          color: const Color(0xFF059669),
                          title: 'Live Turn Notifications',
                          subtitle: 'Get notified when your turn is approaching',
                        ),
                        const SizedBox(height: 14),
                        _buildFeatureRow(
                          icon: Icons.qr_code_scanner_rounded,
                          color: const Color(0xFFD97706),
                          title: 'Instant QR Check-in',
                          subtitle: 'Scan office QR codes for fast queue entry',
                        ),
                        const SizedBox(height: 28),

                        const Divider(color: Color(0xFFF1F5F9), height: 1),
                        const SizedBox(height: 24),

                        // Google 1-Tap Sign In / Register Button
                        SizedBox(
                          height: 54,
                          child: OutlinedButton(
                            onPressed: _loading ? null : _handleGoogleSignIn,
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: Color(0xFFCBD5E1), width: 1.5),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                              backgroundColor: Colors.white,
                              elevation: 0,
                            ),
                            child: _loading
                                ? const SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(
                                      color: Color(0xFF4F46E5),
                                      strokeWidth: 2.5,
                                    ),
                                  )
                                : Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Image.network(
                                        'https://www.gstatic.com/firebasejs/ui/2.0.0/images/auth/google.svg',
                                        width: 22,
                                        height: 22,
                                        errorBuilder: (context, error, stackTrace) => const Icon(
                                          Icons.g_mobiledata_rounded,
                                          size: 28,
                                          color: Color(0xFF4285F4),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      const Flexible(
                                        child: Text(
                                          'Continue with Google',
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w700,
                                            color: Color(0xFF0F172A),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                          ),
                        ),

                        const SizedBox(height: 14),

                        // Auto-registration & terms note
                        const Text(
                          'New user? Signing in with Google will confirm Terms & Conditions and register your customer account.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 12,
                            color: Color(0xFF94A3B8),
                            height: 1.35,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Security Badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.shield_outlined, size: 16, color: Color(0xFF64748B)),
                        SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            'Protected by Google OAuth 2.0 & Queueless Microservices',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: Color(0xFF64748B),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFeatureRow({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 20, color: color),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1E293B),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF64748B),
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
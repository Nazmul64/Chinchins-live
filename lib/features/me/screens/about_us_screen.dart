import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../../core/constants/api_constants.dart';
import '../../../core/theme/app_colors.dart';

class AboutUsScreen extends StatefulWidget {
  const AboutUsScreen({super.key});

  @override
  State<AboutUsScreen> createState() => _AboutUsScreenState();
}

class _AboutUsScreenState extends State<AboutUsScreen> {
  bool _isLoading = true;
  Map<String, dynamic>? _aboutData;

  @override
  void initState() {
    super.initState();
    _fetchAboutUs();
  }

  Future<void> _fetchAboutUs() async {
    try {
      final url = Uri.parse('${ApiConstants.baseUrl}/app/about');
      var response = await http.get(url, headers: {'Accept': 'application/json'}).timeout(const Duration(seconds: 8));

      if (response.statusCode == 404) {
        response = await http.get(
          Uri.parse('${ApiConstants.baseUrl}/about'),
          headers: {'Accept': 'application/json'},
        ).timeout(const Duration(seconds: 8));
      }

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded is Map && decoded['data'] != null) {
          setState(() {
            _aboutData = decoded['data'] as Map<String, dynamic>;
            _isLoading = false;
          });
          return;
        }
      }
    } catch (_) {}

    // Fallback default data
    setState(() {
      _aboutData = {
        'app_name': 'Chinchins Live',
        'app_tagline': 'Meet, Chat & Video Call Live',
        'version': '1.0.1 (Build 2)',
        'company_name': 'Chinchins Live Network Inc.',
        'official_website': 'https://chinchins.live',
        'support_email': 'support@chinchins.live',
        'support_whatsapp': '+8801700000000',
        'content': 'Welcome to Chinchins Live — the premier real-time interactive live video streaming, social connection, and entertainment platform.\n\nOur mission is to connect people across the globe through crystal-clear 1-on-1 private video calls, dynamic live broadcasting, interactive virtual gifting, and instant messaging.',
        'features': [
          {
            'title': 'HD 1-on-1 Video Calls',
            'description': 'Real-time WebRTC low-latency HD video and crystal-clear audio calls.',
            'icon': Icons.videocam_rounded,
          },
          {
            'title': '160+ Luxury Virtual Gifts',
            'description': 'Animated SVG and 3D effects across 12 unique categories.',
            'icon': Icons.card_giftcard_rounded,
          },
          {
            'title': 'VIP Cards & Privileges',
            'description': 'Exclusive avatar frames, entry badges, and bonus daily gems.',
            'icon': Icons.workspace_premium_rounded,
          },
          {
            'title': '100% Safe Community',
            'description': '24/7 AI moderation, end-to-end encrypted calls, and user block/report tools.',
            'icon': Icons.verified_user_rounded,
          },
        ]
      };
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final appName = _aboutData?['app_name']?.toString() ?? 'Chinchins Live';
    final tagline = _aboutData?['app_tagline']?.toString() ?? 'Meet, Chat & Video Call Live';
    final version = _aboutData?['version']?.toString() ?? '1.0.1 (Build 2)';
    final company = _aboutData?['company_name']?.toString() ?? 'Chinchins Live Network Inc.';
    final content = _aboutData?['content']?.toString() ?? '';
    final website = _aboutData?['official_website']?.toString() ?? 'https://chinchins.live';
    final supportEmail = _aboutData?['support_email']?.toString() ?? 'support@chinchins.live';

    return Scaffold(
      backgroundColor: const Color(0xFF131122),
      appBar: AppBar(
        backgroundColor: const Color(0xFF131122),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'About Us',
          style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.neonPink))
          : SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              physics: const BouncingScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const SizedBox(height: 10),
                  // App Icon / Logo with Glow
                  Container(
                    width: 90,
                    height: 90,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [AppColors.neonPink, Color(0xFF8B5CF6)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.neonPink.withValues(alpha: 0.35),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: const Icon(Icons.videocam_rounded, size: 48, color: Colors.white),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    appName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    tagline,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white12),
                    ),
                    child: Text(
                      'Version $version',
                      style: const TextStyle(
                        color: Color(0xFF00E676),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Mission & Overview Card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E1B2E),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.stars_rounded, color: Color(0xFFFFD700), size: 20),
                            SizedBox(width: 8),
                            Text(
                              'Platform Overview',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          content,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 13.5,
                            height: 1.55,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Feature Cards
                  _buildFeatureCard(
                    icon: Icons.video_call_rounded,
                    iconColor: AppColors.neonPink,
                    title: 'HD 1-on-1 Video Calls',
                    subtitle: 'Real-time WebRTC low-latency HD video and crystal-clear audio calls with instant coin rewards.',
                  ),
                  const SizedBox(height: 10),
                  _buildFeatureCard(
                    icon: Icons.card_giftcard_rounded,
                    iconColor: const Color(0xFF8B5CF6),
                    title: '160+ Luxury Virtual Gifts',
                    subtitle: 'Rich animations, SVIP royal badges, CP items, and dynamic gifting tray.',
                  ),
                  const SizedBox(height: 10),
                  _buildFeatureCard(
                    icon: Icons.shield_rounded,
                    iconColor: const Color(0xFF00E676),
                    title: 'Safe & Encrypted Community',
                    subtitle: '24/7 AI moderation, end-to-end encrypted calls, and zero tolerance for harassment.',
                  ),
                  const SizedBox(height: 20),

                  // Contact & Support Info Card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E1B2E),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Official Contact & Support',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        _buildContactRow(Icons.language_rounded, 'Website', website),
                        const Divider(color: Colors.white10, height: 16),
                        _buildContactRow(Icons.email_outlined, 'Support Email', supportEmail),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Company Copyright Footer
                  Text(
                    '© 2026 $company',
                    style: const TextStyle(color: Colors.white38, fontSize: 12),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'All rights reserved.',
                    style: TextStyle(color: Colors.white24, fontSize: 11),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
    );
  }

  Widget _buildFeatureCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1B2E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: iconColor, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: Colors.white60,
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContactRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, color: AppColors.neonPink, size: 18),
        const SizedBox(width: 10),
        Text(
          '$label: ',
          style: const TextStyle(color: Colors.white60, fontSize: 13),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

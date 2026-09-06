import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../../core/constants/api_constants.dart';
import '../../../core/theme/app_colors.dart';

class PrivacyPolicyScreen extends StatefulWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  State<PrivacyPolicyScreen> createState() => _PrivacyPolicyScreenState();
}

class _PrivacyPolicyScreenState extends State<PrivacyPolicyScreen> {
  bool _isLoading = true;
  String _title = 'Chinchins Live Privacy Policy';
  String _lastUpdated = 'September 2026';
  String _content = '';
  List<Map<String, String>> _sections = [];

  @override
  void initState() {
    super.initState();
    _fetchPrivacyPolicy();
  }

  Future<void> _fetchPrivacyPolicy() async {
    try {
      final url = Uri.parse('${ApiConstants.baseUrl}/app/privacy-policy');
      var response = await http.get(url, headers: {'Accept': 'application/json'}).timeout(const Duration(seconds: 8));

      if (response.statusCode == 404) {
        response = await http.get(
          Uri.parse('${ApiConstants.baseUrl}/privacy-policy'),
          headers: {'Accept': 'application/json'},
        ).timeout(const Duration(seconds: 8));
      }

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded is Map && decoded['data'] != null) {
          final data = decoded['data'] as Map<String, dynamic>;
          setState(() {
            _title = data['title']?.toString() ?? 'Chinchins Live Privacy Policy';
            _lastUpdated = data['last_updated']?.toString() ?? 'September 2026';
            _content = data['content']?.toString() ?? '';
            if (data['sections'] is List) {
              _sections = (data['sections'] as List).map((s) {
                return {
                  'heading': s['heading']?.toString() ?? '',
                  'body': s['body']?.toString() ?? '',
                };
              }).toList();
            }
            _isLoading = false;
          });
          return;
        }
      }
    } catch (_) {}

    // Fallback default policy
    setState(() {
      _title = 'Chinchins Live Privacy Policy';
      _lastUpdated = 'September 2026';
      _content = 'At Chinchins Live (operated by Chinchins Live Network Inc.), we are deeply committed to protecting the privacy, confidentiality, and security of our users\' personal data.';
      _sections = [
        {
          'heading': '1. Information We Collect',
          'body': '• Account Profile: Phone number, email, display name, age (18+ only), gender, profile photo, and bio.\n• Technical & Device Data: Device identifier (FCM push token), OS version, and network IP address.\n• Communications: Video and audio call session logs (duration and timestamps only). Call video and audio streams are encrypted peer-to-peer (WebRTC) and NEVER recorded on servers.',
        },
        {
          'heading': '2. Device Permissions',
          'body': '• Camera & Microphone: Strictly requested for live 1-on-1 video and voice conversations initiated by you.\n• Photos & Storage: Only accessed when you explicitly choose to upload an avatar or chat image.',
        },
        {
          'heading': '3. Financial & Coin Recharge Security',
          'body': 'All coin purchases, VIP packages, and recharge transactions are processed via secure encrypted payment gateways. We never store credit card numbers or banking passwords.',
        },
        {
          'heading': '4. Right to Delete Your Account',
          'body': 'You have the absolute right to delete your Chinchins Live account and all associated personal data at any time from Settings -> Delete Account. Upon deletion, all tokens, profile info, and sessions are permanently wiped.',
        },
        {
          'heading': '5. Community Safety & 18+ Age Policy',
          'body': 'Chinchins Live strictly enforces an 18+ policy. Minors are prohibited from registering. We employ 24/7 AI moderation and user reporting systems to ensure a safe, respectful environment.',
        },
      ];
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
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
          'Privacy Policy',
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
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header badge
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF00E676).withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.verified_user_rounded, color: Color(0xFF00E676), size: 22),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _title,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Last Updated: $_lastUpdated',
                              style: const TextStyle(color: Colors.white54, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Introduction Box
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E1B2E),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
                    ),
                    child: Text(
                      _content,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 13.5,
                        height: 1.5,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Structured Sections
                  ..._sections.map((sec) => _buildSectionCard(sec['heading']!, sec['body']!)),

                  const SizedBox(height: 20),
                  // Contact legal support
                  Center(
                    child: Text(
                      'Questions regarding privacy? Contact privacy@chinchins.live',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 12),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
    );
  }

  Widget _buildSectionCard(String heading, String body) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1B2E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            heading,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14.5,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            body,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 13,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

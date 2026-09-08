import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../../core/constants/api_constants.dart';
import '../../../core/theme/app_colors.dart';

class TermsOfServiceScreen extends StatefulWidget {
  const TermsOfServiceScreen({super.key});

  @override
  State<TermsOfServiceScreen> createState() => _TermsOfServiceScreenState();
}

class _TermsOfServiceScreenState extends State<TermsOfServiceScreen> {
  bool _isLoading = true;
  String _title = 'Chinchins Live Terms of Service';
  String _lastUpdated = 'September 2026';
  String _content = '';
  List<Map<String, String>> _sections = [];

  @override
  void initState() {
    super.initState();
    _fetchTerms();
  }

  Future<void> _fetchTerms() async {
    try {
      final url = Uri.parse(ApiConstants.appTerms);
      var response = await http.get(url, headers: {'Accept': 'application/json'}).timeout(const Duration(seconds: 8));

      if (response.statusCode == 404) {
        response = await http.get(
          Uri.parse('${ApiConstants.baseUrl}/terms-of-service'),
          headers: {'Accept': 'application/json'},
        ).timeout(const Duration(seconds: 8));
      }

      if (response.statusCode == 404) {
        response = await http.get(
          Uri.parse('${ApiConstants.baseUrl}/terms'),
          headers: {'Accept': 'application/json'},
        ).timeout(const Duration(seconds: 8));
      }

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded is Map && (decoded['data'] != null || decoded['content'] != null)) {
          final data = decoded['data'] is Map ? (decoded['data'] as Map<String, dynamic>) : (decoded as Map<String, dynamic>);
          setState(() {
            _title = data['title']?.toString() ?? 'Chinchins Live Terms of Service';
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

    // Fallback static copy if offline
    if (mounted) {
      setState(() {
        _title = 'Chinchins Live Terms of Service';
        _lastUpdated = 'September 2026';
        _content =
            'Welcome to Chinchins Live! By accessing or using our mobile application and related streaming services, you agree to comply with and be bound by these Terms of Service. If you do not agree to these terms, please do not use our services.';
        _sections = [
          {
            'heading': '1. Account Registration & Security',
            'body':
                'You must provide accurate, complete, and updated registration information, including your valid phone number. You are responsible for safeguarding your password and account credentials.',
          },
          {
            'heading': '2. User Conduct & Community Guidelines',
            'body':
                'Chinchins Live strictly prohibits harassment, hate speech, explicit illegal content, fraud, and impersonation. Violations will result in immediate suspension and account termination.',
          },
          {
            'heading': '3. Virtual Gifts, Coins & Billing',
            'body':
                'Coins and virtual gifts purchased within the platform are non-refundable unless required by applicable law. Hosts earn rewards according to platform revenue split rules.',
          },
          {
            'heading': '4. 1v1 Video Calling Policy',
            'body':
                '1v1 video and audio calls are billed per minute based on the streamer\'s rate. Inappropriate behavior during calls will lead to immediate disconnection and reporting.',
          },
          {
            'heading': '5. Termination',
            'body':
                'We reserve the right to suspend or terminate your access to Chinchins Live at our discretion, without notice, for conduct that violates these Terms or harms other users.',
          },
        ];
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      appBar: AppBar(
        backgroundColor: AppColors.surfaceDark,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Terms of Service',
          style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.neonPink))
          : SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              physics: const BouncingScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: AppColors.neonPink.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.neonPink.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.gavel_rounded, color: AppColors.neonPink, size: 22),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _title,
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Last updated: $_lastUpdated',
                                style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Main intro text
                  if (_content.isNotEmpty) ...[
                    Text(
                      _content,
                      style: const TextStyle(color: Colors.white70, fontSize: 13.5, height: 1.55),
                    ),
                    const SizedBox(height: 20),
                  ],

                  // Sections
                  ..._sections.map((section) => Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceDark,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppColors.cardBorder),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              section['heading'] ?? '',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              section['body'] ?? '',
                              style: const TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 12.5,
                                height: 1.5,
                              ),
                            ),
                          ],
                        ),
                      )),

                  const SizedBox(height: 24),
                  Center(
                    child: Text(
                      '© 2026 Chinchins Live. All rights reserved.',
                      style: TextStyle(color: AppColors.textMuted.withValues(alpha: 0.6), fontSize: 11),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
    );
  }
}

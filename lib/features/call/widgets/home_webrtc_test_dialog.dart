import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../../config/app_config.dart';
import '../../../core/theme/app_colors.dart';
import '../../auth/services/auth_api_service.dart';

class HomeWebRTCTestDialog extends StatefulWidget {
  const HomeWebRTCTestDialog({super.key});

  static void show(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => const HomeWebRTCTestDialog(),
    );
  }

  @override
  State<HomeWebRTCTestDialog> createState() => _HomeWebRTCTestDialogState();
}

class _HomeWebRTCTestDialogState extends State<HomeWebRTCTestDialog> {
  bool _isTesting = true;
  String _apiStatus = 'চেক করা হচ্ছে...';
  bool _apiSuccess = false;
  String _iceServersStatus = 'চেক করা হচ্ছে...';
  bool _iceSuccess = false;
  String _userStatus = 'ইউজার চেক করা হচ্ছে...';
  Map<String, dynamic>? _userData;

  @override
  void initState() {
    super.initState();
    _runDiagnostics();
  }

  Future<void> _runDiagnostics() async {
    setState(() => _isTesting = true);

    try {
      final user = await AuthApiService.getSavedUser();
      _userData = user;
      _userStatus = user != null
          ? 'লগইন আছে (আইডি: ${user['id'] ?? user['account_id']}, নাম: ${user['name'] ?? user['username']})'
          : '⚠️ ইউজার সেশন পাওয়া যায়নি';
    } catch (e) {
      _userStatus = 'ইউজার চেক এরর: $e';
    }

    try {
      final token = await AuthApiService.getToken();
      final res = await http.get(
        Uri.parse('${AppConfig.baseUrl}/call/ice-servers'),
        headers: {
          'Accept': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 6));

      if (res.statusCode == 200) {
        _apiStatus = 'সফল (200 OK) - লাইভ সার্ভার রেসপন্স দিচ্ছে';
        _apiSuccess = true;

        final decoded = jsonDecode(res.body);
        final ice = decoded['data']?['iceServers'];
        if (ice is List) {
          _iceSuccess = true;
          _iceServersStatus = '${ice.length}টি STUN/TURN সার্ভার কনফিগারেশন লোড হয়েছে';
        } else {
          _iceServersStatus = 'ICE সার্ভার ডেটা ফরম্যাট যাচাই প্রয়োজন';
        }
      } else {
        _apiStatus = 'সার্ভার রেসপন্স কোড: ${res.statusCode}';
      }
    } catch (e) {
      _apiStatus = 'লাইভ সার্ভার কানেকশন এরর: $e';
      _iceServersStatus = 'ফলব্যাক কনফিগারেশন সক্রিয় থাকবে';
    }

    if (mounted) {
      setState(() => _isTesting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF161224),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: AppColors.neonPink, width: 1.5),
      ),
      title: const Row(
        children: [
          Icon(Icons.network_check_rounded, color: AppColors.neonPink, size: 24),
          SizedBox(width: 10),
          Text(
            'WebRTC লাইভ ডায়াগনস্টিক',
            style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '🇧🇩 আপনার ফোন থেকে লাইভ সার্ভার ও WebRTC নেটওয়ার্কের বর্তমান স্ট্যাটাস:',
              style: TextStyle(color: Colors.white70, fontSize: 12),
            ),
            const SizedBox(height: 14),

            _buildRow(
              icon: Icons.person_rounded,
              title: 'ইউজার অ্যাকাউন্ট',
              desc: _userStatus,
              isOk: _userData != null,
            ),
            const SizedBox(height: 10),

            _buildRow(
              icon: Icons.cloud_done_rounded,
              title: 'লাইভ API এন্ডপয়েন্ট',
              desc: '${AppConfig.baseUrl}\n$_apiStatus',
              isOk: _apiSuccess,
            ),
            const SizedBox(height: 10),

            _buildRow(
              icon: Icons.cell_tower_rounded,
              title: 'STUN / TURN রিলে সার্ভার',
              desc: 'chinchins.live:3478 (TCP+UDP)\n$_iceServersStatus',
              isOk: _iceSuccess || !_isTesting,
            ),
            const SizedBox(height: 14),

            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.black38,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.white12),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline_rounded, color: AppColors.gemYellow, size: 18),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'ভিডিও কল দেওয়ার পর কল স্ক্রিনের উপরে 🛠️ আইকন বা "Calling..." বক্সে ট্যাপ করলে লাইভ ভিডিও ডেটা ট্র্যাকিং দেখতে পাবেন।',
                      style: TextStyle(color: Colors.white70, fontSize: 11),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _runDiagnostics,
          child: _isTesting
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.neonPink),
                )
              : const Text('পুনরায় টেস্ট করুন', style: TextStyle(color: AppColors.neonPink)),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.neonPink,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          onPressed: () => Navigator.pop(context),
          child: const Text('ঠিক আছে', style: TextStyle(color: Colors.white)),
        ),
      ],
    );
  }

  Widget _buildRow({
    required IconData icon,
    required String title,
    required String desc,
    required bool isOk,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          isOk ? Icons.check_circle_rounded : Icons.pending_rounded,
          color: isOk ? const Color(0xFF00E676) : const Color(0xFFFFD600),
          size: 20,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 2),
              Text(
                desc,
                style: const TextStyle(color: Colors.white60, fontSize: 11),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

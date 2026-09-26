import 'dart:async';
import 'package:flutter/material.dart';
import '../../../core/models/model_profile.dart';
import '../../../core/services/hive_cache_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/app_logger.dart';
import '../../auth/services/auth_api_service.dart';
import '../services/live_streaming_api_service.dart';
import 'live_room_screen.dart';

class GoLiveScreen extends StatefulWidget {
  const GoLiveScreen({super.key});

  @override
  State<GoLiveScreen> createState() => _GoLiveScreenState();
}

class _GoLiveScreenState extends State<GoLiveScreen> {
  final TextEditingController _titleController = TextEditingController();
  int _selectedCategoryIndex = 0;
  bool _isStarting = false;

  final List<Map<String, dynamic>> _categories = [
    {'name': 'Music', 'icon': Icons.music_note_rounded, 'color': const Color(0xFF8B5CF6)},
    {'name': 'Gaming', 'icon': Icons.sports_esports_rounded, 'color': const Color(0xFF3B82F6)},
    {'name': 'Chatting', 'icon': Icons.chat_bubble_rounded, 'color': const Color(0xFFEC4899)},
    {'name': 'Beauty', 'icon': Icons.face_retouching_natural_rounded, 'color': const Color(0xFFF43F5E)},
    {'name': 'Education', 'icon': Icons.school_rounded, 'color': const Color(0xFF10B981)},
    {'name': 'Others', 'icon': Icons.more_horiz_rounded, 'color': const Color(0xFF6B7280)},
  ];

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  void _startLiveStream() {
    final title = _titleController.text.trim().isNotEmpty
        ? _titleController.text.trim()
        : '${_categories[_selectedCategoryIndex]['name']} Live Stream 🔥';

    try {
      final savedUser = HiveCacheService.getCachedUserProfile();
      final String myId = savedUser?['id']?.toString() ?? savedUser?['account_id']?.toString() ?? 'host_me';
      final String myName = savedUser?['name']?.toString() ?? savedUser?['display_name']?.toString() ?? 'Creator';
      final String myAvatar = savedUser?['avatar']?.toString() ?? savedUser?['avatar_url']?.toString() ?? 'https://chinchins.live/uploads/app/logo.png';

      final hostModel = ModelProfile.fromJson({
        'id': myId,
        'account_id': savedUser?['account_id']?.toString() ?? myId,
        'name': myName,
        'avatar_url': myAvatar,
        'price_per_min': 100,
        'country': savedUser?['country'] ?? 'Global',
      });

      // ⚡ Sub-Second Navigation: Instant push in 0.00ms!
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => LiveRoomScreen(
            host: hostModel,
            title: title,
            isHost: true,
          ),
        ),
      );
    } catch (e, st) {
      AppLogger.error('GoLiveError', e, st);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0910),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Close & Help
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Colors.white, size: 28),
                    onPressed: () => Navigator.pop(context),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Icon(Icons.flip_camera_ios_rounded, color: Colors.white, size: 16),
                        SizedBox(width: 6),
                        Text(
                          'Flip',
                          style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Title Header (Screen H)
              const Text(
                'Go Live',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Share your talent with the world',
                style: TextStyle(
                  color: Colors.white54,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 32),

              // Category Picker 3x2 Grid (Screen H)
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _categories.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  mainAxisSpacing: 16,
                  crossAxisSpacing: 16,
                  childAspectRatio: 1.0,
                ),
                itemBuilder: (context, index) {
                  final cat = _categories[index];
                  final isSelected = _selectedCategoryIndex == index;
                  final Color catColor = cat['color'] as Color;

                  return GestureDetector(
                    onTap: () => setState(() => _selectedCategoryIndex = index),
                    child: Container(
                      decoration: BoxDecoration(
                        color: isSelected
                            ? const Color(0xFFFF2A6D).withValues(alpha: 0.15)
                            : const Color(0xFF161426),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isSelected
                              ? const Color(0xFFFF2A6D)
                              : Colors.white.withValues(alpha: 0.08),
                          width: isSelected ? 2 : 1,
                        ),
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                  color: const Color(0xFFFF2A6D).withValues(alpha: 0.35),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                ),
                              ]
                            : null,
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: catColor.withValues(alpha: isSelected ? 0.3 : 0.15),
                            ),
                            child: Center(
                              child: Icon(
                                cat['icon'] as IconData,
                                color: isSelected ? Colors.white : catColor,
                                size: 22,
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            cat['name'] as String,
                            style: TextStyle(
                              color: isSelected ? Colors.white : Colors.white70,
                              fontSize: 13,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 36),

              // Title Input Section (Screen H)
              const Text(
                'Add a short title',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 10),
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF161426),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                ),
                child: TextField(
                  controller: _titleController,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  decoration: const InputDecoration(
                    hintText: 'What are you going live for?',
                    hintStyle: TextStyle(color: Colors.white38, fontSize: 14),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  ),
                ),
              ),
              const SizedBox(height: 40),

              // Start Live Gradient Pill Button (Screen H)
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _isStarting ? null : _startLiveStream,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    padding: EdgeInsets.zero,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(26),
                    ),
                  ),
                  child: Ink(
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFFF2A6D), Color(0xFFFF0055)],
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                      ),
                      borderRadius: BorderRadius.circular(26),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFFF2A6D).withValues(alpha: 0.45),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Container(
                      alignment: Alignment.center,
                      child: _isStarting
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2.5,
                              ),
                            )
                          : const Text(
                              'Start Live',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5,
                              ),
                            ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

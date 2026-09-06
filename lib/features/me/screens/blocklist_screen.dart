import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/cached_image_loader.dart';
import '../../chat/services/chat_api_service.dart';

class BlocklistScreen extends StatefulWidget {
  const BlocklistScreen({super.key});

  @override
  State<BlocklistScreen> createState() => _BlocklistScreenState();
}

class _BlocklistScreenState extends State<BlocklistScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _blockedUsers = [];

  @override
  void initState() {
    super.initState();
    _loadBlockedList();
  }

  Future<void> _loadBlockedList() async {
    setState(() => _isLoading = true);
    try {
      final list = await ChatApiService.getBlockedUsers();
      if (mounted) {
        setState(() {
          _blockedUsers = list;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _unblock(Map<String, dynamic> user) async {
    final userId = user['id'] ?? user['user_id'] ?? user['target_id'];
    final name = user['name'] ?? user['nickname'] ?? 'User';
    
    final res = await ChatApiService.unblockUser(userId);
    if (res['success'] == true && mounted) {
      setState(() {
        _blockedUsers.removeWhere((u) => (u['id'] ?? u['user_id']) == userId);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unblocked $name successfully.'),
          backgroundColor: AppColors.cardDarkElevated,
          duration: const Duration(seconds: 2),
        ),
      );
    }
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
          'Blocklist',
          style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.neonPink))
          : _blockedUsers.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.05),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.block_rounded, color: Colors.white38, size: 48),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'No blocked users',
                        style: TextStyle(color: Colors.white70, fontSize: 16, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Users you block will appear here.',
                        style: TextStyle(color: AppColors.textMuted, fontSize: 13),
                      ),
                    ],
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  itemCount: _blockedUsers.length,
                  separatorBuilder: (_, __) => const Divider(color: Colors.white10, height: 1),
                  itemBuilder: (context, index) {
                    final user = _blockedUsers[index];
                    final name = user['name'] ?? user['nickname'] ?? 'User';
                    final avatar = user['avatar'] ?? user['avatar_url'] ?? '';

                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: Row(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(24),
                            child: SizedBox(
                              width: 48,
                              height: 48,
                              child: CachedImageLoader(
                                imageUrl: avatar,
                                width: 48,
                                height: 48,
                              ),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  name,
                                  style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'ID: ${user['account_id'] ?? user['id'] ?? "---"}',
                                  style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white.withValues(alpha: 0.12),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                              elevation: 0,
                            ),
                            onPressed: () => _unblock(user),
                            child: const Text('Unblock', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                    );
                  },
                ),
    );
  }
}

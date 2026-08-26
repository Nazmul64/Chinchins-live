import 'package:flutter/material.dart';
import '../../../core/data/mock_data.dart';
import '../../../core/models/chat_message.dart';
import '../../../core/models/model_profile.dart';
import '../../../core/services/profile_api_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/cached_image_loader.dart';
import '../widgets/chat_thread_tile.dart';
import '../../chat/screens/chat_detail_screen.dart';

class MessagesScreen extends StatefulWidget {
  const MessagesScreen({super.key});

  @override
  State<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends State<MessagesScreen> {
  int _activeSubTabIndex = 0; // 0: Messages, 1: Intimacy
  late List<ChatThread> _threads;
  List<ModelProfile> _liveHosts = [];

  @override
  void initState() {
    super.initState();
    _threads = List.from(MockData.chatThreads);
    _loadLiveHosts();
  }

  Future<void> _loadLiveHosts() async {
    final hosts = await ProfileApiService.getHomeFeed();
    if (hosts.isNotEmpty && mounted) {
      setState(() {
        _liveHosts = hosts;
      });
    }
  }

  void _openChat(ChatThread thread) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChatDetailScreen(thread: thread),
      ),
    ).then((_) {
      setState(() {
        // Refresh state
      });
    });
  }

  void _showNewChatDialog() {
    final availableHosts = _liveHosts;
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.cardDarkElevated,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Start New Chat',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            if (availableHosts.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Center(
                  child: Text('No active hosts online', style: TextStyle(color: AppColors.textMuted)),
                ),
              )
            else
              ...availableHosts.take(6).map((model) => ListTile(
                    leading: Container(
                      width: 44,
                      height: 44,
                      decoration: const BoxDecoration(shape: BoxShape.circle),
                      child: ClipOval(
                        child: CachedImageLoader(imageUrl: model.avatarUrl, fit: BoxFit.cover),
                      ),
                    ),
                    title: Text(model.fullName.isNotEmpty ? model.fullName : model.name, style: const TextStyle(color: Colors.white)),
                    subtitle: Text(model.location, style: const TextStyle(color: AppColors.textMuted)),
                    trailing: const Icon(Icons.chat_bubble_outline, color: AppColors.neonPink),
                    onTap: () {
                      Navigator.pop(context);
                      final thread = ChatThread(
                        id: 't_${model.id}',
                        modelId: model.id,
                        name: model.fullName.isNotEmpty ? model.fullName : model.name,
                        avatarUrl: model.avatarUrl,
                        lastMessage: 'Hello! ❤️',
                        time: 'Just now',
                        messages: [],
                      );
                      _openChat(thread);
                    },
                  )),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      body: SafeArea(
        child: Column(
          children: [
            // Top Bar matching Screenshot 3
            Padding(
              padding: const EdgeInsets.only(left: 16, right: 16, top: 12, bottom: 8),
              child: Row(
                children: [
                  // "Messages" title with red indicator dot
                  GestureDetector(
                    onTap: () => setState(() => _activeSubTabIndex = 0),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Messages',
                          style: TextStyle(
                            color: _activeSubTabIndex == 0 ? Colors.white : AppColors.textMuted,
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Container(
                          width: 6,
                          height: 6,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.badgePink,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(width: 20),

                  // "Intimacy" Tab
                  GestureDetector(
                    onTap: () => setState(() => _activeSubTabIndex = 1),
                    child: Text(
                      'Intimacy',
                      style: TextStyle(
                        color: _activeSubTabIndex == 1 ? Colors.white : AppColors.textMuted,
                        fontSize: 16,
                        fontWeight: _activeSubTabIndex == 1 ? FontWeight.bold : FontWeight.w500,
                      ),
                    ),
                  ),

                  const Spacer(),

                  // Phone/Call Log Icon Button (with orange pill background)
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: AppColors.warmOrange.withValues(alpha: 0.18),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.phone_rounded,
                      color: AppColors.warmOrange,
                      size: 20,
                    ),
                  ),

                  const SizedBox(width: 10),

                  // "+" Add button
                  GestureDetector(
                    onTap: _showNewChatDialog,
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: const BoxDecoration(
                        color: AppColors.cardDarkElevated,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.add,
                        color: Colors.white,
                        size: 22,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const Divider(color: AppColors.cardBorder, height: 1, thickness: 0.8),

            // Chat Threads List
            Expanded(
              child: ListView.separated(
                itemCount: _threads.length,
                separatorBuilder: (context, index) => const Divider(
                  color: AppColors.cardBorder,
                  height: 1,
                  indent: 84,
                  endIndent: 16,
                ),
                itemBuilder: (context, index) {
                  final thread = _threads[index];
                  return ChatThreadTile(
                    thread: thread,
                    onTap: () => _openChat(thread),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

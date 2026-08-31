import 'dart:async';
import 'package:flutter/material.dart';
import '../../../core/models/chat_message.dart';
import '../../../core/models/model_profile.dart';
import '../../../core/services/profile_api_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/cached_image_loader.dart';
import '../widgets/chat_thread_tile.dart';
import '../../chat/services/chat_api_service.dart';
import '../../chat/screens/chat_detail_screen.dart';

class MessagesScreen extends StatefulWidget {
  const MessagesScreen({super.key});

  @override
  State<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends State<MessagesScreen> {
  int _activeSubTabIndex = 0; // 0: Messages, 1: Intimacy
  List<ChatThread> _threads = [];
  List<ModelProfile> _liveHosts = [];
  bool _isLoading = true;
  Timer? _realtimePollTimer;

  @override
  void initState() {
    super.initState();
    _loadConversations(initial: true);
    _loadLiveHosts();
    _startRealtimePolling();
  }

  @override
  void dispose() {
    _realtimePollTimer?.cancel();
    super.dispose();
  }

  void _startRealtimePolling() {
    _realtimePollTimer?.cancel();
    // Real-time polling every 3.5 seconds to refresh incoming messages & auto-greetings
    _realtimePollTimer = Timer.periodic(const Duration(milliseconds: 3500), (_) {
      if (mounted) {
        _loadConversations(silent: true);
      }
    });
  }

  Future<void> _loadConversations({bool initial = false, bool silent = false}) async {
    if (initial && mounted) {
      setState(() => _isLoading = true);
    }

    try {
      final res = await ChatApiService.getConversations();
      if (res != null && mounted) {
        if (res['conversations'] is List) {
          final convList = (res['conversations'] as List)
              .map((c) => ChatThread.fromJson(c as Map<String, dynamic>))
              .toList();

          // Sort conversations by latest message timestamp (most recent at top)
          convList.sort((a, b) {
            if (a.lastMessageAt != null && b.lastMessageAt != null) {
              return b.lastMessageAt!.compareTo(a.lastMessageAt!);
            }
            if (a.lastMessageAt != null) return -1;
            if (b.lastMessageAt != null) return 1;
            return 0;
          });

          setState(() {
            _threads = convList;
            _isLoading = false;
          });
          return;
        }
      }
    } catch (_) {}

    if (mounted && initial) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadLiveHosts() async {
    try {
      final hosts = await ProfileApiService.getHomeFeed();
      if (hosts.isNotEmpty && mounted) {
        setState(() {
          _liveHosts = hosts;
        });
      }
    } catch (_) {}
  }

  void _openChat(ChatThread thread) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChatDetailScreen(thread: thread),
      ),
    ).then((_) {
      _loadConversations(silent: true);
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
            // Top Bar matching Screenshot
            Padding(
              padding: const EdgeInsets.only(left: 16, right: 16, top: 12, bottom: 8),
              child: Row(
                children: [
                  // "Messages" title with real-time unread indicator dot
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
                        ValueListenableBuilder<int>(
                          valueListenable: ChatApiService.totalUnreadBadgeNotifier,
                          builder: (context, count, _) {
                            final hasUnread = count > 0 || _threads.any((t) => t.unreadCount > 0);
                            if (!hasUnread) return const SizedBox.shrink();
                            return Container(
                              width: 7,
                              height: 7,
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: AppColors.badgePink,
                              ),
                            );
                          },
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
              child: _isLoading && _threads.isEmpty
                  ? const Center(
                      child: CircularProgressIndicator(color: AppColors.neonPink),
                    )
                  : RefreshIndicator(
                      color: AppColors.neonPink,
                      backgroundColor: AppColors.cardDark,
                      onRefresh: () => _loadConversations(initial: false),
                      child: _threads.isEmpty
                          ? ListView(
                              physics: const AlwaysScrollableScrollPhysics(),
                              children: [
                                const SizedBox(height: 120),
                                Center(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Container(
                                        width: 80,
                                        height: 80,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: AppColors.cardDarkElevated,
                                          border: Border.all(color: AppColors.cardBorder),
                                        ),
                                        child: const Icon(
                                          Icons.chat_bubble_outline_rounded,
                                          color: AppColors.neonPink,
                                          size: 38,
                                        ),
                                      ),
                                      const SizedBox(height: 16),
                                      const Text(
                                        'No conversations yet',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      const Text(
                                        'View host profiles or start a new chat!',
                                        style: TextStyle(
                                          color: AppColors.textMuted,
                                          fontSize: 13,
                                        ),
                                      ),
                                      const SizedBox(height: 20),
                                      ElevatedButton.icon(
                                        onPressed: _showNewChatDialog,
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: AppColors.neonPink,
                                          foregroundColor: Colors.white,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(20),
                                          ),
                                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                                        ),
                                        icon: const Icon(Icons.add, size: 18),
                                        label: const Text('Start Chatting'),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            )
                          : ListView.separated(
                              physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
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
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/models/app_notification.dart';
import '../../../core/models/chat_message.dart';
import '../../../core/models/model_profile.dart';
import '../../../core/services/notification_api_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/cached_image_loader.dart';
import '../../auth/services/auth_api_service.dart';
import '../../chat/screens/chat_detail_screen.dart';
import '../../call/screens/video_call_screen.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  bool _isLoading = true;
  List<AppNotification> _notifications = [];

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    setState(() => _isLoading = true);
    final list = await NotificationApiService.instance.fetchNotifications();
    if (mounted) {
      setState(() {
        _notifications = list;
        _isLoading = false;
      });
    }
  }

  void _triggerTestPush() async {
    final savedUser = await AuthApiService.getSavedUser();
    final userId = savedUser?['id'] ?? savedUser?['user_id'] ?? 1;

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Triggering live push notification on server...'),
        duration: Duration(seconds: 1),
      ),
    );

    final res = await NotificationApiService.testPushNotification(
      userId: userId,
      type: 'profile_view',
      title: 'Profile Visitor Alert 👁️',
      body: 'Someone just viewed your Chinchins Live profile!',
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res['message']?.toString() ?? 'Push notification dispatched!'),
          backgroundColor: res['status'] == true ? Colors.green : AppColors.neonPink,
        ),
      );
      _loadNotifications();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0E17),
      appBar: AppBar(
        backgroundColor: const Color(0xFF161426),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Notifications & Alerts',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.send_to_mobile_rounded, color: AppColors.neonPink, size: 22),
            tooltip: 'Send Test Push Alert',
            onPressed: _triggerTestPush,
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.white70, size: 22),
            tooltip: 'Refresh',
            onPressed: _loadNotifications,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(AppColors.neonPink),
              ),
            )
          : _notifications.isEmpty
              ? _buildEmptyState()
              : RefreshIndicator(
                  onRefresh: _loadNotifications,
                  color: AppColors.neonPink,
                  backgroundColor: const Color(0xFF1E1C2E),
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                    itemCount: _notifications.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      return _buildNotificationCard(_notifications[index]);
                    },
                  ),
                ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFF1A1829),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
            child: const Icon(
              Icons.notifications_none_rounded,
              size: 56,
              color: Colors.white38,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'No notifications yet',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Profile visitors, gifts, calls & updates\nwill appear here in real-time.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white54,
              fontSize: 13,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.neonPink,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            ),
            icon: const Icon(Icons.notifications_active_rounded, color: Colors.white, size: 18),
            label: const Text('Send Test Alert', style: TextStyle(color: Colors.white)),
            onPressed: _triggerTestPush,
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationCard(AppNotification n) {
    IconData typeIcon;
    Color iconBgColor;
    Color iconColor;

    switch (n.type) {
      case 'profile_view':
        typeIcon = Icons.remove_red_eye_rounded;
        iconBgColor = Colors.purple.withValues(alpha: 0.2);
        iconColor = const Color(0xFFBF5AF2);
        break;
      case 'gift':
        typeIcon = Icons.card_giftcard_rounded;
        iconBgColor = Colors.amber.withValues(alpha: 0.2);
        iconColor = Colors.amber;
        break;
      case 'call':
        typeIcon = Icons.phone_callback_rounded;
        iconBgColor = Colors.green.withValues(alpha: 0.2);
        iconColor = Colors.greenAccent;
        break;
      case 'message':
      default:
        typeIcon = Icons.chat_bubble_outline_rounded;
        iconBgColor = AppColors.neonPink.withValues(alpha: 0.2);
        iconColor = AppColors.neonPink;
        break;
    }

    final formattedTime = n.createdAt != null
        ? DateFormat('hh:mm a • dd MMM').format(n.createdAt!)
        : 'Just now';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF181628),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: n.isRead ? Colors.white.withValues(alpha: 0.06) : AppColors.neonPink.withValues(alpha: 0.4),
          width: n.isRead ? 1 : 1.5,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Avatar or Notification Icon
          if (n.viewerAvatar != null && n.viewerAvatar!.isNotEmpty)
            Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: CachedImageLoader(
                    imageUrl: n.viewerAvatar!,
                    width: 48,
                    height: 48,
                    fit: BoxFit.cover,
                  ),
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      color: iconColor,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(typeIcon, color: Colors.white, size: 10),
                  ),
                ),
              ],
            )
          else if (n.giftIcon != null && n.giftIcon!.isNotEmpty)
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: iconBgColor,
                borderRadius: BorderRadius.circular(14),
              ),
              padding: const EdgeInsets.all(8),
              child: CachedImageLoader(imageUrl: n.giftIcon!, fit: BoxFit.contain),
            )
          else
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: iconBgColor,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(typeIcon, color: iconColor, size: 24),
            ),

          const SizedBox(width: 12),

          // Content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        n.title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      formattedTime,
                      style: const TextStyle(
                        color: Colors.white38,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  n.message,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                    height: 1.3,
                  ),
                ),

                // Interactive quick actions
                if (n.type == 'profile_view' && n.viewerId != null) ...[
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      _buildQuickActionButton(
                        icon: Icons.chat_rounded,
                        label: 'Say Hi 👋',
                        color: AppColors.neonPink,
                        onTap: () {
                          final thread = ChatThread(
                            id: 't_${n.viewerId}',
                            modelId: n.viewerId.toString(),
                            name: n.viewerName ?? 'User',
                            avatarUrl: n.viewerAvatar ?? '',
                            lastMessage: 'Hello! ❤️',
                            time: 'Just now',
                            messages: [],
                          );
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ChatDetailScreen(thread: thread),
                            ),
                          );
                        },
                      ),
                      const SizedBox(width: 8),
                      _buildQuickActionButton(
                        icon: Icons.videocam_rounded,
                        label: 'Video Call',
                        color: const Color(0xFF00C853),
                        onTap: () {
                          final model = ModelProfile.fromJson({
                            'id': n.viewerId.toString(),
                            'account_id': n.viewerId.toString(),
                            'name': n.viewerName ?? 'User',
                            'avatar': n.viewerAvatar ?? '',
                            'video_call_rate': 100,
                          });
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => VideoCallScreen(model: model),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ] else if (n.type == 'gift') ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.amber.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.monetization_on_rounded, color: Colors.amber, size: 14),
                        const SizedBox(width: 4),
                        Text(
                          '+${n.coinsEarned ?? 0} Coins credited to wallet',
                          style: const TextStyle(
                            color: Colors.amber,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.4)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 14),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

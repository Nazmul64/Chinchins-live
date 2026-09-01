import 'package:flutter/material.dart';
import '../../../core/models/chat_message.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/cached_image_loader.dart';

class ChatThreadTile extends StatelessWidget {
  final ChatThread thread;
  final VoidCallback onTap;

  const ChatThreadTile({
    super.key,
    required this.thread,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            // Avatar with online badge
            Stack(
              children: [
                Container(
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      colors: [Color(0xFF8E24AA), Color(0xFFE91E63)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    border: Border.all(
                      color: AppColors.cardBorder,
                      width: 1.5,
                    ),
                  ),
                  child: ClipOval(
                    child: thread.avatarUrl.isNotEmpty
                        ? CachedImageLoader(
                            imageUrl: thread.avatarUrl,
                            fit: BoxFit.cover,
                          )
                        : Center(
                            child: Text(
                              thread.name.isNotEmpty ? thread.name[0].toUpperCase() : 'U',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 22,
                              ),
                            ),
                          ),
                  ),
                ),
                if (thread.isOnline)
                  Positioned(
                    bottom: 2,
                    right: 2,
                    child: Container(
                      width: 13,
                      height: 13,
                      decoration: BoxDecoration(
                        color: AppColors.onlineGreen,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: AppColors.backgroundDark,
                          width: 2,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 14),

            // Name and Last Message
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          thread.name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (thread.badgeEmoji != null) ...[
                        const SizedBox(width: 4),
                        Text(
                          thread.badgeEmoji!,
                          style: const TextStyle(fontSize: 14),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 5),
                  _buildLastMessageSnippet(thread.lastMessage),
                ],
              ),
            ),

            // Time & Unread Counter
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  thread.time,
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 6),
                if (thread.unreadCount > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                    decoration: BoxDecoration(
                      color: AppColors.badgePink,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Center(
                      child: Text(
                        '${thread.unreadCount}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  )
                else
                  const SizedBox(height: 18),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLastMessageSnippet(String message) {
    if (message.startsWith('[Video Call]')) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.videocam_rounded,
            color: Color(0xFF6C63FF),
            size: 14,
          ),
          const SizedBox(width: 4),
          Text(
            message,
            style: const TextStyle(
              color: Color(0xFF8C84FF),
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      );
    }

    if (message.startsWith('[Image]')) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.photo_rounded,
            color: AppColors.textSecondary,
            size: 14,
          ),
          const SizedBox(width: 4),
          Text(
            message,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 13,
            ),
          ),
        ],
      );
    }

    return Text(
      message,
      style: const TextStyle(
        color: AppColors.textSecondary,
        fontSize: 13,
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }
}

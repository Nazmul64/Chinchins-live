import 'package:flutter/material.dart';
import '../../../core/models/chat_message.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/cached_image_loader.dart';

class ChatBubble extends StatelessWidget {
  final ChatMessage message;
  final VoidCallback? onImageTap;

  const ChatBubble({
    super.key,
    required this.message,
    this.onImageTap,
  });

  @override
  Widget build(BuildContext context) {
    if (message.type == MessageType.introSecret) {
      return _buildIntroSecretCard();
    }

    if (message.type == MessageType.callRecord) {
      return _buildCallRecordCard();
    }

    if (message.type == MessageType.gift) {
      return _buildGiftMessageCard();
    }

    final isMe = message.isFromMe;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
      child: Row(
        mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMe) ...[
            CircleAvatar(
              radius: 16,
              backgroundImage: NetworkImage(message.senderAvatar),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isMe
                    ? AppColors.cardDarkElevated
                    : const Color(0xFF2B2544),
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(isMe ? 16 : 4),
                  bottomRight: Radius.circular(isMe ? 4 : 16),
                ),
                border: Border.all(
                  color: isMe ? AppColors.cardBorder : Colors.transparent,
                  width: 0.8,
                ),
              ),
              child: Column(
                crossAxisAlignment:
                    isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                children: [
                  if (message.imageUrl != null) ...[
                    GestureDetector(
                      onTap: onImageTap,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: CachedImageLoader(
                          imageUrl: message.imageUrl!,
                          width: 200,
                          height: 180,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    if (message.text.isNotEmpty) const SizedBox(height: 6),
                  ],
                  if (message.text.isNotEmpty)
                    Text(
                      message.text,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        height: 1.3,
                      ),
                    ),
                  const SizedBox(height: 3),
                  Text(
                    message.time,
                    style: const TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // "Hi there! Want to know a secret?" Intro Card from Screenshot 2
  Widget _buildIntroSecretCard() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF381F4B), Color(0xFF25163D)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppColors.neonPurple.withValues(alpha: 0.4),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.neonPurple.withValues(alpha: 0.15),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.auto_awesome, color: AppColors.gemYellow, size: 18),
              const SizedBox(width: 6),
              Text(
                message.senderName,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 4),
              const Icon(Icons.star_rounded, color: AppColors.gemYellow, size: 16),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            message.text,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFFD6C8FF),
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  // Call status record e.g. "📹 Rejected Today 09:55" from Screenshot 2
  Widget _buildCallRecordCard() {
    final isRejected = message.callStatus == CallRecordStatus.rejected;
    final statusText = isRejected ? 'Rejected' : (message.text.isNotEmpty ? message.text : 'Video Call');

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 40, vertical: 6),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.cardDarkElevated,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.cardBorder,
          width: 0.8,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.videocam_off_rounded,
            color: isRejected ? AppColors.badgePink : AppColors.neonPink,
            size: 16,
          ),
          const SizedBox(width: 8),
          Text(
            statusText,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            message.time,
            style: const TextStyle(
              color: AppColors.textMuted,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGiftMessageCard() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 30, vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        gradient: AppColors.primaryGradient,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.neonPink.withValues(alpha: 0.3),
            blurRadius: 10,
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(message.giftEmoji ?? '🎁', style: const TextStyle(fontSize: 24)),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Sent ${message.giftName ?? "Gift"}!',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                message.time,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 10,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

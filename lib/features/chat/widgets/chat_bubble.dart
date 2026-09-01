import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import '../../../core/models/chat_message.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/cached_image_loader.dart';

class ChatBubble extends StatelessWidget {
  final ChatMessage message;
  final String? fallbackAvatar;
  final String? partnerName;
  final VoidCallback? onImageTap;

  const ChatBubble({
    super.key,
    required this.message,
    this.fallbackAvatar,
    this.partnerName,
    this.onImageTap,
  });

  bool _isEmojiOnly(String text) {
    final clean = text.trim();
    if (clean.isEmpty) return false;
    // Check if only 1 to 3 emojis and length is short
    final runes = clean.runes.toList();
    if (runes.length <= 4) {
      for (final r in runes) {
        if (r < 0x2000 && r != 0x00A9 && r != 0x00AE) return false;
      }
      return true;
    }
    return false;
  }

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
    final effectiveAvatar = message.senderAvatar.isNotEmpty
        ? message.senderAvatar
        : (fallbackAvatar ?? '');

    final isEmoji = message.type == MessageType.text && _isEmojiOnly(message.text);

    if (isEmoji) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 16),
        child: Row(
          mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (!isMe) ...[
              _buildAvatar(effectiveAvatar),
              const SizedBox(width: 8),
            ],
            Column(
              crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                Text(
                  message.text,
                  style: const TextStyle(fontSize: 34),
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        message.time,
                        style: const TextStyle(color: Colors.white38, fontSize: 10),
                      ),
                      if (isMe) ...[
                        const SizedBox(width: 4),
                        const Icon(Icons.done_all_rounded, color: Color(0xFF00E5FF), size: 13),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 12),
      child: Row(
        mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMe) ...[
            _buildAvatar(effectiveAvatar),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              constraints: const BoxConstraints(maxWidth: 290),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                gradient: isMe
                    ? const LinearGradient(
                        colors: [Color(0xFFE91E63), Color(0xFF8E24AA)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      )
                    : null,
                color: isMe ? null : const Color(0xFF1E1A34),
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(18),
                  topRight: const Radius.circular(18),
                  bottomLeft: Radius.circular(isMe ? 18 : 4),
                  bottomRight: Radius.circular(isMe ? 4 : 18),
                ),
                border: Border.all(
                  color: isMe ? Colors.white.withValues(alpha: 0.15) : const Color(0xFF332B56),
                  width: 0.8,
                ),
                boxShadow: [
                  BoxShadow(
                    color: isMe
                        ? const Color(0xFFE91E63).withValues(alpha: 0.25)
                        : Colors.black.withValues(alpha: 0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment:
                    isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                children: [
                  // Voice Message UI
                  if (message.type == MessageType.voice) ...[
                    _VoicePlayerWidget(
                      audioUrl: message.imageUrl,
                      durationSecs: message.callDurationSeconds ?? 4,
                      isMe: isMe,
                    ),
                  ],

                  // Image Message UI
                  if (message.type == MessageType.image) ...[
                    GestureDetector(
                      onTap: onImageTap,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          constraints: const BoxConstraints(
                            minWidth: 180,
                            maxWidth: 260,
                            minHeight: 140,
                            maxHeight: 240,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black26,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: CachedImageLoader(
                            imageUrl: message.imageUrl ?? '',
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                    ),
                    if (message.text.isNotEmpty &&
                        message.text != 'Photo' &&
                        message.text != '[Image]' &&
                        message.text != '[photo]')
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          message.text,
                          style: const TextStyle(color: Colors.white, fontSize: 14, height: 1.3),
                        ),
                      ),
                  ],

                  // Text Message UI
                  if (message.type == MessageType.text && message.text.isNotEmpty)
                    Text(
                      message.text,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14.5,
                        height: 1.35,
                        letterSpacing: 0.1,
                      ),
                    ),

                  const SizedBox(height: 4),

                  // Timestamp & status
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        message.time,
                        style: TextStyle(
                          color: isMe ? Colors.white70 : AppColors.textMuted,
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      if (isMe) ...[
                        const SizedBox(width: 4),
                        const Icon(
                          Icons.done_all_rounded,
                          color: Color(0xFF00E5FF),
                          size: 13,
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvatar(String effectiveAvatar) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: AppColors.neonPink.withValues(alpha: 0.4),
          width: 1.2,
        ),
      ),
      child: ClipOval(
        child: effectiveAvatar.isNotEmpty
            ? CachedImageLoader(
                imageUrl: effectiveAvatar,
                fit: BoxFit.cover,
              )
            : Container(
                color: AppColors.cardDarkElevated,
                child: Center(
                  child: Text(
                    (partnerName != null && partnerName!.isNotEmpty)
                        ? partnerName![0].toUpperCase()
                        : (message.senderName.isNotEmpty ? message.senderName[0].toUpperCase() : 'H'),
                    style: const TextStyle(
                      color: AppColors.neonPink,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
      ),
    );
  }

  // "Hi there! Want to know a secret?" Intro Card
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

  // Call status record e.g. "📹 Rejected Today 09:55"
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

class _VoicePlayerWidget extends StatefulWidget {
  final String? audioUrl;
  final int durationSecs;
  final bool isMe;

  const _VoicePlayerWidget({
    required this.audioUrl,
    required this.durationSecs,
    required this.isMe,
  });

  @override
  State<_VoicePlayerWidget> createState() => _VoicePlayerWidgetState();
}

class _VoicePlayerWidgetState extends State<_VoicePlayerWidget> {
  final AudioPlayer _player = AudioPlayer();
  bool _isPlaying = false;
  Duration _position = Duration.zero;

  @override
  void initState() {
    super.initState();
    _player.onPlayerStateChanged.listen((state) {
      if (mounted) {
        setState(() {
          _isPlaying = state == PlayerState.playing;
        });
      }
    });
    _player.onPositionChanged.listen((pos) {
      if (mounted) {
        setState(() {
          _position = pos;
        });
      }
    });
    _player.onPlayerComplete.listen((_) {
      if (mounted) {
        setState(() {
          _isPlaying = false;
          _position = Duration.zero;
        });
      }
    });
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  Future<void> _togglePlay() async {
    final rawUrl = widget.audioUrl;
    if (rawUrl == null || rawUrl.isEmpty) return;

    try {
      if (_isPlaying) {
        await _player.pause();
      } else {
        final cleanUrl = CachedImageLoader.normalize(rawUrl);
        if (cleanUrl.startsWith('http://') || cleanUrl.startsWith('https://')) {
          await _player.play(UrlSource(cleanUrl));
        } else {
          await _player.play(DeviceFileSource(cleanUrl));
        }
      }
    } catch (e) {
      debugPrint('[VoicePlayer Error]: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final totalSecs = widget.durationSecs > 0 ? widget.durationSecs : 4;
    final currentSecs = _position.inSeconds;

    return Container(
      width: 190,
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            onTap: _togglePlay,
            child: Container(
              width: 38,
              height: 38,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [Color(0xFF00E676), Color(0xFF00B0FF)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Icon(
                _isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                color: Colors.white,
                size: 24,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: List.generate(14, (i) {
                    final isPassed = _isPlaying && (i / 14) <= (currentSecs / totalSecs);
                    final heights = [8.0, 14.0, 20.0, 12.0, 18.0, 10.0, 22.0, 16.0, 12.0, 18.0, 14.0, 8.0, 16.0, 10.0];
                    return Container(
                      margin: const EdgeInsets.symmetric(horizontal: 1.2),
                      width: 2.5,
                      height: heights[i % heights.length],
                      decoration: BoxDecoration(
                        color: isPassed ? const Color(0xFF00E676) : Colors.white54,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 4),
                Text(
                  _isPlaying ? '0:0${currentSecs % 60}' : '0:0$totalSecs',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 10.5,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

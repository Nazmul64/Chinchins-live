import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/cached_image_loader.dart';

class VoicePartySeatWidget extends StatefulWidget {
  final int seatIndex;
  final String? userName;
  final String? avatarUrl;
  final String? frameSvgUrl;
  final bool isSpeaking;
  final bool isMuted;
  final bool isLocked;
  final bool isHost;
  final bool isTopGifter;
  final int level;
  final int coinsReceived;
  final VoidCallback onTap;

  const VoicePartySeatWidget({
    super.key,
    required this.seatIndex,
    this.userName,
    this.avatarUrl,
    this.frameSvgUrl,
    this.isSpeaking = false,
    this.isMuted = false,
    this.isLocked = false,
    this.isHost = false,
    this.isTopGifter = false,
    this.level = 1,
    this.coinsReceived = 0,
    required this.onTap,
  });

  @override
  State<VoicePartySeatWidget> createState() => _VoicePartySeatWidgetState();
}

class _VoicePartySeatWidgetState extends State<VoicePartySeatWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    if (widget.isSpeaking) {
      _pulseController.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(VoicePartySeatWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isSpeaking && !_pulseController.isAnimating) {
      _pulseController.repeat(reverse: true);
    } else if (!widget.isSpeaking && _pulseController.isAnimating) {
      _pulseController.stop();
      _pulseController.reset();
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Color _getSeatBorderColor() {
    if (widget.isSpeaking) return const Color(0xFF00FF88); // Glowing neon green when speaking
    if (widget.isHost) return const Color(0xFF10B981); // Emerald host border
    switch (widget.seatIndex % 4) {
      case 0:
        return const Color(0xFF3B82F6); // Blue
      case 1:
        return const Color(0xFFA855F7); // Purple
      case 2:
        return const Color(0xFFEC4899); // Pink
      case 3:
      default:
        return const Color(0xFF06B6D4); // Cyan
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasUser = widget.avatarUrl != null && widget.avatarUrl!.isNotEmpty;
    final cleanFrame = widget.frameSvgUrl != null && widget.frameSvgUrl!.isNotEmpty
        ? CachedImageLoader.normalize(widget.frameSvgUrl!)
        : null;
    final borderColor = _getSeatBorderColor();

    return GestureDetector(
      onTap: widget.onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        margin: const EdgeInsets.symmetric(horizontal: 2.5, vertical: 3),
        padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFF131A26).withValues(alpha: 0.92),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: widget.isSpeaking ? const Color(0xFF00FF88) : borderColor.withValues(alpha: 0.55),
            width: widget.isSpeaking ? 2.0 : 1.2,
          ),
          boxShadow: [
            if (widget.isSpeaking)
              BoxShadow(
                color: const Color(0xFF00FF88).withValues(alpha: 0.4),
                blurRadius: 12,
                spreadRadius: 2,
              )
            else
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.35),
                blurRadius: 6,
                offset: const Offset(0, 3),
              ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Avatar Stack with Speaking Halo and Mic Indicator
            SizedBox(
              width: 52,
              height: 52,
              child: Stack(
                alignment: Alignment.center,
                clipBehavior: Clip.none,
                children: [
                  // Speaking Glowing Pulse Halo
                  if (widget.isSpeaking)
                    AnimatedBuilder(
                      animation: _pulseAnimation,
                      builder: (context, child) {
                        return Transform.scale(
                          scale: _pulseAnimation.value,
                          child: Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: const Color(0xFF00FF88),
                                width: 2,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF00FF88).withValues(alpha: 0.6),
                                  blurRadius: 10,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),

                  // Circular Avatar or Empty "+" Slot
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: hasUser ? const Color(0xFF1E293B) : const Color(0xFF1E1B4B),
                      border: Border.all(
                        color: widget.isSpeaking
                            ? const Color(0xFF00FF88)
                            : (widget.isHost ? const Color(0xFFFFD700) : borderColor),
                        width: 1.5,
                      ),
                    ),
                    child: ClipOval(
                      child: hasUser
                          ? CachedImageLoader(
                              imageUrl: widget.avatarUrl!,
                              fit: BoxFit.cover,
                            )
                          : (widget.isLocked
                              ? const Center(
                                  child: Icon(Icons.lock_rounded, color: AppColors.gemYellow, size: 18),
                                )
                              : const Center(
                                  child: Icon(
                                    Icons.add_rounded,
                                    color: Color(0xFF818CF8),
                                    size: 26,
                                  ),
                                )),
                    ),
                  ),

                  // Avatar Base Frame Overlay
                  if (cleanFrame != null && cleanFrame.isNotEmpty)
                    Positioned.fill(
                      child: IgnorePointer(
                        child: cleanFrame.toLowerCase().contains('.svg')
                            ? SvgPicture.network(
                                cleanFrame,
                                fit: BoxFit.contain,
                                placeholderBuilder: (_) => const SizedBox.shrink(),
                              )
                            : CachedImageLoader(
                                imageUrl: cleanFrame,
                                fit: BoxFit.contain,
                              ),
                      ),
                    ),

                  // Host Crown / Top Gifter Crown
                  if (widget.isHost || widget.isTopGifter)
                    Positioned(
                      top: -9,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: const BoxDecoration(
                          color: Color(0xFF0B0E14),
                          shape: BoxShape.circle,
                        ),
                        child: const Text(
                          '👑',
                          style: TextStyle(fontSize: 12),
                        ),
                      ),
                    ),

                  // Mic Status Icon (Unmuted Green / Muted Red)
                  if (hasUser)
                    Positioned(
                      bottom: -2,
                      right: -2,
                      child: Container(
                        padding: const EdgeInsets.all(2.5),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0B0E14),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: widget.isMuted ? const Color(0xFFEF4444) : const Color(0xFF10B981),
                            width: 1.2,
                          ),
                        ),
                        child: Icon(
                          widget.isMuted ? Icons.mic_off_rounded : Icons.mic_rounded,
                          color: widget.isMuted ? const Color(0xFFEF4444) : const Color(0xFF10B981),
                          size: 10,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 4),

            // Username or "Your Seat"
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 68),
              child: Text(
                hasUser ? (widget.userName ?? 'User') : 'Your Seat',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 10.5,
                  fontWeight: hasUser ? FontWeight.bold : FontWeight.w600,
                  shadows: const [
                    Shadow(color: Colors.black87, blurRadius: 4),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 2),

            // Role Badge: 👑 Host / 👤 Speaker / Join Now
            if (hasUser)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                decoration: BoxDecoration(
                  color: widget.isHost
                      ? const Color(0xFF78350F).withValues(alpha: 0.85)
                      : const Color(0xFF312E81).withValues(alpha: 0.85),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: widget.isHost
                        ? const Color(0xFFFFD700).withValues(alpha: 0.6)
                        : const Color(0xFF818CF8).withValues(alpha: 0.4),
                    width: 0.6,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (widget.isHost) ...[
                      const Text('👑', style: TextStyle(fontSize: 8)),
                      const SizedBox(width: 2),
                      const Text(
                        'Host',
                        style: TextStyle(
                          color: Color(0xFFFFD700),
                          fontSize: 8.5,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ] else ...[
                      const Icon(Icons.person_rounded, color: Color(0xFF93C5FD), size: 9),
                      const SizedBox(width: 1.5),
                      const Text(
                        'Speaker',
                        style: TextStyle(
                          color: Color(0xFFE2E8F0),
                          fontSize: 8.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ),
              )
            else
              Text(
                'Join Now',
                style: TextStyle(
                  color: const Color(0xFF38BDF8),
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                  shadows: [
                    Shadow(
                      color: const Color(0xFF38BDF8).withValues(alpha: 0.5),
                      blurRadius: 6,
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

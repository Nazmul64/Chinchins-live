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
    this.coinsReceived = 0,
    required this.onTap,
  });

  @override
  State<VoicePartySeatWidget> createState() => _VoicePartySeatWidgetState();
}

class _VoicePartySeatWidgetState extends State<VoicePartySeatWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _waveController;

  @override
  void initState() {
    super.initState();
    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    if (widget.isSpeaking) {
      _waveController.repeat();
    }
  }

  @override
  void didUpdateWidget(VoicePartySeatWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isSpeaking && !_waveController.isAnimating) {
      _waveController.repeat();
    } else if (!widget.isSpeaking && _waveController.isAnimating) {
      _waveController.stop();
      _waveController.reset();
    }
  }

  @override
  void dispose() {
    _waveController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hasUser = widget.avatarUrl != null && widget.avatarUrl!.isNotEmpty;
    final cleanFrame = widget.frameSvgUrl != null && widget.frameSvgUrl!.isNotEmpty
        ? CachedImageLoader.normalize(widget.frameSvgUrl!)
        : null;

    return GestureDetector(
      onTap: widget.onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 80,
            height: 80,
            child: Stack(
              alignment: Alignment.center,
              clipBehavior: Clip.none,
              children: [
                // ১. স্পিকিং রিপল ওয়েভ অ্যানিমেশন (যখন মাইকে কথা বলে)
                if (widget.isSpeaking)
                  AnimatedBuilder(
                    animation: _waveController,
                    builder: (context, child) {
                      final waveScale = _waveController.value;
                      final waveOpacity = (1.0 - waveScale).clamp(0.0, 1.0);
                      return Container(
                        width: 66 + (waveScale * 14),
                        height: 66 + (waveScale * 14),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: const Color(0xFFF43F5E).withValues(alpha: waveOpacity),
                            width: 2.2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFF43F5E).withValues(alpha: 0.4 * waveOpacity),
                              blurRadius: 10,
                              spreadRadius: 3,
                            ),
                          ],
                        ),
                      );
                    },
                  ),

                // ২. ইউজার সার্কুলার প্রোফাইল ছবি অথবা এম্পটি সিট
                Container(
                  width: 58,
                  height: 58,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFF251E36),
                    border: Border.all(
                      color: widget.isHost
                          ? AppColors.gemYellow
                          : (widget.isSpeaking ? const Color(0xFFF43F5E) : Colors.white24),
                      width: widget.isHost ? 2 : 1.2,
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
                                child: Icon(Icons.lock_rounded, color: AppColors.gemYellow, size: 22),
                              )
                            : Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(
                                      Icons.chair_rounded,
                                      color: Color(0xFF8B85A1),
                                      size: 20,
                                    ),
                                    Text(
                                      '${widget.seatIndex}',
                                      style: const TextStyle(
                                        color: Color(0xFF8B85A1),
                                        fontSize: 9,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              )),
                  ),
                ),

                // ৩. লাক্সারি অ্যাভাটার ফ্রেম ওভারলে (King, Queen, God-Tier, etc.)
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

                // Host Crown Badge (Top Center)
                if (widget.isHost)
                  Positioned(
                    top: -4,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: const BoxDecoration(
                        color: Colors.black87,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.military_tech_rounded,
                        color: AppColors.gemYellow,
                        size: 15,
                      ),
                    ),
                  ),

                // ৪. মাইক ও মিউট স্ট্যাটাস ইন্ডিকেটর (নিচে ডানপাশে)
                if (hasUser)
                  Positioned(
                    bottom: 2,
                    right: 4,
                    child: Container(
                      padding: const EdgeInsets.all(3.5),
                      decoration: BoxDecoration(
                        color: widget.isMuted ? Colors.black87 : const Color(0xFFE11D48),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 1.5),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.5),
                            blurRadius: 3,
                          ),
                        ],
                      ),
                      child: Icon(
                        widget.isMuted ? Icons.mic_off_rounded : Icons.mic_rounded,
                        color: Colors.white,
                        size: 11,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 3),

          // ৫. সিট নম্বর ও ইউজারের নাম
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
            decoration: BoxDecoration(
              color: Colors.black54,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.white12, width: 0.6),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(2.5),
                  decoration: const BoxDecoration(
                    color: Color(0xFFE11D48),
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    '${widget.seatIndex}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 8.5,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 3),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 58),
                  child: Text(
                    widget.userName ?? 'Seat ${widget.seatIndex}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Coins / Diamonds Received
          if (hasUser && widget.coinsReceived > 0)
            Padding(
              padding: const EdgeInsets.only(top: 1),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.diamond_rounded, color: AppColors.gemYellow, size: 9),
                  const SizedBox(width: 1.5),
                  Text(
                    '${widget.coinsReceived}',
                    style: const TextStyle(
                      color: AppColors.gemYellow,
                      fontSize: 8,
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

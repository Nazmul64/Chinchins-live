import 'package:flutter/material.dart';
import '../../../core/models/group_room.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/cached_image_loader.dart';

class RoomSeatWidget extends StatefulWidget {
  final RoomSeat seat;
  final VoidCallback onTap;
  final bool isVideoGrid;

  const RoomSeatWidget({
    super.key,
    required this.seat,
    required this.onTap,
    this.isVideoGrid = false,
  });

  @override
  State<RoomSeatWidget> createState() => _RoomSeatWidgetState();
}

class _RoomSeatWidgetState extends State<RoomSeatWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _rippleController;
  late Animation<double> _rippleAnimation;

  @override
  void initState() {
    super.initState();
    _rippleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);

    _rippleAnimation = Tween<double>(begin: 1.0, end: 1.18).animate(
      CurvedAnimation(parent: _rippleController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _rippleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final seat = widget.seat;
    final displayIndex = seat.seatIndex + 1;

    return GestureDetector(
      onTap: widget.onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Seat Avatar or Empty Seat Chair
          SizedBox(
            width: 50,
            height: 50,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Speaking Animated Ripple Waves
                if (seat.isSpeaking && !seat.isEmpty)
                  AnimatedBuilder(
                    animation: _rippleAnimation,
                    builder: (context, child) {
                      return Container(
                        width: 50 * _rippleAnimation.value,
                        height: 50 * _rippleAnimation.value,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.neonPink.withValues(
                            alpha: 0.35 * (1.2 - _rippleAnimation.value),
                          ),
                          border: Border.all(
                            color: AppColors.neonPink.withValues(alpha: 0.8),
                            width: 1.5,
                          ),
                        ),
                      );
                    },
                  ),

                // Main Circle Avatar / Empty Chair
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFF251E36),
                    border: Border.all(
                      color: seat.isHost
                          ? AppColors.gemYellow
                          : (seat.isSpeaking ? AppColors.neonPink : AppColors.cardBorder),
                      width: seat.isHost ? 2 : 1.2,
                    ),
                  ),
                  child: seat.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.chair_rounded,
                                color: Color(0xFF756E8A),
                                size: 18,
                              ),
                              Text(
                                '$displayIndex',
                                style: const TextStyle(
                                  color: Color(0xFF756E8A),
                                  fontSize: 8,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        )
                      : ClipOval(
                          child: (seat.userAvatar != null && seat.userAvatar!.isNotEmpty)
                              ? CachedImageLoader(
                                  imageUrl: seat.userAvatar!,
                                  fit: BoxFit.cover,
                                )
                              : Container(
                                  color: const Color(0xFF381F4B),
                                  child: Center(
                                    child: Text(
                                      (seat.userName?.isNotEmpty == true)
                                          ? seat.userName![0].toUpperCase()
                                          : '$displayIndex',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ),
                                ),
                        ),
                ),

                // Host Crown Icon (Seat 1 / isHost)
                if (seat.isHost)
                  Positioned(
                    top: -2,
                    child: Container(
                      padding: const EdgeInsets.all(1.5),
                      decoration: const BoxDecoration(
                        color: Colors.black87,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.military_tech_rounded,
                        color: AppColors.gemYellow,
                        size: 13,
                      ),
                    ),
                  ),

                // Verified Badge
                if (!seat.isEmpty && seat.isVerified)
                  Positioned(
                    top: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.all(1),
                      decoration: const BoxDecoration(
                        color: Color(0xFF00E5FF),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.check_rounded,
                        color: Colors.black,
                        size: 8,
                      ),
                    ),
                  ),

                // Mute / Mic Status Badge
                if (!seat.isEmpty && seat.isMuted)
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: const BoxDecoration(
                        color: Color(0xFFFF1744),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.mic_off_rounded,
                        color: Colors.white,
                        size: 8,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 2),

          // User Name / Take Seat label + Level
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 1),
            child: Text(
              seat.isEmpty ? 'Seat $displayIndex' : (seat.userName ?? 'Guest'),
              textAlign: TextAlign.center,
              style: TextStyle(
                color: seat.isEmpty ? AppColors.textMuted : Colors.white,
                fontSize: 9,
                fontWeight: seat.isHost ? FontWeight.bold : FontWeight.w500,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),

          // Coins Received / Role Badge
          if (!seat.isEmpty && seat.coinsReceived > 0)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.diamond_rounded, color: AppColors.gemYellow, size: 8),
                const SizedBox(width: 1),
                Text(
                  '${seat.coinsReceived}',
                  style: const TextStyle(
                    color: AppColors.gemYellow,
                    fontSize: 7.5,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            )
          else if (seat.isHost)
            Container(
              margin: const EdgeInsets.only(top: 1),
              padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 0.5),
              decoration: BoxDecoration(
                color: AppColors.gemYellow.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(3),
              ),
              child: const Text(
                'HOST',
                style: TextStyle(
                  color: AppColors.gemYellow,
                  fontSize: 7,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

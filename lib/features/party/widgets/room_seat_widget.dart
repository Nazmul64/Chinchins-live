import 'package:flutter/material.dart';
import '../../../core/models/group_room.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/cached_image_loader.dart';

class RoomSeatWidget extends StatefulWidget {
  final RoomSeat seat;
  final VoidCallback onTap;

  const RoomSeatWidget({
    super.key,
    required this.seat,
    required this.onTap,
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

    return GestureDetector(
      onTap: widget.onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Seat Avatar or Empty Seat Chair
          SizedBox(
            width: 64,
            height: 64,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Speaking Animated Ripple Waves
                if (seat.isSpeaking && !seat.isEmpty)
                  AnimatedBuilder(
                    animation: _rippleAnimation,
                    builder: (context, child) {
                      return Container(
                        width: 64 * _rippleAnimation.value,
                        height: 64 * _rippleAnimation.value,
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
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFF251E36),
                    border: Border.all(
                      color: seat.isHost
                          ? AppColors.gemYellow
                          : (seat.isSpeaking ? AppColors.neonPink : AppColors.cardBorder),
                      width: seat.isHost ? 2 : 1.5,
                    ),
                  ),
                  child: seat.isEmpty
                      ? const Center(
                          child: Icon(
                            Icons.chair_rounded,
                            color: Color(0xFF756E8A),
                            size: 24,
                          ),
                        )
                      : ClipOval(
                          child: CachedImageLoader(
                            imageUrl: seat.userAvatar!,
                            fit: BoxFit.cover,
                          ),
                        ),
                ),

                // Host Crown Icon
                if (seat.isHost)
                  Positioned(
                    top: -2,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: const BoxDecoration(
                        color: Colors.black54,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.military_tech_rounded,
                        color: AppColors.gemYellow,
                        size: 16,
                      ),
                    ),
                  ),

                // Mute / Mic Status Badge
                if (!seat.isEmpty && seat.isMuted)
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.all(3),
                      decoration: const BoxDecoration(
                        color: Color(0xFFFF1744),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.mic_off_rounded,
                        color: Colors.white,
                        size: 10,
                      ),
                    ),
                  ),

                // Empty Seat Number Badge
                if (seat.isEmpty)
                  Positioned(
                    bottom: 2,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '${seat.seatIndex + 1}',
                        style: const TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 4),

          // User Name / Take Seat label
          SizedBox(
            width: 68,
            child: Text(
              seat.isEmpty ? 'Seat ${seat.seatIndex + 1}' : seat.userName!,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: seat.isEmpty ? AppColors.textMuted : Colors.white,
                fontSize: 11,
                fontWeight: seat.isHost ? FontWeight.bold : FontWeight.w500,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),

          // Coins Received Badge
          if (!seat.isEmpty && seat.coinsReceived > 0)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.diamond_rounded, color: AppColors.gemYellow, size: 10),
                const SizedBox(width: 2),
                Text(
                  '${seat.coinsReceived}',
                  style: const TextStyle(
                    color: AppColors.gemYellow,
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

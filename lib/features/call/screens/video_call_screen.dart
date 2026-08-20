import 'dart:async';
import 'package:flutter/material.dart';
import '../../../core/models/model_profile.dart';
import '../../../core/models/gift_item.dart';
import '../../../core/data/mock_data.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/cached_image_loader.dart';
import '../../chat/widgets/gift_picker_modal.dart';
import '../../wallet/widgets/continue_call_recharge_dialog.dart';

class VideoCallScreen extends StatefulWidget {
  final ModelProfile model;

  const VideoCallScreen({
    super.key,
    required this.model,
  });

  @override
  State<VideoCallScreen> createState() => _VideoCallScreenState();
}

class _VideoCallScreenState extends State<VideoCallScreen> {
  int _callSeconds = 79; // Start at 01:19 as in the screenshot or count upwards
  Timer? _timer;
  bool _isMuted = false;
  bool _isCameraOff = false;
  bool _isBeautyFilterOn = true;
  String? _activeGiftShower;
  int _userGems = 12450;
  bool _isRechargeDialogVisible = false;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _callSeconds++;
          // Trigger the recharge dialog automatically after preview time if not already shown
          if (_callSeconds == 85 && !_isRechargeDialogVisible) {
            _showRechargePopup();
          }
        });
      }
    });
  }

  String _formatDuration(int seconds) {
    final mins = (seconds ~/ 60).toString().padLeft(2, '0');
    final secs = (seconds % 60).toString().padLeft(2, '0');
    return '$mins:$secs';
  }

  void _showGiftShower(GiftItem gift) {
    setState(() {
      _activeGiftShower = gift.emoji;
      _userGems -= gift.coins;
    });

    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() {
          _activeGiftShower = null;
        });
      }
    });
  }

  void _showRechargePopup() {
    setState(() {
      _isRechargeDialogVisible = true;
    });
  }

  void _hideRechargePopupAndEndCall() {
    setState(() {
      _isRechargeDialogVisible = false;
    });
    Navigator.pop(context);
  }

  void _onGetCoinsSuccess() {
    setState(() {
      _userGems += 7560;
      _isRechargeDialogVisible = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('🎉 7,560 Gems added! Video call extended.'),
        backgroundColor: AppColors.onlineGreen,
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 1. Host Video Stream Feed
          CachedImageLoader(
            imageUrl: widget.model.avatarUrl,
            fit: BoxFit.cover,
          ),

          // Dark overlay gradient
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Color(0x99000000),
                  Colors.transparent,
                  Color(0xCC000000),
                ],
                stops: [0.0, 0.4, 1.0],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),

          // 2. Animated Gift Overlay
          if (_activeGiftShower != null)
            Center(
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.2, end: 1.6),
                duration: const Duration(milliseconds: 900),
                curve: Curves.elasticOut,
                builder: (context, scale, child) {
                  return Transform.scale(
                    scale: scale,
                    child: Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.black54,
                        border: Border.all(color: AppColors.gemYellow, width: 2),
                      ),
                      child: Text(
                        _activeGiftShower!,
                        style: const TextStyle(fontSize: 64),
                      ),
                    ),
                  );
                },
              ),
            ),

          // 3. Top Call Duration & "Continue Video Call" Pills matching Screenshot
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Column(
                children: [
                  // Top Row: Timer Mini Window + User Gems
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Host Info Pill
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.black45,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.white24, width: 0.8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircleAvatar(
                              radius: 14,
                              backgroundImage: NetworkImage(widget.model.avatarUrl),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              widget.model.name,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Top Timer Box matching Screenshot (01:19)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.6),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: AppColors.gemYellow.withValues(alpha: 0.4), width: 0.8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.diamond_rounded, color: AppColors.gemYellow, size: 14),
                                const SizedBox(width: 4),
                                Text(
                                  '$_userGems',
                                  style: const TextStyle(
                                    color: AppColors.gemYellow,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.6),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: Colors.white24, width: 0.8),
                            ),
                            child: Text(
                              _formatDuration(_callSeconds),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // "Continue Video Call 💎 1800/min" Pill matching Screenshot
                  GestureDetector(
                    onTap: _showRechargePopup,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.65),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white24, width: 0.8),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            'Continue Video Call',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.diamond_rounded, color: AppColors.gemYellow, size: 14),
                              const SizedBox(width: 4),
                              Text(
                                '${widget.model.pricePerMin}/min',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 4. Floating Self-Camera Preview (Top Right)
          if (!_isRechargeDialogVisible)
            Positioned(
              top: 140,
              right: 16,
              child: Container(
                width: 90,
                height: 125,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.white38, width: 1.5),
                  boxShadow: const [
                    BoxShadow(color: Colors.black54, blurRadius: 10),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Container(
                        color: const Color(0xFF1E1830),
                        child: _isCameraOff
                            ? const Center(
                                child: Icon(Icons.videocam_off, color: Colors.white54, size: 28),
                              )
                            : CachedImageLoader(
                                imageUrl: MockData.imgLivePreview,
                                fit: BoxFit.cover,
                              ),
                      ),
                      Positioned(
                        bottom: 4,
                        left: 6,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                          decoration: BoxDecoration(
                            color: Colors.black54,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'You',
                            style: TextStyle(color: Colors.white, fontSize: 9),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // 5. Bottom Call Controls (shown when recharge popup is closed)
          if (!_isRechargeDialogVisible)
            Positioned(
              bottom: 30,
              left: 0,
              right: 0,
              child: SafeArea(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    // Beauty Filter Toggle
                    _buildCallControlButton(
                      icon: Icons.auto_fix_high_rounded,
                      isActive: _isBeautyFilterOn,
                      activeColor: AppColors.neonPurple,
                      onTap: () {
                        setState(() {
                          _isBeautyFilterOn = !_isBeautyFilterOn;
                        });
                      },
                    ),

                    // Mic Toggle
                    _buildCallControlButton(
                      icon: _isMuted ? Icons.mic_off_rounded : Icons.mic_rounded,
                      isActive: !_isMuted,
                      activeColor: Colors.white24,
                      onTap: () {
                        setState(() {
                          _isMuted = !_isMuted;
                        });
                      },
                    ),

                    // End Call Button (Big Red) -> Shows Recharge Dialog
                    GestureDetector(
                      onTap: _showRechargePopup,
                      child: Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: const Color(0xFFFF2D55),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFFF2D55).withValues(alpha: 0.5),
                              blurRadius: 16,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.call_end_rounded,
                          color: Colors.white,
                          size: 32,
                        ),
                      ),
                    ),

                    // Camera Toggle
                    _buildCallControlButton(
                      icon: _isCameraOff ? Icons.videocam_off_rounded : Icons.switch_camera_rounded,
                      isActive: !_isCameraOff,
                      activeColor: Colors.white24,
                      onTap: () {
                        setState(() {
                          _isCameraOff = !_isCameraOff;
                        });
                      },
                    ),

                    // Send Live Gift Button
                    _buildCallControlButton(
                      icon: Icons.card_giftcard_rounded,
                      isActive: true,
                      activeColor: AppColors.warmOrange,
                      onTap: () {
                        showModalBottomSheet(
                          context: context,
                          isScrollControlled: true,
                          backgroundColor: Colors.transparent,
                          builder: (context) => GiftPickerModal(
                            onGiftSelected: _showGiftShower,
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),

          // 6. Centered Overlaid Dialog matching Screenshot (with Ribbon Diamond, Host Photo, 7560 BDT 150.00, Get Coins)
          if (_isRechargeDialogVisible)
            Container(
              color: Colors.black.withValues(alpha: 0.55),
              child: Center(
                child: ContinueCallRechargeDialog(
                  model: widget.model,
                  durationText: _formatDuration(_callSeconds),
                  onClose: _hideRechargePopupAndEndCall,
                  onGetCoins: _onGetCoinsSuccess,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCallControlButton({
    required IconData icon,
    required bool isActive,
    required Color activeColor,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isActive ? activeColor : Colors.black45,
          border: Border.all(color: Colors.white24, width: 1),
        ),
        child: Icon(
          icon,
          color: Colors.white,
          size: 22,
        ),
      ),
    );
  }
}

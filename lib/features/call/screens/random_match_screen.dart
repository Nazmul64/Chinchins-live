import 'dart:async';
import 'package:flutter/material.dart';
import '../../../core/models/model_profile.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/cached_image_loader.dart';
import '../../wallet/widgets/recharge_gems_sheet.dart';
import '../services/call_api_service.dart';
import 'video_call_screen.dart';

class RandomMatchScreen extends StatefulWidget {
  const RandomMatchScreen({super.key});

  @override
  State<RandomMatchScreen> createState() => _RandomMatchScreenState();
}

class _RandomMatchScreenState extends State<RandomMatchScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _radarController;
  bool _isSearching = true;
  bool _isConnecting = false;
  ModelProfile? _matchedProfile;
  int _countdown = 3;
  Timer? _countdownTimer;

  @override
  void initState() {
    super.initState();
    _radarController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();

    _findMatch();
  }

  @override
  void dispose() {
    _radarController.dispose();
    _countdownTimer?.cancel();
    super.dispose();
  }

  Future<void> _findMatch() async {
    setState(() {
      _isSearching = true;
      _isConnecting = false;
      _matchedProfile = null;
    });

    try {
      final res = await CallApiService.randomMatch(
        callType: 'video',
        gender: 'female',
      );

      if (mounted) {
        if (res != null && res['matched_user'] != null) {
          final user = res['matched_user'] as Map<String, dynamic>;
          final profile = ModelProfile.fromJson(user);

          setState(() {
            _matchedProfile = profile;
            _isSearching = false;
            _countdown = 3;
          });

          _startAutoConnect();
        } else {
          // Fallback demo match
          setState(() {
            _matchedProfile = ModelProfile.fromJson({
              'id': '2',
              'name': 'Ayeena04',
              'avatar': 'https://images.unsplash.com/photo-1534528741775-53994a69daeb',
              'age': 21,
              'country': 'Bangladesh',
              'video_call_rate': 100,
            });
            _isSearching = false;
            _countdown = 3;
          });
          _startAutoConnect();
        }
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isSearching = false);
      }
    }
  }

  void _startAutoConnect() {
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_countdown > 1) {
        setState(() => _countdown--);
      } else {
        timer.cancel();
        _connectCall();
      }
    });
  }

  Future<void> _connectCall() async {
    if (_matchedProfile == null || _isConnecting) return;
    _countdownTimer?.cancel();

    setState(() => _isConnecting = true);

    final res = await CallApiService.initiateCall(
      receiverId: _matchedProfile!.id,
      callType: 'video',
    );

    if (!mounted) return;

    if (res['success'] == true) {
      final callId = res['call_id'] is int ? res['call_id'] as int : int.tryParse(res['call_id']?.toString() ?? '1') ?? 1;
      final isFreeTrial = res['is_free_trial'] == true;
      final freeSecs = (res['free_duration_seconds'] is int) ? res['free_duration_seconds'] as int : 10;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => VideoCallScreen(
            model: _matchedProfile!,
            callId: callId,
            isFreeTrial: isFreeTrial,
            freeDurationSeconds: freeSecs,
          ),
        ),
      );
    } else if (res['is_low_balance'] == true || res['code'] == 'LOW_BALANCE_DEPOSIT_REQUIRED') {
      setState(() => _isConnecting = false);
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (context) => RechargeGemsSheet(
          onRechargeSuccess: () {
            _connectCall();
          },
        ),
      );
    } else {
      setState(() => _isConnecting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res['message'] ?? 'Could not start call'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0E17),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          '1-on-1 Video Matching',
          style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Column(
            children: [
              const SizedBox(height: 10),
              // Subtitle
              Text(
                _isSearching
                    ? '🔍 Searching for available female hosts...'
                    : '🎉 Match Found! Connecting with Host...',
                style: TextStyle(
                  color: _isSearching ? AppColors.textSecondary : AppColors.onlineGreen,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 30),

              // Radar / Matched Host Card
              Expanded(
                child: Center(
                  child: _isSearching
                      ? _buildRadarAnimation()
                      : _buildMatchedCard(),
                ),
              ),

              const SizedBox(height: 20),

              // Bottom Action Controls
              if (!_isSearching && _matchedProfile != null) ...[
                Row(
                  children: [
                    // Skip / Next Match
                    Expanded(
                      flex: 1,
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white70,
                          side: const BorderSide(color: Colors.white24),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        icon: const Icon(Icons.refresh_rounded, size: 18),
                        label: const Text('Next Match', style: TextStyle(fontWeight: FontWeight.bold)),
                        onPressed: _findMatch,
                      ),
                    ),
                    const SizedBox(width: 12),

                    // Connect Now Button
                    Expanded(
                      flex: 2,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          padding: EdgeInsets.zero,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        onPressed: _isConnecting ? null : _connectCall,
                        child: Ink(
                          decoration: BoxDecoration(
                            gradient: AppColors.primaryGradient,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            alignment: Alignment.center,
                            child: _isConnecting
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                  )
                                : Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Icon(Icons.videocam_rounded, color: Colors.white, size: 20),
                                      const SizedBox(width: 8),
                                      Text(
                                        'Call Now ($_countdown s)',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 15,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 14),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRadarAnimation() {
    return AnimatedBuilder(
      animation: _radarController,
      builder: (context, child) {
        return Stack(
          alignment: Alignment.center,
          children: [
            // Wave 3
            Container(
              width: 260 * _radarController.value,
              height: 260 * _radarController.value,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.neonPurple.withValues(alpha: (1.0 - _radarController.value) * 0.25),
              ),
            ),
            // Wave 2
            Container(
              width: 180 * _radarController.value,
              height: 180 * _radarController.value,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppColors.neonPink.withValues(alpha: (1.0 - _radarController.value) * 0.6),
                  width: 2,
                ),
              ),
            ),
            // Center Glowing Core
            Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: AppColors.primaryGradient,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.neonPink.withValues(alpha: 0.6),
                    blurRadius: 20,
                    spreadRadius: 4,
                  ),
                ],
              ),
              child: const Icon(
                Icons.videocam_rounded,
                color: Colors.white,
                size: 44,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildMatchedCard() {
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(maxWidth: 320, maxHeight: 420),
      decoration: BoxDecoration(
        color: AppColors.cardDarkElevated,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.neonPink.withValues(alpha: 0.6), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: AppColors.neonPink.withValues(alpha: 0.3),
            blurRadius: 24,
            spreadRadius: 2,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Host Cover Photo
            CachedImageLoader(
              imageUrl: _matchedProfile!.avatarUrl,
              fit: BoxFit.cover,
            ),
            // Gradient Overlay
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.transparent,
                    Color(0x66000000),
                    Color(0xEE0F0E17),
                  ],
                  stops: [0.3, 0.65, 1.0],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
            // Host Info
            Positioned(
              left: 16,
              right: 16,
              bottom: 20,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Text(
                        _matchedProfile!.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE91E63),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '${_matchedProfile!.age}',
                          style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.location_on_rounded, color: Colors.white70, size: 14),
                      const SizedBox(width: 4),
                      Text(
                        _matchedProfile!.location,
                        style: const TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.gemYellow.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.gemYellow.withValues(alpha: 0.5)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.diamond_rounded, color: AppColors.gemYellow, size: 14),
                        const SizedBox(width: 4),
                        Text(
                          '${_matchedProfile!.pricePerMin} Gems / min',
                          style: const TextStyle(
                            color: AppColors.gemYellow,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
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

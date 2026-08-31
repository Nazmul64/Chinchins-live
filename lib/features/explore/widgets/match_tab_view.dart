import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import '../../../core/models/model_profile.dart';
import '../../../core/data/mock_data.dart';
import '../../../core/services/profile_api_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/cached_image_loader.dart';
import '../services/match_api_service.dart';
import '../../call/screens/random_match_screen.dart';
import '../../profile/screens/host_profile_screen.dart';

class MatchTabView extends StatefulWidget {
  final VoidCallback? onStartMatching;

  const MatchTabView({super.key, this.onStartMatching});

  @override
  State<MatchTabView> createState() => _MatchTabViewState();
}

class _MatchTabViewState extends State<MatchTabView> {
  // Pool of all available online users
  List<ModelProfile> _pool = [];

  // Exactly 8 card slots displayed on screen
  List<ModelProfile> _displayedSlots = [];

  // Timer for smoothly swapping user photos one by one
  Timer? _swapTimer;
  Timer? _apiPollTimer;
  Timer? _counterJiggleTimer;

  int _currentSlotIndex = 0;
  int _poolCursor = 0;
  int _waitingCount = 5383;
  final Random _random = Random();

  @override
  void initState() {
    super.initState();
    _initializePoolAndSlots();
    _fetchLiveOnlineUsers();
    _startPeriodicSwapper();
    _startLiveCountJiggle();
  }

  @override
  void dispose() {
    _swapTimer?.cancel();
    _apiPollTimer?.cancel();
    _counterJiggleTimer?.cancel();
    super.dispose();
  }

  void _initializePoolAndSlots() {
    // Start with rich model profiles from MockData
    final basePool = List<ModelProfile>.from(MockData.models);
    _pool = basePool;

    // Fill the initial 8 slots
    _displayedSlots = [];
    for (int i = 0; i < 8; i++) {
      if (i < _pool.length) {
        _displayedSlots.add(_pool[i]);
      } else {
        _displayedSlots.add(_pool[i % _pool.length]);
      }
    }
    _poolCursor = 8 % max(1, _pool.length);
  }

  Future<void> _fetchLiveOnlineUsers() async {
    try {
      // 1. Try dedicated Match API endpoint (/api/match)
      final matchData = await MatchApiService.getMatchData();
      if (matchData != null && mounted) {
        if (matchData['waiting_count'] is int) {
          _waitingCount = matchData['waiting_count'] as int;
        }
        if (matchData['hosts'] is List) {
          final hostsList = (matchData['hosts'] as List)
              .map((h) => ModelProfile.fromJson(h as Map<String, dynamic>))
              .toList();
          if (hostsList.isNotEmpty) {
            setState(() {
              final existingIds = hostsList.map((e) => e.id).toSet();
              final remainingOld = _pool.where((p) => !existingIds.contains(p.id)).toList();
              _pool = [...hostsList, ...remainingOld];
              for (int i = 0; i < min(8, _pool.length); i++) {
                if (i < _displayedSlots.length) {
                  _displayedSlots[i] = _pool[i];
                }
              }
            });
            return;
          }
        }
      }

      // 2. Fallback to Home Feed API
      final liveFeed = await ProfileApiService.getHomeFeed();
      if (liveFeed.isNotEmpty && mounted) {
        final onlineOnly = liveFeed.where((m) {
          final name = m.name.toLowerCase();
          return !name.contains('admin') && m.isOnline;
        }).toList();

        if (onlineOnly.isNotEmpty) {
          setState(() {
            final existingIds = onlineOnly.map((e) => e.id).toSet();
            final remainingOld = _pool.where((p) => !existingIds.contains(p.id)).toList();
            _pool = [...onlineOnly, ...remainingOld];

            for (int i = 0; i < min(8, _pool.length); i++) {
              if (i >= _displayedSlots.length) {
                _displayedSlots.add(_pool[i]);
              }
            }
          });
        }
      }
    } catch (_) {}

    // Periodic check every 20 seconds for new online users
    _apiPollTimer?.cancel();
    _apiPollTimer = Timer.periodic(const Duration(seconds: 20), (_) => _fetchLiveOnlineUsers());
  }

  void _startPeriodicSwapper() {
    _swapTimer?.cancel();
    // Swap 1 avatar every 2.2 seconds sequentially/randomly with animation
    _swapTimer = Timer.periodic(const Duration(milliseconds: 2200), (_) {
      if (!mounted || _pool.isEmpty || _displayedSlots.length < 8) return;

      // Choose next slot in an engaging order: [0, 5, 2, 7, 1, 4, 3, 6]
      const pattern = [0, 5, 2, 7, 1, 4, 3, 6];
      final targetSlot = pattern[_currentSlotIndex % pattern.length];
      _currentSlotIndex++;

      // Find next candidate from pool that is not in the other slots
      final currentlyShowingIds = _displayedSlots.map((m) => m.id).toSet();
      ModelProfile? nextProfile;

      for (int i = 0; i < _pool.length; i++) {
        final candidate = _pool[(_poolCursor + i) % _pool.length];
        if (!currentlyShowingIds.contains(candidate.id)) {
          nextProfile = candidate;
          _poolCursor = (_poolCursor + i + 1) % _pool.length;
          break;
        }
      }

      // Fallback if pool is small
      if (nextProfile == null) {
        nextProfile = _pool[_poolCursor % _pool.length];
        _poolCursor = (_poolCursor + 1) % _pool.length;
      }

      setState(() {
        _displayedSlots[targetSlot] = nextProfile!;
      });
    });
  }

  void _startLiveCountJiggle() {
    _counterJiggleTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!mounted) return;
      setState(() {
        // Subtle realistic live count fluctuation around 5380-5395
        final delta = _random.nextInt(5) - 2; // -2, -1, 0, 1, 2
        _waitingCount = (_waitingCount + delta).clamp(5300, 5450);
      });
    });
  }

  void _onSlotTapped(ModelProfile profile) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => HostProfileScreen(model: profile),
      ),
    );
  }

  void _onStartMatchingPressed() {
    if (widget.onStartMatching != null) {
      widget.onStartMatching!();
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const RandomMatchScreen(),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_displayedSlots.length < 8) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.neonPink),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final screenWidth = constraints.maxWidth;
        final horizontalPadding = 16.0;
        final columnGap = 8.0;
        final totalGaps = 3 * columnGap;
        final availableWidth = screenWidth - (horizontalPadding * 2) - totalGaps;
        final cardWidth = availableWidth / 4;
        final cardHeight = cardWidth * 1.42;

        return SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: 8),
            child: Column(
              children: [
                const SizedBox(height: 6),

                // 8 Avatar Cards in 4 Staggered Columns matching Screenshot
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Column 1 (Slots 0 & 4)
                    _buildColumn(
                      topModel: _displayedSlots[0],
                      bottomModel: _displayedSlots[4],
                      width: cardWidth,
                      height: cardHeight,
                      topOffset: 0,
                    ),
                    SizedBox(width: columnGap),

                    // Column 2 (Slots 1 & 5) - shifted down slightly
                    _buildColumn(
                      topModel: _displayedSlots[1],
                      bottomModel: _displayedSlots[5],
                      width: cardWidth,
                      height: cardHeight,
                      topOffset: 16,
                    ),
                    SizedBox(width: columnGap),

                    // Column 3 (Slots 2 & 6) - shifted down a little
                    _buildColumn(
                      topModel: _displayedSlots[2],
                      bottomModel: _displayedSlots[6],
                      width: cardWidth,
                      height: cardHeight,
                      topOffset: 4,
                    ),
                    SizedBox(width: columnGap),

                    // Column 4 (Slots 3 & 7) - shifted down
                    _buildColumn(
                      topModel: _displayedSlots[3],
                      bottomModel: _displayedSlots[7],
                      width: cardWidth,
                      height: cardHeight,
                      topOffset: 18,
                    ),
                  ],
                ),

                const SizedBox(height: 38),

                // Live Number: 5383
                Text(
                  '$_waitingCount',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 40,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.5,
                    fontFamily: 'sans-serif',
                  ),
                ),
                const SizedBox(height: 6),

                // Subtitle: People waiting to meet you
                Text(
                  'People waiting to meet you',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.85),
                    fontSize: 15.5,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.3,
                  ),
                ),
                const SizedBox(height: 28),

                // "Start Matching" Pill Gradient Button matching Screenshot
                Center(
                  child: Container(
                    width: min(screenWidth * 0.78, 300),
                    height: 52,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(26),
                      gradient: const LinearGradient(
                        colors: [
                          Color(0xFF8A1BC7), // Vibrant Deep Violet
                          Color(0xFFD81B60), // Vivid Magenta Pink
                          Color(0xFFFF2A85), // Hot Neon Pink
                        ],
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFFF2A85).withValues(alpha: 0.4),
                          blurRadius: 18,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(26),
                        onTap: _onStartMatchingPressed,
                        splashColor: Colors.white24,
                        highlightColor: Colors.white10,
                        child: const Center(
                          child: Text(
                            'Start Matching',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16.5,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.4,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 24),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildColumn({
    required ModelProfile topModel,
    required ModelProfile bottomModel,
    required double width,
    required double height,
    required double topOffset,
  }) {
    return Padding(
      padding: EdgeInsets.only(top: topOffset),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildAvatarCard(model: topModel, width: width, height: height),
          const SizedBox(height: 8),
          _buildAvatarCard(model: bottomModel, width: width, height: height),
        ],
      ),
    );
  }

  Widget _buildAvatarCard({
    required ModelProfile model,
    required double width,
    required double height,
  }) {
    return GestureDetector(
      onTap: () => _onSlotTapped(model),
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: const Color(0xFF1E162A),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.12),
            width: 0.8,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.35),
              blurRadius: 6,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(13),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 600),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            transitionBuilder: (child, animation) {
              return FadeTransition(
                opacity: animation,
                child: ScaleTransition(
                  scale: Tween<double>(begin: 0.92, end: 1.0).animate(animation),
                  child: child,
                ),
              );
            },
            child: KeyedSubtree(
              key: ValueKey('${model.id}_${model.avatarUrl}'),
              child: SizedBox(
                width: width,
                height: height,
                child: CachedImageLoader(
                  imageUrl: model.avatarUrl,
                  fit: BoxFit.cover,
                  width: width,
                  height: height,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

import 'dart:ui';
import 'package:flutter/material.dart';
import '../../../core/models/model_profile.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/avatar_with_frame.dart';
import '../services/call_api_service.dart';

class InCallProfileSheet extends StatefulWidget {
  final ModelProfile model;
  final VoidCallback? onFollowChanged;

  const InCallProfileSheet({
    super.key,
    required this.model,
    this.onFollowChanged,
  });

  static void show(
    BuildContext context, {
    required ModelProfile model,
    VoidCallback? onFollowChanged,
  }) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => InCallProfileSheet(
        model: model,
        onFollowChanged: onFollowChanged,
      ),
    );
  }

  @override
  State<InCallProfileSheet> createState() => _InCallProfileSheetState();
}

class _InCallProfileSheetState extends State<InCallProfileSheet> {
  bool _isFollowing = false;
  bool _isLoadingFollow = true;
  int _followersCount = 0;
  int _followingCount = 0;

  @override
  void initState() {
    super.initState();
    _followersCount = widget.model.followersCount;
    _followingCount = widget.model.followingCount;
    _checkFollowStatus();
  }

  Future<void> _checkFollowStatus() async {
    try {
      final status = await CallApiService.getFollowStatus(widget.model.id);
      if (mounted) {
        setState(() {
          _isFollowing = status['is_following'] == true;
          if (status['followers_count'] is int && status['followers_count'] > 0) {
            _followersCount = status['followers_count'];
          }
          if (status['following_count'] is int && status['following_count'] > 0) {
            _followingCount = status['following_count'];
          }
          _isLoadingFollow = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoadingFollow = false);
      }
    }
  }

  Future<void> _toggleFollow() async {
    setState(() => _isLoadingFollow = true);
    final previousState = _isFollowing;
    final newFollowing = !previousState;

    setState(() {
      _isFollowing = newFollowing;
      _followersCount += newFollowing ? 1 : -1;
      if (_followersCount < 0) _followersCount = 0;
    });

    try {
      if (newFollowing) {
        await CallApiService.followUser(widget.model.id, source: 'call');
      } else {
        await CallApiService.unfollowUser(widget.model.id);
      }
      widget.onFollowChanged?.call();
    } catch (_) {
      // Revert on error
      if (mounted) {
        setState(() {
          _isFollowing = previousState;
          _followersCount += previousState ? 1 : -1;
          if (_followersCount < 0) _followersCount = 0;
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isLoadingFollow = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
          decoration: BoxDecoration(
            color: const Color(0xFF140E24).withValues(alpha: 0.92),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            border: Border.all(color: AppColors.neonPink.withValues(alpha: 0.35), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.7),
                blurRadius: 25,
                offset: const Offset(0, -5),
              ),
            ],
          ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Modal Handle
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 18),

                // Host Avatar + Level Frame
                AvatarWithFrame(
                  avatarUrl: widget.model.avatarUrl,
                  frameUrl: widget.model.avatarFrameUrl,
                  level: widget.model.currentLevel > 0 ? widget.model.currentLevel : widget.model.level,
                  badgeColor: widget.model.badgeColor,
                  glowColor: widget.model.glowColor,
                  size: 76,
                  showLevelBadge: true,
                ),
                const SizedBox(height: 12),

                // Name & Country Flag
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      widget.model.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 19,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.3,
                      ),
                    ),
                    if (widget.model.countryFlag.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      Text(widget.model.countryFlag, style: const TextStyle(fontSize: 18)),
                    ],
                  ],
                ),
                const SizedBox(height: 6),

                // Account ID & Gender/Age Badge
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'ID: ${widget.model.effectiveAccountId}',
                        style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w600),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: ((widget.model.gender ?? '').toLowerCase() == 'male')
                            ? const Color(0xFF2196F3).withValues(alpha: 0.3)
                            : const Color(0xFFE91E63).withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: ((widget.model.gender ?? '').toLowerCase() == 'male')
                              ? const Color(0xFF2196F3)
                              : const Color(0xFFE91E63),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            ((widget.model.gender ?? '').toLowerCase() == 'male') ? Icons.male_rounded : Icons.female_rounded,
                            size: 13,
                            color: Colors.white,
                          ),
                          const SizedBox(width: 3),
                          Text(
                            '${widget.model.age > 0 ? widget.model.age : 22}',
                            style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),

                // Stats Row: Followers, Following, Charm / Gems
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white10),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildStatColumn('Followers', '$_followersCount'),
                      Container(width: 1, height: 26, color: Colors.white12),
                      _buildStatColumn('Following', '$_followingCount'),
                      Container(width: 1, height: 26, color: Colors.white12),
                      _buildStatColumn('Rate/Min', '${widget.model.pricePerMin > 0 ? widget.model.pricePerMin : 100} 💎'),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Follow / Unfollow Action Button
                GestureDetector(
                  onTap: _isLoadingFollow ? null : _toggleFollow,
                  child: Container(
                    width: double.infinity,
                    height: 48,
                    decoration: BoxDecoration(
                      gradient: _isFollowing
                          ? const LinearGradient(colors: [Color(0xFF37474F), Color(0xFF263238)])
                          : AppColors.primaryGradient,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        if (!_isFollowing)
                          BoxShadow(
                            color: AppColors.neonPink.withValues(alpha: 0.4),
                            blurRadius: 14,
                            spreadRadius: 1,
                          ),
                      ],
                    ),
                    child: Center(
                      child: _isLoadingFollow
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  _isFollowing ? Icons.check_rounded : Icons.person_add_rounded,
                                  color: Colors.white,
                                  size: 18,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  _isFollowing ? 'Following' : 'Follow Host',
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
                const SizedBox(height: 10),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatColumn(String label, String value) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(color: Colors.white60, fontSize: 11),
        ),
      ],
    );
  }
}

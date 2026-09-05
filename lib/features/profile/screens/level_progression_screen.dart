import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/avatar_with_frame.dart';
import '../services/level_bases_api_service.dart';

class LevelProgressionScreen extends StatefulWidget {
  final String? accountId;
  final String? userId;

  const LevelProgressionScreen({
    super.key,
    this.accountId,
    this.userId,
  });

  @override
  State<LevelProgressionScreen> createState() => _LevelProgressionScreenState();
}

class _LevelProgressionScreenState extends State<LevelProgressionScreen> {
  bool _isLoading = true;
  String? _errorMessage;
  Map<String, dynamic>? _levelStatusData;
  List<dynamic> _allBases = [];

  @override
  void initState() {
    super.initState();
    _fetchLevelData();
  }

  Future<void> _fetchLevelData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final statusFuture = LevelBasesApiService.getUserLevelStatus(
        accountId: widget.accountId,
        userId: widget.userId,
      );
      final basesFuture = LevelBasesApiService.getAllProfileBases();

      final results = await Future.wait([statusFuture, basesFuture]);

      final statusRes = results[0] as Map<String, dynamic>?;
      final basesRes = results[1] as List<dynamic>?;

      if (statusRes != null && statusRes['status'] == true && statusRes['data'] != null) {
        if (mounted) {
          setState(() {
            _levelStatusData = statusRes['data'] as Map<String, dynamic>;
            _allBases = basesRes ?? [];
            _isLoading = false;
          });
        }
      } else {
        // Fallback: try using profile bases if level-status was empty
        if (mounted) {
          setState(() {
            _allBases = basesRes ?? [];
            _isLoading = false;
            if (_levelStatusData == null && _allBases.isEmpty) {
              _errorMessage = 'Unable to load level progression data.';
            }
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Failed to load level status: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0E17),
      appBar: AppBar(
        backgroundColor: const Color(0xFF161426),
        elevation: 0,
        title: const Text(
          'Host Level & Profile Bases',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: AppColors.neonPink),
            tooltip: 'Refresh',
            onPressed: _fetchLevelData,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(color: AppColors.neonPink),
                  SizedBox(height: 14),
                  Text('Loading level progression...', style: TextStyle(color: Colors.white70, fontSize: 13)),
                ],
              ),
            )
          : _errorMessage != null && _levelStatusData == null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 48),
                        const SizedBox(height: 12),
                        Text(_errorMessage!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70)),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: _fetchLevelData,
                          style: ElevatedButton.styleFrom(backgroundColor: AppColors.neonPink),
                          icon: const Icon(Icons.refresh_rounded, color: Colors.white),
                          label: const Text('Try Again', style: TextStyle(color: Colors.white)),
                        ),
                      ],
                    ),
                  ),
                )
              : _buildContent(),
    );
  }

  Widget _buildContent() {
    final user = _levelStatusData?['user'] as Map<String, dynamic>?;
    final progression = _levelStatusData?['progression'] as Map<String, dynamic>?;
    final List<dynamic> levelsScale = (_levelStatusData?['levels_scale'] as List<dynamic>?) ?? _allBases;

    final userName = user?['nickname'] ?? user?['name'] ?? 'Host';
    final userAvatar = user?['avatar_url']?.toString() ?? '';
    final int totalEarned = progression?['total_earned_coins'] is int
        ? progression!['total_earned_coins'] as int
        : (user?['total_earned_coins'] is int ? user!['total_earned_coins'] as int : 0);

    final int currentLevel = progression?['current_level'] is int
        ? progression!['current_level'] as int
        : 0;
    final String levelName = progression?['level_name']?.toString() ?? 'Level $currentLevel';
    final String frameUrl = progression?['avatar_frame_url']?.toString() ?? '';
    final String badgeColor = progression?['badge_color']?.toString() ?? '#f59e0b';
    final String glowColor = progression?['glow_color']?.toString() ?? 'rgba(245, 158, 11, 0.4)';
    final String privilegeText = progression?['privilege_text']?.toString() ?? 'Standard Profile Frame';

    final int nextLevel = progression?['next_level'] is int ? progression!['next_level'] as int : currentLevel + 1;
    final int coinsForNextLevel = progression?['coins_for_next_level'] is int ? progression!['coins_for_next_level'] as int : 1000;
    final int coinsNeeded = progression?['coins_needed_to_level_up'] is int ? progression!['coins_needed_to_level_up'] as int : 0;
    final double progressPercentage = (progression?['progress_percentage'] != null)
        ? (progression!['progress_percentage'] as num).toDouble()
        : 0.0;
    final bool isMaxLevel = progression?['is_max_level'] == true;

    return RefreshIndicator(
      onRefresh: _fetchLevelData,
      color: AppColors.neonPink,
      backgroundColor: const Color(0xFF1E1B33),
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Hero Card with Avatar + Frame Preview & Current Level
            _buildHeroCard(
              userName: userName,
              avatarUrl: userAvatar,
              frameUrl: frameUrl,
              level: currentLevel,
              levelName: levelName,
              badgeColor: badgeColor,
              glowColor: glowColor,
              totalEarned: totalEarned,
              privilegeText: privilegeText,
            ),
            const SizedBox(height: 16),

            // 2. Progression Progress Bar Card
            _buildProgressBarCard(
              currentLevel: currentLevel,
              nextLevel: nextLevel,
              totalEarned: totalEarned,
              coinsForNextLevel: coinsForNextLevel,
              coinsNeeded: coinsNeeded,
              progressPercentage: progressPercentage,
              isMaxLevel: isMaxLevel,
              badgeColor: badgeColor,
            ),
            const SizedBox(height: 16),

            // 3. 50/50 Revenue Split Explanation Card
            _buildEarningMechanicsCard(),
            const SizedBox(height: 20),

            // 4. Master Scale of All 10+ Levels & Profile Frames
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  '🎖️ Level Tiers & Profile Frames',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.primaryPink.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.primaryPink.withValues(alpha: 0.4)),
                  ),
                  child: Text(
                    '${levelsScale.length} Tiers',
                    style: const TextStyle(color: AppColors.neonPink, fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Level Scale List
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: levelsScale.length,
              separatorBuilder: (context, index) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final tier = levelsScale[index] as Map<String, dynamic>;
                return _buildLevelTierTile(tier, currentLevel);
              },
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Widget _buildHeroCard({
    required String userName,
    required String avatarUrl,
    required String frameUrl,
    required int level,
    required String levelName,
    required String badgeColor,
    required String glowColor,
    required int totalEarned,
    required String privilegeText,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFF281C44),
            Color(0xFF191730),
            Color(0xFF111024),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: HexColor.fromHex(badgeColor, defaultColor: AppColors.neonPink).withValues(alpha: 0.4),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: HexColor.fromHex(badgeColor, defaultColor: AppColors.neonPink).withValues(alpha: 0.15),
            blurRadius: 18,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Large Avatar With Active Frame
          AvatarWithFrame(
            avatarUrl: avatarUrl,
            frameUrl: frameUrl.isNotEmpty ? frameUrl : null,
            level: level,
            badgeColor: badgeColor,
            glowColor: glowColor,
            size: 96,
            showLevelBadge: true,
          ),
          const SizedBox(height: 16),

          // User Name & Level Title
          Text(
            userName,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),

          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: HexColor.fromHex(badgeColor, defaultColor: AppColors.neonPink).withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: HexColor.fromHex(badgeColor, defaultColor: AppColors.neonPink),
                width: 1,
              ),
            ),
            child: Text(
              levelName,
              style: TextStyle(
                color: HexColor.fromHex(badgeColor, defaultColor: AppColors.neonPink),
                fontSize: 13,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Lifetime Earned Coins Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.monetization_on_rounded, color: Colors.amber, size: 18),
                const SizedBox(width: 6),
                const Text('Lifetime Earned:', style: TextStyle(color: Colors.white70, fontSize: 12)),
                const SizedBox(width: 6),
                Text(
                  '$totalEarned coins',
                  style: const TextStyle(
                    color: Colors.amberAccent,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // Active Perk Description
          Text(
            '✨ $privilegeText',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white60,
              fontSize: 12,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressBarCard({
    required int currentLevel,
    required int nextLevel,
    required int totalEarned,
    required int coinsForNextLevel,
    required int coinsNeeded,
    required double progressPercentage,
    required bool isMaxLevel,
    required String badgeColor,
  }) {
    final clampedPercent = (progressPercentage / 100.0).clamp(0.0, 1.0);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF18152B),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: HexColor.fromHex(badgeColor, defaultColor: AppColors.neonPink),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text('Lv.$currentLevel', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(width: 8),
                  const Text('Level Progression', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                ],
              ),
              if (!isMaxLevel)
                Text(
                  'Next: Lv.$nextLevel',
                  style: const TextStyle(color: AppColors.neonPurple, fontSize: 12, fontWeight: FontWeight.bold),
                )
              else
                const Text(
                  'MAX LEVEL',
                  style: TextStyle(color: Colors.amber, fontSize: 12, fontWeight: FontWeight.bold),
                ),
            ],
          ),
          const SizedBox(height: 12),

          // Linear Gradient Progress Bar
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              height: 12,
              child: Stack(
                children: [
                  Container(color: Colors.white12),
                  FractionallySizedBox(
                    widthFactor: clampedPercent,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            HexColor.fromHex(badgeColor, defaultColor: AppColors.neonPink),
                            AppColors.neonPink,
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${progressPercentage.toStringAsFixed(1)}% Completed',
                style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w600),
              ),
              if (!isMaxLevel)
                Text(
                  '$coinsNeeded coins to Lv.$nextLevel',
                  style: const TextStyle(color: Colors.amberAccent, fontSize: 11, fontWeight: FontWeight.bold),
                )
              else
                const Text(
                  'Apex Master Tier 👑',
                  style: TextStyle(color: Colors.amber, fontSize: 11, fontWeight: FontWeight.bold),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEarningMechanicsCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF131B2E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF1D4ED8).withValues(alpha: 0.4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF2563EB).withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.auto_graph_rounded, color: Color(0xFF60A5FA), size: 20),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '50/50 Host Earning Split Mechanics',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                ),
                SizedBox(height: 3),
                Text(
                  'Every coin earned from 1-on-1 audio/video calls (50% host share) and gifts automatically counts towards your lifetime level progression!',
                  style: TextStyle(color: Colors.white60, fontSize: 11.5, height: 1.35),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLevelTierTile(Map<String, dynamic> tier, int currentLevel) {
    final int level = (tier['level'] is int) ? tier['level'] as int : int.tryParse(tier['level']?.toString() ?? '0') ?? 0;
    final String name = tier['name']?.toString() ?? 'Level $level';
    final int requiredCoins = (tier['required_coins'] is int)
        ? tier['required_coins'] as int
        : int.tryParse(tier['required_coins']?.toString() ?? '0') ?? 0;
    final String frameUrl = tier['frame_image_url']?.toString() ?? tier['base_frame_image']?.toString() ?? '';
    final String badgeColor = tier['badge_color']?.toString() ?? '#94a3b8';
    final String privilegeText = tier['privilege_text']?.toString() ?? '';
    final bool isUnlocked = tier['is_unlocked'] == true || currentLevel >= level;
    final bool isCurrent = tier['is_current'] == true || currentLevel == level;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isCurrent
            ? const Color(0xFF221A3B)
            : isUnlocked
                ? const Color(0xFF161426)
                : const Color(0xFF100E1C),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isCurrent
              ? HexColor.fromHex(badgeColor, defaultColor: AppColors.neonPink)
              : isUnlocked
                  ? Colors.white12
                  : Colors.white.withValues(alpha: 0.05),
          width: isCurrent ? 1.5 : 1,
        ),
      ),
      child: Row(
        children: [
          // Frame Preview Widget
          SizedBox(
            width: 58,
            height: 58,
            child: AvatarWithFrame(
              avatarUrl: 'https://placehold.co/100x100/381F4B/FFF?text=Lv.$level',
              frameUrl: frameUrl.isNotEmpty ? frameUrl : null,
              level: level,
              badgeColor: badgeColor,
              size: 40,
              showLevelBadge: false,
            ),
          ),
          const SizedBox(width: 12),

          // Level Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: HexColor.fromHex(badgeColor, defaultColor: AppColors.neonPink),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'Lv.$level',
                        style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        name,
                        style: TextStyle(
                          color: isUnlocked ? Colors.white : Colors.white54,
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    const Icon(Icons.monetization_on_rounded, color: Colors.amber, size: 13),
                    const SizedBox(width: 3),
                    Text(
                      '$requiredCoins coins required',
                      style: const TextStyle(color: Colors.amberAccent, fontSize: 11, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
                if (privilegeText.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    privilegeText,
                    style: const TextStyle(color: Colors.white54, fontSize: 10.5),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),

          // Status Badge
          if (isCurrent)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                gradient: AppColors.primaryGradient,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text('CURRENT', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800)),
            )
          else if (isUnlocked)
            const Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 20)
          else
            const Icon(Icons.lock_rounded, color: Colors.white24, size: 20),
        ],
      ),
    );
  }
}

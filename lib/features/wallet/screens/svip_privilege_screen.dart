import 'package:flutter/material.dart';
import '../../auth/services/auth_api_service.dart';
import '../services/wallet_api_service.dart';
import 'deposit_screen.dart';

class SvipPrivilegeScreen extends StatefulWidget {
  final int initialLevelIndex;

  const SvipPrivilegeScreen({
    super.key,
    this.initialLevelIndex = 1,
  });

  @override
  State<SvipPrivilegeScreen> createState() => _SvipPrivilegeScreenState();
}

class _SvipPrivilegeScreenState extends State<SvipPrivilegeScreen> {
  int _selectedLevelIndex = 1; // Default to SVIP1
  int _userCurrentSvipLevel = 0; // Current user SVIP (e.g. 0)
  int _userCurrentPoints = 0;
  int _userWalletCoins = 0;
  bool _isLoading = true;

  final PageController _pageController = PageController(viewportFraction: 0.28, initialPage: 1);
  final ScrollController _scrollController = ScrollController();

  final List<Map<String, dynamic>> _svipLevels = [
    {
      'level': 0,
      'name': 'SVIP0',
      'title': 'Novice Member',
      'points_required': 0,
      'privileges_count': 0,
      'theme_color': const Color(0xFF9E9E9E),
      'secondary_color': const Color(0xFF616161),
      'badge_text': 'SVIP0',
    },
    {
      'level': 1,
      'name': 'SVIP1',
      'title': 'Emerald Knight',
      'points_required': 400,
      'privileges_count': 6,
      'theme_color': const Color(0xFF10B981),
      'secondary_color': const Color(0xFF047857),
      'badge_text': 'SVIP1',
    },
    {
      'level': 2,
      'name': 'SVIP2',
      'title': 'Cyan Monarch',
      'points_required': 1200,
      'privileges_count': 8,
      'theme_color': const Color(0xFF06B6D4),
      'secondary_color': const Color(0xFF0E7490),
      'badge_text': 'SVIP2',
    },
    {
      'level': 3,
      'name': 'SVIP3',
      'title': 'Sapphire Duke',
      'points_required': 3000,
      'privileges_count': 11,
      'theme_color': const Color(0xFF3B82F6),
      'secondary_color': const Color(0xFF1D4ED8),
      'badge_text': 'SVIP3',
    },
    {
      'level': 4,
      'name': 'SVIP4',
      'title': 'Royal Marquis',
      'points_required': 8000,
      'privileges_count': 13,
      'theme_color': const Color(0xFF8B5CF6),
      'secondary_color': const Color(0xFF6D28D9),
      'badge_text': 'SVIP4',
    },
    {
      'level': 5,
      'name': 'SVIP5',
      'title': 'Golden Sovereign',
      'points_required': 20000,
      'privileges_count': 15,
      'theme_color': const Color(0xFFF59E0B),
      'secondary_color': const Color(0xFFB45309),
      'badge_text': 'SVIP5',
    },
    {
      'level': 6,
      'name': 'SVIP6',
      'title': 'Crimson Emperor',
      'points_required': 50000,
      'privileges_count': 16,
      'theme_color': const Color(0xFFEF4444),
      'secondary_color': const Color(0xFFB91C1C),
      'badge_text': 'SVIP6',
    },
    {
      'level': 7,
      'name': 'SVIP7',
      'title': 'Cosmic Overlord',
      'points_required': 120000,
      'privileges_count': 17,
      'theme_color': const Color(0xFFEC4899),
      'secondary_color': const Color(0xFFBE185D),
      'badge_text': 'SVIP7',
    },
    {
      'level': 8,
      'name': 'SVIP8',
      'title': 'Supreme Celestial',
      'points_required': 300000,
      'privileges_count': 17,
      'theme_color': const Color(0xFFFFD700),
      'secondary_color': const Color(0xFFFF8F00),
      'badge_text': 'SVIP8',
    },
  ];

  @override
  void initState() {
    super.initState();
    _selectedLevelIndex = widget.initialLevelIndex.clamp(0, _svipLevels.length - 1);
    _loadUserStatus();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadUserStatus() async {
    setState(() => _isLoading = true);
    try {
      final user = await AuthApiService.getSavedUser();
      final wallet = await WalletApiService.getWalletBalance().catchError((_) => null);

      if (mounted) {
        setState(() {
          _userCurrentSvipLevel = user?['svip_level'] ?? 0;
          _userCurrentPoints = user?['svip_points'] ?? 0;
          if (wallet != null && wallet['coins'] != null) {
            _userWalletCoins = wallet['coins'] as int;
          }
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showHelpDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF181726),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: Color(0xFFFFD700), width: 1),
        ),
        title: const Row(
          children: [
            Icon(Icons.workspace_premium_rounded, color: Color(0xFFFFD700), size: 24),
            SizedBox(width: 8),
            Text(
              'SVIP Privileges & Rules',
              style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildHelpSection(
                title: '1. How to Earn SVIP Points?',
                desc: 'Earn 1 SVIP Point for every 1,000 Diamonds spent or recharged in Chinchins Live.',
              ),
              const SizedBox(height: 12),
              _buildHelpSection(
                title: '2. SVIP Levels Progression',
                desc: 'SVIP1: 400 Pts\nSVIP2: 1,200 Pts\nSVIP3: 3,000 Pts\nSVIP4: 8,000 Pts\nSVIP5: 20,000 Pts\nSVIP6: 50,000 Pts\nSVIP7: 120,000 Pts\nSVIP8: 300,000 Pts',
              ),
              const SizedBox(height: 12),
              _buildHelpSection(
                title: '3. Privileges Guarantee',
                desc: 'Unlocked SVIP perks remain active during your SVIP validity period. Enjoy exclusive animated avatar frames, entrance banners, HD 1v1 video calls, and 24/7 personal customer service.',
              ),
            ],
          ),
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFFD700),
              foregroundColor: Colors.black87,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Got It', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildHelpSection({required String title, required String desc}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(color: Color(0xFFFFD700), fontWeight: FontWeight.bold, fontSize: 13)),
        const SizedBox(height: 4),
        Text(desc, style: const TextStyle(color: Colors.white70, fontSize: 12, height: 1.4)),
      ],
    );
  }

  void _openRechargeSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Container(
        height: MediaQuery.of(context).size.height * 0.65,
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(
          color: Color(0xFF141320),
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          border: Border(top: BorderSide(color: Color(0xFFFFD700), width: 1.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Upgrade SVIP Points',
                  style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFD700).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFFFD700), width: 0.8),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.diamond_rounded, color: Color(0xFFFFD700), size: 14),
                      const SizedBox(width: 4),
                      Text('$_userWalletCoins Gems', style: const TextStyle(color: Color(0xFFFFD700), fontSize: 12, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'Recharge diamonds to level up your SVIP status and unlock all 17 VIP privileges instantly.',
              style: TextStyle(color: Colors.white60, fontSize: 12),
            ),
            const SizedBox(height: 18),
            Expanded(
              child: GridView.count(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 1.35,
                children: [
                  _buildRechargePackCard('150 Gems', '৳ 150', '+150 Pts', 150),
                  _buildRechargePackCard('750 Gems', '৳ 750', '+750 Pts', 750, isPopular: true),
                  _buildRechargePackCard('1,500 Gems', '৳ 1,500', '+1,500 Pts', 1500),
                  _buildRechargePackCard('5,000 Gems', '৳ 5,000', '+5,000 Pts', 5000),
                ],
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFFD700),
                  foregroundColor: Colors.black87,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                  elevation: 6,
                ),
                onPressed: () {
                  Navigator.pop(ctx);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const DepositScreen(
                        selectedPackage: {
                          'price': 750,
                          'price_bdt': 750,
                          'coins': 7500,
                          'title': '750 Gems SVIP Upgrade Pack',
                        },
                      ),
                    ),
                  ).then((_) => _loadUserStatus());
                },
                child: const Text(
                  'Go to Recharge Center',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRechargePackCard(String gems, String price, String pts, int priceValue, {bool isPopular = false}) {
    return GestureDetector(
      onTap: () {
        Navigator.pop(context);
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => DepositScreen(
              selectedPackage: {
                'price': priceValue,
                'price_bdt': priceValue,
                'coins': priceValue * 10,
                'title': '$gems Pack',
              },
            ),
          ),
        ).then((_) => _loadUserStatus());
      },
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFF1E1C2C),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isPopular ? const Color(0xFFFFD700) : Colors.white12,
            width: isPopular ? 1.5 : 1.0,
          ),
          boxShadow: isPopular
              ? [
                  BoxShadow(
                    color: const Color(0xFFFFD700).withValues(alpha: 0.2),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (isPopular)
              Container(
                margin: const EdgeInsets.only(bottom: 4),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFD700),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text('HOT', style: TextStyle(color: Colors.black87, fontSize: 9, fontWeight: FontWeight.bold)),
              ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.diamond_rounded, color: Color(0xFFFFD700), size: 16),
                const SizedBox(width: 4),
                Text(gems, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
              ],
            ),
            const SizedBox(height: 4),
            Text(pts, style: const TextStyle(color: Colors.greenAccent, fontSize: 11, fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            Text(price, style: const TextStyle(color: Colors.amberAccent, fontWeight: FontWeight.bold, fontSize: 14)),
          ],
        ),
      ),
    );
  }

  void _showPrivilegeDetailModal(Map<String, dynamic> priv, bool isUnlocked, int requiredLevel) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(22),
        decoration: const BoxDecoration(
          color: Color(0xFF181628),
          borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
          border: Border(top: BorderSide(color: Color(0xFFE8D3BF), width: 1)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
            ),
            const SizedBox(height: 18),
            Container(
              width: 68,
              height: 68,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    (priv['color'] as Color).withValues(alpha: 0.35),
                    Colors.transparent,
                  ],
                ),
                border: Border.all(color: priv['color'] as Color, width: 1.5),
              ),
              child: Icon(priv['icon'] as IconData, color: priv['color'] as Color, size: 36),
            ),
            const SizedBox(height: 12),
            Text(
              priv['title'] as String,
              style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: BoxDecoration(
                color: isUnlocked ? Colors.green.withValues(alpha: 0.2) : Colors.orange.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: isUnlocked ? Colors.greenAccent : Colors.orangeAccent, width: 0.8),
              ),
              child: Text(
                isUnlocked ? 'Unlocked for SVIP$_selectedLevelIndex' : 'Unlocks at SVIP$requiredLevel',
                style: TextStyle(
                  color: isUnlocked ? Colors.greenAccent : Colors.orangeAccent,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              priv['desc'] as String,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
            ),
            const SizedBox(height: 22),
            SizedBox(
              width: double.infinity,
              height: 46,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFFD700),
                  foregroundColor: Colors.black87,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                ),
                onPressed: () {
                  Navigator.pop(ctx);
                  _openRechargeSheet();
                },
                child: Text(
                  isUnlocked ? 'Enjoy Privilege' : 'Upgrade to SVIP$requiredLevel',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentLevelData = _svipLevels[_selectedLevelIndex];
    final String currentLevelName = currentLevelData['name'];
    final Color themeColor = currentLevelData['theme_color'];
    final int privilegesCount = currentLevelData['privileges_count'];

    return Scaffold(
      backgroundColor: const Color(0xFF0C0B14),
      body: SafeArea(
        child: Column(
          children: [
            // Top App Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
                    onPressed: () => Navigator.pop(context),
                  ),
                  Text(
                    currentLevelName,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      shadows: [
                        Shadow(color: themeColor.withValues(alpha: 0.6), blurRadius: 10),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.help_outline_rounded, color: Colors.white70, size: 22),
                    tooltip: 'SVIP Rules',
                    onPressed: _showHelpDialog,
                  ),
                ],
              ),
            ),

            // Scrollable Content
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: Color(0xFFFFD700)))
                  : SingleChildScrollView(
                      controller: _scrollController,
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          // 1. Current User SVIP Card (Matching Screenshot 5)
                          _buildUserSvipStatusCard(),
                          const SizedBox(height: 18),

                          // 2. Horizontal SVIP Level Slider / Tabs (Matching Screenshot 2, 3, 4, 5)
                          _buildLevelSelectorCarousel(),
                          const SizedBox(height: 16),

                          // 3. Selected Level Privileges Count Heading
                          Text(
                            'Enjoy $privilegesCount/17 privileges',
                            style: const TextStyle(
                              color: Color(0xFFD4AF37),
                              fontSize: 13.5,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.3,
                            ),
                          ),
                          const SizedBox(height: 18),

                          // 4. Section 1: Honor Identity Privileges
                          _buildSectionDivider('Honor Identity Privileges'),
                          const SizedBox(height: 14),
                          _buildHonorIdentityGrid(),
                          const SizedBox(height: 22),

                          // 5. Section 2: Functional Privileges
                          _buildSectionDivider('Functional Privileges'),
                          const SizedBox(height: 14),
                          _buildFunctionalPrivilegesGrid(),
                          const SizedBox(height: 22),

                          // 6. Section 3: Management Privileges
                          _buildSectionDivider('Management Privileges'),
                          const SizedBox(height: 14),
                          _buildManagementPrivilegesGrid(),
                          const SizedBox(height: 24),

                          // 7. Section 4: Exclusive Service Privileges
                          _buildSectionDivider('Exclusive Service Privileges'),
                          const SizedBox(height: 14),
                          _buildExclusiveServiceCard(),
                          const SizedBox(height: 30),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
      // Bottom Dock Bar: 1v1 Service Action
      bottomNavigationBar: _buildBottomServiceBar(),
    );
  }

  // Top User Status Card (Matching Screenshot 5)
  Widget _buildUserSvipStatusCard() {
    final nextLevelPoints = (_userCurrentSvipLevel < _svipLevels.length - 1)
        ? _svipLevels[_userCurrentSvipLevel + 1]['points_required'] as int
        : 400;
    final progress = nextLevelPoints > 0
        ? (_userCurrentPoints / nextLevelPoints).clamp(0.0, 1.0)
        : 0.0;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFF2B2738),
            Color(0xFF191724),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.15),
          width: 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'SVIP$_userCurrentSvipLevel',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _userCurrentSvipLevel == 0 ? 'You are not a SVIP' : 'Active SVIP Member',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),

              // Glowing Shield Emblem & Upgrade Button
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _buildWingsEmblem(
                    level: _userCurrentSvipLevel == 0 ? 1 : _userCurrentSvipLevel,
                    size: 46,
                  ),
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: _openRechargeSheet,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFF3E5D8), Color(0xFFD6BAA2)],
                        ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFD6BAA2).withValues(alpha: 0.4),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Text(
                        'Upgrade',
                        style: TextStyle(
                          color: Colors.black87,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 10),

          // Monthly Points Progress
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "This Month's Points: $_userCurrentPoints / $nextLevelPoints",
                style: const TextStyle(color: Colors.white70, fontSize: 11),
              ),
              Text(
                '${(progress * 100).toInt()}%',
                style: const TextStyle(color: Color(0xFFFFD700), fontSize: 11, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 5,
              backgroundColor: Colors.white12,
              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFFFD700)),
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Earn 1 Point per 1000 Diamonds',
            style: TextStyle(color: Colors.white38, fontSize: 10.5),
          ),
        ],
      ),
    );
  }

  // Horizontal Level Selector
  Widget _buildLevelSelectorCarousel() {
    return SizedBox(
      height: 90,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: _svipLevels.length - 1, // Start from SVIP1 to SVIP8
        itemBuilder: (context, index) {
          final levelIndex = index + 1;
          final levelData = _svipLevels[levelIndex];
          final bool isSelected = _selectedLevelIndex == levelIndex;
          final Color themeColor = levelData['theme_color'];

          return GestureDetector(
            onTap: () {
              setState(() {
                _selectedLevelIndex = levelIndex;
              });
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: isSelected ? const Color(0xFF1E1B2E) : Colors.transparent,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isSelected ? themeColor : Colors.white12,
                  width: isSelected ? 1.8 : 1.0,
                ),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: themeColor.withValues(alpha: 0.35),
                          blurRadius: 10,
                          offset: const Offset(0, 2),
                        ),
                      ]
                    : null,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildWingsEmblem(
                    level: levelIndex,
                    size: isSelected ? 38 : 32,
                    showGlow: isSelected,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'SVIP$levelIndex',
                    style: TextStyle(
                      color: isSelected ? Colors.white : Colors.white54,
                      fontSize: 12,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // Section Header with Glowing Dividers (Matching Screenshot 2, 3, 4, 5)
  Widget _buildSectionDivider(String title) {
    return Row(
      children: [
        Expanded(
          child: Container(
            height: 1,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.transparent,
                  const Color(0xFFD4AF37).withValues(alpha: 0.6),
                ],
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Text(
            title,
            style: const TextStyle(
              color: Color(0xFFE5C384),
              fontSize: 12.5,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.3,
            ),
          ),
        ),
        Expanded(
          child: Container(
            height: 1,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFFD4AF37).withValues(alpha: 0.6),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  // 1. Honor Identity Grid (SVIP Nameplate, Avatar Frame, Profile Card, Entry Banner, Entry Effect)
  Widget _buildHonorIdentityGrid() {
    final List<Map<String, dynamic>> items = [
      {
        'title': 'SVIP Nameplate',
        'icon': Icons.badge_rounded,
        'color': const Color(0xFFFFD700),
        'unlock_level': 1,
        'desc': 'Exclusive SVIP nameplate shown next to your nickname across live rooms and chat.',
      },
      {
        'title': 'SVIP Avatar Frame',
        'icon': Icons.camera_front_rounded,
        'color': const Color(0xFF00E5FF),
        'unlock_level': 1,
        'desc': 'Gorgeous animated SVIP frame for your profile avatar.',
      },
      {
        'title': 'SVIP Profile Card',
        'icon': Icons.credit_card_rounded,
        'color': const Color(0xFF7C4DFF),
        'unlock_level': 1,
        'desc': 'Custom luxury backdrop card on your personal profile page.',
      },
      {
        'title': 'SVIP Entry Banner',
        'icon': Icons.flag_rounded,
        'color': const Color(0xFFFF4081),
        'unlock_level': 2,
        'desc': 'Welcome announcement banner broadcasted in room chat when you enter.',
      },
      {
        'title': 'SVIP Entry Effect',
        'icon': Icons.auto_awesome_rounded,
        'color': const Color(0xFFFF9100),
        'unlock_level': 3,
        'desc': 'Stunning full-screen entrance animation ride (Supercar, Phoenix, Spaceship).',
      },
    ];

    return Wrap(
      spacing: 12,
      runSpacing: 14,
      alignment: WrapAlignment.center,
      children: items.map((item) {
        final bool isUnlocked = _selectedLevelIndex >= (item['unlock_level'] as int);
        final int reqLevel = item['unlock_level'] as int;

        return _buildPrivilegeItem(
          title: item['title'] as String,
          icon: item['icon'] as IconData,
          color: item['color'] as Color,
          isUnlocked: isUnlocked,
          requiredLevel: reqLevel,
          onTap: () => _showPrivilegeDetailModal(item, isUnlocked, reqLevel),
        );
      }).toList(),
    );
  }

  // 2. Functional Privileges Grid (1v1 Call Duration Display, HD 1v1, Room Lock, Group Chat)
  Widget _buildFunctionalPrivilegesGrid() {
    final List<Map<String, dynamic>> items = [
      {
        'title': '1v1 Call Duration\nDisplay',
        'icon': Icons.videocam_rounded,
        'color': const Color(0xFFFFD54F),
        'unlock_level': 1,
        'desc': 'Displays live call timer badge during 1v1 video calls.',
      },
      {
        'title': 'HD 1v1',
        'icon': Icons.hd_rounded,
        'color': const Color(0xFF64B5F6),
        'unlock_level': 1,
        'desc': 'Enables crystal clear 1080p WebRTC high definition video stream.',
      },
      {
        'title': 'Room Lock',
        'icon': Icons.lock_outline_rounded,
        'color': const Color(0xFFFFB74D),
        'unlock_level': 2,
        'desc': 'Allows setting private passcode locks on your party rooms.',
      },
      {
        'title': 'Group Chat',
        'icon': Icons.groups_rounded,
        'color': const Color(0xFFBA68C8),
        'unlock_level': 3,
        'desc': 'Create and manage exclusive high-capacity VIP group chat rooms.',
      },
    ];

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: items.map((item) {
        final bool isUnlocked = _selectedLevelIndex >= (item['unlock_level'] as int);
        final int reqLevel = item['unlock_level'] as int;

        return _buildPrivilegeItem(
          title: item['title'] as String,
          icon: item['icon'] as IconData,
          color: item['color'] as Color,
          isUnlocked: isUnlocked,
          requiredLevel: reqLevel,
          onTap: () => _showPrivilegeDetailModal(item, isUnlocked, reqLevel),
        );
      }).toList(),
    );
  }

  // 3. Management Privileges Grid (Report, Unban, Unban for Others)
  Widget _buildManagementPrivilegesGrid() {
    final List<Map<String, dynamic>> items = [
      {
        'title': 'Report',
        'icon': Icons.report_problem_rounded,
        'color': const Color(0xFFFFD54F),
        'unlock_level': 1,
        'desc': 'Fast-track priority report processing by our 24/7 security moderation team.',
      },
      {
        'title': 'Unban',
        'icon': Icons.lock_open_rounded,
        'color': const Color(0xFF81C784),
        'unlock_level': 5,
        'desc': 'Self-unban appeal privilege with instant automated priority review.',
      },
      {
        'title': 'Unban for Others',
        'icon': Icons.shield_rounded,
        'color': const Color(0xFF4FC3F7),
        'unlock_level': 6,
        'desc': 'Privilege to vouch and request unban for friends and community members.',
      },
    ];

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: items.map((item) {
        final bool isUnlocked = _selectedLevelIndex >= (item['unlock_level'] as int);
        final int reqLevel = item['unlock_level'] as int;

        return _buildPrivilegeItem(
          title: item['title'] as String,
          icon: item['icon'] as IconData,
          color: item['color'] as Color,
          isUnlocked: isUnlocked,
          requiredLevel: reqLevel,
          onTap: () => _showPrivilegeDetailModal(item, isUnlocked, reqLevel),
        );
      }).toList(),
    );
  }

  // 4. Exclusive Service Privileges Card
  Widget _buildExclusiveServiceCard() {
    final bool isUnlocked = _selectedLevelIndex >= 7;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFF161524),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isUnlocked
                  ? const Color(0xFFFFD700).withValues(alpha: 0.15)
                  : Colors.white.withValues(alpha: 0.05),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.support_agent_rounded,
              color: isUnlocked ? const Color(0xFFFFD700) : Colors.white38,
              size: 24,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text(
                      '1v1 Dedicated Customer Service',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    const SizedBox(width: 6),
                    if (!isUnlocked)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.white10,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text('SVIP7', style: TextStyle(color: Colors.white60, fontSize: 9, fontWeight: FontWeight.bold)),
                      ),
                  ],
                ),
                const SizedBox(height: 2),
                const Text(
                  '24/7 Personal VIP Manager for account & recharge queries',
                  style: TextStyle(color: Colors.white54, fontSize: 11),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Single Privilege Item Cell
  Widget _buildPrivilegeItem({
    required String title,
    required IconData icon,
    required Color color,
    required bool isUnlocked,
    required int requiredLevel,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 76,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Circular Icon Container with optional lock badge
            Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: isUnlocked
                        ? color.withValues(alpha: 0.15)
                        : const Color(0xFF1B1A28),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isUnlocked ? color.withValues(alpha: 0.4) : Colors.white12,
                      width: 1.0,
                    ),
                    boxShadow: isUnlocked
                        ? [
                            BoxShadow(
                              color: color.withValues(alpha: 0.2),
                              blurRadius: 8,
                            ),
                          ]
                        : null,
                  ),
                  child: Center(
                    child: Icon(
                      icon,
                      color: isUnlocked ? color : Colors.white30,
                      size: 22,
                    ),
                  ),
                ),

                // If locked, show small lock pill / badge
                if (!isUnlocked)
                  Positioned(
                    top: -4,
                    right: -4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2C2A3A),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.white24, width: 0.5),
                      ),
                      child: Text(
                        'SVIP$requiredLevel',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 7.5,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              title,
              textAlign: TextAlign.center,
              maxLines: 2,
              style: TextStyle(
                color: isUnlocked ? Colors.white : Colors.white54,
                fontSize: 10,
                fontWeight: isUnlocked ? FontWeight.w600 : FontWeight.normal,
                height: 1.15,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Floating Wings / Shield Emblem Graphic
  Widget _buildWingsEmblem({
    required int level,
    required double size,
    bool showGlow = false,
  }) {
    Color emblemColor;
    switch (level) {
      case 1:
        emblemColor = const Color(0xFF10B981);
        break;
      case 2:
        emblemColor = const Color(0xFF06B6D4);
        break;
      case 3:
        emblemColor = const Color(0xFF3B82F6);
        break;
      case 4:
        emblemColor = const Color(0xFF8B5CF6);
        break;
      case 5:
        emblemColor = const Color(0xFFF59E0B);
        break;
      case 6:
        emblemColor = const Color(0xFFEF4444);
        break;
      case 7:
        emblemColor = const Color(0xFFEC4899);
        break;
      case 8:
        emblemColor = const Color(0xFFFFD700);
        break;
      default:
        emblemColor = const Color(0xFF9E9E9E);
    }

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            emblemColor.withValues(alpha: showGlow ? 0.4 : 0.2),
            Colors.transparent,
          ],
        ),
        boxShadow: showGlow
            ? [
                BoxShadow(
                  color: emblemColor.withValues(alpha: 0.5),
                  blurRadius: 10,
                ),
              ]
            : null,
      ),
      child: Center(
        child: Stack(
          alignment: Alignment.center,
          children: [
            Icon(Icons.shield_rounded, color: emblemColor, size: size * 0.85),
            Icon(Icons.star_rounded, color: Colors.white, size: size * 0.4),
          ],
        ),
      ),
    );
  }

  // Bottom Floating Bar: 1v1 Service (Matching Screenshot 2, 3, 4, 5)
  Widget _buildBottomServiceBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
      decoration: const BoxDecoration(
        color: Color(0xFF0E0D18),
        border: Border(top: BorderSide(color: Colors.white10, width: 0.8)),
      ),
      child: SizedBox(
        width: double.infinity,
        height: 48,
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF28253A),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
              side: const BorderSide(color: Colors.white24, width: 0.8),
            ),
            elevation: 2,
          ),
          onPressed: () {
            if (_selectedLevelIndex < 7) {
              _openRechargeSheet();
            } else {
              _showPrivilegeDetailModal(
                {
                  'title': '1v1 VIP Dedicated Service',
                  'icon': Icons.support_agent_rounded,
                  'color': const Color(0xFFFFD700),
                  'unlock_level': 7,
                  'desc': 'Contact your private VIP account manager for priority customer support.',
                },
                true,
                7,
              );
            }
          },
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                _selectedLevelIndex >= 7 ? Icons.support_agent_rounded : Icons.lock_outline_rounded,
                size: 18,
                color: _selectedLevelIndex >= 7 ? const Color(0xFFFFD700) : Colors.white70,
              ),
              const SizedBox(width: 8),
              Text(
                '1v1 Service',
                style: TextStyle(
                  color: _selectedLevelIndex >= 7 ? const Color(0xFFFFD700) : Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

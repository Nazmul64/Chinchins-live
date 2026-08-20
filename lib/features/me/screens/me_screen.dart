import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/cached_image_loader.dart';
import '../../../core/data/mock_data.dart';
import '../../wallet/widgets/recharge_gems_sheet.dart';
import '../../party/screens/create_room_screen.dart';

class MeScreen extends StatefulWidget {
  const MeScreen({super.key});

  @override
  State<MeScreen> createState() => _MeScreenState();
}

class _MeScreenState extends State<MeScreen> {
  int _myGems = 0;
  final int _beansCount = 0;
  final int _iLikeCount = 0;
  final int _likeMeCount = 0;

  void _openRechargeSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => RechargeGemsSheet(
        onRechargeSuccess: () {
          setState(() {
            _myGems += 32000;
          });
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Bar with "Me" title and "..." menu matching Screenshot 2
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Me',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.more_horiz_rounded, color: Colors.white70, size: 24),
                    onPressed: () {},
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // 1. User Profile Header (Guest_ddD7Su, ID: 388953365, ♂ 22, Bangladesh)
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Avatar with circular border
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: const Color(0xFF6A798A), width: 2),
                    ),
                    child: const ClipOval(
                      child: CachedImageLoader(
                        imageUrl: MockData.imgLivePreview,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),

                  // Name, ID, Location, Gender & Age
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Text(
                              'Guest_ddD7Su',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const Spacer(),
                            IconButton(
                              icon: const Icon(Icons.edit_outlined, color: AppColors.textMuted, size: 18),
                              onPressed: () {},
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),

                        // Badges: ♂ 22, Bangladesh, ID 388953365
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            // Gender & Age
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFF1E88E5),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.male_rounded, color: Colors.white, size: 11),
                                  SizedBox(width: 2),
                                  Text('22', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                                ],
                              ),
                            ),

                            // Country Bangladesh
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFF00796B),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Text(
                                'Bangladesh',
                                style: TextStyle(color: Colors.white, fontSize: 10),
                              ),
                            ),

                            // Copyable ID
                            GestureDetector(
                              onTap: () {
                                Clipboard.setData(const ClipboardData(text: '388953365'));
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('ID copied to clipboard'),
                                    duration: Duration(seconds: 1),
                                  ),
                                );
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppColors.cardDarkElevated,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text('ID 388953365', style: TextStyle(color: AppColors.textMuted, fontSize: 10)),
                                    SizedBox(width: 3),
                                    Icon(Icons.copy_rounded, color: AppColors.textMuted, size: 10),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),

              // 2. Stats Row ("0 I Like", "0 Like Me") matching Screenshot 2
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildStatItem('I Like', '$_iLikeCount'),
                  Container(width: 1, height: 20, color: AppColors.cardBorder),
                  _buildStatItem('Like Me', '$_likeMeCount'),
                ],
              ),
              const SizedBox(height: 16),

              // 3. Two Main Balance Cards (My Gems & Beans Center) matching Screenshot 2
              Row(
                children: [
                  // My Gems Card
                  Expanded(
                    child: GestureDetector(
                      onTap: _openRechargeSheet,
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF381F4B), Color(0xFF231433)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.neonPurple.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Row(
                                  children: [
                                    Text(
                                      'My Gems',
                                      style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600),
                                    ),
                                    SizedBox(width: 2),
                                    Icon(Icons.chevron_right_rounded, color: AppColors.textMuted, size: 16),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '$_myGems',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            const Icon(
                              Icons.diamond_rounded,
                              color: AppColors.gemYellow,
                              size: 32,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),

                  // Beans Center Card
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF2B1D3A), Color(0xFF1B1226)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.cardBorder),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Row(
                                children: [
                                  Text(
                                    'Beans Center',
                                    style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600),
                                  ),
                                  SizedBox(width: 2),
                                  Icon(Icons.chevron_right_rounded, color: AppColors.textMuted, size: 16),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '$_beansCount',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          Container(
                            width: 32,
                            height: 32,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: Color(0xFFFFB300),
                            ),
                            child: const Center(
                              child: Icon(Icons.toll_rounded, color: Colors.black87, size: 20),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // 4. "👑 Host Center — Start Audio & Video Room" Action Card
              GestureDetector(
                onTap: () {
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (context) => const CreateRoomScreen(),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF4A148C), Color(0xFFC2185B)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.neonPink.withValues(alpha: 0.35),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withValues(alpha: 0.2),
                        ),
                        child: const Icon(Icons.mic_external_on_rounded, color: Colors.white, size: 24),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  '👑 Host Center',
                                  style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                                ),
                                SizedBox(width: 6),
                                Icon(Icons.fiber_manual_record, color: AppColors.onlineGreen, size: 10),
                              ],
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Host your own Voice & Video room (10-50+ members)',
                              style: TextStyle(color: Colors.white70, fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Text(
                          'Go Live',
                          style: TextStyle(
                            color: Color(0xFFC2185B),
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // 5. "Spend Less, Get More Gems! 50% off" Banner matching Screenshot 2
              GestureDetector(
                onTap: _openRechargeSheet,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF2C1940), Color(0xFF1E112B)],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.neonPurple.withValues(alpha: 0.35)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.card_membership_rounded, color: AppColors.gemYellow, size: 24),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Spend Less, Get More Gems!',
                              style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Update to Monthly Card',
                              style: TextStyle(color: AppColors.textMuted, fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.gemYellow,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          '50% off',
                          style: TextStyle(color: Colors.black, fontSize: 11, fontWeight: FontWeight.w900),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // 5. "Keep Our Secret 🤫" Disguise Banner
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF381F4B), Color(0xFF231433)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: AppColors.neonPurple.withValues(alpha: 0.4), width: 1),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Keep Our Secret 🤫',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(height: 3),
                            Text(
                              'Change icon to hide this app',
                              style: TextStyle(
                                color: Color(0xFFD6C8FF),
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                        Row(
                          children: [
                            Container(
                              width: 34,
                              height: 34,
                              decoration: BoxDecoration(
                                gradient: AppColors.primaryGradient,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Center(
                                child: Text('LIVE', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 8)),
                              ),
                            ),
                            const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 4),
                              child: Icon(Icons.sync_alt_rounded, color: AppColors.gemYellow, size: 18),
                            ),
                            Container(
                              width: 34,
                              height: 34,
                              decoration: BoxDecoration(
                                color: const Color(0xFF1E88E5),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Center(
                                child: Icon(Icons.wb_sunny_rounded, color: Colors.amber, size: 20),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      height: 36,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.neonPurple,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                        ),
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('🔒 App Icon disguised as Weather app!'),
                              backgroundColor: AppColors.neonPurple,
                            ),
                          );
                        },
                        child: const Text('Change Now', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                      ),
                    ),
                  ],
                ),
              ),

              // 6. Action Menu Grid (2 rows x 4 items) matching Screenshot 2
              Container(
                padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
                decoration: BoxDecoration(
                  color: AppColors.cardDark,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: AppColors.cardBorder, width: 0.8),
                ),
                child: Column(
                  children: [
                    // Row 1
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildGridMenuItem(Icons.military_tech_rounded, 'SVIP', const Color(0xFFFFB300)),
                        _buildGridMenuItem(Icons.backpack_rounded, 'My Bag', const Color(0xFF42A5F5)),
                        _buildGridMenuItem(Icons.diamond_rounded, 'Gems Center', AppColors.neonPink, onTap: _openRechargeSheet),
                        _buildGridMenuItem(Icons.payment_rounded, 'Payment\ndetails', const Color(0xFF26A69A)),
                      ],
                    ),
                    const SizedBox(height: 18),

                    // Row 2
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildGridMenuItem(Icons.star_rounded, 'My Level', const Color(0xFFFF7043)),
                        _buildGridMenuItem(Icons.card_giftcard_rounded, 'Reward', const Color(0xFF66BB6A)),
                        _buildGridMenuItem(Icons.settings_rounded, 'Settings', AppColors.textMuted),
                        _buildGridMenuItem(Icons.support_agent_rounded, 'Customer\nService', const Color(0xFFAB47BC)),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 3),
        Text(
          label,
          style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
        ),
      ],
    );
  }

  Widget _buildGridMenuItem(IconData icon, String label, Color iconColor, {VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap ?? () {},
      child: SizedBox(
        width: 72,
        child: Column(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: iconColor, size: 24),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w500,
                height: 1.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

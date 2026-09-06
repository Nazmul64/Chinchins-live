import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/models/model_profile.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/avatar_with_frame.dart';
import '../../auth/services/auth_api_service.dart';
import '../../auth/widgets/logout_confirmation_dialog.dart';
import '../../profile/screens/edit_profile_media_screen.dart';
import '../../profile/screens/level_progression_screen.dart';
import '../../wallet/screens/wallet_screen.dart';
import '../../wallet/services/wallet_api_service.dart';
import '../../kyc/screens/kyc_verification_screen.dart';
import '../../bag/screens/my_bag_screen.dart';

class AppSideDrawer extends StatefulWidget {
  const AppSideDrawer({super.key});

  @override
  State<AppSideDrawer> createState() => _AppSideDrawerState();
}

class _AppSideDrawerState extends State<AppSideDrawer> {
  ModelProfile? _myProfile;
  int _coins = 0;
  int _beans = 0;

  @override
  void initState() {
    super.initState();
    _loadProfileAndWallet();
  }

  Future<void> _loadProfileAndWallet() async {
    final savedUser = await AuthApiService.getSavedUser();
    if (savedUser != null && mounted) {
      setState(() {
        _myProfile = ModelProfile.fromJson(savedUser);
        _coins = savedUser['coins'] is int ? savedUser['coins'] : _coins;
      });
    }

    try {
      final walletData = await WalletApiService.getWalletBalance();
      if (walletData != null && mounted) {
        setState(() {
          _coins = walletData['coins'] ?? _coins;
          _beans = walletData['beans'] ?? _beans;
        });
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final profile = _myProfile;

    return Drawer(
      backgroundColor: const Color(0xFF131122),
      child: SafeArea(
        child: Column(
          children: [
            // 1. Profile Header with Gradient Background
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFF281056).withValues(alpha: 0.9),
                    const Color(0xFF131122),
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
                border: const Border(
                  bottom: BorderSide(color: AppColors.cardBorder, width: 0.8),
                ),
              ),
              child: Row(
                children: [
                  AvatarWithFrame(
                    avatarUrl: profile?.avatarUrl ?? 'https://images.unsplash.com/photo-1534528741775-53994a69daeb',
                    size: 60,
                    level: profile?.level ?? 1,
                    frameUrl: profile?.avatarFrameUrl,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          profile?.name ?? 'Chinchins User',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Text(
                              'ID: ${profile?.effectiveAccountId ?? "---"}',
                              style: const TextStyle(
                                color: AppColors.textMuted,
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(width: 4),
                            GestureDetector(
                              onTap: () {
                                if (profile != null) {
                                  Clipboard.setData(ClipboardData(text: profile.effectiveAccountId));
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('ID Copied to clipboard!'),
                                      duration: Duration(seconds: 1),
                                    ),
                                  );
                                }
                              },
                              child: const Icon(
                                Icons.copy_rounded,
                                color: AppColors.textMuted,
                                size: 13,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFD54F).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: const Color(0xFFFFD54F).withValues(alpha: 0.5),
                              width: 0.8,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.diamond_rounded, color: Color(0xFFFFD54F), size: 12),
                              const SizedBox(width: 4),
                              Text(
                                '$_coins Gems',
                                style: const TextStyle(
                                  color: Color(0xFFFFD54F),
                                  fontSize: 11,
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

            // 2. Navigation Menu Items List
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                children: [
                  _buildDrawerTile(
                    icon: Icons.person_rounded,
                    iconColor: const Color(0xFF00E5FF),
                    title: 'Edit Profile & Photos',
                    subtitle: 'Manage avatars, photos & bio',
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const EditProfileMediaScreen()),
                      );
                    },
                  ),
                  _buildDrawerTile(
                    icon: Icons.account_balance_wallet_rounded,
                    iconColor: const Color(0xFFFFD54F),
                    title: 'My Wallet & Gems',
                    subtitle: 'Recharge, coin packages & withdrawal',
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const WalletScreen()),
                      );
                    },
                  ),
                  _buildDrawerTile(
                    icon: Icons.backpack_rounded,
                    iconColor: const Color(0xFFFF2A6D),
                    title: 'My Bag (আমার ব্যাগ)',
                    subtitle: 'Avatar frames, chat themes & coupons',
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const MyBagScreen()),
                      );
                    },
                  ),
                  _buildDrawerTile(
                    icon: Icons.verified_user_rounded,
                    iconColor: const Color(0xFF00E676),
                    title: 'KYC Identity Verification',
                    subtitle: 'Verify NID/Passport for host badge',
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const KycVerificationScreen()),
                      );
                    },
                  ),
                  _buildDrawerTile(
                    icon: Icons.military_tech_rounded,
                    iconColor: const Color(0xFFAB47BC),
                    title: 'Level & Progression',
                    subtitle: 'Badges, privileges & status',
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const LevelProgressionScreen()),
                      );
                    },
                  ),
                ],
              ),
            ),

            // 3. Bottom Log Out Button
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: InkWell(
                onTap: () {
                  Navigator.pop(context);
                  LogoutConfirmationDialog.show(context);
                },
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFE91E63), Color(0xFFFF2A6D)],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFFF2A6D).withValues(alpha: 0.35),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.logout_rounded, color: Colors.white, size: 20),
                      SizedBox(width: 8),
                      Text(
                        'Log Out',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDrawerTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.15),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: iconColor, size: 20),
        ),
        title: Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 13.5,
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: const TextStyle(
            color: AppColors.textMuted,
            fontSize: 11,
          ),
        ),
        trailing: const Icon(
          Icons.chevron_right_rounded,
          color: Colors.white38,
          size: 20,
        ),
        onTap: onTap,
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/cached_image_loader.dart';
import '../../../core/data/mock_data.dart';
import '../../../core/models/model_profile.dart';
import '../../../core/services/profile_api_service.dart';
import '../../auth/services/auth_api_service.dart';
import '../../profile/screens/host_profile_screen.dart';
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

  ModelProfile? _myProfile;

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
  }

  Future<void> _loadUserProfile() async {
    // 1. Try local saved user first
    final savedUser = await AuthApiService.getSavedUser();
    if (savedUser != null && mounted) {
      setState(() {
        _myProfile = ModelProfile.fromJson(savedUser);
      });
    }

    // 2. Fetch fresh profile from Laravel REST API
    final remoteProfile = await ProfileApiService.getMyProfile();
    if (remoteProfile != null && mounted) {
      setState(() {
        _myProfile = remoteProfile;
      });
    }
  }

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

  void _openMyHostProfile() {
    final profile = _myProfile ??
        const ModelProfile(
          id: '602281635',
          name: 'Ayeena04',
          age: 27,
          location: 'Pakistan',
          intro: 'Sweet girl looking for honest talk ❤️',
          languages: ['English', 'Urdu'],
          avatarUrl: MockData.imgLivePreview,
          galleryUrls: [MockData.imgLivePreview],
          charmLevel: 98,
          topFan: 'Prince_01',
          pricePerMin: 1800,
        );

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => HostProfileScreen(model: profile),
      ),
    );
  }

  Future<void> _performProfileUpdate({
    required String name,
    required String age,
    required String country,
    required String intro,
    required String languages,
    required String tags,
  }) async {
    final res = await ProfileApiService.updateProfile(
      nickname: name.trim(),
      age: int.tryParse(age.trim()) ?? 27,
      country: country.trim(),
      introduction: intro.trim(),
      languages: languages.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList(),
      tags: tags.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList(),
    );

    if (!mounted) return;

    if (res['success'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile updated in Laravel Database!'), backgroundColor: Colors.green),
      );
      _loadUserProfile();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(res['message'] ?? 'Update failed'), backgroundColor: Colors.red),
      );
    }
  }

  void _showEditProfileDialog() {
    final nameCtrl = TextEditingController(text: _myProfile?.name ?? 'Nazmul');
    final introCtrl = TextEditingController(text: _myProfile?.intro ?? 'Sweet girl looking for honest talk ❤️');
    final ageCtrl = TextEditingController(text: '${_myProfile?.age ?? 27}');
    final countryCtrl = TextEditingController(text: _myProfile?.location ?? 'Pakistan');
    final langCtrl = TextEditingController(text: _myProfile?.languages.join(', ') ?? 'English, Urdu');
    final tagsCtrl = TextEditingController(text: _myProfile?.tags.join(', ') ?? 'Live video, Music, Singing');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.cardDarkElevated,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Edit Profile (Live API)', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'Nickname / Name',
                  labelStyle: TextStyle(color: AppColors.textMuted),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: ageCtrl,
                keyboardType: TextInputType.number,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'Age',
                  labelStyle: TextStyle(color: AppColors.textMuted),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: countryCtrl,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'Country / Location',
                  labelStyle: TextStyle(color: AppColors.textMuted),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: introCtrl,
                maxLines: 2,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'Introduction / Bio',
                  labelStyle: TextStyle(color: AppColors.textMuted),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: langCtrl,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'Languages (comma separated)',
                  labelStyle: TextStyle(color: AppColors.textMuted),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: tagsCtrl,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'Interests / Tags (comma separated)',
                  labelStyle: TextStyle(color: AppColors.textMuted),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: AppColors.textMuted)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.neonPurple,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () {
              Navigator.pop(ctx);
              _performProfileUpdate(
                name: nameCtrl.text,
                age: ageCtrl.text,
                country: countryCtrl.text,
                intro: introCtrl.text,
                languages: langCtrl.text,
                tags: tagsCtrl.text,
              );
            },
            child: const Text('Save to DB', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final displayName = _myProfile?.name ?? 'Ayeena04';
    final accountId = _myProfile?.id ?? '602281635';
    final userAge = '${_myProfile?.age ?? 27}';
    final userCountry = _myProfile?.location ?? 'Pakistan';
    final avatar = _myProfile?.avatarUrl ?? MockData.imgLivePreview;

    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadUserProfile,
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
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.remove_red_eye_outlined, color: AppColors.neonPurple, size: 22),
                          tooltip: 'View Profile Preview',
                          onPressed: _openMyHostProfile,
                        ),
                        IconButton(
                          icon: const Icon(Icons.more_horiz_rounded, color: Colors.white70, size: 24),
                          onPressed: () {},
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // 1. User Profile Header (matching Screenshot 2)
                GestureDetector(
                  onTap: _openMyHostProfile,
                  child: Row(
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
                        child: ClipOval(
                          child: CachedImageLoader(
                            imageUrl: avatar,
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
                                Text(
                                  displayName,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 17,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const Spacer(),
                                IconButton(
                                  icon: const Icon(Icons.edit_outlined, color: AppColors.neonPurple, size: 18),
                                  onPressed: _showEditProfileDialog,
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),

                            // Badges: Gender & Age, Location, ID
                            Wrap(
                              spacing: 6,
                              runSpacing: 4,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                // Gender & Age
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFEC4899),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.female_rounded, color: Colors.white, size: 11),
                                      const SizedBox(width: 2),
                                      Text(userAge, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                                    ],
                                  ),
                                ),

                                // Country
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF0284C7),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    userCountry,
                                    style: const TextStyle(color: Colors.white, fontSize: 10),
                                  ),
                                ),

                                // Copyable ID
                                GestureDetector(
                                  onTap: () {
                                    Clipboard.setData(ClipboardData(text: accountId));
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('ID $accountId copied to clipboard'),
                                        duration: const Duration(seconds: 1),
                                      ),
                                    );
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: AppColors.cardDarkElevated,
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text('ID $accountId', style: const TextStyle(color: AppColors.textMuted, fontSize: 10)),
                                        const SizedBox(width: 3),
                                        const Icon(Icons.copy_rounded, color: AppColors.textMuted, size: 10),
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
                                  const Text('My Gems', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
                                  const SizedBox(height: 6),
                                  Row(
                                    children: [
                                      const Icon(Icons.diamond_rounded, color: AppColors.gemYellow, size: 16),
                                      const SizedBox(width: 4),
                                      Text(
                                        '$_myGems',
                                        style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              const Icon(Icons.chevron_right_rounded, color: Colors.white54, size: 20),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),

                    // Beans Center Card
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF3B2818), Color(0xFF24180E)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.gemYellow.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Beans Center', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
                                const SizedBox(height: 6),
                                Row(
                                  children: [
                                    const Icon(Icons.spa_rounded, color: Colors.amber, size: 16),
                                    const SizedBox(width: 4),
                                    Text(
                                      '$_beansCount',
                                      style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            const Icon(Icons.chevron_right_rounded, color: Colors.white54, size: 20),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // 4. Create Party Room Banner matching Screenshot 2
                GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const CreateRoomScreen()),
                    );
                  },
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF2A1B4E), Color(0xFF1B2B4E)],
                      ),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.cardBorder),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: const BoxDecoration(
                            color: Color(0xFF6C63FF),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.mic_rounded, color: Colors.white, size: 20),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Create a party room', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                              SizedBox(height: 2),
                              Text('To start a great party and earn gifts', style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
                            ],
                          ),
                        ),
                        const Icon(Icons.chevron_right_rounded, color: Colors.white54, size: 22),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                // 5. App Icon Camouflage Box
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.cardDark,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.cardBorder),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('App icon camouflage', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                              SizedBox(height: 2),
                              Text('To prevent embarrassment', style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
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
                                content: Text('App Icon disguised as Weather app!'),
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
                const SizedBox(height: 14),

                // 6. Action Menu Grid (2 rows x 4 items)
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
                          _buildGridMenuItem(
                            Icons.settings_rounded,
                            'Settings',
                            AppColors.textMuted,
                            onTap: () {
                              _showLogoutDialog(context);
                            },
                          ),
                          _buildGridMenuItem(Icons.support_agent_rounded, 'Customer\nService', const Color(0xFFAB47BC)),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                // Logout Action Tile
                Center(
                  child: TextButton.icon(
                    onPressed: () => _showLogoutDialog(context),
                    icon: const Icon(Icons.logout_rounded, color: AppColors.badgePink, size: 18),
                    label: const Text(
                      'Log Out',
                      style: TextStyle(
                        color: AppColors.badgePink,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: AppColors.surfaceDark,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.cardBorder),
        ),
        title: const Text('Log Out', style: TextStyle(color: Colors.white)),
        content: const Text(
          'Are you sure you want to log out of Chinchins Live?',
          style: TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Cancel', style: TextStyle(color: AppColors.textMuted)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.badgePink,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () async {
              Navigator.pop(dialogCtx);
              await AuthApiService.logout();
              if (context.mounted) {
                Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
              }
            },
            child: const Text('Log Out', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
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

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/cached_image_loader.dart';
import '../../../core/widgets/avatar_with_frame.dart';
import '../../../core/data/mock_data.dart';
import '../../../core/models/model_profile.dart';
import '../../../core/services/profile_api_service.dart';
import '../../../core/services/local_image_cache.dart';
import '../../../core/services/app_update_service.dart';
import '../../../core/services/remote_config_service.dart';
import '../../auth/services/auth_api_service.dart';
import '../../auth/screens/login_screen.dart';
import '../../profile/screens/host_profile_screen.dart';
import '../../profile/screens/edit_profile_media_screen.dart';
import '../../profile/screens/level_progression_screen.dart';
import '../../wallet/screens/wallet_screen.dart';
import '../../wallet/screens/withdraw_screen.dart';
import '../../wallet/screens/premium_vip_screen.dart';
import '../../wallet/services/wallet_api_service.dart';
import '../../party/screens/create_room_screen.dart';
import '../../kyc/screens/kyc_verification_screen.dart';
import '../../kyc/services/kyc_api_service.dart';

class MeScreen extends StatefulWidget {
  const MeScreen({super.key});

  @override
  State<MeScreen> createState() => _MeScreenState();
}

class _MeScreenState extends State<MeScreen> {
  int _myGems = 0;
  int _beans = 0;
  final int _iLikeCount = 0;
  final int _likeMeCount = 0;

  ModelProfile? _myProfile;
  final ImagePicker _picker = ImagePicker();
  bool _isUploading = false;
  String _kycStatus = 'unverified';

  @override
  void initState() {
    super.initState();
    LocalImageCache.init();
    _loadUserProfile();
    _loadKycStatus();
  }

  Future<void> _loadKycStatus() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _kycStatus = prefs.getString('kyc_verification_status') ?? 'unverified';
      });
    }
    // Asynchronously refresh status from server
    try {
      final statusResult = await KycApiService.getKycStatus();
      if (statusResult != null && mounted) {
        setState(() {
          _kycStatus = (statusResult['kyc_status'] ?? _kycStatus).toString().toLowerCase();
        });
      }
    } catch (_) {}
  }

  Future<void> _openKycScreen() async {
    final updated = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (context) => const KycVerificationScreen()),
    );
    if (updated == true || mounted) {
      _loadKycStatus();
    }
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

    // 3. Fetch fresh wallet balance
    try {
      final walletData = await WalletApiService.getWalletBalance();
      if (walletData != null && mounted) {
        setState(() {
          _myGems = walletData['coins'] ?? _myGems;
          _beans = walletData['beans'] ?? _beans;
        });
      }
    } catch (_) {}
  }

  void _openWalletScreen({int initialTabIndex = 0}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => WalletScreen(initialTabIndex: initialTabIndex),
      ),
    ).then((_) {
      _loadUserProfile();
    });
  }

  void _openRechargeSheet() {
    _openWalletScreen(initialTabIndex: 0);
  }

  void _openWithdrawScreen() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => WithdrawScreen(
          onWithdrawSuccess: () {
            _loadUserProfile();
          },
        ),
      ),
    ).then((_) {
      _loadUserProfile();
    });
  }

  void _openMonthlyCardScreen([int initialCardIndex = 0]) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PremiumVipScreen(initialCardIndex: initialCardIndex),
      ),
    ).then((_) {
      _loadUserProfile();
    });
  }

  void _openMyHostProfile() {
    final profile = _myProfile ??
        const ModelProfile(
          id: '6829104721',
          name: 'Chinchins User',
          age: 25,
          location: 'Bangladesh',
          intro: 'Welcome to Chinchins Live! ✨',
          languages: ['English', 'Bengali'],
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

  Future<void> _openEditProfileMediaScreen() async {
    final updated = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => EditProfileMediaScreen(
          isInitialSetup: false,
          initialProfile: _myProfile,
        ),
      ),
    );
    if (updated == true || mounted) {
      _loadUserProfile();
    }
  }

  // --- Profile Avatar & Photo Upload Handlers ---

  Future<void> _pickAndUploadAvatar() async {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surfaceDark,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(
                'Change Profile Photo (Avatar)',
                style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
            const Divider(color: AppColors.cardBorder, height: 1),
            ListTile(
              leading: const Icon(Icons.camera_alt_rounded, color: AppColors.neonPink),
              title: const Text('Take Photo from Camera', style: TextStyle(color: Colors.white)),
              onTap: () async {
                Navigator.pop(ctx);
                final picked = await _picker.pickImage(
                  source: ImageSource.camera,
                  maxWidth: 1080,
                  maxHeight: 1080,
                  imageQuality: 85,
                );
                if (picked != null) _uploadAvatarFile(picked.path);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_rounded, color: AppColors.neonPurple),
              title: const Text('Choose from Gallery', style: TextStyle(color: Colors.white)),
              onTap: () async {
                Navigator.pop(ctx);
                final picked = await _picker.pickImage(
                  source: ImageSource.gallery,
                  maxWidth: 1080,
                  maxHeight: 1080,
                  imageQuality: 85,
                );
                if (picked != null) _uploadAvatarFile(picked.path);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _uploadAvatarFile(String path) async {
    await LocalImageCache.setAvatar(path);
    if (!mounted) return;
    setState(() {
      _isUploading = true;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Row(
          children: [
            SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
            SizedBox(width: 12),
            Text('Uploading profile avatar to server...'),
          ],
        ),
        duration: Duration(seconds: 4),
      ),
    );

    final res = await ProfileApiService.uploadAvatar(path);
    if (!mounted) return;
    setState(() => _isUploading = false);

    if (res['success'] == true) {
      if (res['user'] != null && res['user'] is Map<String, dynamic>) {
        await AuthApiService.saveUser(res['user']);
        if (mounted) {
          setState(() {
            _myProfile = ModelProfile.fromJson(res['user']);
          });
        }
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Avatar updated successfully! ✨'), backgroundColor: Colors.green),
      );
      _loadUserProfile();
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(res['message'] ?? 'Avatar upload failed'), backgroundColor: Colors.red),
      );
    }
  }



  Future<void> _pickAndUploadGalleryPhotos() async {
    final pickedList = await _picker.pickMultiImage(
      maxWidth: 1080,
      maxHeight: 1080,
      imageQuality: 85,
    );
    if (pickedList.isNotEmpty) {
      final paths = pickedList.map((x) => x.path).toList();
      await LocalImageCache.addGallery(paths);
      if (mounted) {
        setState(() {});
      }

      if (!mounted) return;
      setState(() => _isUploading = true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
              const SizedBox(width: 12),
              Text('Uploading ${pickedList.length} photos to your gallery...'),
            ],
          ),
          duration: const Duration(seconds: 5),
        ),
      );

      final res = await ProfileApiService.uploadPhotos(paths);
      if (!mounted) return;
      setState(() => _isUploading = false);

      if (res['success'] == true) {
        if (res['user'] != null && res['user'] is Map<String, dynamic>) {
          await AuthApiService.saveUser(res['user']);
          if (mounted) {
            setState(() {
              _myProfile = ModelProfile.fromJson(res['user']);
            });
          }
        }
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Gallery photos uploaded successfully! 🎉'), backgroundColor: Colors.green),
        );
        _loadUserProfile();
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(res['message'] ?? 'Gallery upload failed'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _deletePhotoConfirm(String photoUrl) async {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Photo', style: TextStyle(color: Colors.white)),
        content: const Text('Are you sure you want to remove this photo from your gallery?', style: TextStyle(color: AppColors.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: AppColors.textMuted)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.badgePink),
            onPressed: () async {
              Navigator.pop(ctx);
              final res = await ProfileApiService.deletePhoto(photoUrl);
              if (mounted) {
                if (res['success'] == true) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Photo deleted successfully')),
                  );
                  _loadUserProfile();
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(res['message'] ?? 'Failed to delete photo'), backgroundColor: Colors.red),
                  );
                }
              }
            },
            child: const Text('Delete', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Future<void> _checkAppUpdatesManually() async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Checking for OTA updates...'),
        duration: Duration(seconds: 1),
      ),
    );
    await AppUpdateService.checkForUpdates(
      context,
      autoShowDialog: true,
      showToastIfUpToDate: true,
    );
  }

  void _showCustomerServiceDialog() {
    final remoteConfig = RemoteConfigService.instance.config;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1829),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: AppColors.primaryPink.withValues(alpha: 0.4)),
        ),
        title: const Row(
          children: [
            Icon(Icons.support_agent_rounded, color: AppColors.primaryPink),
            SizedBox(width: 8),
            Text('Customer Support', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Need help or experiencing issues? Contact our official 24/7 Live Support team:',
              style: TextStyle(color: Colors.white70, fontSize: 13),
            ),
            const SizedBox(height: 16),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.chat_rounded, color: Colors.greenAccent, size: 20),
              ),
              title: const Text('WhatsApp Support', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
              subtitle: Text(remoteConfig.supportWhatsapp, style: const TextStyle(color: Colors.white60, fontSize: 12)),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.email_rounded, color: Colors.lightBlueAccent, size: 20),
              ),
              title: const Text('Email Support', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
              subtitle: Text(remoteConfig.supportEmail, style: const TextStyle(color: Colors.white60, fontSize: 12)),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close', style: TextStyle(color: AppColors.primaryPink, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    String fullName = '';
    if (_myProfile?.firstName != null && _myProfile!.firstName!.trim().isNotEmpty) {
      fullName = _myProfile!.firstName!.trim();
      if (_myProfile?.lastName != null && _myProfile!.lastName!.trim().isNotEmpty) {
        fullName += ' ${_myProfile!.lastName!.trim()}';
      }
    }
    final displayName = fullName.isNotEmpty
        ? fullName
        : (_myProfile?.name ?? 'User');

    final accountId = _myProfile?.effectiveAccountId ?? _myProfile?.accountId ?? _myProfile?.id ?? '84920183';
    final userAge = '${_myProfile?.age ?? 25}';
    final userCountry = _myProfile?.location ?? 'Bangladesh';
    final avatar = (_myProfile?.avatarUrl != null && _myProfile!.avatarUrl.isNotEmpty)
        ? _myProfile!.avatarUrl
        : (LocalImageCache.localAvatar ?? MockData.imgLivePreview);

    final List<String> gallery = [];
    if (_myProfile?.galleryUrls != null) {
      gallery.addAll(_myProfile!.galleryUrls);
    }
    for (final loc in LocalImageCache.localGallery) {
      if (!gallery.contains(loc)) {
        gallery.insert(0, loc);
      }
    }
    if (gallery.isEmpty) {
      gallery.add(avatar);
    }

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
                        if (_isUploading)
                          const Padding(
                            padding: EdgeInsets.only(right: 10),
                            child: SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.neonPink),
                            ),
                          ),
                        IconButton(
                          icon: const Icon(Icons.remove_red_eye_outlined, color: AppColors.neonPurple, size: 22),
                          tooltip: 'View Profile Preview',
                          onPressed: _openMyHostProfile,
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // 1. User Profile Header with Avatar Camera Picker
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Avatar with Profile Base Frame & Camera Picker Badge
                    GestureDetector(
                      onTap: _pickAndUploadAvatar,
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          AvatarWithFrame(
                            avatarUrl: avatar,
                            frameUrl: _myProfile?.avatarFrameUrl,
                            level: _myProfile?.currentLevel ?? 0,
                            badgeColor: _myProfile?.badgeColor ?? '#f59e0b',
                            glowColor: _myProfile?.glowColor,
                            size: 68,
                            showLevelBadge: true,
                          ),
                          Positioned(
                            top: 0,
                            right: 0,
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                gradient: AppColors.primaryGradient,
                                shape: BoxShape.circle,
                                border: Border.all(color: AppColors.backgroundDark, width: 1.5),
                              ),
                              child: const Icon(Icons.camera_alt_rounded, color: Colors.white, size: 11),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 14),

                    // Full Name, ID, Location, Gender, Age & Phone
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  displayName,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 17,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.edit_outlined, color: AppColors.neonPurple, size: 18),
                                onPressed: _openEditProfileMediaScreen,
                                tooltip: 'Edit Profile & Photos',
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),

                          // Badges: Gender & Age, Location, ID, Phone
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              // Gender & Age
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                decoration: BoxDecoration(
                                  color: (_myProfile?.gender?.toLowerCase() == 'male')
                                      ? const Color(0xFF3B82F6)
                                      : const Color(0xFFEC4899),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      (_myProfile?.gender?.toLowerCase() == 'male')
                                          ? Icons.male_rounded
                                          : Icons.female_rounded,
                                      color: Colors.white,
                                      size: 12,
                                    ),
                                    const SizedBox(width: 3),
                                    Text(userAge, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                                  ],
                                ),
                              ),

                              // Country
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF0284C7),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  userCountry,
                                  style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w500),
                                ),
                              ),

                              // Copyable Account ID
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
                                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: AppColors.cardDarkElevated,
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(color: AppColors.cardBorder.withValues(alpha: 0.5)),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text('ID $accountId', style: const TextStyle(color: AppColors.textSecondary, fontSize: 11)),
                                      const SizedBox(width: 4),
                                      const Icon(Icons.copy_rounded, color: AppColors.textMuted, size: 11),
                                    ],
                                  ),
                                ),
                              ),

                              // Phone Number Badge
                              if (_myProfile?.phone != null && _myProfile!.phone!.isNotEmpty)
                                GestureDetector(
                                  onTap: () {
                                    Clipboard.setData(ClipboardData(text: _myProfile!.phone!));
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('Phone ${_myProfile!.phone!} copied'),
                                        duration: const Duration(seconds: 1),
                                      ),
                                    );
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF10B981).withValues(alpha: 0.18),
                                      border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.4), width: 0.8),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(Icons.phone_android_rounded, color: Color(0xFF34D399), size: 12),
                                        const SizedBox(width: 3),
                                        Text(
                                          _myProfile!.phone!,
                                          style: const TextStyle(
                                            color: Color(0xFF34D399),
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
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
                const SizedBox(height: 12),

                // Quick Action Buttons: Edit Profile & Add Photos
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: const BorderSide(color: AppColors.neonPink),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(vertical: 8),
                        ),
                        icon: const Icon(Icons.edit_note_rounded, color: AppColors.neonPink, size: 18),
                        label: const Text('Edit Profile & Photos', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                        onPressed: _openEditProfileMediaScreen,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: const BorderSide(color: AppColors.neonPurple),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(vertical: 8),
                        ),
                        icon: const Icon(Icons.add_photo_alternate_rounded, color: AppColors.neonPurple, size: 18),
                        label: const Text('Add Photos', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                        onPressed: _pickAndUploadGalleryPhotos,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Photo Gallery Management Section
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
                          GestureDetector(
                            onTap: _openEditProfileMediaScreen,
                            child: Row(
                              children: [
                                const Icon(Icons.photo_library_rounded, color: AppColors.neonPink, size: 18),
                                const SizedBox(width: 6),
                                Text(
                                  'My Gallery Photos (${gallery.length})',
                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                                ),
                                const SizedBox(width: 4),
                                const Icon(Icons.chevron_right_rounded, color: Colors.white54, size: 16),
                              ],
                            ),
                          ),
                          GestureDetector(
                            onTap: _pickAndUploadGalleryPhotos,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                gradient: AppColors.primaryGradient,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.add_rounded, color: Colors.white, size: 14),
                                  SizedBox(width: 2),
                                  Text('Upload', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        height: 80,
                        child: ListView(
                          scrollDirection: Axis.horizontal,
                          physics: const BouncingScrollPhysics(),
                          children: [
                            // Add new photo button card
                            GestureDetector(
                              onTap: _pickAndUploadGalleryPhotos,
                              child: Container(
                                width: 76,
                                height: 80,
                                margin: const EdgeInsets.only(right: 8),
                                decoration: BoxDecoration(
                                  color: AppColors.cardDarkElevated,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: AppColors.cardBorder),
                                ),
                                child: const Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.add_a_photo_rounded, color: AppColors.neonPink, size: 22),
                                    SizedBox(height: 4),
                                    Text('Add Photo', style: TextStyle(color: AppColors.textMuted, fontSize: 10)),
                                  ],
                                ),
                              ),
                            ),
                            // Existing Gallery Photos
                            ...gallery.map((imgUrl) => Stack(
                                  children: [
                                    Container(
                                      width: 76,
                                      height: 80,
                                      margin: const EdgeInsets.only(right: 8),
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(color: AppColors.cardBorder),
                                      ),
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(12),
                                        child: CachedImageLoader(imageUrl: imgUrl, fit: BoxFit.cover),
                                      ),
                                    ),
                                    Positioned(
                                      top: 2,
                                      right: 10,
                                      child: GestureDetector(
                                        onTap: () => _deletePhotoConfirm(imgUrl),
                                        child: Container(
                                          padding: const EdgeInsets.all(3),
                                          decoration: const BoxDecoration(color: Colors.black87, shape: BoxShape.circle),
                                          child: const Icon(Icons.close_rounded, color: Colors.redAccent, size: 12),
                                        ),
                                      ),
                                    ),
                                  ],
                                )),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

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

                // 3. Balance Cards: My Gems & Beans Center (Matching Screenshot 1)
                Row(
                  children: [
                    // My Gems Card
                    Expanded(
                      child: GestureDetector(
                        onTap: _openRechargeSheet,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
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
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Row(
                                      children: [
                                        Flexible(
                                          child: Text(
                                            'My Gems',
                                            style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        SizedBox(width: 2),
                                        Icon(Icons.chevron_right_rounded, color: Colors.white54, size: 14),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      '$_myGems',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 4),
                              Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: AppColors.gemYellow.withValues(alpha: 0.2),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.diamond_rounded, color: AppColors.gemYellow, size: 22),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),

                    // Beans Center Card
                    Expanded(
                      child: GestureDetector(
                        onTap: _openWithdrawScreen,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF1F2445), Color(0xFF141730)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0xFF536DFE).withValues(alpha: 0.3)),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Row(
                                      children: [
                                        Flexible(
                                          child: Text(
                                            'Beans Center',
                                            style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        SizedBox(width: 2),
                                        Icon(Icons.chevron_right_rounded, color: Colors.white54, size: 14),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      '$_beans',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 4),
                              Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: Colors.amber.withValues(alpha: 0.2),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.egg_rounded, color: Colors.amber, size: 22),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // 4. "Spend Less, Get More Gems! Update to New User Weekly Card" VIP Banner (Matching Screenshot 1)
                GestureDetector(
                  onTap: () => _openMonthlyCardScreen(0),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF2E1C38), Color(0xFF1E172A)],
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.amber.withValues(alpha: 0.5), width: 1.2),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.amber.withValues(alpha: 0.15),
                          blurRadius: 10,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            gradient: AppColors.primaryGradient,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.card_giftcard_rounded, color: Colors.white, size: 22),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Spend Less, Get More Gems!',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13.5,
                                ),
                              ),
                              SizedBox(height: 2),
                              Text(
                                'Update to New User Weekly Card',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.amber,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(color: Colors.amber.withValues(alpha: 0.4), blurRadius: 6),
                            ],
                          ),
                          child: const Text(
                            'View',
                            style: TextStyle(
                              color: Colors.black87,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                // 5. Action Menu Grid (Matching Screenshot 1: SVIP, My Bag, Gems Center, Payment details, My Level, Reward...)
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
                  decoration: BoxDecoration(
                    color: AppColors.cardDark,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: AppColors.cardBorder, width: 0.8),
                  ),
                  child: Column(
                    children: [
                      // Row 1 (SVIP, My Bag, Gems Center, Payment details)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _buildGridMenuItem(Icons.workspace_premium_rounded, 'SVIP', const Color(0xFFFFB300), onTap: () => _openMonthlyCardScreen(1)),
                          _buildGridMenuItem(Icons.backpack_rounded, 'My Bag', const Color(0xFFAB47BC), onTap: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('My Bag: You have 0 items currently.')),
                            );
                          }),
                          _buildGridMenuItem(Icons.diamond_rounded, 'Gems Center', const Color(0xFF00E676), onTap: () => _openWalletScreen(initialTabIndex: 0)),
                          _buildGridMenuItem(Icons.account_balance_wallet_rounded, 'Payment\ndetails', const Color(0xFF42A5F5), onTap: () => _openWalletScreen(initialTabIndex: 1)),
                        ],
                      ),
                      const SizedBox(height: 18),

                      // Row 2 (My Level, Reward, KYC Verify, Support)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _buildGridMenuItem(Icons.military_tech_rounded, 'My Level', const Color(0xFFFF7043), onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => LevelProgressionScreen(
                                  accountId: _myProfile?.effectiveAccountId,
                                  userId: _myProfile?.id,
                                ),
                              ),
                            );
                          }),
                          _buildGridMenuItem(Icons.calendar_month_rounded, 'Reward', const Color(0xFF00E5FF), onTap: () => _openMonthlyCardScreen(0)),
                          _buildGridMenuItem(Icons.verified_user_rounded, 'KYC\nVerify', const Color(0xFF10B981), onTap: _openKycScreen),
                          _buildGridMenuItem(Icons.support_agent_rounded, 'Customer\nService', const Color(0xFFEC4899), onTap: _showCustomerServiceDialog),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // 6. Create Party Room Banner
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

                // 7. App OTA Update & Version Card
                GestureDetector(
                  onTap: _checkAppUpdatesManually,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: AppColors.cardDark,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.cardBorder),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppColors.primaryPink.withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.system_update_rounded, color: AppColors.primaryPink, size: 20),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Check for App Updates', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13.5)),
                              SizedBox(height: 2),
                              Text('Version 1.0.0 (Build 1) • OTA Live Updates', style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Text('Check', style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
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
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (context) => const LoginScreen()),
                  (route) => false,
                );
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

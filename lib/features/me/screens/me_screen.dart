import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/cached_image_loader.dart';
import '../../../core/data/mock_data.dart';
import '../../../core/models/model_profile.dart';
import '../../../core/services/profile_api_service.dart';
import '../../../core/services/local_image_cache.dart';
import '../../auth/services/auth_api_service.dart';
import '../../profile/screens/host_profile_screen.dart';
import '../../profile/screens/edit_profile_media_screen.dart';
import '../../wallet/screens/wallet_screen.dart';
import '../../wallet/screens/withdraw_screen.dart';
import '../../wallet/screens/withdraw_history_screen.dart';
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

  void _openWithdrawHistoryScreen() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const WithdrawHistoryScreen(),
      ),
    );
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

  void _showDiagnosticsDialog() {
    bool isTesting = false;
    List<String> diagnosticLogs = [];

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          return AlertDialog(
            backgroundColor: AppColors.surfaceDark,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Row(
              children: [
                Icon(Icons.cloud_done_rounded, color: AppColors.neonPink, size: 22),
                SizedBox(width: 8),
                Text('Live Server & Image Diagnostics', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
              ],
            ),
            content: SizedBox(
              width: double.maxFinite,
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.green.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.green.withValues(alpha: 0.4)),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.check_circle_rounded, color: Colors.greenAccent, size: 16),
                          SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'Live Server: https://chinchins.live/api',
                              style: TextStyle(color: Colors.greenAccent, fontSize: 12, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Divider(color: AppColors.cardBorder, height: 20),
                    const Text('Live User Profile:', style: TextStyle(color: AppColors.textSecondary, fontSize: 12, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text('ID: ${_myProfile?.id ?? "N/A"}', style: const TextStyle(color: Colors.white, fontSize: 12)),
                    Text('Name: ${_myProfile?.fullName ?? "N/A"}', style: const TextStyle(color: Colors.white, fontSize: 12)),
                    Text('Avatar: ${_myProfile?.avatarUrl ?? "None"}', style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
                    Text('Cover: ${_myProfile?.coverPhotoUrl ?? "None"}', style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
                    Text('Gallery: ${_myProfile?.galleryUrls.length ?? 0} photos', style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(backgroundColor: AppColors.cardDarkElevated, padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
                      icon: isTesting
                          ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.network_check_rounded, size: 14, color: AppColors.neonPurple),
                      label: const Text('Test Live Image HTTP Status', style: TextStyle(fontSize: 12, color: Colors.white)),
                      onPressed: isTesting
                          ? null
                          : () async {
                              setDialogState(() {
                                isTesting = true;
                                diagnosticLogs = [];
                              });

                              final urlsToTest = <String>[];
                              if (_myProfile?.avatarUrl != null) urlsToTest.add(_myProfile!.avatarUrl);
                              if (_myProfile?.coverPhotoUrl != null) urlsToTest.add(_myProfile!.coverPhotoUrl!);
                              if (_myProfile?.galleryUrls != null) urlsToTest.addAll(_myProfile!.galleryUrls);

                              for (final rawUrl in urlsToTest) {
                                final norm = CachedImageLoader.normalize(rawUrl);
                                try {
                                  if (norm.startsWith('http')) {
                                    final res = await http.get(Uri.parse(norm)).timeout(const Duration(seconds: 5));
                                    diagnosticLogs.add('HTTP ${res.statusCode}: $norm');
                                  } else {
                                    diagnosticLogs.add('Local file: $norm');
                                  }
                                } catch (e) {
                                  diagnosticLogs.add('FAIL: $norm -> $e');
                                }
                              }

                              if (urlsToTest.isEmpty) {
                                diagnosticLogs.add('No image URLs found to test.');
                              }

                              setDialogState(() {
                                isTesting = false;
                              });
                            },
                    ),
                    if (diagnosticLogs.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(color: Colors.black45, borderRadius: BorderRadius.circular(8)),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: diagnosticLogs
                              .map((l) => Text(l,
                                  style: TextStyle(
                                      color: l.startsWith('HTTP 200') ? Colors.greenAccent : Colors.redAccent,
                                      fontSize: 10,
                                      fontFamily: 'monospace')))
                              .toList(),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Close', style: TextStyle(color: AppColors.textMuted)),
              ),
            ],
          );
        },
      ),
    );
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

    final accountId = _myProfile?.id ?? '6829104721';
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
                        IconButton(
                          icon: const Icon(Icons.more_horiz_rounded, color: Colors.white70, size: 24),
                          tooltip: 'API & Image Diagnostics',
                          onPressed: _showDiagnosticsDialog,
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
                    // Avatar with Camera Picker Badge
                    GestureDetector(
                      onTap: _pickAndUploadAvatar,
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Container(
                            width: 68,
                            height: 68,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: AppColors.neonPink.withValues(alpha: 0.8), width: 2.5),
                            ),
                            child: ClipOval(
                              child: CachedImageLoader(
                                imageUrl: avatar,
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                          Positioned(
                            bottom: -2,
                            right: -2,
                            child: Container(
                              padding: const EdgeInsets.all(5),
                              decoration: BoxDecoration(
                                gradient: AppColors.primaryGradient,
                                shape: BoxShape.circle,
                                border: Border.all(color: AppColors.backgroundDark, width: 2),
                              ),
                              child: const Icon(Icons.camera_alt_rounded, color: Colors.white, size: 13),
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

                // 3. Three Main Balance / Action Cards (My Gems, Withdraw, Beans Center)
                Row(
                  children: [
                    // My Gems Card
                    Expanded(
                      flex: 5,
                      child: GestureDetector(
                        onTap: _openRechargeSheet,
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF381F4B), Color(0xFF231433)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: AppColors.neonPurple.withValues(alpha: 0.3)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text('My Gems', style: TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.w600)),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                    decoration: BoxDecoration(
                                      color: AppColors.neonPink.withValues(alpha: 0.2),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: const Text('Top-up', style: TextStyle(color: AppColors.neonPink, fontSize: 9.5, fontWeight: FontWeight.bold)),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  const Icon(Icons.diamond_rounded, color: AppColors.gemYellow, size: 16),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Text(
                                      '$_myGems',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),

                    // Withdraw / Cash Out Card
                    Expanded(
                      flex: 5,
                      child: GestureDetector(
                        onTap: _openWithdrawScreen,
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF143328), Color(0xFF0D211A)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: AppColors.onlineGreen.withValues(alpha: 0.4)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text('Cash Out', style: TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.w600)),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                    decoration: BoxDecoration(
                                      color: AppColors.onlineGreen.withValues(alpha: 0.2),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: const Text('bKash/Nagad', style: TextStyle(color: AppColors.onlineGreen, fontSize: 9, fontWeight: FontWeight.bold)),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              const Row(
                                children: [
                                  Icon(Icons.payments_rounded, color: AppColors.onlineGreen, size: 16),
                                  SizedBox(width: 4),
                                  Text(
                                    'Withdraw',
                                    style: TextStyle(color: AppColors.onlineGreen, fontSize: 14, fontWeight: FontWeight.bold),
                                  ),
                                  Spacer(),
                                  Icon(Icons.chevron_right_rounded, color: Colors.white54, size: 16),
                                ],
                              ),
                            ],
                          ),
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
                // 5. KYC Verification Card
                GestureDetector(
                  onTap: _openKycScreen,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF231738), Color(0xFF171329)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: _kycStatus == 'approved'
                            ? Colors.greenAccent.withValues(alpha: 0.5)
                            : _kycStatus == 'pending'
                                ? Colors.amber.withValues(alpha: 0.5)
                                : AppColors.neonPurple.withValues(alpha: 0.35),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(9),
                          decoration: BoxDecoration(
                            gradient: _kycStatus == 'approved'
                                ? const LinearGradient(colors: [Color(0xFF00E676), Color(0xFF00B0FF)])
                                : _kycStatus == 'pending'
                                    ? const LinearGradient(colors: [Color(0xFFFFB300), Color(0xFFFF6D00)])
                                    : AppColors.primaryGradient,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            _kycStatus == 'approved'
                                ? Icons.verified_rounded
                                : _kycStatus == 'pending'
                                    ? Icons.hourglass_top_rounded
                                    : Icons.verified_user_rounded,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Text(
                                    'KYC Verification',
                                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13.5),
                                  ),
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: _kycStatus == 'approved'
                                          ? const Color(0xFF064E3B)
                                          : _kycStatus == 'pending'
                                              ? const Color(0xFF78350F)
                                              : const Color(0xFF312E81),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(
                                        color: _kycStatus == 'approved'
                                            ? Colors.greenAccent
                                            : _kycStatus == 'pending'
                                                ? Colors.amber
                                                : const Color(0xFF818CF8),
                                        width: 0.6,
                                      ),
                                    ),
                                    child: Text(
                                      _kycStatus == 'approved'
                                          ? 'Verified'
                                          : _kycStatus == 'pending'
                                              ? 'Pending'
                                              : 'Submit Now',
                                      style: TextStyle(
                                        color: _kycStatus == 'approved'
                                            ? Colors.greenAccent
                                            : _kycStatus == 'pending'
                                                ? Colors.amber
                                                : const Color(0xFFA5B4FC),
                                        fontSize: 9.5,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 2),
                              const Text(
                                'NID, Passport, or Birth Certificate',
                                style: TextStyle(color: AppColors.textMuted, fontSize: 11),
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.chevron_right_rounded, color: Colors.white54, size: 20),
                      ],
                    ),
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
                          _buildGridMenuItem(Icons.account_balance_wallet_rounded, 'Wallet', const Color(0xFFFFB300), onTap: () => _openWalletScreen(initialTabIndex: 0)),
                          _buildGridMenuItem(Icons.payments_rounded, 'Withdraw\nCoins', const Color(0xFF00E676), onTap: _openWithdrawScreen),
                          _buildGridMenuItem(Icons.receipt_long_rounded, 'Deposit\nHistory', const Color(0xFF42A5F5), onTap: () => _openWalletScreen(initialTabIndex: 1)),
                          _buildGridMenuItem(Icons.history_rounded, 'Withdraw\nHistory', const Color(0xFF80D8FF), onTap: _openWithdrawHistoryScreen),
                        ],
                      ),
                      const SizedBox(height: 18),

                      // Row 2
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _buildGridMenuItem(Icons.diamond_rounded, 'Buy Coin', AppColors.neonPink, onTap: () => _openWalletScreen(initialTabIndex: 0)),
                          _buildGridMenuItem(Icons.verified_user_rounded, 'KYC\nVerify', const Color(0xFF00E676), onTap: _openKycScreen),
                          _buildGridMenuItem(Icons.star_rounded, 'My Level', const Color(0xFFFF7043)),
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

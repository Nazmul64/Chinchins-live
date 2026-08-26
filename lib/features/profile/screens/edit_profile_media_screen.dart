import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/models/model_profile.dart';
import '../../../core/services/profile_api_service.dart';
import '../../../core/services/local_image_cache.dart';
import '../../../core/widgets/cached_image_loader.dart';
import '../../../core/widgets/gradient_button.dart';
import '../../auth/services/auth_api_service.dart';
import '../../navigation/screens/main_navigation_screen.dart';

class EditProfileMediaScreen extends StatefulWidget {
  final bool isInitialSetup;
  final ModelProfile? initialProfile;

  const EditProfileMediaScreen({
    super.key,
    this.isInitialSetup = false,
    this.initialProfile,
  });

  @override
  State<EditProfileMediaScreen> createState() => _EditProfileMediaScreenState();
}

class _EditProfileMediaScreenState extends State<EditProfileMediaScreen> {
  final _formKey = GlobalKey<FormState>();
  final ImagePicker _picker = ImagePicker();

  // Profile data
  bool _isLoading = true;
  bool _isSaving = false;
  String? _uploadingSection; // 'avatar', 'cover', 'gallery'

  // Controllers
  late TextEditingController _nicknameController;
  late TextEditingController _introController;
  late TextEditingController _ageController;
  late TextEditingController _cityController;
  late TextEditingController _videoCallRateController;

  String _selectedGender = 'female';
  String _selectedCountry = 'Bangladesh';
  bool _isOnline = true;

  // Local state copies
  String? _avatarUrl;
  String? _coverUrl;
  List<String> _galleryUrls = [];

  @override
  void initState() {
    super.initState();
    _nicknameController = TextEditingController();
    _introController = TextEditingController();
    _ageController = TextEditingController();
    _cityController = TextEditingController();
    _videoCallRateController = TextEditingController();

    _loadInitialData();
  }

  @override
  void dispose() {
    _nicknameController.dispose();
    _introController.dispose();
    _ageController.dispose();
    _cityController.dispose();
    _videoCallRateController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    setState(() => _isLoading = true);

    ModelProfile? profile = widget.initialProfile;

    if (profile == null) {
      final savedUser = await AuthApiService.getSavedUser();
      if (savedUser != null) {
        profile = ModelProfile.fromJson(savedUser);
      }
    }

    final freshProfile = await ProfileApiService.getMyProfile();
    if (freshProfile != null) {
      profile = freshProfile;
    }

    if (profile != null) {
      _nicknameController.text = profile.name;
      _introController.text = profile.intro;
      _ageController.text = profile.age.toString();
      _cityController.text = profile.city ?? '';
      _videoCallRateController.text = profile.pricePerMin.toString();
      _selectedGender = (profile.gender ?? 'female').toLowerCase();
      _selectedCountry = profile.location;
      _isOnline = profile.isOnline;

      _avatarUrl = profile.avatarUrl;
      _coverUrl = profile.coverPhotoUrl;
      _galleryUrls = List<String>.from(profile.galleryUrls);
    } else {
      _ageController.text = '22';
      _videoCallRateController.text = '100';
      _introController.text = 'Hello! Welcome to my live profile ❤️';
    }

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  // --- Avatar Photo Actions ---

  void _showAvatarOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surfaceDark,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
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
              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Text(
                'Profile Photo (Avatar)',
                style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold),
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
            if (_avatarUrl != null && _avatarUrl!.isNotEmpty)
              ListTile(
                leading: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
                title: const Text('Remove Avatar Photo', style: TextStyle(color: Colors.redAccent)),
                onTap: () async {
                  Navigator.pop(ctx);
                  _deleteAvatar();
                },
              ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  Future<void> _uploadAvatarFile(String filePath) async {
    setState(() => _uploadingSection = 'avatar');
    await LocalImageCache.setAvatar(filePath);

    final res = await ProfileApiService.uploadAvatar(filePath);
    if (!mounted) return;
    setState(() => _uploadingSection = null);

    if (res['success'] == true) {
      final user = res['user'];
      if (user != null && user is Map<String, dynamic>) {
        await AuthApiService.saveUser(user);
        final updated = ModelProfile.fromJson(user);
        setState(() {
          _avatarUrl = updated.avatarUrl;
        });
      }
      _showSuccessSnackBar('Avatar updated successfully! ✨');
    } else {
      _showErrorSnackBar(res['message'] ?? 'Failed to upload avatar');
    }
  }

  Future<void> _deleteAvatar() async {
    setState(() => _uploadingSection = 'avatar');
    final res = await ProfileApiService.deleteAvatar();
    if (!mounted) return;
    setState(() => _uploadingSection = null);

    if (res['success'] == true) {
      setState(() {
        _avatarUrl = null;
      });
      _showSuccessSnackBar('Avatar removed.');
    } else {
      _showErrorSnackBar(res['message'] ?? 'Failed to remove avatar');
    }
  }

  // --- Cover Photo Actions ---

  void _showCoverOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surfaceDark,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
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
              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Text(
                'Cover Banner Photo',
                style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold),
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
                  maxWidth: 1920,
                  maxHeight: 1080,
                  imageQuality: 85,
                );
                if (picked != null) _uploadCoverFile(picked.path);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_rounded, color: AppColors.neonPurple),
              title: const Text('Choose from Gallery', style: TextStyle(color: Colors.white)),
              onTap: () async {
                Navigator.pop(ctx);
                final picked = await _picker.pickImage(
                  source: ImageSource.gallery,
                  maxWidth: 1920,
                  maxHeight: 1080,
                  imageQuality: 85,
                );
                if (picked != null) _uploadCoverFile(picked.path);
              },
            ),
            if (_coverUrl != null && _coverUrl!.isNotEmpty)
              ListTile(
                leading: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
                title: const Text('Remove Cover Photo', style: TextStyle(color: Colors.redAccent)),
                onTap: () async {
                  Navigator.pop(ctx);
                  _deleteCover();
                },
              ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  Future<void> _uploadCoverFile(String filePath) async {
    setState(() => _uploadingSection = 'cover');
    await LocalImageCache.setCover(filePath);

    final res = await ProfileApiService.uploadCover(filePath);
    if (!mounted) return;
    setState(() => _uploadingSection = null);

    if (res['success'] == true) {
      final user = res['user'];
      if (user != null && user is Map<String, dynamic>) {
        await AuthApiService.saveUser(user);
        final updated = ModelProfile.fromJson(user);
        setState(() {
          _coverUrl = updated.coverPhotoUrl;
        });
      }
      _showSuccessSnackBar('Cover photo updated! ✨');
    } else {
      _showErrorSnackBar(res['message'] ?? 'Failed to upload cover photo');
    }
  }

  Future<void> _deleteCover() async {
    setState(() => _uploadingSection = 'cover');
    final res = await ProfileApiService.deleteCover();
    if (!mounted) return;
    setState(() => _uploadingSection = null);

    if (res['success'] == true) {
      setState(() {
        _coverUrl = null;
      });
      _showSuccessSnackBar('Cover photo removed.');
    } else {
      _showErrorSnackBar(res['message'] ?? 'Failed to remove cover photo');
    }
  }

  // --- Gallery Photos Actions ---

  Future<void> _pickAndUploadGalleryPhotos({bool multiSelect = true}) async {
    if (multiSelect) {
      final pickedList = await _picker.pickMultiImage(
        maxWidth: 1080,
        maxHeight: 1080,
        imageQuality: 85,
      );
      if (pickedList.isNotEmpty) {
        final paths = pickedList.map((e) => e.path).toList();
        await _uploadGalleryPaths(paths);
      }
    } else {
      final picked = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1080,
        maxHeight: 1080,
        imageQuality: 85,
      );
      if (picked != null) {
        await _uploadGalleryPaths([picked.path]);
      }
    }
  }

  Future<void> _takeCameraPhotoForGallery() async {
    final picked = await _picker.pickImage(
      source: ImageSource.camera,
      maxWidth: 1080,
      maxHeight: 1080,
      imageQuality: 85,
    );
    if (picked != null) {
      await _uploadGalleryPaths([picked.path]);
    }
  }

  Future<void> _uploadGalleryPaths(List<String> paths) async {
    setState(() => _uploadingSection = 'gallery');
    await LocalImageCache.addGallery(paths);

    final res = await ProfileApiService.uploadPhotos(paths);
    if (!mounted) return;
    setState(() => _uploadingSection = null);

    if (res['success'] == true) {
      final user = res['user'];
      if (user != null && user is Map<String, dynamic>) {
        await AuthApiService.saveUser(user);
        final updated = ModelProfile.fromJson(user);
        setState(() {
          _galleryUrls = List<String>.from(updated.galleryUrls);
        });
      } else if (res['gallery_image_urls'] is List) {
        setState(() {
          _galleryUrls = List<String>.from(res['gallery_image_urls']);
        });
      }
      _showSuccessSnackBar('${paths.length} photo(s) added to gallery! 🎉');
    } else {
      _showErrorSnackBar(res['message'] ?? 'Failed to upload gallery photos');
    }
  }

  void _showGalleryAddSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surfaceDark,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
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
              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Text(
                'Add Photos to Gallery',
                style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold),
              ),
            ),
            const Divider(color: AppColors.cardBorder, height: 1),
            ListTile(
              leading: const Icon(Icons.photo_library_rounded, color: AppColors.neonPink),
              title: const Text('Choose Multiple from Gallery', style: TextStyle(color: Colors.white)),
              subtitle: const Text('Select multiple photos at once', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
              onTap: () {
                Navigator.pop(ctx);
                _pickAndUploadGalleryPhotos(multiSelect: true);
              },
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt_rounded, color: AppColors.neonPurple),
              title: const Text('Take a Photo from Camera', style: TextStyle(color: Colors.white)),
              subtitle: const Text('Capture a live moment', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
              onTap: () {
                Navigator.pop(ctx);
                _takeCameraPhotoForGallery();
              },
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  void _showPhotoActionSheet(String photoUrl, int index) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surfaceDark,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
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
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: SizedBox(
                      width: 40,
                      height: 40,
                      child: CachedImageLoader(imageUrl: photoUrl, fit: BoxFit.cover),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Photo #${index + 1} Options',
                    style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
            const Divider(color: AppColors.cardBorder, height: 1),
            ListTile(
              leading: const Icon(Icons.fullscreen_rounded, color: Colors.cyanAccent),
              title: const Text('View Fullscreen', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(ctx);
                _viewFullscreenImage(photoUrl);
              },
            ),
            ListTile(
              leading: const Icon(Icons.sync_rounded, color: AppColors.gemYellow),
              title: const Text('Replace this Photo', style: TextStyle(color: Colors.white)),
              subtitle: const Text('Delete this photo and upload a new one', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
              onTap: () async {
                Navigator.pop(ctx);
                final picked = await _picker.pickImage(
                  source: ImageSource.gallery,
                  maxWidth: 1080,
                  maxHeight: 1080,
                  imageQuality: 85,
                );
                if (picked != null) {
                  await _deleteSinglePhoto(photoUrl, showToast: false);
                  await _uploadGalleryPaths([picked.path]);
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_forever_rounded, color: Colors.redAccent),
              title: const Text('Delete Photo', style: TextStyle(color: Colors.redAccent)),
              onTap: () {
                Navigator.pop(ctx);
                _confirmDeleteSinglePhoto(photoUrl, index);
              },
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  void _confirmDeleteSinglePhoto(String photoUrl, int index) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 22),
            SizedBox(width: 8),
            Text('Delete Photo', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 17)),
          ],
        ),
        content: const Text(
          'Are you sure you want to remove this photo from your gallery?',
          style: TextStyle(color: AppColors.textMuted, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () {
              Navigator.pop(ctx);
              _deleteSinglePhoto(photoUrl);
            },
            child: const Text('Delete', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteSinglePhoto(String photoUrl, {bool showToast = true}) async {
    setState(() => _uploadingSection = 'gallery');
    final res = await ProfileApiService.deletePhoto(photoUrl);
    if (!mounted) return;
    setState(() => _uploadingSection = null);

    if (res['success'] == true) {
      setState(() {
        _galleryUrls.remove(photoUrl);
      });
      // Refresh user profile
      final fresh = await ProfileApiService.getMyProfile();
      if (fresh != null && mounted) {
        setState(() {
          _galleryUrls = List<String>.from(fresh.galleryUrls);
        });
      }
      if (showToast) _showSuccessSnackBar('Photo deleted successfully.');
    } else {
      if (showToast) _showErrorSnackBar(res['message'] ?? 'Failed to delete photo');
    }
  }

  void _confirmClearAllGallery() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.orangeAccent, size: 22),
            SizedBox(width: 8),
            Text('Clear All Gallery', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 17)),
          ],
        ),
        content: const Text(
          'Are you sure you want to delete ALL photos from your gallery? This cannot be undone.',
          style: TextStyle(color: AppColors.textMuted, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              setState(() => _uploadingSection = 'gallery');
              final res = await ProfileApiService.clearGallery();
              if (!mounted) return;
              setState(() => _uploadingSection = null);

              if (res['success'] == true) {
                setState(() {
                  _galleryUrls.clear();
                });
                _showSuccessSnackBar('All gallery photos cleared.');
              } else {
                _showErrorSnackBar(res['message'] ?? 'Failed to clear gallery');
              }
            },
            child: const Text('Clear All', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _viewFullscreenImage(String photoUrl) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (ctx) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            iconTheme: const IconThemeData(color: Colors.white),
            title: const Text('Photo Preview', style: TextStyle(color: Colors.white, fontSize: 16)),
            actions: [
              IconButton(
                icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
                onPressed: () {
                  Navigator.pop(ctx);
                  _confirmDeleteSinglePhoto(photoUrl, _galleryUrls.indexOf(photoUrl));
                },
              ),
            ],
          ),
          body: Center(
            child: InteractiveViewer(
              panEnabled: true,
              boundaryMargin: const EdgeInsets.all(20),
              minScale: 0.8,
              maxScale: 4.0,
              child: CachedImageLoader(
                imageUrl: photoUrl,
                fit: BoxFit.contain,
              ),
            ),
          ),
        ),
      ),
    );
  }

  // --- Save Profile Changes ---

  Future<void> _handleSaveAndFinish() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    final ageInt = int.tryParse(_ageController.text.trim()) ?? 22;
    final rateInt = int.tryParse(_videoCallRateController.text.trim()) ?? 100;

    final res = await ProfileApiService.updateProfile(
      nickname: _nicknameController.text.trim(),
      introduction: _introController.text.trim(),
      gender: _selectedGender,
      age: ageInt,
      country: _selectedCountry,
      city: _cityController.text.trim().isNotEmpty ? _cityController.text.trim() : null,
      videoCallRate: rateInt,
      isActive: _isOnline,
    );

    if (!mounted) return;
    setState(() => _isSaving = false);

    if (res['success'] == true) {
      if (res['user'] != null && res['user'] is Map<String, dynamic>) {
        await AuthApiService.saveUser(res['user']);
      }
      _showSuccessSnackBar('Profile & Media saved successfully! 🎉');

      if (!mounted) return;
      if (widget.isInitialSetup) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const MainNavigationScreen()),
          (route) => false,
        );
      } else {
        Navigator.pop(context, true);
      }
    } else {
      _showErrorSnackBar(res['message'] ?? 'Failed to update profile');
    }
  }

  void _handleSkip() {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const MainNavigationScreen()),
      (route) => false,
    );
  }

  void _showSuccessSnackBar(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: const Color(0xFF1B3828),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: AppColors.onlineGreen),
        ),
        content: Row(
          children: [
            const Icon(Icons.check_circle_rounded, color: AppColors.onlineGreen, size: 20),
            const SizedBox(width: 10),
            Expanded(child: Text(msg, style: const TextStyle(color: Colors.white, fontSize: 13))),
          ],
        ),
      ),
    );
  }

  void _showErrorSnackBar(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: const Color(0xFF381B20),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 4),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: AppColors.badgePink),
        ),
        content: Row(
          children: [
            const Icon(Icons.error_outline_rounded, color: AppColors.badgePink, size: 20),
            const SizedBox(width: 10),
            Expanded(child: Text(msg, style: const TextStyle(color: Colors.white, fontSize: 13))),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: AppColors.backgroundDark,
        body: Center(
          child: CircularProgressIndicator(color: AppColors.neonPink),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      appBar: AppBar(
        backgroundColor: AppColors.surfaceDark,
        elevation: 0,
        centerTitle: true,
        leading: widget.isInitialSetup
            ? null
            : IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
                onPressed: () => Navigator.pop(context),
              ),
        title: Text(
          widget.isInitialSetup ? 'Complete Your Profile' : 'Edit Profile & Photos',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          if (widget.isInitialSetup)
            TextButton(
              onPressed: _handleSkip,
              child: const Text(
                'Skip',
                style: TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            )
          else
            TextButton(
              onPressed: _isSaving ? null : _handleSaveAndFinish,
              child: _isSaving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.neonPink),
                    )
                  : const Text(
                      'Save',
                      style: TextStyle(
                        color: AppColors.neonPink,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.only(bottom: 120),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Cover and Avatar Photo Header
              _buildCoverAndAvatarSection(),

              const SizedBox(height: 24),

              // 2. Photo Gallery Section (Add, Edit, Replace, Delete Photos)
              _buildGallerySection(),

              const SizedBox(height: 24),

              // 3. Profile Information Form Fields
              _buildProfileDetailsSection(),

              const SizedBox(height: 32),

              // 4. Action Save Button
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: GradientButton(
                  text: widget.isInitialSetup ? 'Complete & Start Exploring 🎉' : 'Save Changes',
                  customChild: _isSaving
                      ? const Center(
                          child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          ),
                        )
                      : null,
                  onTap: _isSaving ? null : _handleSaveAndFinish,
                ),
              ),
              if (widget.isInitialSetup) ...[
                const SizedBox(height: 12),
                Center(
                  child: TextButton(
                    onPressed: _handleSkip,
                    child: const Text(
                      'I will upload photos later',
                      style: TextStyle(color: AppColors.textMuted, fontSize: 13),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // --- Section 1: Cover and Avatar Photo ---

  Widget _buildCoverAndAvatarSection() {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        // Cover Photo Container
        GestureDetector(
          onTap: _showCoverOptions,
          child: Container(
            height: 180,
            width: double.infinity,
            decoration: const BoxDecoration(
              color: AppColors.cardDark,
              border: Border(bottom: BorderSide(color: AppColors.cardBorder)),
            ),
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (_coverUrl != null && _coverUrl!.isNotEmpty)
                  CachedImageLoader(
                    imageUrl: _coverUrl!,
                    fit: BoxFit.cover,
                  )
                else
                  Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xFF2E1B4E), Color(0xFF1B1B3A)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: const Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.add_photo_alternate_rounded, color: Colors.white38, size: 38),
                          SizedBox(height: 6),
                          Text('Tap to add Cover Banner', style: TextStyle(color: Colors.white54, fontSize: 13)),
                        ],
                      ),
                    ),
                  ),

                // Gradient Overlay
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.transparent, Colors.black.withValues(alpha: 0.6)],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                ),

                // Cover edit button badge
                Positioned(
                  right: 14,
                  bottom: 14,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.65),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white24),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_uploadingSection == 'cover')
                          const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        else
                          const Icon(Icons.camera_alt_rounded, color: Colors.white, size: 15),
                        const SizedBox(width: 6),
                        Text(
                          _coverUrl != null && _coverUrl!.isNotEmpty ? 'Change Cover' : 'Add Cover',
                          style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        // Avatar Overlay
        Positioned(
          left: 20,
          bottom: -40,
          child: GestureDetector(
            onTap: _showAvatarOptions,
            child: Stack(
              children: [
                Container(
                  width: 90,
                  height: 90,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      colors: [AppColors.neonPink, AppColors.neonPurple],
                    ),
                    border: Border.all(color: AppColors.backgroundDark, width: 3),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.neonPink.withValues(alpha: 0.35),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ClipOval(
                    child: _avatarUrl != null && _avatarUrl!.isNotEmpty
                        ? CachedImageLoader(
                            imageUrl: _avatarUrl!,
                            fit: BoxFit.cover,
                          )
                        : Container(
                            color: AppColors.cardDark,
                            child: const Icon(Icons.person_rounded, color: Colors.white54, size: 48),
                          ),
                  ),
                ),

                // Camera badge icon on avatar
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    padding: const EdgeInsets.all(7),
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [AppColors.neonPink, Color(0xFFFF4081)],
                      ),
                      boxShadow: [
                        BoxShadow(color: Colors.black45, blurRadius: 4),
                      ],
                    ),
                    child: _uploadingSection == 'avatar'
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.camera_alt_rounded, color: Colors.white, size: 15),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // --- Section 2: Photo Gallery Manager (Add, Edit, Delete, Reorder) ---

  Widget _buildGallerySection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: AppColors.surfaceDark,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.cardBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Gallery Header with Actions
            Row(
              children: [
                Expanded(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.photo_library_rounded, color: AppColors.neonPink, size: 18),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          'Gallery (${_galleryUrls.length})',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                if (_galleryUrls.isNotEmpty) ...[
                  TextButton.icon(
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    onPressed: _confirmClearAllGallery,
                    icon: const Icon(Icons.delete_sweep_rounded, color: Colors.redAccent, size: 15),
                    label: const Text(
                      'Clear',
                      style: TextStyle(color: Colors.redAccent, fontSize: 11, fontWeight: FontWeight.w600),
                    ),
                  ),
                  const SizedBox(width: 4),
                ],
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.neonPurple,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    minimumSize: Size.zero,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    elevation: 0,
                  ),
                  onPressed: _showGalleryAddSheet,
                  icon: const Icon(Icons.add_photo_alternate_rounded, color: Colors.white, size: 14),
                  label: const Text(
                    '+ Add',
                    style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 6),
            const Text(
              'Showcase your best moments! Tap any photo to edit, preview fullscreen, or remove.',
              style: TextStyle(color: AppColors.textMuted, fontSize: 12),
            ),

            const SizedBox(height: 16),

            // Loading overlay for gallery operations
            if (_uploadingSection == 'gallery')
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.neonPink.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.neonPink.withValues(alpha: 0.3)),
                ),
                child: const Row(
                  children: [
                    SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.neonPink)),
                    SizedBox(width: 12),
                    Text('Syncing gallery with server...', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500)),
                  ],
                ),
              ),

            // Gallery Grid
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _galleryUrls.length + 1,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                childAspectRatio: 0.85,
              ),
              itemBuilder: (context, index) {
                // Last item is always the Add Button
                if (index == _galleryUrls.length) {
                  return GestureDetector(
                    onTap: _showGalleryAddSheet,
                    child: Container(
                      decoration: BoxDecoration(
                        color: AppColors.cardDark,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: AppColors.neonPink.withValues(alpha: 0.5),
                          style: BorderStyle.solid,
                          width: 1.5,
                        ),
                      ),
                      child: const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.add_circle_outline_rounded, color: AppColors.neonPink, size: 30),
                          SizedBox(height: 6),
                          Text(
                            'Add Photo',
                            style: TextStyle(color: AppColors.neonPink, fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                final photoUrl = _galleryUrls[index];

                return Stack(
                  children: [
                    // Photo Card
                    GestureDetector(
                      onTap: () => _showPhotoActionSheet(photoUrl, index),
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppColors.cardBorder),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.3),
                              blurRadius: 4,
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(13),
                          child: CachedImageLoader(
                            imageUrl: photoUrl,
                            fit: BoxFit.cover,
                            width: double.infinity,
                            height: double.infinity,
                          ),
                        ),
                      ),
                    ),

                    // Photo Number Badge (#1, #2, ...)
                    Positioned(
                      left: 6,
                      top: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.65),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.white24, width: 0.5),
                        ),
                        child: Text(
                          '#${index + 1}',
                          style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),

                    // Delete button in top right
                    Positioned(
                      right: 4,
                      top: 4,
                      child: GestureDetector(
                        onTap: () => _confirmDeleteSinglePhoto(photoUrl, index),
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            color: Colors.black87,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.close_rounded, color: Colors.redAccent, size: 14),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  // --- Section 3: Profile Details Form ---

  Widget _buildProfileDetailsSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.surfaceDark,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.cardBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.badge_rounded, color: AppColors.neonPurple, size: 20),
                SizedBox(width: 8),
                Text(
                  'Profile Information',
                  style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),

            const SizedBox(height: 18),

            // Nickname / Display Name
            _buildInputField(
              controller: _nicknameController,
              label: 'Display Name / Nickname',
              hint: 'e.g. Sadia Queen 👑',
              icon: Icons.person_outline_rounded,
              validator: (val) {
                if (val == null || val.trim().isEmpty) return 'Please enter your display name';
                return null;
              },
            ),

            const SizedBox(height: 16),

            // Introduction / Bio
            _buildInputField(
              controller: _introController,
              label: 'Bio / Introduction',
              hint: 'Say something awesome about yourself...',
              icon: Icons.edit_note_rounded,
              maxLines: 3,
            ),

            const SizedBox(height: 16),

            // Gender & Age Row
            Row(
              children: [
                // Gender Selection
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Gender', style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: AppColors.cardDark,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppColors.cardBorder),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _selectedGender,
                            dropdownColor: AppColors.surfaceDark,
                            isExpanded: true,
                            icon: const Icon(Icons.arrow_drop_down_rounded, color: Colors.white70),
                            items: const [
                              DropdownMenuItem(value: 'female', child: Text('👩 Female', style: TextStyle(color: Colors.white))),
                              DropdownMenuItem(value: 'male', child: Text('👨 Male', style: TextStyle(color: Colors.white))),
                              DropdownMenuItem(value: 'other', child: Text('✨ Other', style: TextStyle(color: Colors.white))),
                            ],
                            onChanged: (val) {
                              if (val != null) setState(() => _selectedGender = val);
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 14),

                // Age
                Expanded(
                  child: _buildInputField(
                    controller: _ageController,
                    label: 'Age',
                    hint: '22',
                    icon: Icons.cake_outlined,
                    keyboardType: TextInputType.number,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // City & Country Row
            Row(
              children: [
                // City
                Expanded(
                  child: _buildInputField(
                    controller: _cityController,
                    label: 'City',
                    hint: 'e.g. Dhaka',
                    icon: Icons.location_city_rounded,
                  ),
                ),
                const SizedBox(width: 14),

                // Video Call Rate
                Expanded(
                  child: _buildInputField(
                    controller: _videoCallRateController,
                    label: 'Call Rate (Gems/m)',
                    hint: '100',
                    icon: Icons.videocam_rounded,
                    keyboardType: TextInputType.number,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Online Availability Toggle
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.cardDark,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.cardBorder),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Icon(
                          _isOnline ? Icons.circle : Icons.circle_outlined,
                          color: _isOnline ? AppColors.onlineGreen : AppColors.textMuted,
                          size: 13,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _isOnline ? 'Online & Available for Calls' : 'Offline / Hidden',
                            style: TextStyle(
                              color: _isOnline ? Colors.white : AppColors.textMuted,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Switch.adaptive(
                    value: _isOnline,
                    activeTrackColor: AppColors.onlineGreen,
                    onChanged: (val) {
                      setState(() => _isOnline = val);
                      ProfileApiService.toggleOnlineStatus(val);
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    int maxLines = 1,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          maxLines: maxLines,
          keyboardType: keyboardType,
          validator: validator,
          style: const TextStyle(color: Colors.white, fontSize: 14),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 13),
            prefixIcon: Icon(icon, color: AppColors.textMuted, size: 18),
            filled: true,
            fillColor: AppColors.cardDark,
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: AppColors.cardBorder),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: AppColors.cardBorder),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: AppColors.neonPink, width: 1.5),
            ),
          ),
        ),
      ],
    );
  }
}

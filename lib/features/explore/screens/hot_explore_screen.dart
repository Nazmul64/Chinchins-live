import 'package:flutter/material.dart';
import '../../../core/models/model_profile.dart';
import '../../../core/services/profile_api_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../auth/services/auth_api_service.dart';
import '../widgets/explore_header.dart';
import '../widgets/model_grid_card.dart';
import '../../profile/screens/host_profile_screen.dart';
import '../../call/screens/video_call_screen.dart';
import '../../call/screens/incoming_call_screen.dart';
import '../../call/screens/random_match_screen.dart';
import '../../call/services/call_api_service.dart';
import '../../party/screens/party_rooms_screen.dart';
import '../../party/screens/create_room_screen.dart';
import '../../wallet/widgets/recharge_gems_sheet.dart';

class HotExploreScreen extends StatefulWidget {
  const HotExploreScreen({super.key});

  @override
  State<HotExploreScreen> createState() => _HotExploreScreenState();
}

class _HotExploreScreenState extends State<HotExploreScreen> {
  int _selectedTabIndex = 0;
  List<ModelProfile> _models = [];
  String _selectedLanguage = 'All';
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    // 1. Instantly show saved local user if logged in
    final savedUser = await AuthApiService.getSavedUser();
    if (savedUser != null && mounted) {
      final p = ModelProfile.fromJson(savedUser);
      if (p.name.trim().toLowerCase() != 'admin' &&
          !p.name.trim().toLowerCase().contains('admin') &&
          p.name.trim().toLowerCase() != 'ayeena04') {
        setState(() {
          _models = [p];
        });
      }
    }
    // 2. Fetch fresh live database users
    await _loadHomeFeed();
  }

  Future<void> _loadHomeFeed() async {
    setState(() => _isLoading = true);
    try {
      // 1. Get logged in user profile
      ModelProfile? myProfile;
      final savedUser = await AuthApiService.getSavedUser();
      if (savedUser != null) {
        myProfile = ModelProfile.fromJson(savedUser);
      }
      final freshMyProfile = await ProfileApiService.getMyProfile();
      if (freshMyProfile != null) {
        myProfile = freshMyProfile;
      }

      // 2. Fetch live users from Laravel REST API
      final liveFeed = await ProfileApiService.getHomeFeed(
        country: _selectedLanguage != 'All' ? _selectedLanguage : null,
      );

      bool isExcludedUser(ModelProfile profile) {
        final name = profile.name.trim().toLowerCase();
        final firstName = (profile.firstName ?? '').trim().toLowerCase();
        final lastName = (profile.lastName ?? '').trim().toLowerCase();
        final email = (profile.email ?? '').trim().toLowerCase();

        return name == 'admin' ||
            name.contains('administrator') ||
            name == 'ayeena04' ||
            name == 'ayeena' ||
            firstName == 'admin' ||
            lastName == 'admin' ||
            email.startsWith('admin@') ||
            email.contains('admin@');
      }

      final List<ModelProfile> combined = [];
      // If user is logged in, show user at the top with Active status!
      if (myProfile != null && !isExcludedUser(myProfile)) {
        combined.add(myProfile);
      }

      for (final user in liveFeed) {
        if (isExcludedUser(user)) continue;
        if (myProfile != null && user.id == myProfile.id) {
          continue; // avoid duplicate
        }
        combined.add(user);
      }

      if (mounted) {
        setState(() {
          _models = combined;
        });
      }
    } catch (_) {}
    if (mounted) setState(() => _isLoading = false);
  }

  void _onTabSelected(int index) {
    if (index == 2 || index == 3) {
      // 2: Match 🔥, 3: Video Call 📹
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const RandomMatchScreen(),
        ),
      );
      return;
    }
    setState(() {
      _selectedTabIndex = index;
    });
  }

  void _openHostProfile(ModelProfile model) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => HostProfileScreen(model: model),
      ),
    );
  }

  Future<void> _startVideoCall(ModelProfile model) async {
    // Show quick progress dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Center(
        child: Card(
          color: Color(0xFF1E1830),
          child: Padding(
            padding: EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(color: AppColors.neonPink),
                SizedBox(height: 14),
                Text(
                  'Connecting Video Call...',
                  style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    try {
      final res = await CallApiService.initiateCall(
        receiverId: model.id,
        callType: 'video',
      );

      if (!mounted) return;
      Navigator.pop(context); // Close progress dialog

      if (res['success'] == true) {
        final callId = res['call_id'] is int
            ? res['call_id'] as int
            : int.tryParse(res['call_id']?.toString() ?? '1') ?? 1;
        final isFreeTrial = res['is_free_trial'] == true;
        final freeSecs = (res['free_duration_seconds'] is int) ? res['free_duration_seconds'] as int : 10;

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => VideoCallScreen(
              model: model,
              callId: callId,
              isFreeTrial: isFreeTrial,
              freeDurationSeconds: freeSecs,
            ),
          ),
        );
      } else if (res['is_low_balance'] == true || res['code'] == 'LOW_BALANCE_DEPOSIT_REQUIRED') {
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (context) => RechargeGemsSheet(
            onRechargeSuccess: () {
              _startVideoCall(model);
            },
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(res['message'] ?? 'Could not initiate call.'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Call error: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  void _simulateIncomingCall() {
    final caller = _models.firstWhere(
      (m) => m.name.contains('Nosimon') || m.name.contains('sexy'),
      orElse: () => _models.first,
    );

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => IncomingCallScreen(model: caller),
      ),
    );
  }

  void _showSayHelloDialog() {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: AppColors.cardDarkElevated,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: AppColors.orangeGradient,
                ),
                child: const Icon(Icons.waving_hand_rounded, color: Colors.white, size: 30),
              ),
              const SizedBox(height: 16),
              const Text(
                'Say Hello to Online Hosts!',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Send an instant wave to 5 available hosts in your area to start chatting.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel', style: TextStyle(color: AppColors.textMuted)),
                    ),
                  ),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.warmOrange,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      ),
                      onPressed: () {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('✨ Greetings sent to 5 online hosts!'),
                            backgroundColor: AppColors.neonPurple,
                          ),
                        );
                      },
                      child: const Text('Say Hello', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showLanguageSelector() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.cardDarkElevated,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        final languages = ['All', 'Bengali', 'English', 'Hindi', 'Spanish'];
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
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
              const Text(
                'Select Language Region',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              ...languages.map((lang) {
                final isSelected = _selectedLanguage == lang;
                return ListTile(
                  title: Text(
                    lang,
                    style: TextStyle(
                      color: isSelected ? AppColors.neonPink : Colors.white,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                  trailing: isSelected
                      ? const Icon(Icons.check_circle, color: AppColors.neonPink)
                      : null,
                  onTap: () {
                    setState(() {
                      _selectedLanguage = lang;
                    });
                    Navigator.pop(context);
                    _loadHomeFeed();
                  },
                );
              }),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      body: SafeArea(
        child: Column(
          children: [
            // Top App Bar matching Screenshot 1
            ExploreHeader(
              selectedTabIndex: _selectedTabIndex,
              onTabSelected: _onTabSelected,
              onSearchTap: _simulateIncomingCall,
              onLanguageTap: _showLanguageSelector,
              onSayHelloTap: _showSayHelloDialog,
            ),

            // Body Content based on Tab
            Expanded(
              child: _selectedTabIndex == 1
                  ? const PartyRoomsScreen()
                  : _isLoading && _models.isEmpty
                      ? const Center(
                          child: CircularProgressIndicator(color: AppColors.neonPink),
                        )
                      : _models.isEmpty
                          ? RefreshIndicator(
                              color: AppColors.neonPink,
                              backgroundColor: AppColors.cardDark,
                              onRefresh: _loadHomeFeed,
                              child: ListView(
                                physics: const AlwaysScrollableScrollPhysics(),
                                children: [
                                  SizedBox(height: MediaQuery.of(context).size.height * 0.25),
                                  const Center(
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.wifi_tethering_off_rounded, color: AppColors.textMuted, size: 54),
                                        SizedBox(height: 14),
                                        Text(
                                          'No Live Streamers Online',
                                          style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold),
                                        ),
                                        SizedBox(height: 6),
                                        Text(
                                          'Pull down to refresh or check back soon',
                                          style: TextStyle(color: AppColors.textMuted, fontSize: 12),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : RefreshIndicator(
                              color: AppColors.neonPink,
                              backgroundColor: AppColors.cardDark,
                              onRefresh: () async {
                                await _loadHomeFeed();
                              },
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                child: GridView.builder(
                                  itemCount: _models.length,
                                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: 2,
                                    childAspectRatio: 0.72,
                                    crossAxisSpacing: 10,
                                    mainAxisSpacing: 10,
                                  ),
                                  itemBuilder: (context, index) {
                                    final model = _models[index];
                                    return ModelGridCard(
                                      model: model,
                                      onTap: () => _openHostProfile(model),
                                      onVideoCallTap: () => _startVideoCall(model),
                                    );
                                  },
                                ),
                              ),
                            ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            builder: (context) => const CreateRoomScreen(),
          );
        },
        backgroundColor: AppColors.neonPink,
        elevation: 8,
        icon: const Icon(Icons.mic_external_on_rounded, color: Colors.white),
        label: const Text(
          'Host Room',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}

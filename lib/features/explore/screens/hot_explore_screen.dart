import 'package:flutter/material.dart';
import '../../../core/models/model_profile.dart';
import '../../../core/services/profile_api_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../auth/services/auth_api_service.dart';
import '../widgets/explore_header.dart';
import '../widgets/model_grid_card.dart';
import '../widgets/match_tab_view.dart';
import '../widgets/draggable_extra_gems_widget.dart';
import '../../profile/screens/host_profile_screen.dart';
import '../../call/screens/video_call_screen.dart';
import '../../call/screens/random_match_screen.dart';
import '../../call/services/call_api_service.dart';
import '../../call/widgets/home_webrtc_test_dialog.dart';

class HotExploreScreen extends StatefulWidget {
  const HotExploreScreen({super.key});

  @override
  State<HotExploreScreen> createState() => _HotExploreScreenState();
}

class _HotExploreScreenState extends State<HotExploreScreen> {
  static List<ModelProfile> _cachedHomeFeed = [];
  int _selectedTabIndex = 0;
  List<ModelProfile> _models = _cachedHomeFeed;
  String _selectedCountryCode = 'BGD';
  String _selectedCountryName = 'Bangladesh';
  String _searchQuery = '';
  bool _isLoading = _cachedHomeFeed.isEmpty;

  @override
  void initState() {
    super.initState();
    _loadHomeFeed();
  }

  Future<void> _loadHomeFeed() async {
    if (_models.isEmpty) {
      setState(() => _isLoading = true);
    }
    try {
      // Fetch user profile and home feed in parallel for maximum speed
      final results = await Future.wait([
        AuthApiService.getSavedUser(),
        ProfileApiService.getMyProfile().catchError((_) => null),
        ProfileApiService.getHomeFeed(
          country: _selectedCountryName != 'All' ? _selectedCountryName : null,
        ),
      ]);

      final savedUser = results[0] as Map<String, dynamic>?;
      final freshMyProfile = results[1] as ModelProfile?;
      final liveFeed = results[2] as List<ModelProfile>;

      ModelProfile? myProfile;
      if (savedUser != null) {
        myProfile = ModelProfile.fromJson(savedUser);
      }
      if (freshMyProfile != null) {
        myProfile = freshMyProfile;
      }

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

      for (final user in liveFeed) {
        if (isExcludedUser(user)) continue;
        if (myProfile != null && (user.id == myProfile.id || (user.accountId.isNotEmpty && user.accountId == myProfile.accountId))) {
          continue; // exclude own profile from explore feed
        }
        combined.add(user);
      }

      // If search query is present, query backend search API
      if (_searchQuery.trim().isNotEmpty) {
        final searchedUsers = await ProfileApiService.searchUsers(query: _searchQuery.trim());
        if (searchedUsers.isNotEmpty) {
          for (final u in searchedUsers) {
            if (!combined.any((m) => m.id == u.id || (m.accountId.isNotEmpty && m.accountId == u.accountId))) {
              combined.add(u);
            }
          }
        }
      }

      // Filter by Tab: If Match tab (index 1), only show online users!
      List<ModelProfile> filtered = combined;
      if (_selectedTabIndex == 1) {
        filtered = filtered.where((m) => m.isOnline).toList();
      }

      // Filter by search query if present (Name, Location, 8-digit Account ID)
      if (_searchQuery.trim().isNotEmpty) {
        final q = _searchQuery.trim().toLowerCase();
        filtered = filtered.where((m) =>
          m.name.toLowerCase().contains(q) ||
          m.fullName.toLowerCase().contains(q) ||
          m.location.toLowerCase().contains(q) ||
          m.accountId.toLowerCase().contains(q) ||
          m.effectiveAccountId.toLowerCase().contains(q) ||
          m.id.toLowerCase().contains(q)
        ).toList();
      }

      if (filtered.isNotEmpty) {
        _cachedHomeFeed = filtered;
      }
      if (mounted) {
        setState(() {
          _models = filtered;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading home feed: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _onTabSelected(int index) {
    if (_selectedTabIndex != index) {
      setState(() {
        _selectedTabIndex = index;
      });
      _loadHomeFeed();
    }
  }

  void _showCountrySelector() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.cardDarkElevated,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        final countries = [
          {'code': 'BGD', 'name': 'Bangladesh 🇧🇩', 'value': 'Bangladesh'},
          {'code': 'IND', 'name': 'India 🇮🇳', 'value': 'India'},
          {'code': 'USA', 'name': 'United States 🇺🇸', 'value': 'USA'},
          {'code': 'ALL', 'name': 'Global 🌍', 'value': 'All'},
        ];
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
                'Select Region / Country',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              ...countries.map((c) {
                final isSelected = _selectedCountryCode == c['code'];
                return ListTile(
                  title: Text(
                    c['name']!,
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
                      _selectedCountryCode = c['code']!;
                      _selectedCountryName = c['value']!;
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

  void _showSearchDialog() {
    showDialog(
      context: context,
      builder: (context) {
        String tempSearch = _searchQuery;
        return AlertDialog(
          backgroundColor: AppColors.cardDarkElevated,
          title: const Text('Search Streamers', style: TextStyle(color: Colors.white, fontSize: 18)),
          content: TextField(
            autofocus: true,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Enter name or ID...',
              hintStyle: const TextStyle(color: Colors.white54),
              filled: true,
              fillColor: Colors.black26,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
            onChanged: (val) => tempSearch = val,
          ),
          actions: [
            TextButton(
              onPressed: () {
                setState(() => _searchQuery = '');
                Navigator.pop(context);
                _loadHomeFeed();
              },
              child: const Text('Clear', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.neonPink),
              onPressed: () {
                setState(() => _searchQuery = tempSearch);
                Navigator.pop(context);
                _loadHomeFeed();
              },
              child: const Text('Search', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
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
    final savedUser = await AuthApiService.getSavedUser();
    final myId = savedUser?['id']?.toString() ?? savedUser?['user_id']?.toString();
    final myAccountId = savedUser?['account_id']?.toString();

    if (!mounted) return;
    if ((myId != null && (myId == model.id || myId == model.accountId)) ||
        (myAccountId != null && (myAccountId == model.accountId || myAccountId == model.id))) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You cannot call your own profile! Please choose another user to call.'),
          backgroundColor: Colors.orangeAccent,
        ),
      );
      return;
    }

    // Show connecting loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: Card(
          color: Color(0xFF1E1B2E),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(color: Colors.pinkAccent),
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
      final initiateRes = await CallApiService.initiateCall(
        receiverId: model.id,
        receiverAccountId: model.accountId,
        callType: 'video',
      );

      if (!mounted) return;
      Navigator.pop(context); // close progress dialog

      if (initiateRes['success'] == true) {
        final dynamic rawCallId = initiateRes['call_id'] ?? initiateRes['id'];
        final int? callId = rawCallId is int
            ? rawCallId
            : int.tryParse(rawCallId?.toString() ?? '');
        final channelName = initiateRes['channel_name']?.toString();
        final isFreeTrial = initiateRes['is_free_trial'] == true;
        final freeSecs = (initiateRes['free_duration_seconds'] is int)
            ? initiateRes['free_duration_seconds'] as int
            : 10;
        final ratePerMin = (initiateRes['rate_per_minute'] is int)
            ? initiateRes['rate_per_minute'] as int
            : (model.pricePerMin > 0 ? model.pricePerMin : 100);

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => VideoCallScreen(
              model: model,
              callId: callId,
              channelName: channelName,
              isFreeTrial: isFreeTrial,
              freeDurationSeconds: freeSecs,
              ratePerMinute: ratePerMin,
              isIncoming: false,
            ),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(initiateRes['message']?.toString() ?? 'Could not initiate call'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Call connection error: $e'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                // Top App Bar with Hot, Match, Search & Country Pill
                ExploreHeader(
                  selectedTabIndex: _selectedTabIndex,
                  onTabSelected: _onTabSelected,
                  onSearchTap: _showSearchDialog,
                  onCountryTap: _showCountrySelector,
                  onDebugTap: () => HomeWebRTCTestDialog.show(context),
                  selectedCountryCode: _selectedCountryCode,
                ),

                // User Cards 2-Column Grid OR Match Tab View
                Expanded(
                  child: _selectedTabIndex == 1
                      ? MatchTabView(
                          onStartMatching: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const RandomMatchScreen(),
                              ),
                            );
                          },
                        )
                      : (_isLoading && _models.isEmpty
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
                                              'No Streamers Found',
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
                                  onRefresh: _loadHomeFeed,
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                    child: GridView.builder(
                                      itemCount: _models.length,
                                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                        crossAxisCount: 2,
                                        childAspectRatio: 0.68, // Exact portrait proportion
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
                                )),
                ),
              ],
            ),

            // Draggable Floating Extra Gems Icon (Tap to open Premium VIP)
            if (_selectedTabIndex == 0)
              const DraggableExtraGemsWidget(
                initialPosition: Offset(12, 420),
              ),
          ],
        ),
      ),
    );
  }
}

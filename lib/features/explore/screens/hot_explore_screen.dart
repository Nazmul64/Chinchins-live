import 'package:flutter/material.dart';
import '../../../core/models/model_profile.dart';
import '../../../core/services/profile_api_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../auth/services/auth_api_service.dart';
import '../widgets/explore_header.dart';
import '../widgets/model_grid_card.dart';
import '../widgets/match_tab_view.dart';
import '../../profile/screens/host_profile_screen.dart';
import '../../call/screens/video_call_screen.dart';
import '../../call/screens/random_match_screen.dart';
import '../../call/services/call_api_service.dart';

class HotExploreScreen extends StatefulWidget {
  const HotExploreScreen({super.key});

  @override
  State<HotExploreScreen> createState() => _HotExploreScreenState();
}

class _HotExploreScreenState extends State<HotExploreScreen> {
  int _selectedTabIndex = 0;
  List<ModelProfile> _models = [];
  String _selectedCountryCode = 'BGD';
  String _selectedCountryName = 'Bangladesh';
  String _searchQuery = '';
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
        country: _selectedCountryName != 'All' ? _selectedCountryName : null,
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

      // Filter by Tab: If Match tab (index 1), only show online users!
      List<ModelProfile> filtered = combined;
      if (_selectedTabIndex == 1) {
        filtered = filtered.where((m) => m.isOnline).toList();
      }

      // Filter by search query if present
      if (_searchQuery.trim().isNotEmpty) {
        final q = _searchQuery.trim().toLowerCase();
        filtered = filtered.where((m) =>
          m.name.toLowerCase().contains(q) ||
          m.location.toLowerCase().contains(q) ||
          m.accountId.contains(q)
        ).toList();
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
    final targetUserId = int.tryParse(model.id) ?? int.tryParse(model.accountId) ?? 2;

    try {
      final initiateRes = await CallApiService.initiateCall(
        receiverId: targetUserId,
        callType: 'video',
      );

      final callData = (initiateRes['data'] is Map)
          ? initiateRes['data']
          : (initiateRes['call'] is Map ? initiateRes['call'] : initiateRes);

      final callId = callData['call_id'] ?? callData['id'] ?? DateTime.now().millisecondsSinceEpoch;
      final channelName = callData['channel_name'] ?? 'call_room_${callId}_$targetUserId';

      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => VideoCallScreen(
            model: model,
            callId: callId,
            channelName: channelName,
            isFreeTrial: callData?['is_free_trial'] == true,
            freeDurationSeconds: callData?['free_duration_seconds'] ?? 10,
            ratePerMinute: model.pricePerMin,
            isIncoming: false,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => VideoCallScreen(
            model: model,
            callId: DateTime.now().millisecondsSinceEpoch,
            channelName: 'call_room_fallback_$targetUserId',
            isFreeTrial: false,
            freeDurationSeconds: 10,
            ratePerMinute: model.pricePerMin,
            isIncoming: false,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      body: SafeArea(
        child: Column(
          children: [
            // Top App Bar with Hot, Match, Search & Country Pill
            ExploreHeader(
              selectedTabIndex: _selectedTabIndex,
              onTabSelected: _onTabSelected,
              onSearchTap: _showSearchDialog,
              onCountryTap: _showCountrySelector,
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
      ),
    );
  }
}

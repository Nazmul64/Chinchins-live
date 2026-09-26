import 'package:flutter/material.dart';
import '../../../core/models/model_profile.dart';
import '../../../core/services/hive_cache_service.dart';
import '../../../core/services/profile_api_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/livu_empty_state_card.dart';
import '../../auth/services/auth_api_service.dart';
import '../widgets/explore_header.dart';
import '../widgets/model_grid_card.dart';
import '../widgets/match_tab_view.dart';
import '../widgets/live_feed_view.dart';
import '../widgets/draggable_extra_gems_widget.dart';
import '../../profile/screens/host_profile_screen.dart';
import '../../wallet/widgets/recharge_gems_sheet.dart';
import '../../wallet/services/wallet_api_service.dart';
import '../../call/screens/random_match_screen.dart';
import '../../call/services/call_api_service.dart';
import '../../call/services/streaming_service.dart';

import '../../party/screens/party_rooms_screen.dart';
import '../../rank/screens/rank_leaderboard_screen.dart';

class HotExploreScreen extends StatefulWidget {
  final VoidCallback? onMenuTap;

  const HotExploreScreen({super.key, this.onMenuTap});

  @override
  State<HotExploreScreen> createState() => _HotExploreScreenState();
}

class _HotExploreScreenState extends State<HotExploreScreen> with AutomaticKeepAliveClientMixin {
  static List<ModelProfile> _cachedHomeFeed = [];
  int _selectedTabIndex = 0;
  List<ModelProfile> _models = [];
  String _selectedCountryCode = 'ALL';
  String _selectedCountryName = 'All';
  String _searchQuery = '';

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    // 1. Instantly populate from Hive/RAM memory cache (0.00ms delay - Zero spinner)
    final initialFeed = ProfileApiService.getCachedHomeFeed();
    if (initialFeed.isNotEmpty) {
      _cachedHomeFeed = initialFeed;
      _models = initialFeed;
    } else if (_cachedHomeFeed.isNotEmpty) {
      _models = _cachedHomeFeed;
    } else {
      _models = [];
    }

    // 2. Fetch fresh updates in parallel in background silently (SWR)
    _loadHomeFeed();
  }

  Future<void> _loadHomeFeed() async {
    try {
      final savedUser = await AuthApiService.getSavedUser();
      ModelProfile? myProfile;
      if (savedUser != null) {
        myProfile = ModelProfile.fromJson(savedUser);
      }

      bool isExcludedUser(ModelProfile profile) {
        final name = profile.name.trim().toLowerCase();
        final firstName = (profile.firstName ?? '').trim().toLowerCase();
        final lastName = (profile.lastName ?? '').trim().toLowerCase();
        final email = (profile.email ?? '').trim().toLowerCase();
        final accountId = profile.accountId.trim();

        return name == 'admin' ||
            name.contains('administrator') ||
            firstName == 'admin' ||
            lastName == 'admin' ||
            accountId == '1000000001' ||
            email.startsWith('admin@') ||
            email.contains('admin@');
      }

      // Fast SWR Fetch
      await ProfileApiService.getHomeFeedSWR(
        country: _selectedCountryName != 'All' ? _selectedCountryName : null,
        onResult: (liveFeed, isFromCache) {
          final List<ModelProfile> combined = [];

          for (final user in liveFeed) {
            if (isExcludedUser(user)) continue;
            if (myProfile != null && (user.id == myProfile.id || (user.accountId.isNotEmpty && user.accountId == myProfile.accountId))) {
              continue; // exclude own profile from explore feed
            }
            combined.add(user);
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
            });
          }
        },
      );
    } catch (e) {
      debugPrint('Error loading home feed: $e');
    }
  }

  void _onTabSelected(int index) {
    if (_selectedTabIndex != index) {
      setState(() {
        _selectedTabIndex = index;
      });
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
          {'code': 'ALL', 'name': 'Global 🌐', 'value': 'All'},
          {'code': 'BGD', 'name': 'Bangladesh 🇧🇩', 'value': 'Bangladesh'},
          {'code': 'PAK', 'name': 'Pakistan 🇵🇰', 'value': 'Pakistan'},
          {'code': 'IND', 'name': 'India 🇮🇳', 'value': 'India'},
          {'code': 'USA', 'name': 'United States 🇺🇸', 'value': 'USA'},
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

  void _startVideoCall(ModelProfile model) {
    final int cachedCoins = WalletApiService.getCachedCoins();
    final int ratePerMin = model.pricePerMin > 0 ? model.pricePerMin : 100;

    // ⚡ ZERO-DELAY INSTANT SYNCHRONOUS CHECK (<0.001s):
    if (cachedCoins < ratePerMin) {
      RechargeGemsSheet.show(
        context,
        model: model,
        receiverId: model.id,
        receiverName: model.name,
        receiverAvatarUrl: model.avatarUrl,
        onRechargeSuccess: () {
          _startVideoCall(model);
        },
      );
      return;
    }

    // ⚡ Synchronous self-call check from Hive cache (0ms — no network call)
    final savedUser = HiveCacheService.getCachedUserProfile();
    final myId = savedUser?['id']?.toString() ?? savedUser?['user_id']?.toString();
    final myAccountId = savedUser?['account_id']?.toString();

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

    // ⚡ 0.00ms INSTANT CALL SCREEN LAUNCH (Zero-Loader Rule)
    final int optimisticCallId = (DateTime.now().millisecondsSinceEpoch ~/ 1000) % 10000000;
    final String channelName = 'call_${model.id}_$optimisticCallId';

    StreamingService.startDynamicCall(
      context: context,
      model: model,
      callId: optimisticCallId,
      channelName: channelName,
      isFreeTrial: false,
      freeDurationSeconds: 16,
      ratePerMinute: ratePerMin,
      isIncoming: false,
    );

    // Concurrently trigger backend notification, FCM VoIP push & socket event
    CallApiService.initiateCall(
      receiverId: model.id,
      receiverAccountId: model.accountId,
      callType: 'video',
    ).then((initiateRes) {
      // Backend signaled in background
    }).catchError((_) {});
  }

  void _openRankLeaderboardScreen() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const RankLeaderboardScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
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
                  onRankTap: _openRankLeaderboardScreen,
                  onMenuTap: widget.onMenuTap ?? () {
                    Scaffold.maybeOf(context)?.openDrawer();
                  },
                  selectedCountryCode: _selectedCountryCode,
                ),

                // User Cards 2-Column Grid, Live, Party, or Match Tab Views in IndexedStack (0ms switch)
                Expanded(
                  child: _buildCurrentTabBody(),
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

  Widget _buildCurrentTabBody() {
    return IndexedStack(
      index: _selectedTabIndex,
      children: [
        // Tab 0: Hot Explore Grid Feed
        _buildHotGridView(),

        // Tab 1: Live Stream Feed
        LiveFeedView(
          models: _models,
          onRefresh: _loadHomeFeed,
        ),

        // Tab 2: Party Rooms Screen
        const PartyRoomsScreen(),

        // Tab 3: Match Tab View
        MatchTabView(
          onStartMatching: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const RandomMatchScreen(),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildHotGridView() {
    if (_models.isEmpty) {
      return RefreshIndicator(
        color: AppColors.neonPink,
        backgroundColor: AppColors.cardDark,
        onRefresh: _loadHomeFeed,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
          children: [
            SizedBox(height: MediaQuery.of(context).size.height * 0.12),
            LivUEmptyStateCard(
              onRefresh: _loadHomeFeed,
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
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
    );
  }
}


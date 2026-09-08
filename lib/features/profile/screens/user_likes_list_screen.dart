import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/models/model_profile.dart';
import '../../../core/models/chat_message.dart';
import '../../../core/services/profile_api_service.dart';
import '../../../core/widgets/cached_image_loader.dart';
import '../../call/services/call_api_service.dart';
import '../../call/widgets/call_recharge_modal.dart';
import '../../call/screens/call_ringing_screen.dart';
import 'host_profile_screen.dart';
import '../../chat/screens/chat_detail_screen.dart';

class UserLikesListScreen extends StatefulWidget {
  final String initialTab; // 'i_like' or 'like_me'

  const UserLikesListScreen({
    super.key,
    this.initialTab = 'i_like',
  });

  @override
  State<UserLikesListScreen> createState() => _UserLikesListScreenState();
}

class _UserLikesListScreenState extends State<UserLikesListScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoadingILike = true;
  bool _isLoadingLikeMe = true;
  List<ModelProfile> _iLikeUsers = [];
  List<ModelProfile> _likeMeUsers = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.initialTab == 'like_me' ? 1 : 0,
    );
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    _loadILike();
    _loadLikeMe();
  }

  Future<void> _loadILike() async {
    setState(() => _isLoadingILike = true);
    final users = await ProfileApiService.getLikesUsers(type: 'i_like');
    if (mounted) {
      setState(() {
        _iLikeUsers = users;
        _isLoadingILike = false;
      });
    }
  }

  Future<void> _loadLikeMe() async {
    setState(() => _isLoadingLikeMe = true);
    final users = await ProfileApiService.getLikesUsers(type: 'like_me');
    if (mounted) {
      setState(() {
        _likeMeUsers = users;
        _isLoadingLikeMe = false;
      });
    }
  }

  Future<void> _initiateVideoCall(ModelProfile user) async {
    try {
      final permRes = await CallApiService.checkCallPermission(
        receiverId: user.id,
        callType: 'video',
      );

      if (!mounted) return;

      if (permRes['can_call'] == false || permRes['show_recharge_modal'] == true || permRes['status'] == false) {
        CallRechargeModal.show(
          context,
          shortageCoins: permRes['shortage_coins'] ?? (user.videoCallRate - (permRes['user_coins'] ?? 0)),
          hostName: user.name,
          callRate: user.videoCallRate,
        );
        return;
      }

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => CallRingingScreen(
            receiverId: user.id,
            receiverName: user.name,
            receiverAvatar: user.avatarUrl,
            callType: 'video',
            channelName: 'call_${DateTime.now().millisecondsSinceEpoch}',
            isCaller: true,
            videoRate: user.videoCallRate,
          ),
        ),
      );
    } catch (_) {
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => HostProfileScreen(model: user)),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      appBar: AppBar(
        backgroundColor: AppColors.surfaceDark,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Likes & Fans ❤️',
          style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.neonPink,
          indicatorWeight: 3,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white54,
          labelStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
          tabs: [
            Tab(text: 'I Like (${_iLikeUsers.length})'),
            Tab(text: 'Like Me (${_likeMeUsers.length})'),
          ],
        ),
      ),
      body: SafeArea(
        child: TabBarView(
          controller: _tabController,
          children: [
            _buildUserListView(_iLikeUsers, _isLoadingILike, isILike: true),
            _buildUserListView(_likeMeUsers, _isLoadingLikeMe, isILike: false),
          ],
        ),
      ),
    );
  }

  Widget _buildUserListView(List<ModelProfile> users, bool isLoading, {required bool isILike}) {
    if (isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.neonPink),
      );
    }

    if (users.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.surfaceDark,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.cardBorder),
                ),
                child: Icon(
                  isILike ? Icons.favorite_border_rounded : Icons.favorite_rounded,
                  color: isILike ? AppColors.neonPink : AppColors.neonPurple,
                  size: 44,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                isILike ? 'No Streamers Liked Yet' : 'No Likes Received Yet',
                style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              Text(
                isILike
                    ? 'Tap the heart icon on any streamer\'s profile to show your love!'
                    : 'Start live streaming or sharing your profile to get more likes!',
                style: const TextStyle(color: AppColors.textMuted, fontSize: 13),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      color: AppColors.neonPink,
      backgroundColor: AppColors.surfaceDark,
      onRefresh: _loadData,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        itemCount: users.length,
        separatorBuilder: (context, index) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final user = users[index];
          return _buildUserCard(user);
        },
      ),
    );
  }

  Widget _buildUserCard(ModelProfile user) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => HostProfileScreen(model: user)),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.surfaceDark,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.cardBorder),
        ),
        child: Row(
          children: [
            // Avatar with Online dot
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.neonPink.withValues(alpha: 0.5), width: 1.5),
                  ),
                  child: ClipOval(
                    child: CachedImageLoader(
                      imageUrl: user.avatarUrl,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                if (user.isOnline)
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: AppColors.onlineGreen,
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.surfaceDark, width: 2),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 12),

            // User Info (Flexible layout to prevent any overflow)
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          user.name,
                          style: const TextStyle(color: Colors.white, fontSize: 14.5, fontWeight: FontWeight.bold),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (user.isVerified) ...[
                        const SizedBox(width: 4),
                        const Icon(Icons.verified_rounded, color: Colors.blueAccent, size: 14),
                      ],
                      const SizedBox(width: 5),
                      Text(
                        user.countryFlag,
                        style: const TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.neonPurple.withValues(alpha: 0.25),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'ID: ${user.effectiveAccountId}',
                          style: const TextStyle(color: Colors.white70, fontSize: 10.5, fontWeight: FontWeight.w600),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(colors: [Color(0xFFFF8E53), Color(0xFFFE6B8B)]),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'Lv${user.level}',
                          style: const TextStyle(color: Colors.white, fontSize: 9.5, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  if (user.intro.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      user.intro,
                      style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),

            // Quick Chat & Video Call Buttons
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  icon: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.cardDark,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.cardBorder),
                    ),
                    child: const Icon(Icons.chat_bubble_outline_rounded, color: AppColors.neonPurple, size: 18),
                  ),
                  onPressed: () {
                    final thread = ChatThread(
                      id: 't_${user.id}',
                      modelId: user.id,
                      name: user.name,
                      avatarUrl: user.avatarUrl,
                      lastMessage: 'Hey! 👋',
                      time: 'Just now',
                      messages: [],
                    );
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ChatDetailScreen(thread: thread),
                      ),
                    );
                  },
                ),
                const SizedBox(width: 8),
                IconButton(
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  icon: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      gradient: AppColors.primaryGradient,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.videocam_rounded, color: Colors.white, size: 18),
                  ),
                  onPressed: () => _initiateVideoCall(user),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

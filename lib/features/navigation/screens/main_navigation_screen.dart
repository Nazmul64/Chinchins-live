import 'dart:async';
import 'package:flutter/material.dart';
import '../../../core/models/model_profile.dart';
import '../../../core/services/signaling_service.dart';
import '../../../core/services/remote_config_service.dart';
import '../../../core/services/app_update_service.dart';
import '../../../core/services/device_registration_service.dart';
import '../../../core/services/notification_api_service.dart';
import '../../auth/services/auth_api_service.dart';
import '../../explore/screens/hot_explore_screen.dart';
import '../../messages/screens/messages_screen.dart';
import '../../me/screens/me_screen.dart';
import '../../call/screens/incoming_call_screen.dart';
import '../../call/services/call_api_service.dart';
import '../../chat/services/chat_api_service.dart';
import '../../call/screens/go_live_screen.dart';
import '../widgets/app_side_drawer.dart';
import '../../../main.dart';

class MainNavigationScreen extends StatefulWidget {
  final bool refreshOnStart;

  const MainNavigationScreen({
    super.key,
    this.refreshOnStart = false,
  });

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  int _currentIndex = 0;
  Timer? _heartbeatTimer;
  StreamSubscription? _wsIncomingCallSub;
  StreamSubscription? _wsEndedSub;
  StreamSubscription? _wsCancelledSub;
  StreamSubscription? _wsRejectedSub;
  int? _activeIncomingCallId;

  late final List<Widget> _screens = [
    HotExploreScreen(
      onMenuTap: () => _scaffoldKey.currentState?.openDrawer(),
      refreshOnStart: widget.refreshOnStart,
    ),
    const MessagesScreen(),
    const MeScreen(),
  ];

  @override
  void initState() {
    super.initState();
    ChatApiService.getConversations();
    _initWebSocketSignaling();
    _startUserHeartbeat();
    _initAppServices();
  }

  void _initAppServices() {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // 1. Fetch live remote configurations & feature toggles
      await RemoteConfigService.instance.fetchRemoteConfig();

      // 2. Check for In-App OTA Updates (display modal if new version/force update available)
      if (mounted) {
        await AppUpdateService.checkForUpdates(context);
      }

      // 3. Register device specifications & push wake token on VPS
      await DeviceRegistrationService.registerDevice();

      // 4. Start polling real-time notification alerts (profile views, gifts, calls)
      NotificationApiService.instance.startNotificationPolling();
    });
  }

  void _initWebSocketSignaling() async {
    try {
      final token = await AuthApiService.getToken();
      final savedUser = await AuthApiService.getSavedUser();
      final userId = savedUser?['id']?.toString() ?? savedUser?['user_id']?.toString();
      final accountId = savedUser?['account_id']?.toString() ?? savedUser?['display_id']?.toString();
      if (token != null && token.isNotEmpty) {
        final signaling = SignalingService();
        await signaling.init(token);
        if (userId != null || accountId != null) {
          await signaling.subscribeToUser(userId ?? accountId, accountId: accountId);
        }
        _wsIncomingCallSub?.cancel();
        _wsIncomingCallSub = signaling.onIncomingCall.listen((data) {
          if (mounted) {
            _handleIncomingCallData(data);
          }
        });
        _wsEndedSub?.cancel();
        _wsEndedSub = signaling.onCallEnded.listen((_) {
          _activeIncomingCallId = null;
        });
        _wsCancelledSub?.cancel();
        _wsCancelledSub = signaling.onCallCancelled.listen((_) {
          _activeIncomingCallId = null;
        });
        _wsRejectedSub?.cancel();
        _wsRejectedSub = signaling.onCallRejected.listen((_) {
          _activeIncomingCallId = null;
        });
      }
    } catch (_) {}
  }

  /// Keep user presence online so incoming calls can be routed reliably
  void _startUserHeartbeat() {
    CallApiService.sendHeartbeat(status: 'online', deviceType: 'android');
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 25), (_) {
      CallApiService.sendHeartbeat(status: 'online', deviceType: 'android');
    });
  }

  void _handleIncomingCallData(Map<String, dynamic> incoming) async {
    final payload = incoming['data'] is Map ? Map<String, dynamic>.from(incoming['data']) : incoming;
    final dynamic rawCallId = payload['call_id'] ?? payload['id'] ?? payload['session_id'] ?? payload['call_session_id'] ?? incoming['call_id'] ?? incoming['id'];
    
    int? callId;
    if (rawCallId is int && rawCallId > 0) {
      callId = rawCallId;
    } else if (rawCallId != null) {
      callId = int.tryParse(rawCallId.toString());
    }

    if (callId == null || callId <= 0) {
      debugPrint('[MainNavigationScreen] Ignored incoming call event with invalid callId: $rawCallId');
      return;
    }

    if (callId != _activeIncomingCallId) {
      _activeIncomingCallId = callId;
      final rawCaller = (payload['caller'] is Map ? payload['caller'] : null) ??
          (payload['sender'] is Map ? payload['sender'] : null) ??
          (payload['user'] is Map ? payload['user'] : null) ??
          (payload['from_user'] is Map ? payload['from_user'] : null) ??
          (incoming['caller'] is Map ? incoming['caller'] : null) ??
          (incoming['sender'] is Map ? incoming['sender'] : null) ??
          (incoming['user'] is Map ? incoming['user'] : null) ??
          {};
      final caller = Map<String, dynamic>.from(rawCaller);
      
      final callerId = caller['id']?.toString() ??
          caller['user_id']?.toString() ??
          caller['account_id']?.toString() ??
          payload['caller_id']?.toString() ??
          payload['from_user_id']?.toString() ??
          '1';
      final callerAccountId = caller['account_id']?.toString() ?? callerId;

      // Prevent Self-Calling Loop
      final savedUser = await AuthApiService.getSavedUser();
      final myId = savedUser?['id']?.toString() ?? savedUser?['user_id']?.toString();
      final myAccountId = savedUser?['account_id']?.toString();
      if ((myId != null && myId.isNotEmpty && (myId == callerId || myId == callerAccountId)) ||
          (myAccountId != null && myAccountId.isNotEmpty && (myAccountId == callerId || myAccountId == callerAccountId))) {
        debugPrint('[MainNavigationScreen] Ignored self-call event: myId=$myId, callerId=$callerId');
        return;
      }

      final callerName = caller['name'] ??
          caller['display_name'] ??
          caller['username'] ??
          payload['caller_name'] ??
          payload['user_name'] ??
          'Chinchins User';
      final callerAvatar = caller['avatar'] ??
          caller['avatar_url'] ??
          caller['profile_photo'] ??
          payload['caller_avatar'] ??
          'https://chinchins.live/uploads/app/logo.png';

      final model = ModelProfile.fromJson({
        'id': callerId,
        'account_id': callerAccountId,
        'name': callerName,
        'avatar': callerAvatar,
        'age': caller['age'] ?? 22,
        'country': caller['country'] ?? 'Bangladesh',
        'video_call_rate': payload['rate_per_minute'] ?? incoming['rate_per_minute'] ?? 100,
      });

      final channelName = (payload['channel_name'] ??
              payload['room_name'] ??
              payload['call_channel'] ??
              payload['call_session_id'] ??
              incoming['channel_name'] ??
              'call_$callId')
          .toString();

      final ringtoneUrl = (payload['incoming_ringtone_url'] ??
              payload['ringtone_url'] ??
              payload['ringtone'] ??
              incoming['incoming_ringtone_url'] ??
              incoming['ringtone_url'])
          ?.toString();

      if (!mounted) return;
      final navState = ChinchinsLiveApp.navigatorKey.currentState ?? Navigator.of(context);
      navState.push(
        MaterialPageRoute(
          builder: (context) => IncomingCallScreen(
            model: model,
            callId: callId,
            channelName: channelName,
            isFreeTrial: payload['is_free_trial'] == true || incoming['is_free_trial'] == true,
            freeDurationSeconds: payload['free_duration_seconds'] ?? incoming['free_duration_seconds'] ?? 10,
            ratePerMinute: payload['rate_per_minute'] ?? incoming['rate_per_minute'] ?? 100,
            ringtoneUrl: ringtoneUrl,
            initialSessionData: payload,
          ),
        ),
      ).then((_) {
        _activeIncomingCallId = null;
      });
    }
  }

  @override
  void dispose() {
    _heartbeatTimer?.cancel();
    _wsIncomingCallSub?.cancel();
    _wsEndedSub?.cancel();
    _wsCancelledSub?.cancel();
    _wsRejectedSub?.cancel();
    NotificationApiService.instance.stopNotificationPolling();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      drawer: const AppSideDrawer(),
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: Container(
        height: 64,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: const BoxDecoration(
          color: Color(0xFF0F0E17),
          border: Border(
            top: BorderSide(color: Color(0xFF26223B), width: 0.6),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            // 1. Home
            _buildCustomNavItem(
              index: 0,
              icon: Icons.home_rounded,
              unselectedIcon: Icons.home_outlined,
              label: 'Home',
            ),

            // 2. Center Go Live "+" Button (TikTok Style)
            GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const GoLiveScreen()),
                );
              },
              child: Container(
                width: 48,
                height: 36,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFF2A6D), Color(0xFFFF0055)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFFF2A6D).withValues(alpha: 0.5),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const Center(
                  child: Icon(Icons.add_rounded, color: Colors.white, size: 26),
                ),
              ),
            ),

            // 3. Inbox with dynamic unread badge
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => setState(() => _currentIndex = 1),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Icon(
                          _currentIndex == 1 ? Icons.chat_bubble_rounded : Icons.chat_bubble_outline_rounded,
                          color: _currentIndex == 1 ? const Color(0xFFFF2A6D) : Colors.white60,
                          size: 22,
                        ),
                        ValueListenableBuilder<int>(
                          valueListenable: ChatApiService.totalUnreadBadgeNotifier,
                          builder: (context, badgeCount, _) {
                            if (badgeCount <= 0) return const SizedBox.shrink();
                            return Positioned(
                              top: -4,
                              right: -8,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFF0055),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Center(
                                  child: Text(
                                    badgeCount > 99 ? '99+' : '$badgeCount',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 9,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Inbox',
                      style: TextStyle(
                        color: _currentIndex == 1 ? const Color(0xFFFF2A6D) : Colors.white60,
                        fontSize: 10,
                        fontWeight: _currentIndex == 1 ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // 4. Profile / Me
            _buildCustomNavItem(
              index: 2,
              icon: Icons.person_rounded,
              unselectedIcon: Icons.person_outline_rounded,
              label: 'Profile',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCustomNavItem({
    required int index,
    required IconData icon,
    required IconData unselectedIcon,
    required String label,
  }) {
    final isSelected = _currentIndex == index;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => setState(() => _currentIndex = index),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isSelected ? icon : unselectedIcon,
              color: isSelected ? const Color(0xFFFF2A6D) : Colors.white60,
              size: 22,
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? const Color(0xFFFF2A6D) : Colors.white60,
                fontSize: 10,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

import 'dart:async';
import 'package:flutter/material.dart';
import '../../../core/models/model_profile.dart';
import '../../../core/services/signaling_service.dart';
import '../../../core/services/remote_config_service.dart';
import '../../../core/services/app_update_service.dart';
import '../../../core/services/device_registration_service.dart';
import '../../../core/services/notification_api_service.dart';
import '../../../core/theme/app_colors.dart';
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
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  int _currentIndex = 0;
  Timer? _incomingCallPollTimer;
  Timer? _heartbeatTimer;
  StreamSubscription? _wsIncomingCallSub;
  bool _isCheckingIncoming = false;
  bool _isLongPollingActive = true;
  int? _activeIncomingCallId;

  late final List<Widget> _screens = [
    HotExploreScreen(
      onMenuTap: () => _scaffoldKey.currentState?.openDrawer(),
    ),
    HotExploreScreen(
      onMenuTap: () => _scaffoldKey.currentState?.openDrawer(),
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
    _startIncomingCallListener();
    _startLongPollStream();
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

  /// Tier 1: Zero-Latency Long-Polling Stream
  void _startLongPollStream() async {
    while (_isLongPollingActive && mounted) {
      try {
        final incoming = await CallApiService.waitIncomingCall(timeoutSeconds: 15);
        if (incoming != null && mounted) {
          _handleIncomingCallData(incoming);
        }
      } catch (_) {
        await Future.delayed(const Duration(seconds: 1));
      }
    }
  }

  /// Tier 2: 1-Second Fallback Poller
  void _startIncomingCallListener() {
    _incomingCallPollTimer = Timer.periodic(const Duration(milliseconds: 1000), (timer) async {
      if (_isCheckingIncoming || !mounted) return;
      _isCheckingIncoming = true;
      try {
        final incoming = await CallApiService.checkIncomingCall();
        if (incoming != null && mounted) {
          _handleIncomingCallData(incoming);
        }
      } catch (_) {}
      _isCheckingIncoming = false;
    });
  }

  void _handleIncomingCallData(Map<String, dynamic> incoming) {
    final dynamic rawCallId = incoming['call_id'] ?? incoming['id'];
    final int? callId = rawCallId is int
        ? rawCallId
        : int.tryParse(rawCallId?.toString() ?? '0');

    if (callId != null && callId > 0 && callId != _activeIncomingCallId) {
      _activeIncomingCallId = callId;
      final rawCaller = (incoming['caller'] is Map ? incoming['caller'] : null) ??
          (incoming['sender'] is Map ? incoming['sender'] : null) ??
          (incoming['user'] is Map ? incoming['user'] : null) ??
          {};
      final caller = Map<String, dynamic>.from(rawCaller);
      final model = ModelProfile.fromJson({
        'id': caller['id']?.toString() ?? caller['user_id']?.toString() ?? caller['account_id']?.toString() ?? '1',
        'account_id': caller['account_id']?.toString() ?? caller['id']?.toString() ?? '1',
        'name': caller['name'] ?? caller['display_name'] ?? caller['username'] ?? 'Chinchins User',
        'avatar': caller['avatar'] ?? caller['avatar_url'] ?? 'https://images.unsplash.com/photo-1534528741775-53994a69daeb',
        'age': caller['age'] ?? 22,
        'country': caller['country'] ?? 'Bangladesh',
        'video_call_rate': incoming['rate_per_minute'] ?? 100,
      });

      final navState = ChinchinsLiveApp.navigatorKey.currentState ?? Navigator.of(context);
      navState.push(
        MaterialPageRoute(
          builder: (context) => IncomingCallScreen(
            model: model,
            callId: callId,
            channelName: incoming['channel_name']?.toString(),
            isFreeTrial: incoming['is_free_trial'] == true,
            freeDurationSeconds: incoming['free_duration_seconds'] ?? 10,
            ratePerMinute: incoming['rate_per_minute'] ?? 100,
            ringtoneUrl: (incoming['incoming_ringtone_url'] ?? incoming['ringtone_url'])?.toString(),
          ),
        ),
      ).then((_) {
        _activeIncomingCallId = null;
      });
    }
  }

  @override
  void dispose() {
    _isLongPollingActive = false;
    _incomingCallPollTimer?.cancel();
    _heartbeatTimer?.cancel();
    _wsIncomingCallSub?.cancel();
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

            // 2. Discover / Explore
            _buildCustomNavItem(
              index: 1,
              icon: Icons.explore_rounded,
              unselectedIcon: Icons.explore_outlined,
              label: 'Discover',
            ),

            // 3. Center Go Live "+" Button (Screen H)
            GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const GoLiveScreen()),
                );
              },
              child: Container(
                width: 44,
                height: 32,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFF2A6D), Color(0xFFFF0055)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFFF2A6D).withValues(alpha: 0.45),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const Center(
                  child: Icon(Icons.add_rounded, color: Colors.white, size: 24),
                ),
              ),
            ),

            // 4. Inbox with dynamic unread badge
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => setState(() => _currentIndex = 2),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Icon(
                          _currentIndex == 2 ? Icons.chat_bubble_rounded : Icons.chat_bubble_outline_rounded,
                          color: _currentIndex == 2 ? const Color(0xFFFF2A6D) : Colors.white60,
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
                        color: _currentIndex == 2 ? const Color(0xFFFF2A6D) : Colors.white60,
                        fontSize: 10,
                        fontWeight: _currentIndex == 2 ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // 5. Profile
            _buildCustomNavItem(
              index: 3,
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

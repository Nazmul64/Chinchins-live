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
import '../../../main.dart';

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 0;
  Timer? _incomingCallPollTimer;
  Timer? _heartbeatTimer;
  StreamSubscription? _wsIncomingCallSub;
  bool _isCheckingIncoming = false;
  bool _isLongPollingActive = true;
  int? _activeIncomingCallId;

  final List<Widget> _screens = const [
    HotExploreScreen(),
    MessagesScreen(),
    MeScreen(),
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
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: AppColors.bottomBarBg,
          border: Border(
            top: BorderSide(color: AppColors.cardBorder, width: 0.6),
          ),
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) {
            setState(() {
              _currentIndex = index;
            });
          },
          backgroundColor: AppColors.bottomBarBg,
          selectedItemColor: Colors.white,
          unselectedItemColor: AppColors.textMuted,
          selectedFontSize: 11,
          unselectedFontSize: 11,
          type: BottomNavigationBarType.fixed,
          items: [
            // "Home" Tab with Home Icon
            BottomNavigationBarItem(
              icon: Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Icon(
                  _currentIndex == 0 ? Icons.home_rounded : Icons.home_outlined,
                  color: _currentIndex == 0 ? Colors.white : AppColors.textMuted,
                  size: 24,
                ),
              ),
              label: 'Home',
            ),

            // "Messages" Tab with dynamic unread badge
            BottomNavigationBarItem(
              icon: Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Icon(
                      _currentIndex == 1 ? Icons.chat_bubble_rounded : Icons.chat_bubble_outline_rounded,
                      color: _currentIndex == 1 ? Colors.white : AppColors.textMuted,
                      size: 24,
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
                              color: const Color(0xFFE91E63),
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
              ),
              label: 'Messages',
            ),

            // "Me" Tab
            BottomNavigationBarItem(
              icon: Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Icon(
                  _currentIndex == 2 ? Icons.sentiment_satisfied_alt_rounded : Icons.sentiment_satisfied_rounded,
                  color: _currentIndex == 2 ? Colors.white : AppColors.textMuted,
                  size: 24,
                ),
              ),
              label: 'Me',
            ),
          ],
        ),
      ),
    );
  }
}

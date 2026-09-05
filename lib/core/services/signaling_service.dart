import 'dart:async';
import 'dart:convert';
import 'package:dart_pusher_channels/dart_pusher_channels.dart';
import '../../config/app_config.dart';
import '../utils/app_logger.dart';

class SignalingService {
  static final SignalingService _instance = SignalingService._internal();
  factory SignalingService() => _instance;
  SignalingService._internal();

  PusherChannelsClient? _pusherClient;
  bool _isConnected = false;
  String? _userToken;

  final Map<String, Channel> _activeChannels = {};
  final Map<String, StreamSubscription> _activeSubscriptions = {};
  StreamSubscription<PusherChannelsClientLifeCycleState>? _lifecycleSub;
  StreamSubscription<void>? _reconnectSub;

  bool get isConnected => _isConnected;

  final StreamController<Map<String, dynamic>> _incomingCallController =
      StreamController<Map<String, dynamic>>.broadcast();
  final StreamController<Map<String, dynamic>> _callAcceptedController =
      StreamController<Map<String, dynamic>>.broadcast();
  final StreamController<Map<String, dynamic>> _callRejectedController =
      StreamController<Map<String, dynamic>>.broadcast();
  final StreamController<Map<String, dynamic>> _callCancelledController =
      StreamController<Map<String, dynamic>>.broadcast();
  final StreamController<Map<String, dynamic>> _callEndedController =
      StreamController<Map<String, dynamic>>.broadcast();
  final StreamController<Map<String, dynamic>> _offerController =
      StreamController<Map<String, dynamic>>.broadcast();
  final StreamController<Map<String, dynamic>> _answerController =
      StreamController<Map<String, dynamic>>.broadcast();
  final StreamController<Map<String, dynamic>> _iceCandidateController =
      StreamController<Map<String, dynamic>>.broadcast();

  Stream<Map<String, dynamic>> get onIncomingCall => _incomingCallController.stream;
  Stream<Map<String, dynamic>> get onCallAccepted => _callAcceptedController.stream;
  Stream<Map<String, dynamic>> get onCallRejected => _callRejectedController.stream;
  Stream<Map<String, dynamic>> get onCallCancelled => _callCancelledController.stream;
  Stream<Map<String, dynamic>> get onCallEnded => _callEndedController.stream;
  Stream<Map<String, dynamic>> get onWebRTCOffer => _offerController.stream;
  Stream<Map<String, dynamic>> get onWebRTCAnswer => _answerController.stream;
  Stream<Map<String, dynamic>> get onWebRTCICECandidate => _iceCandidateController.stream;

  EndpointAuthorizableChannelTokenAuthorizationDelegate<PrivateChannelAuthorizationData>
      _getAuthDelegate() {
    return EndpointAuthorizableChannelTokenAuthorizationDelegate.forPrivateChannel(
      authorizationEndpoint: Uri.parse(AppConfig.authEndpoint),
      headers: {
        'Authorization': 'Bearer ${_userToken ?? ""}',
        'Accept': 'application/json',
      },
    );
  }

  Future<void> init(String userToken) async {
    _userToken = userToken;

    try {
      AppLogger.info('SignalingService', 'Initializing Reverb WebSockets client on VPS (${AppConfig.reverbHost})...');

      if (_pusherClient != null && !_pusherClient!.isDisposed) {
        await disconnect();
      }

      final port = AppConfig.reverbUseTLS ? AppConfig.reverbWssPort : AppConfig.reverbWsPort;
      final scheme = AppConfig.reverbUseTLS ? 'wss' : 'ws';

      final options = PusherChannelsOptions.fromHost(
        scheme: scheme,
        host: AppConfig.reverbHost,
        port: port,
        key: AppConfig.reverbAppKey,
      );

      _pusherClient = PusherChannelsClient.websocket(
        options: options,
        connectionErrorHandler: (exception, trace, refresh) {
          AppLogger.error('SignalingServiceError', 'WebSocket Error: $exception', trace);
          refresh();
        },
      );

      _lifecycleSub = _pusherClient!.lifecycleStream.listen((state) {
        AppLogger.info('SignalingService', 'Connection state changed: $state');
        _isConnected = (state == PusherChannelsClientLifeCycleState.establishedConnection);
      });

      _reconnectSub = _pusherClient!.onConnectionEstablished.listen((_) {
        AppLogger.info('SignalingService', 'Connection established. Re-subscribing channels...');
        for (final channel in _activeChannels.values) {
          try {
            channel.subscribeIfNotUnsubscribed();
          } catch (_) {}
        }
      });

      await _pusherClient!.connect();
    } catch (e, st) {
      AppLogger.error('SignalingServiceInitError', e, st);
    }
  }

  Future<void> _subscribeToChannel(String channelName, {bool isPrivate = true}) async {
    if (_pusherClient == null) return;
    if (_activeChannels.containsKey(channelName)) return;

    try {
      Channel channel;
      if (isPrivate) {
        channel = _pusherClient!.privateChannel(
          channelName,
          authorizationDelegate: _getAuthDelegate(),
        );
      } else {
        channel = _pusherClient!.publicChannel(channelName);
      }

      final sub = channel.bindToAll().listen((event) {
        _handleChannelEvent(event);
      });

      _activeChannels[channelName] = channel;
      _activeSubscriptions[channelName] = sub;
      channel.subscribeIfNotUnsubscribed();
      AppLogger.info('SignalingService', 'Subscribed to channel: $channelName (private: $isPrivate)');
    } catch (e, st) {
      AppLogger.error('SubscribeChannelError', 'Error subscribing to $channelName: $e', st);
    }
  }

  Future<void> subscribeToUser(dynamic userId, {dynamic accountId}) async {
    if (userId == null || _pusherClient == null) return;

    final uIdStr = userId.toString().trim();
    if (uIdStr.isNotEmpty) {
      await _subscribeToChannel('private-user.$uIdStr', isPrivate: true);
      await _subscribeToChannel('user.$uIdStr', isPrivate: false);
    }

    if (accountId != null) {
      final accIdStr = accountId.toString().trim();
      if (accIdStr.isNotEmpty && accIdStr != uIdStr) {
        await _subscribeToChannel('private-user.$accIdStr', isPrivate: true);
        await _subscribeToChannel('user.$accIdStr', isPrivate: false);
      }
    }
  }

  Future<void> subscribeToCallRoom(String roomId) async {
    if (_pusherClient == null || roomId.isEmpty) return;
    await _subscribeToChannel('private-call.$roomId', isPrivate: true);
    await _subscribeToChannel('call.$roomId', isPrivate: false);
  }

  Future<void> leaveCallRoom() async {
    final toRemove = _activeChannels.keys.where((k) => k.contains('call.')).toList();
    for (final chName in toRemove) {
      try {
        _activeSubscriptions[chName]?.cancel();
        _activeSubscriptions.remove(chName);
        _activeChannels[chName]?.unsubscribe();
        _activeChannels.remove(chName);
      } catch (_) {}
    }
  }

  void _handleChannelEvent(ChannelReadEvent event) {
    final eventName = event.name;
    Map<String, dynamic> data = {};

    try {
      final parsed = event.tryGetDataAsMap();
      if (parsed != null) {
        data = Map<String, dynamic>.from(parsed);
      } else if (event.data is String) {
        final raw = jsonDecode(event.data as String);
        if (raw is Map) {
          data = Map<String, dynamic>.from(raw);
        } else if (raw is String) {
          final raw2 = jsonDecode(raw);
          if (raw2 is Map) data = Map<String, dynamic>.from(raw2);
        }
      }
    } catch (_) {}

    AppLogger.info('SignalingService', 'Received Event: $eventName on channel ${event.channelName}');

    final cleanName = eventName.startsWith('.') ? eventName.substring(1) : eventName;
    final lowerName = cleanName.toLowerCase();

    // Check for incoming call
    if (cleanName == 'call.incoming' ||
        cleanName == 'CallIncoming' ||
        cleanName == 'incoming.call' ||
        cleanName == 'incoming_call' ||
        cleanName == 'call.initiated' ||
        cleanName == 'CallInitiated' ||
        cleanName.endsWith('IncomingCallEvent') ||
        cleanName.endsWith('CallIncomingEvent') ||
        cleanName.endsWith('CallInitiatedEvent') ||
        lowerName.contains('incoming') ||
        (data.containsKey('caller') && (data.containsKey('call_id') || data.containsKey('channel_name')))) {
      _incomingCallController.add(data);
      return;
    }

    // Check for other WebRTC signaling events
    switch (cleanName) {
      case 'call.accepted':
      case 'CallAccepted':
        _callAcceptedController.add(data);
        break;
      case 'call.rejected':
      case 'CallRejected':
        _callRejectedController.add(data);
        break;
      case 'call.cancelled':
      case 'CallCancelled':
        _callCancelledController.add(data);
        break;
      case 'call.ended':
      case 'CallEnded':
        _callEndedController.add(data);
        break;
      case 'webrtc.offer':
      case 'WebRTCOffer':
        _offerController.add(data);
        break;
      case 'webrtc.answer':
      case 'WebRTCAnswer':
        _answerController.add(data);
        break;
      case 'webrtc.ice_candidate':
      case 'WebRTCICECandidate':
        _iceCandidateController.add(data);
        break;
    }
  }

  Future<void> disconnect() async {
    try {
      for (final sub in _activeSubscriptions.values) {
        await sub.cancel();
      }
      _activeSubscriptions.clear();

      for (final ch in _activeChannels.values) {
        try {
          ch.unsubscribe();
        } catch (_) {}
      }
      _activeChannels.clear();

      _lifecycleSub?.cancel();
      _lifecycleSub = null;
      _reconnectSub?.cancel();
      _reconnectSub = null;

      if (_pusherClient != null && !_pusherClient!.isDisposed) {
        await _pusherClient!.disconnect();
        _pusherClient!.dispose();
        _pusherClient = null;
      }
      _isConnected = false;
    } catch (_) {}
  }
}
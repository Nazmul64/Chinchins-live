import 'dart:async';
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
  String? _currentUserChannelName;
  String? _currentRoomChannelName;

  PrivateChannel? _userChannel;
  StreamSubscription<ChannelReadEvent>? _userChannelSub;
  PrivateChannel? _roomChannel;
  StreamSubscription<ChannelReadEvent>? _roomChannelSub;
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
        AppLogger.info('SignalingService', 'Connection established. Re-subscribing channels if needed...');
        _userChannel?.subscribeIfNotUnsubscribed();
        _roomChannel?.subscribeIfNotUnsubscribed();
      });

      await _pusherClient!.connect();
    } catch (e, st) {
      AppLogger.error('SignalingServiceInitError', e, st);
    }
  }

  Future<void> subscribeToUser(dynamic userId) async {
    if (userId == null || _pusherClient == null) return;
    final channelName = 'private-user.$userId';
    if (_currentUserChannelName == channelName && _userChannel != null) return;

    try {
      if (_userChannel != null) {
        _userChannelSub?.cancel();
        _userChannelSub = null;
        _userChannel?.unsubscribe();
      }

      _currentUserChannelName = channelName;
      _userChannel = _pusherClient!.privateChannel(
        channelName,
        authorizationDelegate: _getAuthDelegate(),
      );

      _userChannelSub = _userChannel!.bindToAll().listen((event) {
        _handleChannelEvent(event);
      });

      _userChannel!.subscribeIfNotUnsubscribed();
      AppLogger.info('SignalingService', 'Subscribed to user channel: $channelName');
    } catch (e, st) {
      AppLogger.error('SubscribeUserChannelError', e, st);
    }
  }

  Future<void> subscribeToCallRoom(String roomId) async {
    if (_pusherClient == null) return;
    final channelName = 'private-call.$roomId';
    if (_currentRoomChannelName == channelName && _roomChannel != null) return;

    try {
      if (_roomChannel != null) {
        _roomChannelSub?.cancel();
        _roomChannelSub = null;
        _roomChannel?.unsubscribe();
      }

      _currentRoomChannelName = channelName;
      _roomChannel = _pusherClient!.privateChannel(
        channelName,
        authorizationDelegate: _getAuthDelegate(),
      );

      _roomChannelSub = _roomChannel!.bindToAll().listen((event) {
        _handleChannelEvent(event);
      });

      _roomChannel!.subscribeIfNotUnsubscribed();
      AppLogger.info('SignalingService', 'Subscribed to call room: $channelName');
    } catch (e, st) {
      AppLogger.error('SubscribeRoomChannelError', e, st);
    }
  }

  Future<void> leaveCallRoom() async {
    if (_roomChannel != null) {
      try {
        _roomChannelSub?.cancel();
        _roomChannelSub = null;
        _roomChannel?.unsubscribe();
        AppLogger.info('SignalingService', 'Unsubscribed from call room: $_currentRoomChannelName');
      } catch (_) {}
      _roomChannel = null;
      _currentRoomChannelName = null;
    }
  }

  void _handleChannelEvent(ChannelReadEvent event) {
    final eventName = event.name;
    final data = event.tryGetDataAsMap() ?? {};

    AppLogger.info('SignalingService', 'Received Event: $eventName on channel ${event.channelName}');

    final cleanName = eventName.startsWith('.') ? eventName.substring(1) : eventName;

    switch (cleanName) {
      case 'call.incoming':
      case 'CallIncoming':
        _incomingCallController.add(data);
        break;
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
      _userChannelSub?.cancel();
      _userChannelSub = null;
      _userChannel?.unsubscribe();
      _userChannel = null;
      _currentUserChannelName = null;

      _roomChannelSub?.cancel();
      _roomChannelSub = null;
      _roomChannel?.unsubscribe();
      _roomChannel = null;
      _currentRoomChannelName = null;

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
    } catch (e, st) {
      AppLogger.error('SignalingServiceDisconnectError', e, st);
    }
  }
}
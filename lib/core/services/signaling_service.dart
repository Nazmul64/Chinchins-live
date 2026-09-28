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
  final Map<String, int> _recentEventSignatures = {};

  bool _isDuplicateEvent(String eventName, Map<String, dynamic> data) {
    // NEVER drop WebRTC signaling events (offer, answer, candidate) or call state transitions
    final lower = eventName.toLowerCase();
    if (lower.contains('signal') ||
        lower.contains('offer') ||
        lower.contains('answer') ||
        lower.contains('candidate') ||
        lower.contains('webrtc') ||
        lower.contains('ice') ||
        lower.contains('call')) {
      return false;
    }

    final msgId = data['id'] ?? data['message_id'] ?? data['message']?['id'];
    final msgText = data['message'] is String ? data['message'] : data['message']?['message'] ?? data['text'];
    final senderId = data['sender_id'] ?? data['user_id'] ?? data['message']?['sender_id'];
    final sig = '${eventName}_${msgId ?? ''}_${senderId ?? ''}_${msgText ?? ''}';

    final now = DateTime.now().millisecondsSinceEpoch;
    _recentEventSignatures.removeWhere((_, time) => now - time > 3500);

    if (_recentEventSignatures.containsKey(sig)) {
      return true;
    }
    _recentEventSignatures[sig] = now;
    return false;
  }

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

  final StreamController<Map<String, dynamic>> _inCallMessageController =
      StreamController<Map<String, dynamic>>.broadcast();
  final StreamController<Map<String, dynamic>> _liveMessageController =
      StreamController<Map<String, dynamic>>.broadcast();
  final StreamController<Map<String, dynamic>> _liveGiftController =
      StreamController<Map<String, dynamic>>.broadcast();
  final StreamController<Map<String, dynamic>> _liveJoinRequestController =
      StreamController<Map<String, dynamic>>.broadcast();
  final StreamController<Map<String, dynamic>> _liveJoinResponseController =
      StreamController<Map<String, dynamic>>.broadcast();
  final StreamController<Map<String, dynamic>> _liveGuestKickedController =
      StreamController<Map<String, dynamic>>.broadcast();
  final StreamController<Map<String, dynamic>> _liveStreamEndedController =
      StreamController<Map<String, dynamic>>.broadcast();
  final StreamController<Map<String, dynamic>> _streamStatusChangedController =
      StreamController<Map<String, dynamic>>.broadcast();
  final StreamController<Map<String, dynamic>> _liveMessageSentController =
      StreamController<Map<String, dynamic>>.broadcast();
  final StreamController<Map<String, dynamic>> _cohostStatusController =
      StreamController<Map<String, dynamic>>.broadcast();
  final StreamController<Map<String, dynamic>> _coHostAcceptedController =
      StreamController<Map<String, dynamic>>.broadcast();
  final StreamController<Map<String, dynamic>> _webRTCSignalController =
      StreamController<Map<String, dynamic>>.broadcast();
  final StreamController<Map<String, dynamic>> _audioMuteController =
      StreamController<Map<String, dynamic>>.broadcast();
  final StreamController<Map<String, dynamic>> _directMessageReceivedController =
      StreamController<Map<String, dynamic>>.broadcast();
  final StreamController<Map<String, dynamic>> _liveLikeController =
      StreamController<Map<String, dynamic>>.broadcast();
  final StreamController<Map<String, dynamic>> _seatRequestController =
      StreamController<Map<String, dynamic>>.broadcast();
  final StreamController<Map<String, dynamic>> _viewerCountUpdatedController =
      StreamController<Map<String, dynamic>>.broadcast();
  final StreamController<Map<String, dynamic>> _hostPrivateCallStatusController =
      StreamController<Map<String, dynamic>>.broadcast();

  Stream<Map<String, dynamic>> get onIncomingCall => _incomingCallController.stream;
  Stream<Map<String, dynamic>> get onCallAccepted => _callAcceptedController.stream;
  Stream<Map<String, dynamic>> get onCallRejected => _callRejectedController.stream;
  Stream<Map<String, dynamic>> get onCallCancelled => _callCancelledController.stream;
  Stream<Map<String, dynamic>> get onCallEnded => _callEndedController.stream;
  Stream<Map<String, dynamic>> get onWebRTCOffer => _offerController.stream;
  Stream<Map<String, dynamic>> get onWebRTCAnswer => _answerController.stream;
  Stream<Map<String, dynamic>> get onWebRTCICECandidate => _iceCandidateController.stream;
  Stream<Map<String, dynamic>> get onInCallMessage => _inCallMessageController.stream;
  Stream<Map<String, dynamic>> get onDirectMessageReceived => _directMessageReceivedController.stream;
  Stream<Map<String, dynamic>> get onLiveMessage => _liveMessageController.stream;
  Stream<Map<String, dynamic>> get onLiveGift => _liveGiftController.stream;
  Stream<Map<String, dynamic>> get onLiveJoinRequest => _liveJoinRequestController.stream;
  Stream<Map<String, dynamic>> get onLiveJoinResponse => _liveJoinResponseController.stream;
  Stream<Map<String, dynamic>> get onLiveGuestKicked => _liveGuestKickedController.stream;
  Stream<Map<String, dynamic>> get onLiveStreamEnded => _liveStreamEndedController.stream;
  Stream<Map<String, dynamic>> get onStreamStatusChanged => _streamStatusChangedController.stream;
  Stream<Map<String, dynamic>> get onLiveMessageSent => _liveMessageSentController.stream;
  Stream<Map<String, dynamic>> get onCoHostStatusChanged => _cohostStatusController.stream;
  Stream<Map<String, dynamic>> get onCoHostAccepted => _coHostAcceptedController.stream;
  Stream<Map<String, dynamic>> get onWebRTCSignal => _webRTCSignalController.stream;
  Stream<Map<String, dynamic>> get onAudioMuteToggled => _audioMuteController.stream;
  Stream<Map<String, dynamic>> get onLiveLike => _liveLikeController.stream;
  Stream<Map<String, dynamic>> get onSeatRequest => _seatRequestController.stream;
  Stream<Map<String, dynamic>> get onViewerCountUpdated => _viewerCountUpdatedController.stream;
  Stream<Map<String, dynamic>> get onHostPrivateCallStatus => _hostPrivateCallStatusController.stream;

  void sendHostPrivateCallStatus({
    required dynamic liveRoomId,
    required bool isOnPrivateCall,
  }) {
    _hostPrivateCallStatusController.add({
      'live_room_id': liveRoomId,
      'is_on_private_call': isOnPrivateCall,
    });
  }

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

      // Subscribe to global lobby & stream feeds
      await _subscribeToChannel('global-live-feed', isPrivate: false);
      await _subscribeToChannel('stream-lobby', isPrivate: false);
      await _subscribeToChannel('live-feed', isPrivate: false);
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
      await _subscribeToChannel('user-chat.$uIdStr', isPrivate: false);
      await _subscribeToChannel('private-user-chat.$uIdStr', isPrivate: true);
      await _subscribeToChannel('chat.$uIdStr', isPrivate: false);
      await _subscribeToChannel('private-chat.$uIdStr', isPrivate: true);
      await _subscribeToChannel('private-user.$uIdStr', isPrivate: true);
      await _subscribeToChannel('user.$uIdStr', isPrivate: false);
      await _subscribeToChannel('calls.$uIdStr', isPrivate: false);
      await _subscribeToChannel('private-calls.$uIdStr', isPrivate: true);
      await _subscribeToChannel('call.$uIdStr', isPrivate: false);
      await _subscribeToChannel('private-call.$uIdStr', isPrivate: true);
      await _subscribeToChannel('user-calls.$uIdStr', isPrivate: false);
      await _subscribeToChannel('private-user-calls.$uIdStr', isPrivate: true);
    }

    if (accountId != null) {
      final accIdStr = accountId.toString().trim();
      if (accIdStr.isNotEmpty && accIdStr != uIdStr) {
        await _subscribeToChannel('user-chat.$accIdStr', isPrivate: false);
        await _subscribeToChannel('private-user-chat.$accIdStr', isPrivate: true);
        await _subscribeToChannel('chat.$accIdStr', isPrivate: false);
        await _subscribeToChannel('private-chat.$accIdStr', isPrivate: true);
        await _subscribeToChannel('private-user.$accIdStr', isPrivate: true);
        await _subscribeToChannel('user.$accIdStr', isPrivate: false);
        await _subscribeToChannel('calls.$accIdStr', isPrivate: false);
        await _subscribeToChannel('private-calls.$accIdStr', isPrivate: true);
        await _subscribeToChannel('call.$accIdStr', isPrivate: false);
        await _subscribeToChannel('private-call.$accIdStr', isPrivate: true);
        await _subscribeToChannel('user-calls.$accIdStr', isPrivate: false);
        await _subscribeToChannel('private-user-calls.$accIdStr', isPrivate: true);
      }
    }
  }

  Future<void> subscribeToCallRoom(String roomId) async {
    if (_pusherClient == null || roomId.isEmpty) return;
    final rId = roomId.trim();
    await _subscribeToChannel('presence-call.$rId', isPrivate: true);
    await _subscribeToChannel('private-call.$rId', isPrivate: true);
    await _subscribeToChannel('call.$rId', isPrivate: false);
    await _subscribeToChannel('private-call_chat.$rId', isPrivate: true);
    await _subscribeToChannel('call_chat.$rId', isPrivate: false);
  }

  Future<void> leaveCallRoom([String? roomId]) async {
    final rId = roomId?.trim() ?? '';
    final toRemove = _activeChannels.keys.where((k) => 
      k.contains('call.$rId') || k.contains('call_chat.$rId') || (rId.isEmpty && (k.contains('call.') || k.contains('call_chat.')))
    ).toList();
    for (final chName in toRemove) {
      try {
        _activeSubscriptions[chName]?.cancel();
        _activeSubscriptions.remove(chName);
        _activeChannels[chName]?.unsubscribe();
        _activeChannels.remove(chName);
      } catch (_) {}
    }
  }

  Future<void> subscribeToPartyRoom(dynamic partyRoomId) async {
    if (_pusherClient == null || partyRoomId == null) return;
    final idStr = partyRoomId.toString().trim();
    if (idStr.isEmpty) return;
    await _subscribeToChannel('party.' + idStr, isPrivate: false);
    await _subscribeToChannel('party-room.' + idStr, isPrivate: false);
    await _subscribeToChannel('private-party-room.' + idStr, isPrivate: true);
    await _subscribeToChannel('party-room-seat.' + idStr, isPrivate: false);
    await _subscribeToChannel('presence-party.' + idStr, isPrivate: true);
    await _subscribeToChannel('presence-party-room.' + idStr, isPrivate: true);
  }

  Future<void> leavePartyRoom(dynamic partyRoomId) async {
    final idStr = partyRoomId?.toString().trim() ?? '';
    final toRemove = _activeChannels.keys.where((k) =>
      k.contains('party.' + idStr) || k.contains('party-room.' + idStr) || (idStr.isEmpty && (k.contains('party.') || k.contains('party-room.')))
    ).toList();
    for (final chName in toRemove) {
      try {
        _activeSubscriptions[chName]?.cancel();
        _activeSubscriptions.remove(chName);
        _activeChannels[chName]?.unsubscribe();
        _activeChannels.remove(chName);
      } catch (_) {}
    }
  }

  Future<void> subscribeToLiveRoom(dynamic liveId) async {
    if (_pusherClient == null || liveId == null) return;
    final idStr = liveId.toString().trim();
    if (idStr.isEmpty) return;
    await _subscribeToChannel('presence-stream.$idStr', isPrivate: true);
    await _subscribeToChannel('stream.$idStr', isPrivate: false);
    await _subscribeToChannel('private-stream.$idStr', isPrivate: true);
    await _subscribeToChannel('presence-live-room.$idStr', isPrivate: true);
    await _subscribeToChannel('presence-live-stream.$idStr', isPrivate: true);
    await _subscribeToChannel('presence-live.$idStr', isPrivate: true);
    await _subscribeToChannel('private-live-room.$idStr', isPrivate: true);
    await _subscribeToChannel('private-live-stream.$idStr', isPrivate: true);
    await _subscribeToChannel('private-live.$idStr', isPrivate: true);
    await _subscribeToChannel('live-room.$idStr', isPrivate: false);
    await _subscribeToChannel('live-stream.$idStr', isPrivate: false);
    await _subscribeToChannel('live.$idStr', isPrivate: false);
  }

  Future<void> leaveLiveRoom(dynamic liveId) async {
    final idStr = liveId?.toString().trim() ?? '';
    final toRemove = _activeChannels.keys.where((k) => 
      k.contains('stream.$idStr') ||
      k.contains('live-room.$idStr') ||
      k.contains('live-stream.$idStr') ||
      k.contains('live.$idStr') ||
      (idStr.isEmpty && (k.contains('stream.') || k.contains('live-room.') || k.contains('live-stream.') || k.contains('live.')))
    ).toList();
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
    final chName = event.channelName;
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

    AppLogger.info('SignalingService', 'Received Event: $eventName on channel $chName');

    final cleanName = eventName.startsWith('.') ? eventName.substring(1) : eventName;
    final lowerName = cleanName.toLowerCase();

    final isCallChannel = chName.contains('call.') ||
        chName.contains('call_chat.') ||
        chName.contains('presence-call.') ||
        chName.contains('private-call.') ||
        data.containsKey('call_session_id') ||
        (data['message'] is Map && data['message']['call_session_id'] != null);

    final isLiveRoomChannel = chName.contains('presence-stream.') ||
        chName.contains('stream.') ||
        chName.contains('live-room.') ||
        chName.contains('live-stream.') ||
        chName.contains('party.') ||
        chName.contains('party-room.') ||
        chName.contains('presence-party.') ||
        chName.contains('live.');

    final isUserChatChannel = chName.contains('user-chat.') ||
        chName.contains('chat.') ||
        chName.contains('conversation.');

    if (_isDuplicateEvent(cleanName, data)) {
      return;
    }

    // 1. IN-CALL GIFTS & LIVE GIFTS BROADCAST
    if (cleanName == 'gift.received' ||
        cleanName == 'GiftSentEvent' ||
        cleanName.endsWith('GiftSentEvent') ||
        cleanName == 'LiveGiftSentEvent' ||
        cleanName.endsWith('LiveGiftSentEvent') ||
        cleanName == 'PartyRoomGiftEvent' ||
        cleanName.endsWith('PartyRoomGiftEvent') ||
        cleanName == 'LiveGiftSent' ||
        cleanName == 'live.gift.sent' ||
        cleanName == 'live.gift' ||
        lowerName.contains('gift.received') ||
        lowerName.contains('giftsent') ||
        data['type'] == 'gift' ||
        data['gift_id'] != null ||
        data['gift'] != null ||
        data['gift_data'] != null) {
      _liveGiftController.add(data);
      if (isCallChannel) {
        _inCallMessageController.add(data);
      }
      return;
    }

    // 2. IN-CALL REAL-TIME CHAT MESSAGES
    if (isCallChannel && (cleanName == 'message.sent' ||
        cleanName == 'MessageSentEvent' ||
        cleanName.endsWith('MessageSentEvent') ||
        cleanName == 'CallMessageEvent' ||
        cleanName.endsWith('CallMessageEvent') ||
        cleanName == 'InCallMessageSent' ||
        cleanName == 'CallMessageSent' ||
        cleanName == 'call.message.sent' ||
        cleanName == 'call.message' ||
        cleanName == 'chat_message' ||
        lowerName.contains('callmessage') ||
        lowerName.contains('incallmessage') ||
        lowerName == 'message.sent')) {
      _inCallMessageController.add(data);
      return;
    }

    // 3. DIRECT 1-ON-1 USER CHAT MESSAGES
    if (isUserChatChannel && (cleanName == 'message.sent' ||
        cleanName == 'message.received' ||
        cleanName == 'DirectMessageSent' ||
        cleanName.endsWith('DirectMessageSent') ||
        cleanName == 'MessageSentEvent' ||
        cleanName.endsWith('MessageSentEvent') ||
        cleanName == 'direct.message.sent' ||
        lowerName == 'message.sent')) {
      _directMessageReceivedController.add(data);
      _inCallMessageController.add(data);
      return;
    }

    // 4. LIVE / PARTY ROOM BROADCAST CHAT COMMENTS
    if (isLiveRoomChannel && (cleanName == 'message.sent' ||
        cleanName == 'chat.message' ||
        cleanName == 'PartyRoomMessageSent' ||
        cleanName.endsWith('PartyRoomMessageSent') ||
        cleanName == 'PartyRoomMessageEvent' ||
        cleanName.endsWith('PartyRoomMessageEvent') ||
        cleanName == 'PartyRoomMessage' ||
        cleanName == 'LiveChatMessageEvent' ||
        cleanName.endsWith('LiveChatMessageEvent') ||
        cleanName == 'ChatMessageEvent' ||
        cleanName.endsWith('ChatMessageEvent') ||
        cleanName == 'LiveMessageSent' ||
        cleanName == 'live.message.sent' ||
        cleanName == 'live.message' ||
        lowerName.contains('partymessage') ||
        lowerName.contains('partyroommessage') ||
        lowerName == 'chat.message' ||
        lowerName == 'message.sent')) {
      _liveMessageSentController.add(data);
      _liveMessageController.add(data);
      return;
    }

    // 5. GENERIC FALLBACK FOR message.sent IF NOT CAUGHT
    if (cleanName == 'message.sent' || cleanName == 'chat.message' || cleanName == 'MessageSentEvent' || lowerName == 'message.sent' || lowerName == 'chat.message') {
      _inCallMessageController.add(data);
      _directMessageReceivedController.add(data);
      _liveMessageController.add(data);
      return;
    }

    // 6. Seat Request Event (SeatRequestEvent -> seat.requested / join.requested)
    // 6. Seat / Co-Host Request Event (SeatRequestEvent -> seat.requested / join.requested / live_join.requested)
    if (cleanName == 'seat.requested' ||
        cleanName == 'SeatRequestEvent' ||
        cleanName.endsWith('SeatRequestEvent') ||
        cleanName == 'join.requested' ||
        cleanName == 'JoinRequestEvent' ||
        cleanName.endsWith('JoinRequestEvent') ||
        cleanName == 'LiveJoinRequested' ||
        cleanName == 'LiveJoinRequestedEvent' ||
        cleanName.endsWith('LiveJoinRequestedEvent') ||
        cleanName == 'live.join.requested' ||
        cleanName == 'live_join.requested' ||
        lowerName == 'seat.requested' ||
        lowerName == 'seatrequestevent' ||
        lowerName == 'join.requested' ||
        lowerName == 'live_join.requested' ||
        lowerName == 'live.join.requested' ||
        lowerName.contains('joinrequest')) {
      _seatRequestController.add(data);
      _liveJoinRequestController.add(data);
      _cohostStatusController.add(data);
      return;
    }

    // 6a. LiveKit / Reverb Co-Host Accepted Trigger (CoHostAcceptedEvent -> cohost.accepted)
    if (cleanName == 'cohost.accepted' ||
        cleanName == 'CoHostAcceptedEvent' ||
        cleanName.endsWith('CoHostAcceptedEvent') ||
        cleanName == 'CoHostAccepted' ||
        cleanName == 'live.cohost.accepted' ||
        lowerName == 'cohost.accepted' ||
        lowerName == 'cohostaccepted') {
      _coHostAcceptedController.add(data);
      _cohostStatusController.add(data);
      _liveJoinResponseController.add(data);
      return;
    }

    // 6b. Co-Host Status Changed (CoHostStatusEvent -> cohost.status.changed)
    if (cleanName == 'cohost.status.changed' ||
        cleanName == 'CoHostStatusEvent' ||
        cleanName.endsWith('CoHostStatusEvent') ||
        cleanName == 'live.cohost.status' ||
        lowerName == 'cohost.status.changed' ||
        lowerName.contains('cohost')) {
      _cohostStatusController.add(data);
      _liveJoinRequestController.add(data);
      return;
    }

    // 7. WebRTC Signal (WebRTCSignalEvent / CallSignalEvent / webrtc.signal / call.signal / signal.sent / offer / answer / candidate)
    if (cleanName == 'webrtc.signal' ||
        cleanName == 'WebRTCSignalEvent' ||
        cleanName == 'CallSignalEvent' ||
        cleanName == 'SignalSent' ||
        cleanName == 'SignalSentEvent' ||
        cleanName == 'SignalEvent' ||
        cleanName == 'call.signal' ||
        cleanName == 'call.signal.sent' ||
        cleanName == 'signal.sent' ||
        cleanName == 'call_signal' ||
        cleanName.endsWith('WebRTCSignalEvent') ||
        cleanName.endsWith('CallSignalEvent') ||
        cleanName.endsWith('SignalSentEvent') ||
        cleanName.endsWith('SignalEvent') ||
        lowerName == 'webrtc.signal' ||
        lowerName == 'call.signal' ||
        lowerName == 'signal.sent' ||
        cleanName == 'webrtc.offer' ||
        cleanName == 'WebRTCOffer' ||
        cleanName == 'CallOfferEvent' ||
        cleanName == 'call.offer' ||
        cleanName.endsWith('WebRTCOffer') ||
        cleanName.endsWith('CallOfferEvent') ||
        cleanName == 'webrtc.answer' ||
        cleanName == 'WebRTCAnswer' ||
        cleanName == 'CallAnswerEvent' ||
        cleanName == 'call.answer' ||
        cleanName.endsWith('WebRTCAnswer') ||
        cleanName.endsWith('CallAnswerEvent') ||
        cleanName == 'webrtc.ice_candidate' ||
        cleanName == 'WebRTCICECandidate' ||
        cleanName == 'CallCandidateEvent' ||
        cleanName == 'call.candidate' ||
        cleanName.endsWith('WebRTCICECandidate') ||
        cleanName.endsWith('CallCandidateEvent') ||
        lowerName.contains('signal') ||
        (isCallChannel && (data.containsKey('sdp') || data.containsKey('candidate') || (data['payload'] is Map && (data['payload']['sdp'] != null || data['payload']['candidate'] != null))))) {
      _webRTCSignalController.add(data);
      
      dynamic rawPayload = data['payload'];
      if (rawPayload is String) {
        try {
          rawPayload = jsonDecode(rawPayload);
        } catch (_) {}
      }
      final Map payloadMap = (rawPayload is Map) ? rawPayload : data;

      final type = (data['type'] ?? payloadMap['type'] ?? data['signal_type'] ?? cleanName).toString().toLowerCase();
      if (type.contains('offer')) {
        _offerController.add(data);
      } else if (type.contains('answer')) {
        _answerController.add(data);
      } else if (type.contains('candidate') || type.contains('ice')) {
        _iceCandidateController.add(data);
      }
      return;
    }

    // 8. Audio Mute / Unmute (AudioMuteEvent -> audio.mute.toggled)
    if (cleanName == 'audio.mute.toggled' ||
        cleanName == 'AudioMuteEvent' ||
        cleanName.endsWith('AudioMuteEvent') ||
        lowerName == 'audio.mute.toggled' ||
        lowerName.contains('audiomute')) {
      _audioMuteController.add(data);
      return;
    }

    // 9. Incoming Call
    if (cleanName == 'call.incoming' ||
        cleanName == 'CallIncoming' ||
        cleanName == 'incoming.call' ||
        cleanName == 'incoming_call' ||
        cleanName == 'call.initiated' ||
        cleanName == 'CallInitiated' ||
        cleanName == 'call_invitation' ||
        cleanName == 'CallInvitation' ||
        cleanName == 'private_call.incoming' ||
        cleanName == 'private_call.initiated' ||
        cleanName.endsWith('IncomingCallEvent') ||
        cleanName.endsWith('CallIncomingEvent') ||
        cleanName.endsWith('CallInitiatedEvent') ||
        cleanName.endsWith('CallInvitationEvent') ||
        cleanName.endsWith('PrivateCallIncomingEvent') ||
        lowerName.contains('incoming') ||
        lowerName.contains('call_initiated') ||
        lowerName.contains('callinitiated') ||
        lowerName.contains('call_invite') ||
        lowerName.contains('callinvite') ||
        ((data.containsKey('caller') || data.containsKey('sender') || data.containsKey('caller_id') || data.containsKey('caller_name')) &&
            (data.containsKey('call_id') || data.containsKey('channel_name') || data.containsKey('call_session_id')))) {
      _incomingCallController.add(data);
      return;
    }

    if (cleanName == 'LiveJoinResponded' ||
        cleanName == 'LiveJoinRespondedEvent' ||
        cleanName.endsWith('LiveJoinRespondedEvent') ||
        cleanName == 'live.join.responded' ||
        cleanName == 'live_join.responded' ||
        cleanName == 'live.cohost.response' ||
        lowerName == 'live_join.responded' ||
        lowerName == 'live.join.responded' ||
        lowerName.contains('joinrespond')) {
      _liveJoinResponseController.add(data);
      _cohostStatusController.add(data);
      return;
    }

    if (cleanName == 'LiveGuestKicked' ||
        cleanName == 'live.guest.kicked' ||
        lowerName.contains('guestkicked')) {
      _liveGuestKickedController.add(data);
      return;
    }

    // 9b. Live Stream Status Changed / Ended (Lobby & Feed sync)
    if (cleanName == 'StreamStatusChanged' ||
        cleanName == 'StreamStatusChangedEvent' ||
        cleanName.endsWith('StreamStatusChanged') ||
        cleanName.endsWith('StreamStatusChangedEvent') ||
        cleanName == 'stream.status.changed' ||
        lowerName.contains('streamstatuschanged')) {
      _streamStatusChangedController.add(data);
      final status = (data['status'] ?? data['action'])?.toString().toLowerCase();
      if (status == 'ended' || status == 'closed' || status == 'stopped') {
        _liveStreamEndedController.add(data);
      }
      return;
    }

    // 9c. Live Stream Hold & Resume Events (Mandate 2 & 4: StreamHoldEvent / StreamResumeEvent)
    if (cleanName == 'StreamHoldEvent' ||
        cleanName.endsWith('StreamHoldEvent') ||
        cleanName == 'stream.hold' ||
        cleanName == 'StreamHold' ||
        lowerName.contains('streamhold') ||
        (data['status'] == 'paused' && data['is_paused'] == true)) {
      _hostPrivateCallStatusController.add({
        'is_on_private_call': true,
        'is_on_call': true,
        'back_soon_text': data['message'] ?? 'I will come back soon',
        ...data,
      });
      return;
    }

    if (cleanName == 'StreamResumeEvent' ||
        cleanName.endsWith('StreamResumeEvent') ||
        cleanName == 'stream.resume' ||
        cleanName == 'StreamResume' ||
        lowerName.contains('streamresume') ||
        (data['status'] == 'live' && data['is_paused'] == false)) {
      _hostPrivateCallStatusController.add({
        'is_on_private_call': false,
        'is_on_call': false,
        'status': 'live',
        ...data,
      });
      return;
    }

    // 9d. Live Host On 1-on-1 Call Status (LiveHostOnCallEvent -> host.call_status / host.private_call)
    if (cleanName == 'LiveHostOnCallEvent' ||
        cleanName.endsWith('LiveHostOnCallEvent') ||
        cleanName == 'host.call_status' ||
        cleanName == 'host.private_call' ||
        cleanName == 'host.on_call' ||
        lowerName.contains('hostoncall') ||
        lowerName.contains('host_call_status') ||
        lowerName.contains('private_call')) {
      _hostPrivateCallStatusController.add(data);
      return;
    }

    if (cleanName == 'LiveStreamEnded' ||
        cleanName == 'LiveStreamEndedEvent' ||
        cleanName.endsWith('LiveStreamEndedEvent') ||
        cleanName == 'live.stream.ended' ||
        cleanName == 'live_stream.ended' ||
        cleanName == 'live.ended' ||
        cleanName == 'party_room.ended' ||
        cleanName == 'PartyRoomEnded' ||
        cleanName == 'PartyRoomEndedEvent' ||
        cleanName.endsWith('PartyRoomEndedEvent') ||
        lowerName == 'live_stream.ended' ||
        lowerName == 'live.stream.ended' ||
        lowerName == 'live.ended' ||
        lowerName == 'party_room.ended' ||
        lowerName.contains('streamended') ||
        lowerName.contains('livestreamended') ||
        lowerName.contains('partyroomended')) {
      _liveStreamEndedController.add(data);
      _streamStatusChangedController.add({'status': 'ended', ...data});
      return;
    }

    // 10. Live Like / Floating Heart Reaction (LiveLikeSent -> live.like)
    if (cleanName == 'live.like' ||
        cleanName == 'LiveLikeSent' ||
        cleanName.endsWith('LiveLikeSent') ||
        cleanName == 'LiveLikeEvent' ||
        lowerName.contains('livelike') ||
        lowerName == 'live.like') {
      _liveLikeController.add(data);
      return;
    }

    // 11. Live Viewer Count Updated (LiveViewerCountUpdated -> viewer.updated)
    if (cleanName == 'viewer.updated' ||
        cleanName == 'LiveViewerCountUpdated' ||
        cleanName.endsWith('LiveViewerCountUpdated') ||
        cleanName == 'ViewerCountUpdated' ||
        lowerName.contains('viewercount') ||
        lowerName == 'viewer.updated') {
      _viewerCountUpdatedController.add(data);
      return;
    }

    // 12. Call Accepted (CallAccepted / call.accepted / private_call.accepted)
    if (cleanName == 'call.accepted' ||
        cleanName == 'CallAccepted' ||
        cleanName == 'CallAcceptedEvent' ||
        cleanName == 'private_call.accepted' ||
        cleanName == 'PrivateCallAccepted' ||
        cleanName == 'PrivateCallAcceptedEvent' ||
        cleanName.endsWith('CallAcceptedEvent') ||
        cleanName.endsWith('PrivateCallAcceptedEvent') ||
        lowerName == 'call.accepted' ||
        lowerName == 'callaccepted' ||
        lowerName == 'call_accepted' ||
        lowerName == 'private_call.accepted' ||
        lowerName == 'privatecallaccepted' ||
        (data['status'] == 'accepted' || data['action'] == 'call_accepted' || data['type'] == 'accepted')) {
      _callAcceptedController.add(data);
      return;
    }

    // 13. Call Rejected (CallRejected / call.rejected / private_call.rejected)
    if (cleanName == 'call.rejected' ||
        cleanName == 'CallRejected' ||
        cleanName == 'CallRejectedEvent' ||
        cleanName == 'private_call.rejected' ||
        cleanName == 'PrivateCallRejected' ||
        cleanName == 'PrivateCallRejectedEvent' ||
        cleanName.endsWith('CallRejectedEvent') ||
        cleanName.endsWith('PrivateCallRejectedEvent') ||
        lowerName == 'call.rejected' ||
        lowerName == 'callrejected' ||
        lowerName == 'call_rejected' ||
        lowerName == 'private_call.rejected' ||
        lowerName == 'privatecallrejected' ||
        (data['status'] == 'rejected' || data['action'] == 'call_rejected' || data['type'] == 'rejected')) {
      _callRejectedController.add(data);
      return;
    }

    // 14. Call Cancelled (CallCancelled / call.cancelled / private_call.cancelled)
    if (cleanName == 'call.cancelled' ||
        cleanName == 'CallCancelled' ||
        cleanName == 'CallCancelledEvent' ||
        cleanName == 'private_call.cancelled' ||
        cleanName == 'PrivateCallCancelled' ||
        cleanName == 'PrivateCallCancelledEvent' ||
        cleanName.endsWith('CallCancelledEvent') ||
        cleanName.endsWith('PrivateCallCancelledEvent') ||
        lowerName == 'call.cancelled' ||
        lowerName == 'callcancelled' ||
        lowerName == 'call_cancelled' ||
        lowerName == 'private_call.cancelled' ||
        lowerName == 'privatecallcancelled' ||
        (data['status'] == 'cancelled' || data['action'] == 'call_cancelled' || data['type'] == 'cancelled')) {
      _callCancelledController.add(data);
      return;
    }

    // 15. Call Ended (CallEnded / call.ended / private_call.ended)
    if (cleanName == 'call.ended' ||
        cleanName == 'CallEnded' ||
        cleanName == 'CallEndedEvent' ||
        cleanName == 'private_call.ended' ||
        cleanName == 'PrivateCallEnded' ||
        cleanName == 'PrivateCallEndedEvent' ||
        cleanName.endsWith('CallEndedEvent') ||
        cleanName.endsWith('PrivateCallEndedEvent') ||
        lowerName == 'call.ended' ||
        lowerName == 'callended' ||
        lowerName == 'call_ended' ||
        lowerName == 'private_call.ended' ||
        lowerName == 'privatecallended' ||
        (data['action'] == 'call_ended') ||
        (data['type'] == 'bye' || data['type'] == 'hangup' || data['type'] == 'ended') ||
        (data['status'] == 'completed' && isCallChannel)) {
      _callEndedController.add(data);
      return;
    }

    if (cleanName == 'webrtc.offer' || cleanName == 'WebRTCOffer' || cleanName.endsWith('WebRTCOffer')) {
      _offerController.add(data);
      return;
    }

    if (cleanName == 'webrtc.answer' || cleanName == 'WebRTCAnswer' || cleanName.endsWith('WebRTCAnswer')) {
      _answerController.add(data);
      return;
    }

    if (cleanName == 'webrtc.ice_candidate' || cleanName == 'WebRTCICECandidate' || cleanName.endsWith('WebRTCICECandidate')) {
      _iceCandidateController.add(data);
      return;
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
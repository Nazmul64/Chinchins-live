import 'dart:async';
import 'dart:convert';
import 'package:dart_pusher_channels/dart_pusher_channels.dart';
import 'package:flutter/foundation.dart';
import '../../config/app_config.dart';
import '../models/live_gift_event.dart';
import '../models/group_room.dart';
import '../utils/app_logger.dart';

class LiveGiftReverbService {
  static final LiveGiftReverbService _instance = LiveGiftReverbService._internal();
  factory LiveGiftReverbService() => _instance;
  LiveGiftReverbService._internal();

  PusherChannelsClient? _pusherClient;
  bool _isInitialized = false;
  bool _isConnected = false;
  String? _activeStreamId;

  bool get isConnected => _isConnected;
  PusherChannelsClient? get pusherClient => _pusherClient;

  final StreamController<LiveGiftEvent> _giftStreamController =
      StreamController<LiveGiftEvent>.broadcast();
  Stream<LiveGiftEvent> get giftStream => _giftStreamController.stream;

  final StreamController<PartyRoomMessage> _messageStreamController =
      StreamController<PartyRoomMessage>.broadcast();
  Stream<PartyRoomMessage> get messageStream => _messageStreamController.stream;

  final StreamController<Map<String, dynamic>> _seatUpdatedStreamController =
      StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get seatUpdatedStream => _seatUpdatedStreamController.stream;

  final StreamController<Map<String, dynamic>> _seatRequestStreamController =
      StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get seatRequestStream => _seatRequestStreamController.stream;

  final Map<String, Channel> _subscribedChannels = {};
  final Map<String, List<StreamSubscription>> _channelSubscriptions = {};
  final Map<String, List<Function(LiveGiftEvent)>> _roomListeners = {};
  final Map<String, List<Function(PartyRoomMessage)>> _roomMessageListeners = {};
  final Map<String, List<Function(Map<String, dynamic>)>> _roomSeatListeners = {};
  final Map<String, List<Function(Map<String, dynamic>)>> _roomSeatRequestListeners = {};

  /// Initialize and connect to Laravel Reverb WebSocket via dart_pusher_channels
  Future<void> init() async {
    if (_isInitialized && _pusherClient != null && !_pusherClient!.isDisposed) {
      return;
    }

    try {
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
          AppLogger.error('LiveGiftReverbError', 'WebSocket Error: $exception', trace);
          refresh();
        },
      );

      _pusherClient!.lifecycleStream.listen((state) {
        debugPrint('[LiveGiftReverb] State: $state');
        _isConnected = (state == PusherChannelsClientLifeCycleState.establishedConnection);
      });

      _pusherClient!.onConnectionEstablished.listen((_) {
        debugPrint('[LiveGiftReverb] Connection established with Reverb server');
        for (final channel in _subscribedChannels.values) {
          channel.subscribeIfNotUnsubscribed();
        }
      });

      await _pusherClient!.connect();
      _isInitialized = true;
      _isConnected = true;
      debugPrint('[LiveGiftReverbService] Connected to Reverb on ${AppConfig.reverbHost}:$port');
    } catch (e, st) {
      AppLogger.error('LiveGiftReverbInitError', e, st);
    }
  }

  /// Subscribe to a specific party/live streaming room channel
  Future<void> subscribeToLiveRoom({
    required String streamId,
    required Function(LiveGiftEvent) onGiftReceived,
    Function(PartyRoomMessage)? onMessageReceived,
    Function(Map<String, dynamic>)? onSeatUpdated,
    Function(Map<String, dynamic>)? onSeatRequested,
  }) async {
    final cleanStreamId = streamId
        .replaceAll('live-stream.', '')
        .replaceAll('presence-stream.', '')
        .replaceAll('stream.', '')
        .replaceAll('party.', '')
        .replaceAll('party-room.', '');
    _activeStreamId = cleanStreamId;

    if (!_roomListeners.containsKey(cleanStreamId)) {
      _roomListeners[cleanStreamId] = [];
    }
    _roomListeners[cleanStreamId]!.add(onGiftReceived);

    if (onMessageReceived != null) {
      if (!_roomMessageListeners.containsKey(cleanStreamId)) {
        _roomMessageListeners[cleanStreamId] = [];
      }
      _roomMessageListeners[cleanStreamId]!.add(onMessageReceived);
    }

    if (onSeatUpdated != null) {
      if (!_roomSeatListeners.containsKey(cleanStreamId)) {
        _roomSeatListeners[cleanStreamId] = [];
      }
      _roomSeatListeners[cleanStreamId]!.add(onSeatUpdated);
    }

    if (onSeatRequested != null) {
      if (!_roomSeatRequestListeners.containsKey(cleanStreamId)) {
        _roomSeatRequestListeners[cleanStreamId] = [];
      }
      _roomSeatRequestListeners[cleanStreamId]!.add(onSeatRequested);
    }

    try {
      if (!_isInitialized || _pusherClient == null) {
        await init();
      }

      final channelNames = [
        'party.$cleanStreamId',
        'party-room.$cleanStreamId',
        'presence-party.$cleanStreamId',
        'stream.$cleanStreamId',
        'presence-stream.$cleanStreamId',
        'live-stream.$cleanStreamId',
        'live-room.$cleanStreamId',
      ];

      for (final channelName in channelNames) {
        debugPrint('[LiveGiftReverbService] Subscribing to $channelName');

        if (!_subscribedChannels.containsKey(channelName)) {
          final channel = _pusherClient!.publicChannel(channelName);
          _subscribedChannels[channelName] = channel;
          _channelSubscriptions[channelName] = [];

          channel.subscribeIfNotUnsubscribed();

          // 1. Gift Events
          final giftEvents = [
            'gift.received',
            '.gift.received',
            'GiftSentEvent',
            '.GiftSentEvent',
            'LiveGiftSentEvent',
            '.LiveGiftSentEvent',
            'PartyRoomGiftEvent',
            '.PartyRoomGiftEvent',
          ];
          for (final evt in giftEvents) {
            final sub = channel.bind(evt).listen((event) {
              _processEventData(event.data, cleanStreamId);
            });
            _channelSubscriptions[channelName]!.add(sub);
          }

          // 2. Chat Message Events
          final msgEvents = [
            'PartyRoomMessageSent',
            '.PartyRoomMessageSent',
            'PartyRoomMessageEvent',
            '.PartyRoomMessageEvent',
            'PartyRoomMessage',
            '.PartyRoomMessage',
            'party.message.sent',
            'message.sent',
            '.message.sent',
            'chat.message',
            '.chat.message',
            'LiveChatMessageEvent',
            '.LiveChatMessageEvent',
            'ChatMessageEvent',
            '.ChatMessageEvent',
          ];
          for (final evt in msgEvents) {
            final sub = channel.bind(evt).listen((event) {
              _processMessageData(event.data, cleanStreamId);
            });
            _channelSubscriptions[channelName]!.add(sub);
          }

          // 3. Seat Updated Events (Speaking indicator, Seat taken, Seat left, Muted, Kicked)
          final seatEvents = [
            'SeatUpdatedEvent',
            '.SeatUpdatedEvent',
            'seat.updated',
            '.seat.updated',
            'SeatUpdated',
            '.SeatUpdated',
          ];
          for (final evt in seatEvents) {
            final sub = channel.bind(evt).listen((event) {
              _processSeatUpdatedData(event.data, cleanStreamId);
            });
            _channelSubscriptions[channelName]!.add(sub);
          }

          // 4. Seat Request Events
          final seatRequestEvents = [
            'SeatRequestEvent',
            '.SeatRequestEvent',
            'seat.requested',
            '.seat.requested',
            'SeatRequested',
            '.SeatRequested',
            'join.requested',
            '.join.requested',
          ];
          for (final evt in seatRequestEvents) {
            final sub = channel.bind(evt).listen((event) {
              _processSeatRequestData(event.data, cleanStreamId);
            });
            _channelSubscriptions[channelName]!.add(sub);
          }
        } else {
          _subscribedChannels[channelName]!.subscribeIfNotUnsubscribed();
        }
      }
    } catch (e, st) {
      AppLogger.error('LiveGiftSubscribeError: streamId=$cleanStreamId', e, st);
    }
  }

  /// Unsubscribe from live/party room
  Future<void> unsubscribeFromLiveRoom(String streamId) async {
    final cleanStreamId = streamId
        .replaceAll('live-stream.', '')
        .replaceAll('presence-stream.', '')
        .replaceAll('stream.', '')
        .replaceAll('party.', '')
        .replaceAll('party-room.', '');
    _roomListeners.remove(cleanStreamId);
    _roomMessageListeners.remove(cleanStreamId);
    _roomSeatListeners.remove(cleanStreamId);
    _roomSeatRequestListeners.remove(cleanStreamId);

    if (_activeStreamId == cleanStreamId) {
      _activeStreamId = null;
    }

    final channelNames = [
      'party.$cleanStreamId',
      'party-room.$cleanStreamId',
      'presence-party.$cleanStreamId',
      'stream.$cleanStreamId',
      'presence-stream.$cleanStreamId',
      'live-stream.$cleanStreamId',
      'live-room.$cleanStreamId',
    ];

    for (final channelName in channelNames) {
      if (_channelSubscriptions.containsKey(channelName)) {
        for (final sub in _channelSubscriptions[channelName]!) {
          await sub.cancel();
        }
        _channelSubscriptions.remove(channelName);
      }

      if (_subscribedChannels.containsKey(channelName)) {
        _subscribedChannels[channelName]!.unsubscribe();
        _subscribedChannels.remove(channelName);
        debugPrint('[LiveGiftReverbService] Unsubscribed from $channelName');
      }
    }
  }

  /// Parse and dispatch incoming live gift events
  void _processEventData(dynamic dataObj, String streamId) {
    try {
      if (dataObj is String) {
        dataObj = jsonDecode(dataObj);
      }

      if (dataObj is Map<String, dynamic> || dataObj is Map) {
        final map = Map<String, dynamic>.from(dataObj as Map);
        if (!map.containsKey('stream_id')) {
          map['stream_id'] = streamId;
        }

        final giftEvent = LiveGiftEvent.fromJson(map);
        _giftStreamController.add(giftEvent);

        if (_roomListeners.containsKey(streamId)) {
          for (final callback in _roomListeners[streamId]!) {
            try {
              callback(giftEvent);
            } catch (cbErr) {
              debugPrint('[LiveGiftReverbService] Gift listener callback error: $cbErr');
            }
          }
        }
      }
    } catch (err, st) {
      AppLogger.error('ProcessGiftEventError', err, st);
    }
  }

  /// Parse and dispatch real-time PartyRoom chat messages
  void _processMessageData(dynamic dataObj, String streamId) {
    try {
      if (dataObj is String) {
        dataObj = jsonDecode(dataObj);
      }

      if (dataObj is Map) {
        final map = Map<String, dynamic>.from(dataObj);
        if (!map.containsKey('room_id')) {
          map['room_id'] = streamId;
        }

        final msg = PartyRoomMessage.fromJson(map);
        _messageStreamController.add(msg);

        if (_roomMessageListeners.containsKey(streamId)) {
          for (final callback in _roomMessageListeners[streamId]!) {
            try {
              callback(msg);
            } catch (cbErr) {
              debugPrint('[LiveGiftReverbService] Message listener callback error: $cbErr');
            }
          }
        }
      }
    } catch (err, st) {
      AppLogger.error('ProcessMessageEventError', err, st);
    }
  }

  /// Parse and dispatch SeatUpdated events
  void _processSeatUpdatedData(dynamic dataObj, String streamId) {
    try {
      if (dataObj is String) {
        dataObj = jsonDecode(dataObj);
      }

      if (dataObj is Map) {
        final map = Map<String, dynamic>.from(dataObj);
        _seatUpdatedStreamController.add(map);

        if (_roomSeatListeners.containsKey(streamId)) {
          for (final callback in _roomSeatListeners[streamId]!) {
            try {
              callback(map);
            } catch (cbErr) {
              debugPrint('[LiveGiftReverbService] Seat updated callback error: $cbErr');
            }
          }
        }
      }
    } catch (err, st) {
      AppLogger.error('ProcessSeatUpdatedError', err, st);
    }
  }

  /// Parse and dispatch SeatRequest events
  void _processSeatRequestData(dynamic dataObj, String streamId) {
    try {
      if (dataObj is String) {
        dataObj = jsonDecode(dataObj);
      }

      if (dataObj is Map) {
        final map = Map<String, dynamic>.from(dataObj);
        _seatRequestStreamController.add(map);

        if (_roomSeatRequestListeners.containsKey(streamId)) {
          for (final callback in _roomSeatRequestListeners[streamId]!) {
            try {
              callback(map);
            } catch (cbErr) {
              debugPrint('[LiveGiftReverbService] Seat request callback error: $cbErr');
            }
          }
        }
      }
    } catch (err, st) {
      AppLogger.error('ProcessSeatRequestError', err, st);
    }
  }

  /// Manually dispatch a local simulated gift event
  void dispatchLocalGift(LiveGiftEvent event) {
    _giftStreamController.add(event);
    if (_roomListeners.containsKey(event.streamId)) {
      for (final callback in _roomListeners[event.streamId]!) {
        callback(event);
      }
    }
  }

  Future<void> disconnect() async {
    if (_pusherClient != null && !_pusherClient!.isDisposed) {
      await _pusherClient!.disconnect();
      _pusherClient!.dispose();
      _pusherClient = null;
    }
    _isInitialized = false;
    _isConnected = false;
    _subscribedChannels.clear();
    _channelSubscriptions.clear();
    _roomListeners.clear();
    _roomMessageListeners.clear();
    _roomSeatListeners.clear();
    _roomSeatRequestListeners.clear();
  }
}

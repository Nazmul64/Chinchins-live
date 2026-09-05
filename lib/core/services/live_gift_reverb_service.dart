import 'dart:async';
import 'dart:convert';
import 'package:dart_pusher_channels/dart_pusher_channels.dart';
import 'package:flutter/foundation.dart';
import '../../config/app_config.dart';
import '../models/live_gift_event.dart';
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

  final StreamController<LiveGiftEvent> _giftStreamController =
      StreamController<LiveGiftEvent>.broadcast();

  Stream<LiveGiftEvent> get giftStream => _giftStreamController.stream;

  final Map<String, Channel> _subscribedChannels = {};
  final Map<String, List<StreamSubscription>> _channelSubscriptions = {};
  final Map<String, List<Function(LiveGiftEvent)>> _roomListeners = {};

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
        // Re-subscribe active channels if needed
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

  /// Subscribe to a specific live streaming room channel: live-stream.{streamId}
  Future<void> subscribeToLiveRoom({
    required String streamId,
    required Function(LiveGiftEvent) onGiftReceived,
  }) async {
    final cleanStreamId = streamId.replaceAll('live-stream.', '');
    _activeStreamId = cleanStreamId;

    if (!_roomListeners.containsKey(cleanStreamId)) {
      _roomListeners[cleanStreamId] = [];
    }
    _roomListeners[cleanStreamId]!.add(onGiftReceived);

    try {
      if (!_isInitialized || _pusherClient == null) {
        await init();
      }

      final channelName = 'live-stream.$cleanStreamId';
      debugPrint('[LiveGiftReverbService] Subscribing to $channelName');

      if (!_subscribedChannels.containsKey(channelName)) {
        final channel = _pusherClient!.publicChannel(channelName);
        _subscribedChannels[channelName] = channel;
        _channelSubscriptions[channelName] = [];

        channel.subscribeIfNotUnsubscribed();

        // Bind to "gift.received"
        final sub1 = channel.bind('gift.received').listen((event) {
          _processEventData(event.data, cleanStreamId);
        });
        _channelSubscriptions[channelName]!.add(sub1);

        // Bind to "LiveGiftSentEvent" class name fallback
        final sub2 = channel.bind('LiveGiftSentEvent').listen((event) {
          _processEventData(event.data, cleanStreamId);
        });
        _channelSubscriptions[channelName]!.add(sub2);
      } else {
        _subscribedChannels[channelName]!.subscribeIfNotUnsubscribed();
      }
    } catch (e, st) {
      AppLogger.error('LiveGiftSubscribeError: streamId=$cleanStreamId', e, st);
    }
  }

  /// Unsubscribe from live room
  Future<void> unsubscribeFromLiveRoom(String streamId) async {
    final cleanStreamId = streamId.replaceAll('live-stream.', '');
    _roomListeners.remove(cleanStreamId);

    if (_activeStreamId == cleanStreamId) {
      _activeStreamId = null;
    }

    final channelName = 'live-stream.$cleanStreamId';
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

        // Emit to global reactive stream
        _giftStreamController.add(giftEvent);

        // Notify room-specific callback listeners
        if (_roomListeners.containsKey(streamId)) {
          for (final callback in _roomListeners[streamId]!) {
            try {
              callback(giftEvent);
            } catch (cbErr) {
              debugPrint('[LiveGiftReverbService] Listener callback error: $cbErr');
            }
          }
        }
      }
    } catch (err, st) {
      AppLogger.error('ProcessGiftEventError', err, st);
    }
  }

  /// Manually dispatch a local simulated gift event (e.g. for instant sender feedback)
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
  }
}

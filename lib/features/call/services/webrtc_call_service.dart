import 'dart:async';
import 'dart:convert';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import '../../../core/services/signaling_service.dart';
import '../../../core/utils/app_logger.dart';
import '../../auth/services/auth_api_service.dart';
import 'call_api_service.dart';

class WebRTCCallService {
  final RTCVideoRenderer localRenderer = RTCVideoRenderer();
  final RTCVideoRenderer remoteRenderer = RTCVideoRenderer();

  MediaStream? _localStream;
  MediaStream? _remoteStream;
  RTCPeerConnection? _peerConnection;
  Timer? _signalingTimer;
  bool _isInitialized = false;
  bool _hasRemoteAnswer = false;
  bool _hasAnsweredOffer = false;
  int _lastSignalId = 0;
  final Set<String> _processedSignalIds = {};
  final List<RTCIceCandidate> _pendingIceCandidates = [];
  String? _currentUserId;

  StreamSubscription? _wsOfferSub;
  StreamSubscription? _wsAnswerSub;
  StreamSubscription? _wsCandidateSub;
  StreamSubscription? _wsEndSub;

  final List<String> debugLogs = [];
  String pcState = 'Not Created';
  String iceState = 'Not Started';
  String offerState = 'Idle';
  String answerState = 'Idle';
  int iceCandidatesSent = 0;
  int iceCandidatesReceived = 0;
  String lastError = 'None';
  Function()? onDebugUpdate;

  void _log(String msg) {
    final time = DateTime.now().toIso8601String().substring(11, 19);
    final entry = '[$time] $msg';
    debugLogs.insert(0, entry);
    if (debugLogs.length > 60) debugLogs.removeLast();
    AppLogger.info('WebRTC', msg);
    onDebugUpdate?.call();
  }

  bool _isSpeakerOn = true;
  bool get isSpeakerOn => _isSpeakerOn;

  bool get isInitialized => _isInitialized;
  MediaStream? get localStream => _localStream;
  MediaStream? get remoteStream => _remoteStream;
  bool get hasRemoteStream => remoteRenderer.srcObject != null;

  Future<bool> initializeMedia({bool isAudioOnly = false}) async {
    try {
      final savedUser = await AuthApiService.getSavedUser();
      _currentUserId = savedUser?['id']?.toString() ?? savedUser?['user_id']?.toString() ?? savedUser?['account_id']?.toString();

      await localRenderer.initialize();
      await remoteRenderer.initialize();

      final Map<String, dynamic> mediaConstraints = {
        'audio': {
          'echoCancellation': true,
          'noiseSuppression': true,
          'autoGainControl': true,
        },
        'video': isAudioOnly
            ? false
            : {
                'facingMode': 'user',
                'mandatory': {
                  'minWidth': '640',
                  'minHeight': '480',
                  'minFrameRate': '30',
                },
                'optional': [],
              },
      };

      try {
        _localStream = await navigator.mediaDevices.getUserMedia(mediaConstraints);
      } catch (_) {
        _localStream = await navigator.mediaDevices.getUserMedia({
          'audio': true,
          'video': !isAudioOnly,
        });
      }

      localRenderer.srcObject = _localStream;
      _isInitialized = true;
      _log('GET_USER_MEDIA_SUCCESS');

      try {
        await Helper.setSpeakerphoneOn(true);
        _isSpeakerOn = true;
      } catch (_) {}

      return _isInitialized;
    } catch (e, st) {
      lastError = e.toString();
      _log('ERROR in initializeMedia: $e');
      AppLogger.error('WebRTCInitError', e, st);
      return false;
    }
  }

  List<Map<String, dynamic>> _sanitizeIceServers(List<Map<String, dynamic>> rawIceServers) {
    final List<Map<String, dynamic>> sanitized = [];

    for (final server in rawIceServers) {
      dynamic rawUrls = server['urls'] ?? server['url'];
      if (rawUrls == null) continue;

      final List<String> urlList = [];
      if (rawUrls is List) {
        for (final item in rawUrls) {
          if (item != null && item.toString().trim().isNotEmpty) {
            urlList.add(item.toString().trim());
          }
        }
      } else if (rawUrls is String && rawUrls.trim().isNotEmpty) {
        urlList.add(rawUrls.trim());
      }

      if (urlList.isEmpty) continue;

      for (final uri in urlList) {
        if (uri.startsWith('stun:')) {
          final cleanStun = uri.split('?').first;
          if (cleanStun.isNotEmpty) {
            sanitized.add({'urls': cleanStun});
          }
        } else if (uri.startsWith('turn:') || uri.startsWith('turns:')) {
          final username = server['username']?.toString().trim();
          final credential = (server['credential'] ?? server['password'])?.toString().trim();
          if (username != null && username.isNotEmpty && credential != null && credential.isNotEmpty) {
            sanitized.add({
              'urls': uri,
              'username': username,
              'credential': credential,
            });
          }
        }
      }
    }

    sanitized.addAll([
      {'urls': 'stun:stun.l.google.com:19302'},
      {'urls': 'stun:stun1.l.google.com:19302'},
      {'urls': 'stun:stun2.l.google.com:19302'},
      {'urls': 'stun:stun3.l.google.com:19302'},
      {'urls': 'stun:stun4.l.google.com:19302'},
    ]);

    return sanitized;
  }

  Future<RTCPeerConnection?> _createPeerConnectionInternal(
    dynamic callId,
    String? channelName,
    Function(MediaStream stream)? onRemoteStreamConnected, {
    required bool isCaller,
  }) async {
    try {
      final rawIceServers = await CallApiService.getIceServers();
      final cleanIceServers = _sanitizeIceServers(rawIceServers);
      _log('ICE_SERVERS_LOADED: ${cleanIceServers.length}');

      final Map<String, dynamic> configuration = {
        'iceServers': cleanIceServers,
        'sdpSemantics': 'unified-plan',
      };

      final Map<String, dynamic> constraints = {
        'mandatory': {},
        'optional': [
          {'DtlsSrtpKeyAgreement': true},
        ],
      };

      final pc = await createPeerConnection(configuration, constraints);
      _peerConnection = pc;
      pcState = 'Created';

      if (_localStream != null) {
        for (final track in _localStream!.getTracks()) {
          try {
            await pc.addTrack(track, _localStream!);
            _log('LOCAL_TRACK_ADDED: ${track.kind}');
          } catch (e) {
            _log('AddTrackError: $e');
          }
        }
      }

      pc.onTrack = (RTCTrackEvent event) async {
        _log('REMOTE_TRACK_RECEIVED: ${event.track.kind}');
        try {
          event.track.enabled = true;
        } catch (_) {}

        if (event.streams.isNotEmpty) {
          _remoteStream = event.streams[0];
        } else {
          _remoteStream ??= await createLocalMediaStream('remote_${DateTime.now().millisecondsSinceEpoch}');
          _remoteStream!.addTrack(event.track);
        }

        try {
          for (final track in _remoteStream!.getTracks()) {
            track.enabled = true;
          }
        } catch (_) {}

        remoteRenderer.srcObject = _remoteStream;
        _log('REMOTE_STREAM_ATTACHED (kind: ${event.track.kind})');
        onRemoteStreamConnected?.call(_remoteStream!);

        try {
          await Helper.setSpeakerphoneOn(true);
          _isSpeakerOn = true;
        } catch (_) {}
      };

      pc.onAddStream = (MediaStream stream) {
        _log('REMOTE_ADD_STREAM: ${stream.id}');
        try {
          for (final track in stream.getTracks()) {
            track.enabled = true;
          }
        } catch (_) {}
        _remoteStream = stream;
        remoteRenderer.srcObject = _remoteStream;
        onRemoteStreamConnected?.call(_remoteStream!);

        try {
          Helper.setSpeakerphoneOn(true);
          _isSpeakerOn = true;
        } catch (_) {}
      };

      pc.onConnectionState = (RTCPeerConnectionState state) {
        pcState = state.toString().split('.').last.replaceAll('RTCPeerConnectionState', '');
        _log('PEER_CONNECTION_STATE: $pcState');
        if (state == RTCPeerConnectionState.RTCPeerConnectionStateConnected) {
          _log('PEER_CONNECTED_SUCCESS');
        }
      };

      pc.onIceConnectionState = (RTCIceConnectionState state) {
        iceState = state.toString().split('.').last.replaceAll('RTCIceConnectionState', '');
        _log('ICE_CONNECTION_STATE: $iceState');
        if (state == RTCIceConnectionState.RTCIceConnectionStateConnected ||
            state == RTCIceConnectionState.RTCIceConnectionStateCompleted) {
          _log('ICE_CONNECTED_SUCCESS');
        }
      };

      pc.onIceCandidate = (RTCIceCandidate candidate) {
        if (candidate.candidate != null && candidate.candidate!.isNotEmpty) {
          iceCandidatesSent++;
          _log('ICE_CANDIDATE_SENT (#$iceCandidatesSent)');
          CallApiService.sendSignal(
            callId: callId,
            channelName: channelName,
            type: 'candidate',
            payload: {
              'candidate': candidate.candidate,
              'sdpMid': candidate.sdpMid,
              'sdpMLineIndex': candidate.sdpMLineIndex,
              'sender_role': isCaller ? 'caller' : 'receiver',
              'sender_id': _currentUserId,
            },
          );
        }
      };

      return pc;
    } catch (e, st) {
      lastError = e.toString();
      _log('ERROR in createPeerConnection: $e');
      AppLogger.error('CreatePeerConnectionError', e, st);
      return null;
    }
  }

  Future<void> startCallAsCaller({
    required dynamic callId,
    String? channelName,
    Function(MediaStream stream)? onRemoteStreamConnected,
    Function()? onCallEnded,
  }) async {
    _hasRemoteAnswer = false;
    _lastSignalId = 0;
    _processedSignalIds.clear();
    _pendingIceCandidates.clear();

    final pc = await _createPeerConnectionInternal(
      callId,
      channelName,
      onRemoteStreamConnected,
      isCaller: true,
    );

    if (pc == null) return;

    try {
      final offer = await pc.createOffer({
        'offerToReceiveAudio': 1,
        'offerToReceiveVideo': 1,
      });
      await pc.setLocalDescription(offer);
      offerState = 'Sent';
      _log('OFFER_CREATED_AND_SENT (sdp length: ${offer.sdp?.length ?? 0})');

      await CallApiService.sendSignal(
        callId: callId,
        channelName: channelName,
        type: 'offer',
        payload: {
          'sdp': offer.sdp,
          'type': offer.type,
          'sender_role': 'caller',
          'sender_id': _currentUserId,
        },
      );
    } catch (e) {
      lastError = 'Offer Error: $e';
      _log('ERROR in startCallAsCaller (createOffer): $e');
      return;
    }

    _setupWebSocketSignaling(callId, channelName, true, onRemoteStreamConnected, onCallEnded);
    _startSignalingPolling(callId, channelName, true, onRemoteStreamConnected, onCallEnded);
  }

  Future<void> startCallAsReceiver({
    required dynamic callId,
    String? channelName,
    Function(MediaStream stream)? onRemoteStreamConnected,
    Function()? onCallEnded,
  }) async {
    _hasAnsweredOffer = false;
    _lastSignalId = 0;
    _processedSignalIds.clear();
    _pendingIceCandidates.clear();

    final pc = await _createPeerConnectionInternal(
      callId,
      channelName,
      onRemoteStreamConnected,
      isCaller: false,
    );

    if (pc == null) return;

    _setupWebSocketSignaling(callId, channelName, false, onRemoteStreamConnected, onCallEnded);
    _startSignalingPolling(callId, channelName, false, onRemoteStreamConnected, onCallEnded);
  }

  String _sanitizeSdp(String rawSdp) {
    if (rawSdp.isEmpty) return '';
    var sdp = rawSdp.trim();

    // 1. Unescape escaped characters
    sdp = sdp.replaceAll(r'\r\n', '\n').replaceAll(r'\n', '\n').replaceAll(r'\r', '\n');
    sdp = sdp.replaceAll('\r\n', '\n').replaceAll('\r', '\n');

    // 2. Locate SDP starting boundary (must start with v=0)
    final v0Index = sdp.indexOf('v=0');
    if (v0Index >= 0) {
      sdp = sdp.substring(v0Index);
    }

    // 3. Filter line-by-line: every valid SDP line starts with <type>=<value>
    final lines = sdp.split('\n');
    final validLines = <String>[];
    for (final rawLine in lines) {
      final line = rawLine.trim();
      if (line.isEmpty) continue;
      // SDP line format is strictly single lower-case letter followed by '='
      if (RegExp(r'^[a-z]=[^\r\n]*$', caseSensitive: false).hasMatch(line)) {
        var cleanLine = line;
        // Strip trailing quotes or escape slashes from json formatting
        while (cleanLine.endsWith('"') || cleanLine.endsWith("'") || cleanLine.endsWith('\\')) {
          cleanLine = cleanLine.substring(0, cleanLine.length - 1).trim();
        }
        if (cleanLine.isNotEmpty) {
          validLines.add(cleanLine);
        }
      } else {
        // If we hit non-SDP characters (e.g. JSON closing braces/quotes), stop parsing
        if (validLines.isNotEmpty && (line.startsWith('}') || line.startsWith('{') || line.startsWith('"') || line.startsWith(','))) {
          break;
        }
      }
    }

    if (validLines.isEmpty) return '';

    // WebRTC RFC standard requires CRLF (\r\n) on every line including the last line
    return '${validLines.join('\r\n')}\r\n';
  }

  String _extractSdp(Map signal, Map payload) {
    dynamic raw = payload['sdp'] ??
        signal['sdp'] ??
        payload['description'] ??
        signal['description'] ??
        payload['session_description'] ??
        signal['session_description'] ??
        payload['payload'] ??
        signal['payload'] ??
        payload['data'] ??
        signal['data'];

    // 1. Unnest map if needed
    while (raw is Map) {
      final inner = raw['sdp'] ?? raw['description'] ?? raw['session_description'] ?? raw['payload'] ?? raw['data'];
      if (inner == null || inner == raw) break;
      raw = inner;
    }

    if (raw == null) return '';

    String sdp = raw.toString().trim();

    // 2. Decode stringified JSON if needed (recursively handles wrapped JSON)
    for (int i = 0; i < 3; i++) {
      final trimmed = sdp.trim();
      if ((trimmed.startsWith('{') && trimmed.endsWith('}')) || (trimmed.startsWith('"') && trimmed.endsWith('"'))) {
        try {
          final decoded = jsonDecode(trimmed);
          if (decoded is Map) {
            final inner = decoded['sdp'] ?? decoded['description'] ?? decoded['session_description'] ?? decoded['payload'];
            if (inner != null) {
              sdp = inner.toString().trim();
              continue;
            }
          } else if (decoded is String) {
            sdp = decoded.trim();
            continue;
          }
        } catch (_) {}
      }
      break;
    }

    return _sanitizeSdp(sdp);
  }

  void _setupWebSocketSignaling(
    dynamic callId,
    String? channelName,
    bool isCaller,
    Function(MediaStream stream)? onRemoteStreamConnected,
    Function()? onCallEnded,
  ) {
    _wsOfferSub?.cancel();
    _wsAnswerSub?.cancel();
    _wsCandidateSub?.cancel();
    _wsEndSub?.cancel();

    final signaling = SignalingService();
    final roomName = channelName ?? '$callId';
    signaling.subscribeToCallRoom(roomName);

    _wsOfferSub = signaling.onWebRTCOffer.listen((data) {
      _log('WS_EVENT_OFFER');
      _processSignalItem(data, isCaller, callId, channelName, onRemoteStreamConnected, onCallEnded);
    });

    _wsAnswerSub = signaling.onWebRTCAnswer.listen((data) {
      _log('WS_EVENT_ANSWER');
      _processSignalItem(data, isCaller, callId, channelName, onRemoteStreamConnected, onCallEnded);
    });

    _wsCandidateSub = signaling.onWebRTCICECandidate.listen((data) {
      _log('WS_EVENT_CANDIDATE');
      _processSignalItem(data, isCaller, callId, channelName, onRemoteStreamConnected, onCallEnded);
    });

    _wsEndSub = signaling.onCallEnded.listen((data) {
      _log('WS_EVENT_CALL_ENDED');
      onCallEnded?.call();
    });
  }

  void _startSignalingPolling(
    dynamic callId,
    String? channelName,
    bool isCaller,
    Function(MediaStream stream)? onRemoteStreamConnected,
    Function()? onCallEnded,
  ) {
    _signalingTimer?.cancel();
    bool isFetching = false;

    _signalingTimer = Timer.periodic(const Duration(milliseconds: 300), (timer) async {
      if (isFetching || _peerConnection == null) return;
      isFetching = true;

      try {
        final signals = await CallApiService.receiveSignals(
          callId: callId,
          channelName: channelName,
          lastSignalId: _lastSignalId,
          autoRead: false,
        );

        for (final signal in signals) {
          final dynamic rawSigId = signal['id'];
          final int? parsedSigId = rawSigId is int ? rawSigId : int.tryParse(rawSigId?.toString() ?? '');
          if (parsedSigId != null && parsedSigId > _lastSignalId) {
            _lastSignalId = parsedSigId;
          }

          await _processSignalItem(signal, isCaller, callId, channelName, onRemoteStreamConnected, onCallEnded);
        }
      } catch (e) {
        _log('PollingError: $e');
      } finally {
        isFetching = false;
      }
    });
  }

  Future<void> _processSignalItem(
    Map signal,
    bool isCaller,
    dynamic callId,
    String? channelName,
    Function(MediaStream stream)? onRemoteStreamConnected,
    Function()? onCallEnded,
  ) async {
    if (_peerConnection == null) return;

    dynamic rawPayload = signal['payload'];
    if (rawPayload is String) {
      try {
        rawPayload = jsonDecode(rawPayload);
      } catch (_) {}
    }
    final Map payload = (rawPayload is Map) ? Map.from(rawPayload) : Map.from(signal);

    final rawType = (signal['type'] ?? payload['type'] ?? signal['event'] ?? signal['signal_type'] ?? '').toString().toLowerCase();
    final signalId = signal['id']?.toString() ?? '${rawType}_${signal['created_at'] ?? signal.hashCode}';
    if (_processedSignalIds.contains(signalId)) return;
    _processedSignalIds.add(signalId);

    // Normalize signal type
    String type = rawType;
    if (rawType.contains('offer')) {
      type = 'offer';
    } else if (rawType.contains('answer')) {
      type = 'answer';
    } else if (rawType.contains('candidate') || rawType.contains('ice')) {
      type = 'candidate';
    } else if (rawType.contains('bye') || rawType.contains('hangup') || rawType.contains('ended')) {
      type = 'call_ended';
    }

    final senderRole = (payload['sender_role'] ?? signal['sender_role'])?.toString().toLowerCase();
    final senderId = (signal['sender_id'] ?? signal['user_id'] ?? payload['sender_id'] ?? payload['user_id'])?.toString();

    // Ignore self-emitted signals
    if (_currentUserId != null && senderId != null && senderId == _currentUserId) {
      return;
    }
    if (isCaller && senderRole == 'caller') {
      return;
    }
    if (!isCaller && senderRole == 'receiver') {
      return;
    }

    if (type == 'call_ended') {
      _signalingTimer?.cancel();
      onCallEnded?.call();
      return;
    }

    if (isCaller) {
      // Caller processes Answer from Receiver
      if (type == 'answer' && !_hasRemoteAnswer) {
        final sdp = _extractSdp(signal, payload);
        if (sdp.isNotEmpty && _peerConnection != null) {
          answerState = 'Received';
          _log('ANSWER_RECEIVED_BY_CALLER (sdp len: ${sdp.length})');
          try {
            await _peerConnection!.setRemoteDescription(RTCSessionDescription(sdp, 'answer'));
            _hasRemoteAnswer = true;
            _log('SET_REMOTE_DESCRIPTION_ANSWER_SUCCESS');
            await _drainPendingCandidates();
          } catch (e) {
            lastError = 'SetRemoteDescAnswerError: $e';
            _log('SetRemoteDescAnswerError: $e');
          }
        }
      } else if (type == 'candidate') {
        await _handleIncomingCandidate(payload);
      }
    } else {
      // Receiver processes Offer from Caller
      if (type == 'offer' && !_hasAnsweredOffer) {
        final sdp = _extractSdp(signal, payload);
        if (sdp.isNotEmpty && _peerConnection != null) {
          offerState = 'Received';
          _log('OFFER_RECEIVED_BY_RECEIVER (sdp len: ${sdp.length})');
          try {
            await _peerConnection!.setRemoteDescription(RTCSessionDescription(sdp, 'offer'));
            _hasAnsweredOffer = true;
            _log('SET_REMOTE_DESCRIPTION_OFFER_SUCCESS');
            await _drainPendingCandidates();

            final answer = await _peerConnection!.createAnswer({
              'offerToReceiveAudio': 1,
              'offerToReceiveVideo': 1,
            });
            await _peerConnection!.setLocalDescription(answer);
            answerState = 'Sent';
            _log('ANSWER_CREATED_AND_SENT (sdp len: ${answer.sdp?.length ?? 0})');

            await CallApiService.sendSignal(
              callId: callId,
              channelName: channelName,
              type: 'answer',
              payload: {
                'sdp': answer.sdp,
                'type': 'answer',
                'sender_role': 'receiver',
                'sender_id': _currentUserId,
              },
            );
          } catch (e) {
            lastError = 'SetRemoteDescOfferError: $e';
            _log('SetRemoteDescOfferError: $e');
          }
        }
      } else if (type == 'candidate') {
        await _handleIncomingCandidate(payload);
      }
    }
  }

  Future<void> _handleIncomingCandidate(Map payload) async {
    String? candidateStr;
    String? sdpMid;
    dynamic sdpMLineIndex;

    dynamic rawCandidate = payload['candidate'] ?? payload['ice_candidate'] ?? payload['iceCandidate'];
    if (rawCandidate is Map) {
      candidateStr = rawCandidate['candidate']?.toString();
      sdpMid = rawCandidate['sdpMid']?.toString() ?? rawCandidate['sdp_mid']?.toString();
      sdpMLineIndex = rawCandidate['sdpMLineIndex'] ?? rawCandidate['sdp_mline_index'];
    } else if (rawCandidate != null) {
      candidateStr = rawCandidate.toString();
      sdpMid = payload['sdpMid']?.toString() ?? payload['sdp_mid']?.toString();
      sdpMLineIndex = payload['sdpMLineIndex'] ?? payload['sdp_mline_index'];
    }

    if (candidateStr != null && candidateStr.trim().isNotEmpty) {
      final int mLineIdx = sdpMLineIndex is int
          ? sdpMLineIndex
          : int.tryParse(sdpMLineIndex?.toString() ?? '0') ?? 0;

      iceCandidatesReceived++;
      _log('ICE_CANDIDATE_RECEIVED (#$iceCandidatesReceived)');
      final cand = RTCIceCandidate(candidateStr.trim(), sdpMid, mLineIdx);

      final remoteDesc = await _peerConnection?.getRemoteDescription();
      if (remoteDesc != null && remoteDesc.sdp != null && remoteDesc.sdp!.isNotEmpty) {
        try {
          await _peerConnection?.addCandidate(cand);
          _log('CANDIDATE_ADDED_TO_PEER');
        } catch (e) {
          _log('AddCandidateError: $e');
        }
      } else {
        _pendingIceCandidates.add(cand);
        _log('CANDIDATE_QUEUED_PENDING_REMOTE_DESC (Total: ${_pendingIceCandidates.length})');
      }
    }
  }

  Future<void> _drainPendingCandidates() async {
    if (_peerConnection == null || _pendingIceCandidates.isEmpty) return;
    _log('DRAINING_${_pendingIceCandidates.length}_PENDING_CANDIDATES');
    for (final cand in List<RTCIceCandidate>.from(_pendingIceCandidates)) {
      try {
        await _peerConnection!.addCandidate(cand);
      } catch (e) {
        _log('DrainCandidateError: $e');
      }
    }
    _pendingIceCandidates.clear();
  }

  Future<void> switchCamera() async {
    if (_localStream != null) {
      final videoTrack = _localStream!.getVideoTracks().firstOrNull;
      if (videoTrack != null) {
        try {
          await Helper.switchCamera(videoTrack);
        } catch (_) {}
      }
    }
  }

  void toggleMute(bool isMuted) {
    if (_localStream != null) {
      for (final track in _localStream!.getAudioTracks()) {
        track.enabled = !isMuted;
      }
    }
  }

  void toggleCamera(bool isOff) {
    if (_localStream != null) {
      for (final track in _localStream!.getVideoTracks()) {
        track.enabled = !isOff;
      }
    }
  }

  Future<void> toggleSpeakerphone(bool isSpeaker) async {
    try {
      await Helper.setSpeakerphoneOn(isSpeaker);
      _isSpeakerOn = isSpeaker;
    } catch (_) {}
  }

  Future<void> dispose() async {
    _signalingTimer?.cancel();
    _signalingTimer = null;

    _wsOfferSub?.cancel();
    _wsAnswerSub?.cancel();
    _wsCandidateSub?.cancel();
    _wsEndSub?.cancel();

    try {
      SignalingService().leaveCallRoom();
    } catch (_) {}

    if (_peerConnection != null) {
      try {
        await _peerConnection!.close();
      } catch (_) {}
      _peerConnection = null;
    }

    if (_localStream != null) {
      for (final track in _localStream!.getTracks()) {
        try {
          track.stop();
        } catch (_) {}
      }
      _localStream = null;
    }

    if (_remoteStream != null) {
      for (final track in _remoteStream!.getTracks()) {
        try {
          track.stop();
        } catch (_) {}
      }
      _remoteStream = null;
    }

    try {
      localRenderer.srcObject = null;
      remoteRenderer.srcObject = null;
      await localRenderer.dispose();
      await remoteRenderer.dispose();
    } catch (_) {}

    _isInitialized = false;
  }
}



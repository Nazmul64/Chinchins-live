import 'package:flutter_webrtc/flutter_webrtc.dart';
import '../../../core/utils/app_logger.dart';

class WebRTCCallService {
  final RTCVideoRenderer localRenderer = RTCVideoRenderer();
  final RTCVideoRenderer remoteRenderer = RTCVideoRenderer();

  MediaStream? _localStream;
  MediaStream? _remoteStream;
  RTCPeerConnection? _peerConnection;
  bool _isInitialized = false;

  bool get isInitialized => _isInitialized;
  MediaStream? get localStream => _localStream;
  MediaStream? get remoteStream => _remoteStream;

  /// Initialize Renderers & User Media Camera Stream
  Future<bool> initializeMedia() async {
    try {
      await localRenderer.initialize();
      await remoteRenderer.initialize();

      // Configure media constraints for live selfie camera
      final Map<String, dynamic> mediaConstraints = {
        'audio': true,
        'video': {
          'facingMode': 'user',
          'optional': [],
          'mandatory': {
            'minWidth': '640',
            'minHeight': '480',
            'minFrameRate': '30',
          },
        },
      };

      try {
        _localStream = await navigator.mediaDevices.getUserMedia(mediaConstraints);
        localRenderer.srcObject = _localStream;
        _isInitialized = true;
        AppLogger.info('WebRTC', 'Local front camera media stream started successfully');
      } catch (e) {
        // Fallback for devices without strict constraints
        try {
          _localStream = await navigator.mediaDevices.getUserMedia({
            'audio': true,
            'video': true,
          });
          localRenderer.srcObject = _localStream;
          _isInitialized = true;
          AppLogger.info('WebRTC', 'Fallback user media stream acquired');
        } catch (err, st) {
          AppLogger.error('WebRTCMediaError', err, st);
          _isInitialized = false;
        }
      }

      return _isInitialized;
    } catch (e, st) {
      AppLogger.error('WebRTCInitError', e, st);
      return false;
    }
  }

  /// Switch between Front & Back Camera
  Future<void> switchCamera() async {
    if (_localStream != null) {
      final videoTrack = _localStream!.getVideoTracks().firstOrNull;
      if (videoTrack != null) {
        try {
          await Helper.switchCamera(videoTrack);
        } catch (e) {
          AppLogger.error('SwitchCameraError', e);
        }
      }
    }
  }

  /// Toggle Audio Mute
  void toggleMute(bool isMuted) {
    if (_localStream != null) {
      for (final track in _localStream!.getAudioTracks()) {
        track.enabled = !isMuted;
      }
    }
  }

  /// Toggle Camera Video Stream On / Off
  void toggleCamera(bool isOff) {
    if (_localStream != null) {
      for (final track in _localStream!.getVideoTracks()) {
        track.enabled = !isOff;
      }
    }
  }

  /// Dispose All WebRTC Streams & Renderers
  Future<void> dispose() async {
    try {
      if (_localStream != null) {
        for (final track in _localStream!.getTracks()) {
          track.stop();
        }
        await _localStream!.dispose();
        _localStream = null;
      }
      if (_remoteStream != null) {
        for (final track in _remoteStream!.getTracks()) {
          track.stop();
        }
        await _remoteStream!.dispose();
        _remoteStream = null;
      }
      if (_peerConnection != null) {
        await _peerConnection!.close();
        await _peerConnection!.dispose();
        _peerConnection = null;
      }
      localRenderer.srcObject = null;
      remoteRenderer.srcObject = null;
      await localRenderer.dispose();
      await remoteRenderer.dispose();
      _isInitialized = false;
      AppLogger.info('WebRTC', 'WebRTC streams and renderers disposed cleanly');
    } catch (e, st) {
      AppLogger.error('WebRTCDisposeError', e, st);
    }
  }
}

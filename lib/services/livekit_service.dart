import 'package:flutter/foundation.dart';
import 'package:livekit_client/livekit_client.dart';
import 'package:permission_handler/permission_handler.dart';

class LiveKitService {
  Room? _room;
  Room? get room => _room;

  final String serverUrl = 'wss://chinchins.live/livekit';

  Future<bool> requestPermissions({bool isVideo = true}) async {
    Map<Permission, PermissionStatus> statuses = await [
      Permission.microphone,
      if (isVideo) Permission.camera,
    ].request();

    return statuses.values.every((status) => status.isGranted);
  }

  /// Connect to LiveKit Room as Host, Co-Host, or Viewer
  Future<Room?> connectToRoom({
    required String token,
    required bool isHost,
    required bool isAudioOnly,
    String? customServerUrl,
  }) async {
    // Ensure audio outputs through speakerphone
    try {
      await Hardware.instance.setSpeakerphoneOn(true);
    } catch (e) {
      debugPrint('Hardware speakerphone error: ' + e.toString());
    }

    if (isHost) {
      final hasPermission = await requestPermissions(isVideo: !isAudioOnly);
      if (!hasPermission) {
        debugPrint('Camera/Mic permissions denied!');
        return null;
      }
    }

    _room = Room(
      roomOptions: const RoomOptions(
        adaptiveStream: true,
        dynacast: true,
        defaultCameraCaptureOptions: CameraCaptureOptions(
          cameraPosition: CameraPosition.front,
          params: VideoParameters(
            dimensions: VideoDimensionsPresets.h720_169,
            encoding: VideoEncoding(
              maxBitrate: 2500 * 1000, // 2.5 Mbps High Definition
              maxFramerate: 30,
            ),
          ),
        ),
        defaultVideoPublishOptions: VideoPublishOptions(
          simulcast: true,
          videoCodec: 'VP8',
          videoEncoding: VideoEncoding(
            maxBitrate: 2500 * 1000,
            maxFramerate: 30,
          ),
        ),
        defaultAudioPublishOptions: AudioPublishOptions(
          name: 'microphone',
        ),
      ),
    );

    try {
      await _room!.connect(
        customServerUrl ?? serverUrl,
        token,
      );

      // Double check speakerphone after connection
      try {
        await Hardware.instance.setSpeakerphoneOn(true);
      } catch (_) {}

      // If host, enable camera and mic automatically
      if (isHost) {
        await _room!.localParticipant?.setMicrophoneEnabled(true);
        if (!isAudioOnly) {
          await _room!.localParticipant?.setCameraEnabled(true);
        }
      }

      return _room;
    } catch (e) {
      debugPrint('LiveKit Connection Error: ' + e.toString());
      return null;
    }
  }

  /// Enable broadcasting for newly accepted co-host
  Future<void> enableBroadcasting({bool isAudioOnly = false}) async {
    if (_room == null) return;
    await requestPermissions(isVideo: !isAudioOnly);
    await _room!.localParticipant?.setMicrophoneEnabled(true);
    if (!isAudioOnly) {
      await _room!.localParticipant?.setCameraEnabled(true);
    }
  }

  /// Create explicit HD Camera Track (720p/1080p 30fps)
  Future<LocalVideoTrack?> createCameraTrack({
    CameraPosition cameraPosition = CameraPosition.front,
    VideoDimensions dimensions = VideoDimensionsPresets.h720_169,
    int maxBitrate = 2500 * 1000,
    int maxFramerate = 30,
  }) async {
    try {
      final track = await LocalVideoTrack.createCameraTrack(
        CameraCaptureOptions(
          cameraPosition: cameraPosition,
          params: VideoParameters(
            dimensions: dimensions,
            encoding: VideoEncoding(
              maxBitrate: maxBitrate,
              maxFramerate: maxFramerate,
            ),
          ),
        ),
      );
      return track;
    } catch (e) {
      debugPrint('LiveKit CreateCameraTrack Error: $e');
      return null;
    }
  }

  /// Publish video track with HD Simulcast & VideoPublishOptions
  Future<void> publishVideoTrack(
    LocalVideoTrack track, {
    bool simulcast = true,
    String videoCodec = 'VP8',
  }) async {
    if (_room == null) return;
    try {
      await _room!.localParticipant?.publishVideoTrack(
        track,
        publishOptions: VideoPublishOptions(
          simulcast: simulcast,
          videoCodec: videoCodec,
        ),
      );
    } catch (e) {
      debugPrint('LiveKit PublishVideoTrack Error: $e');
    }
  }

  /// Toggle microphone
  Future<void> setMicrophoneEnabled(bool enabled) async {
    if (_room == null) return;
    await _room!.localParticipant?.setMicrophoneEnabled(enabled);
  }

  /// Toggle camera
  Future<void> setCameraEnabled(bool enabled) async {
    if (_room == null) return;
    await _room!.localParticipant?.setCameraEnabled(enabled);
  }

  /// Disconnect and release room
  Future<void> disconnect() async {
    await _room?.disconnect();
    await _room?.dispose();
    _room = null;
  }
}

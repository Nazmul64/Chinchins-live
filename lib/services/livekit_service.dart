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
        defaultAudioPublishOptions: AudioPublishOptions(
          name: 'microphone',
        ),
        defaultVideoPublishOptions: VideoPublishOptions(
          simulcast: true,
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

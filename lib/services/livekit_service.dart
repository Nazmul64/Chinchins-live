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

  /// লাইভ ভিডিও হোস্ট অথবা ভয়েস চ্যাট স্পিকার হিসেবে কানেক্ট হতে
  Future<Room?> connectToRoom({
    required String token,
    required bool isHost,
    required bool isAudioOnly,
    String? customServerUrl,
  }) async {
    final hasPermission = await requestPermissions(isVideo: !isAudioOnly);
    if (!hasPermission) {
      debugPrint("Camera/Mic permissions denied!");
      return null;
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

      // হোস্ট বা স্পিকার হলে অডিও/ভিডিও ট্র্যাক পাবলিশ করা
      if (isHost) {
        await _room!.localParticipant?.setMicrophoneEnabled(true);
        if (!isAudioOnly) {
          await _room!.localParticipant?.setCameraEnabled(true);
        }
      }

      return _room;
    } catch (e) {
      debugPrint("LiveKit Connection Error: $e");
      return null;
    }
  }

  /// অডিয়েন্স থেকে কো-হোস্ট বা অডিও সিটে স্পিকার হিসেবে মাইক/ক্যামেরা অন করতে
  Future<void> enableBroadcasting({bool isAudioOnly = false}) async {
    if (_room == null) return;
    await _room!.localParticipant?.setMicrophoneEnabled(true);
    if (!isAudioOnly) {
      await _room!.localParticipant?.setCameraEnabled(true);
    }
  }

  /// মাইক মিউট / আনমিউট টগল
  Future<void> setMicrophoneEnabled(bool enabled) async {
    if (_room == null) return;
    await _room!.localParticipant?.setMicrophoneEnabled(enabled);
  }

  /// ক্যামেরা অন / অফ টগল
  Future<void> setCameraEnabled(bool enabled) async {
    if (_room == null) return;
    await _room!.localParticipant?.setCameraEnabled(enabled);
  }

  /// সংযোগ বিচ্ছিন্ন করা
  Future<void> disconnect() async {
    await _room?.disconnect();
    await _room?.dispose();
    _room = null;
  }
}

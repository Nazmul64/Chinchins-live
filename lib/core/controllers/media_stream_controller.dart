import 'package:flutter/foundation.dart';
import 'package:livekit_client/livekit_client.dart';

/// 🎥 MediaStreamController: Full HD 1080p Media Engine (TikTok & BIGO Standard)
class MediaStreamController {
  /// Create Full HD 1080p 30fps 3.5Mbps camera video track
  static Future<LocalVideoTrack> createHDCamera() async {
    try {
      return await LocalVideoTrack.createCameraTrack(
        const CameraCaptureOptions(
          cameraPosition: CameraPosition.front,
          params: VideoParameters(
            dimensions: VideoDimensionsPresets.h1080_169, // 1080p Full HD
            encoding: VideoEncoding(
              maxBitrate: 3500 * 1000, // 3.5 Mbps bitrate (Zero blur or pixelation)
              maxFramerate: 30,
            ),
          ),
        ),
      );
    } catch (e) {
      debugPrint('[MediaStreamController] 1080p creation fallback to 720p: $e');
      return await LocalVideoTrack.createCameraTrack(
        const CameraCaptureOptions(
          cameraPosition: CameraPosition.front,
          params: VideoParameters(
            dimensions: VideoDimensionsPresets.h720_169, // 720p HD fallback
            encoding: VideoEncoding(
              maxBitrate: 2500 * 1000,
              maxFramerate: 30,
            ),
          ),
        ),
      );
    }
  }

  /// Publish Full HD video track with H264 hardware acceleration
  static Future<void> publishTrack(Room room, LocalVideoTrack track) async {
    try {
      await room.localParticipant?.publishVideoTrack(
        track,
        publishOptions: const VideoPublishOptions(
          simulcast: true,
          videoCodec: 'H264', // Hardware accelerated codec
        ),
      );
    } catch (e) {
      debugPrint('[MediaStreamController] Publish track error: $e');
    }
  }
}

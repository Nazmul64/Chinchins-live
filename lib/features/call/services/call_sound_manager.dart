import 'package:audioplayers/audioplayers.dart';
import '../../../core/utils/app_logger.dart';

class CallSoundManager {
  static AudioPlayer? _player;
  static bool _isPlaying = false;

  static Future<void> playOutgoingRingtone([String? customUrl]) async {
    if (_isPlaying) return;
    try {
      _player ??= AudioPlayer();
      await _player!.setReleaseMode(ReleaseMode.loop);
      await _player!.setVolume(1.0);
      if (customUrl != null && customUrl.startsWith('http')) {
        await _player!.play(UrlSource(customUrl));
      } else {
        await _player!.play(AssetSource('sounds/calling_ringtone.wav'));
      }
      _isPlaying = true;
      AppLogger.info('CallSound', 'Playing outgoing calling ringtone sound...');
    } catch (e, st) {
      AppLogger.error('CallSoundError', e, st);
    }
  }

  static Future<void> playIncomingRingtone([String? customUrl]) async {
    if (_isPlaying) return;
    try {
      _player ??= AudioPlayer();
      await _player!.setReleaseMode(ReleaseMode.loop);
      await _player!.setVolume(1.0);
      if (customUrl != null && customUrl.startsWith('http')) {
        await _player!.play(UrlSource(customUrl));
      } else {
        await _player!.play(AssetSource('sounds/calling_ringtone.wav'));
      }
      _isPlaying = true;
      AppLogger.info('CallSound', 'Playing incoming phone ringing sound...');
    } catch (e, st) {
      AppLogger.error('IncomingCallSoundError', e, st);
    }
  }

  static Future<void> stopRingtone() async {
    if (!_isPlaying && _player == null) return;
    try {
      if (_player != null) {
        await _player!.stop();
      }
      _isPlaying = false;
      AppLogger.info('CallSound', 'Calling ringtone stopped.');
    } catch (e, st) {
      AppLogger.error('StopCallSoundError', e, st);
    }
  }

  static Future<void> dispose() async {
    try {
      if (_player != null) {
        await _player!.stop();
        await _player!.dispose();
        _player = null;
      }
      _isPlaying = false;
    } catch (_) {}
  }
}
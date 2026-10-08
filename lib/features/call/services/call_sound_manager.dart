import 'package:audioplayers/audioplayers.dart';
import '../../../core/utils/app_logger.dart';

class CallSoundManager {
  static AudioPlayer? _player;
  static bool _isPlaying = false;
  static String? _cachedIncomingRingtoneUrl;
  static String? _cachedOutgoingRingtoneUrl;

  static void setDynamicRingtones({String? incomingUrl, String? outgoingUrl}) {
    if (incomingUrl != null && incomingUrl.trim().isNotEmpty && incomingUrl.startsWith('http')) {
      _cachedIncomingRingtoneUrl = incomingUrl.trim();
      AppLogger.info('CallSound', 'Dynamic incoming ringtone set: $_cachedIncomingRingtoneUrl');
    }
    if (outgoingUrl != null && outgoingUrl.trim().isNotEmpty && outgoingUrl.startsWith('http')) {
      _cachedOutgoingRingtoneUrl = outgoingUrl.trim();
      AppLogger.info('CallSound', 'Dynamic outgoing ringtone set: $_cachedOutgoingRingtoneUrl');
    }
  }

  static String? get incomingRingtoneUrl => _cachedIncomingRingtoneUrl;
  static String? get outgoingRingtoneUrl => _cachedOutgoingRingtoneUrl;

  static Future<void> playOutgoingRingtone([String? customUrl]) async {
    if (_isPlaying) return;
    try {
      _player ??= AudioPlayer();
      await _player!.setAudioContext(
        AudioContext(
          android: const AudioContextAndroid(
            isSpeakerphoneOn: true,
            stayAwake: true,
            contentType: AndroidContentType.sonification,
            usageType: AndroidUsageType.voiceCommunication,
            audioMode: AndroidAudioMode.inCommunication,
          ),
          iOS: AudioContextIOS(
            category: AVAudioSessionCategory.playAndRecord,
            options: {
              AVAudioSessionOptions.defaultToSpeaker,
            },
          ),
        ),
      );
      await _player!.setReleaseMode(ReleaseMode.loop);
      await _player!.setVolume(1.0);

      final targetUrl = (customUrl != null && customUrl.trim().isNotEmpty && customUrl.startsWith('http'))
          ? customUrl.trim()
          : (_cachedOutgoingRingtoneUrl != null && _cachedOutgoingRingtoneUrl!.startsWith('http')
              ? _cachedOutgoingRingtoneUrl
              : null);

      if (targetUrl != null) {
        AppLogger.info('CallSound', 'Playing dynamic outgoing calling ringtone sound ($targetUrl)...');
        await _player!.play(UrlSource(targetUrl));
      } else {
        AppLogger.info('CallSound', 'Playing asset outgoing calling ringtone sound...');
        await _player!.play(AssetSource('sounds/calling_ringtone.wav'));
      }
      _isPlaying = true;
    } catch (e, st) {
      AppLogger.error('CallSoundError', e, st);
    }
  }

  static Future<void> playIncomingRingtone([String? customUrl]) async {
    if (_isPlaying) return;
    try {
      _player ??= AudioPlayer();
      await _player!.setAudioContext(
        AudioContext(
          android: const AudioContextAndroid(
            isSpeakerphoneOn: true,
            stayAwake: true,
            contentType: AndroidContentType.music,
            usageType: AndroidUsageType.notificationRingtone,
            audioMode: AndroidAudioMode.ringtone,
          ),
          iOS: AudioContextIOS(
            category: AVAudioSessionCategory.playback,
            options: {
              AVAudioSessionOptions.defaultToSpeaker,
            },
          ),
        ),
      );
      await _player!.setReleaseMode(ReleaseMode.loop);
      await _player!.setVolume(1.0);

      final targetUrl = (customUrl != null && customUrl.trim().isNotEmpty && customUrl.startsWith('http'))
          ? customUrl.trim()
          : (_cachedIncomingRingtoneUrl != null && _cachedIncomingRingtoneUrl!.startsWith('http')
              ? _cachedIncomingRingtoneUrl
              : null);

      if (targetUrl != null) {
        AppLogger.info('CallSound', 'Playing dynamic incoming phone ringing sound ($targetUrl)...');
        await _player!.play(UrlSource(targetUrl));
      } else {
        AppLogger.info('CallSound', 'Playing asset incoming phone ringing sound...');
        await _player!.play(AssetSource('sounds/calling_ringtone.wav'));
      }
      _isPlaying = true;
    } catch (e, st) {
      AppLogger.error('IncomingCallSoundError', e, st);
    }
  }

  static Future<void> stopRingtone() async {
    if (!_isPlaying && _player == null) return;
    try {
      if (_player != null) {
        await _player!.stop();
        await _player!.release();
        await _player!.dispose();
        _player = null;
      }
      _isPlaying = false;
      AppLogger.info('CallSound', 'Calling ringtone stopped and audio focus released.');
    } catch (e, st) {
      AppLogger.error('StopCallSoundError', e, st);
    }
  }

  static Future<void> dispose() async {
    await stopRingtone();
  }
}
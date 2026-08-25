class AppConfig {
  // Base REST API URL
  static const String baseUrl = 'https://chinchins.live/api';

  // WebSocket & Reverb (Pusher) Credentials
  static const String reverbAppKey = 'chinchins_key_2026';
  static const String reverbHost = 'chinchins.live';
  static const int reverbPort = 443;
  static const String reverbScheme = 'https';
  static const String reverbWsPath = '/ws';
  static const String authEndpoint = 'https://chinchins.live/broadcasting/auth';

  // WebRTC ICE Servers (STUN/TURN) Config
  static const Map<String, dynamic> rtcConfiguration = {
    'iceServers': [
      {'urls': 'stun:chinchins.live:3478'},
      {
        'urls': 'turn:chinchins.live:3478',
        'username': 'chinchins',
        'credential': 'ChinchinsSecret2026TurnKey',
      },
    ],
  };
}
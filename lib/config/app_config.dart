class AppConfig {
  // Base REST API URL
  static const String baseUrl = 'https://chinchins.live/api';

  // WebSocket & Reverb (Pusher) Credentials
  static const String reverbAppKey = 'chinchins_key_2026';
  static const String reverbHost = 'chinchins.live';
  static const int reverbPort = 443;
  static const int reverbWsPort = 8080;
  static const int reverbWssPort = 443;
  static const bool reverbUseTLS = true;
  static const String reverbScheme = 'https';
  static const String reverbWsPath = '/ws';
  static const String authEndpoint = 'https://chinchins.live/api/broadcasting/auth';

  // WebRTC ICE Servers (STUN/TURN) Config
  static const Map<String, dynamic> rtcConfiguration = {
    'iceServers': [
      {
        'urls': [
          'stun:stun.l.google.com:19302',
          'stun:stun1.l.google.com:19302',
          'stun:stun2.l.google.com:19302',
          'stun:stun.cloudflare.com:3478',
          'stun:chinchins.live:3478',
        ],
      },
      {
        'urls': [
          'turn:chinchins.live:3478?transport=udp',
          'turn:chinchins.live:3478?transport=tcp',
        ],
        'username': 'chinchins',
        'credential': 'ChinchinsSecret2026TurnKey',
      },
      {
        'urls': [
          'turn:openrelay.metered.ca:443',
          'turn:openrelay.metered.ca:443?transport=tcp',
        ],
        'username': 'openrelay',
        'credential': 'openrelay',
      },
    ],
  };
}


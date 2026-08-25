import 'package:pusher_channels_flutter/pusher_channels_flutter.dart';
import '../config/app_config.dart';

class SignalingService {
  static final SignalingService _instance = SignalingService._internal();
  factory SignalingService() => _instance;
  SignalingService._internal();

  final PusherChannelsFlutter pusher = PusherChannelsFlutter.getInstance();

  Future<void> init(String userToken) async {
    await pusher.init(
      apiKey: AppConfig.reverbAppKey,
      cluster: 'mt1',
      authEndpoint: AppConfig.authEndpoint,
      onAuthorizer: (channelName, socketId, options) async {
        // Headers with Bearer Token for private channels
        return {
          "headers": {
            "Authorization": "Bearer $userToken",
            "Accept": "application/json",
          }
        };
      },
    );
    await pusher.connect();
  }
}
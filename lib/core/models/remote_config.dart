class RemoteConfig {
  final String appName;
  final String appTagline;
  final String appLogoUrl;
  final String appIconUrl;
  final String latestVersion;
  final int freeMessagesLimit;
  final int messageCoinCost;
  final int videoCallRate;
  final int audioCallRate;
  final int freeTrialDuration;
  final String incomingRingtone;
  final String outgoingRingtone;
  final Map<String, dynamic> remoteFlags;
  final String supportEmail;
  final String supportWhatsapp;

  const RemoteConfig({
    this.appName = 'Chinchins Live',
    this.appTagline = 'Meet, Chat & Video Call Live',
    this.appLogoUrl = 'https://chinchins.live/assets/images/branding/logo.png',
    this.appIconUrl = 'https://chinchins.live/assets/images/branding/icon.png',
    this.latestVersion = '1.0.0',
    this.freeMessagesLimit = 5,
    this.messageCoinCost = 5,
    this.videoCallRate = 100,
    this.audioCallRate = 60,
    this.freeTrialDuration = 10,
    this.incomingRingtone = 'https://assets.mixkit.co/active_storage/sfx/2874/2874-preview.mp3',
    this.outgoingRingtone = 'https://assets.mixkit.co/active_storage/sfx/1359/1359-preview.mp3',
    this.remoteFlags = const {
      'enable_video_calling': true,
      'enable_audio_calling': true,
      'enable_random_matching': true,
      'enable_instant_call_wake': true,
      'enable_push_notifications': true,
      'enable_in_app_updates': true,
      'enable_profile_view_alert': true,
      'enable_auto_chat_greetings': true,
      'maintenance_mode': false,
    },
    this.supportEmail = 'support@chinchins.live',
    this.supportWhatsapp = '+8801700000000',
  });

  bool get isVideoCallingEnabled => remoteFlags['enable_video_calling'] != false;
  bool get isAudioCallingEnabled => remoteFlags['enable_audio_calling'] != false;
  bool get isRandomMatchingEnabled => remoteFlags['enable_random_matching'] != false;
  bool get isInstantCallWakeEnabled => remoteFlags['enable_instant_call_wake'] != false;
  bool get isPushNotificationsEnabled => remoteFlags['enable_push_notifications'] != false;
  bool get isInAppUpdatesEnabled => remoteFlags['enable_in_app_updates'] != false;
  bool get isProfileViewAlertEnabled => remoteFlags['enable_profile_view_alert'] != false;
  bool get isAutoChatGreetingsEnabled => remoteFlags['enable_auto_chat_greetings'] != false;
  bool get isMaintenanceMode => remoteFlags['maintenance_mode'] == true;
  String get maintenanceMessage =>
      remoteFlags['maintenance_message']?.toString() ??
      'Server is currently undergoing scheduled maintenance.';

  factory RemoteConfig.fromJson(Map<String, dynamic> json) {
    return RemoteConfig(
      appName: json['app_name']?.toString() ?? 'Chinchins Live',
      appTagline: json['app_tagline']?.toString() ?? 'Meet, Chat & Video Call Live',
      appLogoUrl: json['app_logo_url']?.toString() ?? 'https://chinchins.live/assets/images/branding/logo.png',
      appIconUrl: json['app_icon_url']?.toString() ?? 'https://chinchins.live/assets/images/branding/icon.png',
      latestVersion: json['latest_version']?.toString() ?? '1.0.0',
      freeMessagesLimit: json['free_messages_limit'] is int
          ? json['free_messages_limit']
          : int.tryParse(json['free_messages_limit']?.toString() ?? '5') ?? 5,
      messageCoinCost: json['message_coin_cost'] is int
          ? json['message_coin_cost']
          : int.tryParse(json['message_coin_cost']?.toString() ?? '5') ?? 5,
      videoCallRate: json['video_call_rate'] is int
          ? json['video_call_rate']
          : int.tryParse(json['video_call_rate']?.toString() ?? '100') ?? 100,
      audioCallRate: json['audio_call_rate'] is int
          ? json['audio_call_rate']
          : int.tryParse(json['audio_call_rate']?.toString() ?? '60') ?? 60,
      freeTrialDuration: json['free_trial_duration'] is int
          ? json['free_trial_duration']
          : int.tryParse(json['free_trial_duration']?.toString() ?? '10') ?? 10,
      incomingRingtone: json['incoming_ringtone']?.toString() ??
          'https://assets.mixkit.co/active_storage/sfx/2874/2874-preview.mp3',
      outgoingRingtone: json['outgoing_ringtone']?.toString() ??
          'https://assets.mixkit.co/active_storage/sfx/1359/1359-preview.mp3',
      remoteFlags: json['remote_flags'] is Map<String, dynamic>
          ? Map<String, dynamic>.from(json['remote_flags'])
          : (json['remote_flags'] is Map ? Map<String, dynamic>.from(json['remote_flags'] as Map) : {}),
      supportEmail: json['support_email']?.toString() ?? 'support@chinchins.live',
      supportWhatsapp: json['support_whatsapp']?.toString() ?? '+8801700000000',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'app_name': appName,
      'app_tagline': appTagline,
      'app_logo_url': appLogoUrl,
      'app_icon_url': appIconUrl,
      'latest_version': latestVersion,
      'free_messages_limit': freeMessagesLimit,
      'message_coin_cost': messageCoinCost,
      'video_call_rate': videoCallRate,
      'audio_call_rate': audioCallRate,
      'free_trial_duration': freeTrialDuration,
      'incoming_ringtone': incomingRingtone,
      'outgoing_ringtone': outgoingRingtone,
      'remote_flags': remoteFlags,
      'support_email': supportEmail,
      'support_whatsapp': supportWhatsapp,
    };
  }
}

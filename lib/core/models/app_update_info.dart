class AppUpdateInfo {
  final bool hasUpdate;
  final bool forceUpdate;
  final String latestVersion;
  final int latestVersionCode;
  final String minSupportedVersion;
  final String title;
  final String changelog;
  final String? downloadUrl;
  final String? fileSize;
  final Map<String, dynamic> remoteFlags;
  final Map<String, dynamic> branding;
  final String? currentInstalledVersion;
  final int? currentInstalledVersionCode;
  final DateTime? serverTime;

  const AppUpdateInfo({
    required this.hasUpdate,
    this.forceUpdate = false,
    required this.latestVersion,
    this.latestVersionCode = 1,
    this.minSupportedVersion = '1.0.0',
    this.title = 'Update Available',
    this.changelog = '',
    this.downloadUrl,
    this.fileSize,
    this.remoteFlags = const {},
    this.branding = const {},
    this.currentInstalledVersion,
    this.currentInstalledVersionCode,
    this.serverTime,
  });

  factory AppUpdateInfo.fromJson(Map<String, dynamic> json) {
    DateTime? parsedServerTime;
    if (json['server_time'] != null) {
      try {
        parsedServerTime = DateTime.parse(json['server_time'].toString());
      } catch (_) {}
    }

    return AppUpdateInfo(
      hasUpdate: json['has_update'] == true,
      forceUpdate: json['force_update'] == true,
      latestVersion: json['latest_version']?.toString() ?? '1.0.0',
      latestVersionCode: json['latest_version_code'] is int
          ? json['latest_version_code']
          : int.tryParse(json['latest_version_code']?.toString() ?? '1') ?? 1,
      minSupportedVersion: json['min_supported_version']?.toString() ?? '1.0.0',
      title: json['title']?.toString() ?? 'Exciting New Features & Live Updates! 🎉',
      changelog: json['changelog']?.toString() ?? '',
      downloadUrl: json['download_url']?.toString(),
      fileSize: json['file_size']?.toString(),
      remoteFlags: json['remote_flags'] is Map<String, dynamic>
          ? Map<String, dynamic>.from(json['remote_flags'])
          : {},
      branding: json['branding'] is Map<String, dynamic>
          ? Map<String, dynamic>.from(json['branding'])
          : {},
      currentInstalledVersion: json['current_installed_version']?.toString(),
      currentInstalledVersionCode: json['current_installed_version_code'] is int
          ? json['current_installed_version_code']
          : int.tryParse(json['current_installed_version_code']?.toString() ?? ''),
      serverTime: parsedServerTime,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'has_update': hasUpdate,
      'force_update': forceUpdate,
      'latest_version': latestVersion,
      'latest_version_code': latestVersionCode,
      'min_supported_version': minSupportedVersion,
      'title': title,
      'changelog': changelog,
      'download_url': downloadUrl,
      'file_size': fileSize,
      'remote_flags': remoteFlags,
      'branding': branding,
      'current_installed_version': currentInstalledVersion,
      'current_installed_version_code': currentInstalledVersionCode,
      'server_time': serverTime?.toIso8601String(),
    };
  }
}

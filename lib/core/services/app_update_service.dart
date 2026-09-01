import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import '../constants/api_constants.dart';
import '../models/app_update_info.dart';
import '../theme/app_colors.dart';
import '../utils/app_logger.dart';
import '../../features/auth/services/auth_api_service.dart';

class AppUpdateService {
  static const String currentAppVersion = '1.0.0';
  static const int currentVersionCode = 1;

  /// Check server for OTA updates
  static Future<AppUpdateInfo?> checkForUpdates(
    BuildContext? context, {
    bool autoShowDialog = true,
    bool showToastIfUpToDate = false,
  }) async {
    try {
      final token = await AuthApiService.getToken();
      final url = Uri.parse(ApiConstants.appCheckUpdate);
      final platform = Platform.isIOS ? 'ios' : 'android';

      final requestPayload = {
        'app_version': currentAppVersion,
        'version_code': currentVersionCode,
        'platform': platform,
      };

      final headers = <String, String>{
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'X-App-Version': currentAppVersion,
        'X-App-Version-Code': currentVersionCode.toString(),
        if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
      };

      final response = await http
          .post(
            url,
            headers: headers,
            body: jsonEncode(requestPayload),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded is Map && (decoded['status'] == true || decoded['data'] != null)) {
          final data = decoded['data'] is Map<String, dynamic>
              ? decoded['data'] as Map<String, dynamic>
              : (decoded['data'] is Map
                  ? Map<String, dynamic>.from(decoded['data'] as Map)
                  : Map<String, dynamic>.from(decoded));

          final updateInfo = AppUpdateInfo.fromJson(data);

          if (updateInfo.hasUpdate && autoShowDialog && context != null && context.mounted) {
            showUpdateDialog(context: context, updateInfo: updateInfo);
          } else if (!updateInfo.hasUpdate && showToastIfUpToDate && context != null && context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Your app is up to date with the latest version!'),
                backgroundColor: Color(0xFF1E1C2E),
                behavior: SnackBarBehavior.floating,
              ),
            );
          }

          return updateInfo;
        }
      }
    } catch (e, st) {
      AppLogger.error('CheckUpdateError', e, st);
    }
    return null;
  }

  /// Launch APK download or App Store URL
  static Future<void> launchDownloadUrl(String url) async {
    try {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      AppLogger.error('LaunchDownloadUrlError', e);
    }
  }

  /// Display a sleek, branded update dialog
  static void showUpdateDialog({
    required BuildContext context,
    required AppUpdateInfo updateInfo,
  }) {
    final bool forceUpdate = updateInfo.forceUpdate;
    final List<String> changelogItems = updateInfo.changelog
        .split('\n')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();

    showDialog(
      context: context,
      barrierDismissible: !forceUpdate,
      builder: (dialogCtx) {
        return PopScope(
          canPop: !forceUpdate,
          child: Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFF1A1829),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: AppColors.neonPink.withValues(alpha: 0.4),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.neonPink.withValues(alpha: 0.2),
                    blurRadius: 24,
                    spreadRadius: 2,
                  ),
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.6),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header Banner with Gradient & Rocket Icon
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xFFFF2D55), Color(0xFFFF6B00)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(22),
                        topRight: Radius.circular(22),
                      ),
                    ),
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.rocket_launch_rounded,
                            color: Colors.white,
                            size: 32,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          updateInfo.title.isNotEmpty ? updateInfo.title : 'New Update Available!',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.3,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.25),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            'Version ${updateInfo.latestVersion}${updateInfo.fileSize != null ? ' (${updateInfo.fileSize})' : ''}',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Body with Changelog
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (forceUpdate)
                          Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.amber.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: Colors.amber.withValues(alpha: 0.4)),
                            ),
                            child: const Row(
                              children: [
                                Icon(Icons.warning_amber_rounded, color: Colors.amber, size: 18),
                                SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'This is a required update to continue using the app.',
                                    style: TextStyle(color: Colors.amber, fontSize: 12, fontWeight: FontWeight.w500),
                                  ),
                                ),
                              ],
                            ),
                          ),

                        const Text(
                          "What's New in this Version:",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 10),

                        // Bulleted list of changelog items
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxHeight: 180),
                          child: SingleChildScrollView(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: changelogItems.map((item) {
                                final cleanText = item.startsWith('•') || item.startsWith('-')
                                    ? item.substring(1).trim()
                                    : item;
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 8),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        '✨ ',
                                        style: TextStyle(fontSize: 13),
                                      ),
                                      Expanded(
                                        child: Text(
                                          cleanText,
                                          style: const TextStyle(
                                            color: Colors.white70,
                                            fontSize: 13,
                                            height: 1.35,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                        ),

                        const SizedBox(height: 20),

                        // Action Buttons
                        Row(
                          children: [
                            if (!forceUpdate) ...[
                              Expanded(
                                flex: 2,
                                child: OutlinedButton(
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: Colors.white70,
                                    side: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                  ),
                                  onPressed: () => Navigator.pop(dialogCtx),
                                  child: const Text(
                                    'Later',
                                    style: TextStyle(fontWeight: FontWeight.w600),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                            ],
                            Expanded(
                              flex: 3,
                              child: Container(
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [Color(0xFFFF2D55), Color(0xFFFF6B00)],
                                    begin: Alignment.centerLeft,
                                    end: Alignment.centerRight,
                                  ),
                                  borderRadius: BorderRadius.circular(16),
                                  boxShadow: [
                                    BoxShadow(
                                      color: AppColors.neonPink.withValues(alpha: 0.4),
                                      blurRadius: 10,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.transparent,
                                    shadowColor: Colors.transparent,
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                  ),
                                  onPressed: () {
                                    final url = updateInfo.downloadUrl;
                                    if (url != null && url.isNotEmpty) {
                                      launchDownloadUrl(url);
                                    } else {
                                      launchDownloadUrl('https://chinchins.live/downloads/chinchins_live.apk');
                                    }
                                  },
                                  child: const Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.download_rounded, color: Colors.white, size: 18),
                                      SizedBox(width: 6),
                                      Text(
                                        'Update Now',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

import 'dart:async';
import 'package:flutter/material.dart';
import '../../../core/models/model_profile.dart';
import '../../../core/services/hive_cache_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/cached_image_loader.dart';
import '../../call/services/call_api_service.dart';
import '../../call/services/streaming_service.dart';
import '../../profile/screens/host_profile_screen.dart';

class CallHistoryScreen extends StatefulWidget {
  const CallHistoryScreen({super.key});

  @override
  State<CallHistoryScreen> createState() => _CallHistoryScreenState();
}

class _CallHistoryScreenState extends State<CallHistoryScreen> {
  List<Map<String, dynamic>> _callLogs = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    // ⚡ 1. Synchronous 0.00ms instantaneous Hive cache load
    _loadFromCache();
    // 2. Background network fetch
    _fetchCallHistory();
  }

  void _loadFromCache() {
    final cached = HiveCacheService.getCachedCallHistory();
    if (cached.isNotEmpty) {
      setState(() {
        _callLogs = cached;
        _isLoading = false;
      });
    }
  }

  Future<void> _fetchCallHistory() async {
    try {
      final logs = await CallApiService.getCallHistory();
      if (mounted) {
        setState(() {
          _callLogs = logs;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _onCallAgain(Map<String, dynamic> log) {
    final partner = log['partner'] is Map ? Map<String, dynamic>.from(log['partner']) : <String, dynamic>{};
    final partnerId = partner['id']?.toString() ?? log['partner_id']?.toString() ?? '';
    final partnerName = partner['display_name'] ?? partner['name'] ?? 'Host';
    final partnerAvatar = partner['avatar_url'] ?? partner['avatar'] ?? '';
    final callType = log['call_type']?.toString() ?? 'video';

    if (partnerId.isEmpty) return;

    final model = ModelProfile.fromJson({
      'id': partnerId,
      'account_id': partner['account_id']?.toString() ?? partnerId,
      'name': partnerName,
      'avatar': partnerAvatar,
      'video_call_rate': partner['video_rate'] ?? partner['video_call_rate'] ?? 100,
    });

    StreamingService.startDynamicCall(
      context: context,
      model: model,
      channelName: 'call_${partnerId}_${DateTime.now().millisecondsSinceEpoch}',
      callType: callType,
    );
  }

  void _openPartnerProfile(Map<String, dynamic> log) {
    final partner = log['partner'] is Map ? Map<String, dynamic>.from(log['partner']) : <String, dynamic>{};
    final partnerId = partner['id']?.toString() ?? log['partner_id']?.toString() ?? '';
    final partnerName = partner['display_name'] ?? partner['name'] ?? 'Host';
    final partnerAvatar = partner['avatar_url'] ?? partner['avatar'] ?? '';

    if (partnerId.isEmpty) return;

    final model = ModelProfile.fromJson({
      'id': partnerId,
      'account_id': partner['account_id']?.toString() ?? partnerId,
      'name': partnerName,
      'avatar': partnerAvatar,
      'video_call_rate': partner['video_rate'] ?? partner['video_call_rate'] ?? 100,
      'is_online': partner['is_online'] == true,
    });

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => HostProfileScreen(model: model),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      appBar: AppBar(
        backgroundColor: AppColors.backgroundDark,
        elevation: 0,
        title: const Text(
          'Call History',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w800,
            fontSize: 20,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading && _callLogs.isEmpty
          ? const Center(child: CircularProgressIndicator(color: AppColors.neonPink))
          : _callLogs.isEmpty
              ? _buildEmptyState()
              : RefreshIndicator(
                  color: AppColors.neonPink,
                  backgroundColor: AppColors.cardDark,
                  onRefresh: _fetchCallHistory,
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    itemCount: _callLogs.length,
                    separatorBuilder: (context, index) => const Divider(
                      color: AppColors.cardBorder,
                      height: 1,
                      indent: 64,
                    ),
                    itemBuilder: (context, index) {
                      final log = _callLogs[index];
                      return _buildCallLogTile(log);
                    },
                  ),
                ),
    );
  }

  Widget _buildCallLogTile(Map<String, dynamic> log) {
    final partner = log['partner'] is Map ? Map<String, dynamic>.from(log['partner']) : <String, dynamic>{};
    final partnerName = partner['display_name'] ?? partner['name'] ?? 'User';
    final partnerAvatar = partner['avatar_url'] ?? partner['avatar'] ?? '';
    final isOutgoing = log['is_outgoing'] == true || log['direction'] == 'outgoing' || log['is_caller'] == true;
    final status = (log['status'] ?? log['status_label'] ?? 'completed').toString().toLowerCase();
    final isMissed = status == 'missed' || status == 'rejected' || status == 'cancelled';
    final callType = (log['call_type'] ?? 'video').toString().toLowerCase();
    final isVideo = callType == 'video';
    final durationText = log['formatted_duration'] ?? log['duration_formatted'] ?? (log['duration_seconds'] != null ? '${log['duration_seconds']}s' : '00:00');
    final timeAgo = log['time_ago'] ?? log['formatted_date'] ?? 'Recently';
    final coins = log['coins_spent'] ?? log['coins'] ?? log['coins_deducted'] ?? 0;

    return InkWell(
      onTap: () => _openPartnerProfile(log),
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            // Partner Avatar
            GestureDetector(
              onTap: () => _openPartnerProfile(log),
              child: Stack(
                children: [
                  Container(
                    width: 50,
                    height: 50,
                    decoration: const BoxDecoration(shape: BoxShape.circle),
                    child: ClipOval(
                      child: CachedImageLoader(
                        imageUrl: partnerAvatar,
                        fit: BoxFit.cover,
                        placeholder: Container(
                          color: const Color(0xFF28203E),
                          child: const Icon(Icons.person, color: Colors.white54, size: 26),
                        ),
                      ),
                    ),
                  ),
                  if (partner['is_online'] == true)
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        width: 14,
                        height: 14,
                        decoration: BoxDecoration(
                          color: const Color(0xFF00E676),
                          shape: BoxShape.circle,
                          border: Border.all(color: AppColors.backgroundDark, width: 2),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 12),

            // Call Details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    partnerName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        isMissed
                            ? Icons.call_missed_rounded
                            : (isOutgoing ? Icons.call_made_rounded : Icons.call_received_rounded),
                        size: 14,
                        color: isMissed
                            ? const Color(0xFFFF5252)
                            : (isOutgoing ? const Color(0xFF00E5FF) : const Color(0xFF69F0AE)),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        isMissed ? 'Missed' : durationText,
                        style: TextStyle(
                          color: isMissed ? const Color(0xFFFF5252) : AppColors.textMuted,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '• $timeAgo',
                        style: const TextStyle(color: Colors.white38, fontSize: 11),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Coins & Call Action Button
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (coins > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    margin: const EdgeInsets.only(bottom: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFD54F).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.diamond_rounded, size: 10, color: Color(0xFFFFD54F)),
                        const SizedBox(width: 2),
                        Text(
                          '$coins',
                          style: const TextStyle(
                            color: Color(0xFFFFD54F),
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                IconButton(
                  onPressed: () => _onCallAgain(log),
                  icon: Icon(
                    isVideo ? Icons.videocam_rounded : Icons.call_rounded,
                    color: AppColors.neonPink,
                    size: 24,
                  ),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.cardDarkElevated,
              border: Border.all(color: AppColors.cardBorder),
            ),
            child: const Icon(
              Icons.phone_missed_rounded,
              color: AppColors.neonPink,
              size: 38,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'No call history yet',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Your incoming and outgoing call logs will appear here.',
            style: TextStyle(
              color: AppColors.textMuted,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}

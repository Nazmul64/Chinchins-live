import 'package:flutter/material.dart';
import '../../../core/models/group_room.dart';
import '../../../core/services/party_room_api_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/cached_image_loader.dart';

class SeatRequestsBottomSheet extends StatefulWidget {
  final dynamic roomId;
  final Function(PartyRoomSeatRequest request, bool accepted) onResponded;

  const SeatRequestsBottomSheet({
    super.key,
    required this.roomId,
    required this.onResponded,
  });

  static Future<void> show(
    BuildContext context, {
    required dynamic roomId,
    required Function(PartyRoomSeatRequest request, bool accepted) onResponded,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => SeatRequestsBottomSheet(
        roomId: roomId,
        onResponded: onResponded,
      ),
    );
  }

  @override
  State<SeatRequestsBottomSheet> createState() => _SeatRequestsBottomSheetState();
}

class _SeatRequestsBottomSheetState extends State<SeatRequestsBottomSheet> {
  List<PartyRoomSeatRequest> _requests = [];
  bool _isLoading = true;
  final Set<dynamic> _processingIds = {};

  @override
  void initState() {
    super.initState();
    _loadRequests();
  }

  Future<void> _loadRequests() async {
    setState(() => _isLoading = true);
    final data = await PartyRoomApiService.getSeatRequests(widget.roomId);
    if (mounted) {
      setState(() {
        _requests = data;
        _isLoading = false;
      });
    }
  }

  Future<void> _handleAction(PartyRoomSeatRequest req, bool accept) async {
    setState(() => _processingIds.add(req.requestId));
    final action = accept ? 'accept' : 'reject';
    final res = await PartyRoomApiService.respondSeatRequest(widget.roomId, req.requestId, action: action);

    if (mounted) {
      setState(() {
        _processingIds.remove(req.requestId);
        _requests.removeWhere((r) => r.requestId == req.requestId);
      });

      widget.onResponded(req, accept);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res['message'] ?? (accept ? '${req.name} stage এ যোগ দিয়েছেন!' : 'রিকোয়েস্ট বাতিল করা হয়েছে')),
          backgroundColor: accept ? const Color(0xFF10B981) : const Color(0xFFEF4444),
          duration: const Duration(seconds: 2),
        ),
      );

      if (_requests.isEmpty) {
        Navigator.pop(context);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.65,
      ),
      decoration: const BoxDecoration(
        color: Color(0xFF131A26),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(
          top: BorderSide(color: Color(0xFF00E5FF), width: 1.2),
        ),
        boxShadow: [
          BoxShadow(
            color: Color(0x6600E5FF),
            blurRadius: 20,
            spreadRadius: -4,
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            const SizedBox(height: 10),
            Container(
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 12),

            // Header Row
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: const Color(0xFF00E5FF).withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.pan_tool_rounded, color: Color(0xFF00E5FF), size: 18),
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    'Guest Speaker Requests',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFF00E5FF),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${_requests.length}',
                      style: const TextStyle(
                        color: Colors.black,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Colors.white60, size: 20),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            const Divider(color: Colors.white12, height: 16),

            // Request List or Loading / Empty State
            if (_isLoading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: Center(
                  child: CircularProgressIndicator(color: Color(0xFF00E5FF), strokeWidth: 2.5),
                ),
              )
            else if (_requests.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: const BoxDecoration(
                        color: Color(0xFF1E293B),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.mic_none_rounded, color: Colors.white38, size: 36),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'কোনো স্পিকার রিকোয়েস্ট অপেক্ষমান নেই',
                      style: TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'শ্রোতারা হাত তুললে (Raise Hand) এখানে শো করবে',
                      style: TextStyle(color: Colors.white38, fontSize: 12),
                    ),
                  ],
                ),
              )
            else
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  itemCount: _requests.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final req = _requests[index];
                    final isProcessing = _processingIds.contains(req.requestId);

                    return Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1B2436),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFF2E3D59)),
                      ),
                      child: Row(
                        children: [
                          // Avatar with Level Ring
                          Stack(
                            alignment: Alignment.center,
                            children: [
                              Container(
                                width: 46,
                                height: 46,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: const LinearGradient(
                                    colors: [Color(0xFF00E5FF), Color(0xFFA855F7)],
                                  ),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(2),
                                  child: ClipOval(
                                    child: req.avatarUrl.isNotEmpty
                                        ? CachedImageLoader(imageUrl: req.avatarUrl, fit: BoxFit.cover)
                                        : Container(
                                            color: const Color(0xFF251E36),
                                            child: Center(
                                              child: Text(
                                                req.name.isNotEmpty ? req.name[0].toUpperCase() : 'U',
                                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                              ),
                                            ),
                                          ),
                                  ),
                                ),
                              ),
                              Positioned(
                                bottom: -2,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFE11D48),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    'Lv.${req.level}',
                                    style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(width: 12),

                          // Name and Details
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Flexible(
                                      child: Text(
                                        req.name,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    const Icon(Icons.verified_rounded, color: Color(0xFF00E5FF), size: 14),
                                  ],
                                ),
                                const SizedBox(height: 3),
                                Row(
                                  children: [
                                    const Icon(Icons.diamond_rounded, color: AppColors.gemYellow, size: 12),
                                    const SizedBox(width: 2),
                                    Text(
                                      '${req.coins} Gems',
                                      style: const TextStyle(color: Colors.white60, fontSize: 11),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),

                          // Action Buttons (Decline / Accept)
                          if (isProcessing)
                            const SizedBox(
                              width: 32,
                              height: 32,
                              child: CircularProgressIndicator(color: Color(0xFF00E5FF), strokeWidth: 2),
                            )
                          else
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // Decline Button
                                InkWell(
                                  onTap: () => _handleAction(req, false),
                                  borderRadius: BorderRadius.circular(12),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFFF1744).withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: const Color(0xFFFF1744).withValues(alpha: 0.4)),
                                    ),
                                    child: const Row(
                                      children: [
                                        Icon(Icons.close_rounded, color: Color(0xFFFF1744), size: 14),
                                        SizedBox(width: 2),
                                        Text(
                                          'Decline',
                                          style: TextStyle(color: Color(0xFFFF1744), fontSize: 11, fontWeight: FontWeight.w600),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),

                                // Accept Button
                                InkWell(
                                  onTap: () => _handleAction(req, true),
                                  borderRadius: BorderRadius.circular(12),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                                    decoration: BoxDecoration(
                                      gradient: const LinearGradient(
                                        colors: [Color(0xFF00E5FF), Color(0xFF10B981)],
                                      ),
                                      borderRadius: BorderRadius.circular(12),
                                      boxShadow: [
                                        BoxShadow(
                                          color: const Color(0xFF00E5FF).withValues(alpha: 0.3),
                                          blurRadius: 6,
                                        ),
                                      ],
                                    ),
                                    child: const Row(
                                      children: [
                                        Icon(Icons.check_rounded, color: Colors.black, size: 15),
                                        SizedBox(width: 3),
                                        Text(
                                          'Accept',
                                          style: TextStyle(color: Colors.black, fontSize: 11, fontWeight: FontWeight.bold),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}

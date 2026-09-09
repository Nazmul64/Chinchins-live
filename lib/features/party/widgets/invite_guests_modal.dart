import 'package:flutter/material.dart';
import '../../../core/models/group_room.dart';
import '../../../core/services/party_room_api_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/cached_image_loader.dart';

class InviteGuestsModal extends StatefulWidget {
  final dynamic roomId;
  final int targetSeatIndex;
  final Function(PartyRoomInvitee invitee) onInvited;

  const InviteGuestsModal({
    super.key,
    required this.roomId,
    required this.targetSeatIndex,
    required this.onInvited,
  });

  static Future<void> show(
    BuildContext context, {
    required dynamic roomId,
    required int targetSeatIndex,
    required Function(PartyRoomInvitee invitee) onInvited,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => InviteGuestsModal(
        roomId: roomId,
        targetSeatIndex: targetSeatIndex,
        onInvited: onInvited,
      ),
    );
  }

  @override
  State<InviteGuestsModal> createState() => _InviteGuestsModalState();
}

class _InviteGuestsModalState extends State<InviteGuestsModal> {
  final TextEditingController _searchController = TextEditingController();
  List<PartyRoomInvitee> _invitees = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadInvitees();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadInvitees([String? query]) async {
    setState(() => _isLoading = true);
    final results = await PartyRoomApiService.searchInvitees(widget.roomId, query: query);
    if (mounted) {
      setState(() {
        _invitees = results;
        _isLoading = false;
      });
    }
  }

  void _handleInvite(PartyRoomInvitee invitee) async {
    final res = await PartyRoomApiService.inviteGuest(
      widget.roomId,
      userId: invitee.id,
      seatIndex: widget.targetSeatIndex,
    );

    if (mounted) {
      Navigator.pop(context);
      if (res['success'] == true) {
        widget.onInvited(invitee);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Invited ${invitee.name} to Seat ${widget.targetSeatIndex + 1}! 🎉'),
            backgroundColor: AppColors.neonPink,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(res['message'] ?? 'Failed to send invite')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.72,
      decoration: const BoxDecoration(
        color: Color(0xFF19132B),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(top: BorderSide(color: AppColors.cardBorder, width: 1)),
      ),
      child: Column(
        children: [
          // Drag Handle
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 14),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Invite to Seat ${widget.targetSeatIndex + 1} 🎤',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      'Search by Name, 8-digit ID, or Connected Friends',
                      style: TextStyle(color: AppColors.textMuted, fontSize: 11),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: Colors.white70),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // Search Box
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              height: 42,
              decoration: BoxDecoration(
                color: AppColors.cardDarkElevated,
                borderRadius: BorderRadius.circular(21),
                border: Border.all(color: AppColors.cardBorder),
              ),
              child: TextField(
                controller: _searchController,
                style: const TextStyle(color: Colors.white, fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'Search Name or 8-digit ID...',
                  hintStyle: const TextStyle(color: AppColors.textHint, fontSize: 12),
                  prefixIcon: const Icon(Icons.search_rounded, color: AppColors.neonPink, size: 20),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear_rounded, color: Colors.white54, size: 16),
                          onPressed: () {
                            _searchController.clear();
                            _loadInvitees();
                          },
                        )
                      : null,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.only(top: 8),
                ),
                onSubmitted: (val) => _loadInvitees(val.trim()),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Invitee List
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: AppColors.neonPink),
                  )
                : _invitees.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.people_outline_rounded, color: AppColors.textMuted, size: 48),
                            const SizedBox(height: 10),
                            const Text(
                              'No users found',
                              style: TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _searchController.text.isNotEmpty
                                  ? 'Try searching with another name or ID'
                                  : 'Connect with friends to invite them easily',
                              style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                        itemCount: _invitees.length,
                        itemBuilder: (context, index) {
                          final user = _invitees[index];

                          return Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: AppColors.cardDark,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: AppColors.cardBorder),
                            ),
                            child: Row(
                              children: [
                                // Avatar + Online dot
                                Stack(
                                  children: [
                                    CircleAvatar(
                                      radius: 22,
                                      backgroundColor: const Color(0xFF2C2244),
                                      child: ClipOval(
                                        child: (user.avatarUrl.isNotEmpty)
                                            ? CachedImageLoader(
                                                imageUrl: user.avatarUrl,
                                                fit: BoxFit.cover,
                                              )
                                            : Text(
                                                user.name.isNotEmpty ? user.name[0].toUpperCase() : 'U',
                                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                              ),
                                      ),
                                    ),
                                    if (user.isOnline)
                                      Positioned(
                                        bottom: 0,
                                        right: 0,
                                        child: Container(
                                          width: 10,
                                          height: 10,
                                          decoration: BoxDecoration(
                                            color: AppColors.onlineGreen,
                                            shape: BoxShape.circle,
                                            border: Border.all(color: AppColors.cardDark, width: 1.5),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                                const SizedBox(width: 12),

                                // Name & ID / Badges
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Flexible(
                                            child: Text(
                                              user.name,
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 13.5,
                                                fontWeight: FontWeight.bold,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          const SizedBox(width: 6),
                                          // Level badge
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                            decoration: BoxDecoration(
                                              gradient: AppColors.orangeGradient,
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            child: Text(
                                              'Lv.${user.level}',
                                              style: const TextStyle(color: Colors.white, fontSize: 8.5, fontWeight: FontWeight.bold),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 3),
                                      Row(
                                        children: [
                                          Text(
                                            'ID: ${user.accountId}',
                                            style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
                                          ),
                                          if (user.isLiked) ...[
                                            const SizedBox(width: 6),
                                            const Icon(Icons.favorite_rounded, color: AppColors.neonPink, size: 10),
                                            const SizedBox(width: 2),
                                            const Text(
                                              'Liked Friend',
                                              style: TextStyle(color: AppColors.neonPink, fontSize: 10, fontWeight: FontWeight.w500),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ],
                                  ),
                                ),

                                // Invite Button
                                if (user.isOnSeat)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: Colors.white12,
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    child: const Text(
                                      'On Seat',
                                      style: TextStyle(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.bold),
                                    ),
                                  )
                                else
                                  ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppColors.neonPink,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                                      elevation: 4,
                                    ),
                                    onPressed: () => _handleInvite(user),
                                    child: const Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.person_add_alt_1_rounded, color: Colors.white, size: 14),
                                        SizedBox(width: 4),
                                        Text('Invite', style: TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.bold)),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}

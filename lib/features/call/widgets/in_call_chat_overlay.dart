import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/cached_image_loader.dart';
import '../services/call_api_service.dart';
import 'in_call_image_viewer_modal.dart';

class CallChatMessage {
  final String id;
  final String senderName;
  final String? senderAvatar;
  final bool isMe;
  final String type; // 'text' or 'image'
  final String message;
  final String? imageUrl;
  final DateTime timestamp;

  CallChatMessage({
    required this.id,
    required this.senderName,
    this.senderAvatar,
    required this.isMe,
    this.type = 'text',
    required this.message,
    this.imageUrl,
    required this.timestamp,
  });

  factory CallChatMessage.fromJson(Map<String, dynamic> json, {String? myId}) {
    final senderId = json['sender_id']?.toString();
    final isMe = (myId != null && senderId == myId) || json['is_me'] == true;
    return CallChatMessage(
      id: json['id']?.toString() ?? DateTime.now().millisecondsSinceEpoch.toString(),
      senderName: json['sender_name'] ?? (isMe ? 'You' : 'Host'),
      senderAvatar: json['sender_avatar']?.toString(),
      isMe: isMe,
      type: json['type']?.toString() ?? 'text',
      message: json['message']?.toString() ?? '',
      imageUrl: json['image_url']?.toString() ?? json['file_url']?.toString(),
      timestamp: json['created_at'] != null
          ? (DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now())
          : DateTime.now(),
    );
  }
}

class InCallChatOverlay extends StatefulWidget {
  final dynamic callSessionId;
  final dynamic receiverId;
  final String receiverName;
  final String? myId;
  final String? myName;

  const InCallChatOverlay({
    super.key,
    required this.callSessionId,
    required this.receiverId,
    required this.receiverName,
    this.myId,
    this.myName,
  });

  @override
  State<InCallChatOverlay> createState() => InCallChatOverlayState();
}

class InCallChatOverlayState extends State<InCallChatOverlay> {
  final List<CallChatMessage> _messages = [];
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final ImagePicker _picker = ImagePicker();
  bool _isUploadingImage = false;
  bool _isChatOpen = false;

  @override
  void initState() {
    super.initState();
    _loadInitialMessages();
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialMessages() async {
    try {
      final msgs = await CallApiService.getCallChatMessages(
        callId: widget.callSessionId,
        callSessionId: widget.callSessionId,
      );
      if (msgs.isNotEmpty && mounted) {
        setState(() {
          _messages.clear();
          for (final m in msgs) {
            _messages.add(CallChatMessage.fromJson(m, myId: widget.myId));
          }
        });
        _scrollToBottom();
      }
    } catch (_) {}
  }

  void addIncomingMessage(Map<String, dynamic> data) {
    if (!mounted) return;
    setState(() {
      _messages.add(CallChatMessage.fromJson(data, myId: widget.myId));
    });
    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendTextMessage([String? presetText]) async {
    final text = (presetText ?? _textController.text).trim();
    if (text.isEmpty) return;

    _textController.clear();

    final localMsg = CallChatMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      senderName: widget.myName ?? 'You',
      isMe: true,
      type: 'text',
      message: text,
      timestamp: DateTime.now(),
    );

    setState(() {
      _messages.add(localMsg);
    });
    _scrollToBottom();

    await CallApiService.sendCallChatMessage(
      callSessionId: widget.callSessionId,
      receiverId: widget.receiverId,
      message: text,
      type: 'text',
    );
  }

  Future<void> _pickAndSendImage() async {
    try {
      final XFile? file = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
        maxWidth: 1280,
      );
      if (file == null) return;

      setState(() => _isUploadingImage = true);

      final uploadedUrl = await CallApiService.uploadLiveImage(File(file.path));

      if (uploadedUrl != null && mounted) {
        final localMsg = CallChatMessage(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          senderName: widget.myName ?? 'You',
          isMe: true,
          type: 'image',
          message: '📷 Photo',
          imageUrl: uploadedUrl,
          timestamp: DateTime.now(),
        );

        setState(() {
          _messages.add(localMsg);
        });
        _scrollToBottom();

        await CallApiService.sendCallChatMessage(
          callSessionId: widget.callSessionId,
          receiverId: widget.receiverId,
          message: '📷 Photo',
          type: 'image',
          imageUrl: uploadedUrl,
        );
      }
    } catch (e) {
      debugPrint('Error sharing live image: $e');
    } finally {
      if (mounted) {
        setState(() => _isUploadingImage = false);
      }
    }
  }

  void toggleChatDrawer() {
    setState(() {
      _isChatOpen = !_isChatOpen;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. Floating Message Bubbles List (Max height 160)
        if (_messages.isNotEmpty)
          Container(
            constraints: const BoxConstraints(maxHeight: 160, maxWidth: 280),
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: ListView.builder(
              controller: _scrollController,
              shrinkWrap: true,
              physics: const BouncingScrollPhysics(),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final msg = _messages[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Align(
                    alignment: msg.isMe ? Alignment.centerRight : Alignment.centerLeft,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: msg.isMe
                            ? AppColors.neonPink.withValues(alpha: 0.85)
                            : Colors.black.withValues(alpha: 0.65),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: msg.isMe ? Colors.white30 : Colors.white12,
                          width: 0.8,
                        ),
                      ),
                      child: msg.type == 'image' && msg.imageUrl != null
                          ? GestureDetector(
                              onTap: () => InCallImageViewerModal.show(context, msg.imageUrl!),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: CachedImageLoader(
                                  imageUrl: msg.imageUrl!,
                                  width: 120,
                                  height: 120,
                                  fit: BoxFit.cover,
                                ),
                              ),
                            )
                          : RichText(
                              text: TextSpan(
                                children: [
                                  TextSpan(
                                    text: '${msg.senderName}: ',
                                    style: TextStyle(
                                      color: msg.isMe ? Colors.white : AppColors.neonPink,
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  TextSpan(
                                    text: msg.message,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 11.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                    ),
                  ),
                );
              },
            ),
          ),

        // 2. Chat Input Row
        if (_isChatOpen) ...[
          const SizedBox(height: 6),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.8),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: AppColors.neonPink.withValues(alpha: 0.7), width: 1.2),
            ),
            child: Row(
              children: [
                // Image Attachment Button
                GestureDetector(
                  onTap: _isUploadingImage ? null : _pickAndSendImage,
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: _isUploadingImage
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.neonPink),
                          )
                        : const Icon(Icons.photo_library_rounded, color: Colors.white, size: 18),
                  ),
                ),
                const SizedBox(width: 8),

                // Text Input
                Expanded(
                  child: TextField(
                    controller: _textController,
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                    decoration: const InputDecoration(
                      hintText: 'Type live message...',
                      hintStyle: TextStyle(color: Colors.white54, fontSize: 13),
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(vertical: 6),
                    ),
                    onSubmitted: (_) => _sendTextMessage(),
                  ),
                ),

                // Send Button
                GestureDetector(
                  onTap: () => _sendTextMessage(),
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      gradient: AppColors.primaryGradient,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.send_rounded, color: Colors.white, size: 16),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

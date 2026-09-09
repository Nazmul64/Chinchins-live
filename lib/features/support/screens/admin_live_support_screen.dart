import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/cached_image_loader.dart';
import '../../auth/services/auth_api_service.dart';
import '../models/support_message_model.dart';
import '../services/support_api_service.dart';

class AdminLiveSupportScreen extends StatefulWidget {
  final String? initialMessage;

  const AdminLiveSupportScreen({
    super.key,
    this.initialMessage,
  });

  @override
  State<AdminLiveSupportScreen> createState() => _AdminLiveSupportScreenState();
}

class _AdminLiveSupportScreenState extends State<AdminLiveSupportScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final ImagePicker _picker = ImagePicker();
  final AudioRecorder _audioRecorder = AudioRecorder();

  List<SupportMessageModel> _messages = [];
  bool _isLoading = true;
  bool _isSending = false;
  bool _isRecording = false;
  int _recordDurationSeconds = 0;
  Timer? _recordTimer;
  Timer? _pollingTimer;

  String _userAccountId = '';

  @override
  void initState() {
    super.initState();
    _loadUserAndMessages();
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    _recordTimer?.cancel();
    _audioRecorder.dispose();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadUserAndMessages() async {
    try {
      final user = await AuthApiService.getSavedUser();
      if (user != null && mounted) {
        setState(() {
          _userAccountId = user['account_id']?.toString() ??
              user['id']?.toString() ??
              '';
        });
      }
    } catch (_) {}

    if (widget.initialMessage != null && widget.initialMessage!.isNotEmpty) {
      _messageController.text = widget.initialMessage!;
    }

    await _fetchMessages();

    // Background live polling every 3.5 seconds
    _pollingTimer = Timer.periodic(const Duration(milliseconds: 3500), (_) {
      _fetchMessages(isBackground: true);
    });
  }

  Future<void> _fetchMessages({bool isBackground = false}) async {
    if (!isBackground) {
      setState(() => _isLoading = true);
    }

    final list = await SupportApiService.getSupportMessages();

    if (mounted) {
      setState(() {
        if (list.isNotEmpty) {
          _messages = list;
        }
        _isLoading = false;
      });

      if (!isBackground && _messages.isNotEmpty) {
        _scrollToBottom();
      }
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage({String? customText, File? imageFile, File? audioFile}) async {
    final text = customText ?? _messageController.text.trim();
    if (text.isEmpty && imageFile == null && audioFile == null) return;

    if (customText == null && imageFile == null && audioFile == null) {
      _messageController.clear();
    }

    final tempMsg = SupportMessageModel(
      id: DateTime.now().millisecondsSinceEpoch,
      userId: int.tryParse(_userAccountId) ?? 0,
      senderType: 'user',
      isMe: true,
      senderName: 'You',
      type: imageFile != null ? 'image' : (audioFile != null ? 'voice' : 'text'),
      message: text.isNotEmpty ? text : null,
      mediaUrl: imageFile?.path ?? audioFile?.path,
      isRead: false,
      createdAt: DateTime.now(),
      formattedTime: _formatTime(DateTime.now()),
    );

    setState(() {
      _messages.add(tempMsg);
      _isSending = true;
    });
    _scrollToBottom();

    final result = await SupportApiService.sendMessage(
      message: text.isNotEmpty ? text : null,
      type: tempMsg.type,
      imageFile: imageFile,
      audioFile: audioFile,
    );

    if (mounted) {
      setState(() {
        _isSending = false;
        if (result != null) {
          final idx = _messages.indexWhere((m) => m.id == tempMsg.id);
          if (idx != -1) {
            _messages[idx] = result;
          }
        }
      });
      _scrollToBottom();
    }
  }

  Future<void> _pickImage() async {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E182A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              margin: const EdgeInsets.only(top: 10, bottom: 8),
              width: 38,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'Send Screenshot / Attachment to Support',
                style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_rounded, color: Color(0xFFFF2D87)),
              title: const Text('Choose from Gallery', style: TextStyle(color: Colors.white)),
              onTap: () async {
                Navigator.pop(ctx);
                final picked = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
                if (picked != null) {
                  _sendMessage(imageFile: File(picked.path), customText: 'Attachment');
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt_rounded, color: Color(0xFF00E676)),
              title: const Text('Take a Photo', style: TextStyle(color: Colors.white)),
              onTap: () async {
                Navigator.pop(ctx);
                final picked = await _picker.pickImage(source: ImageSource.camera, imageQuality: 85);
                if (picked != null) {
                  _sendMessage(imageFile: File(picked.path), customText: 'Attachment');
                }
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _toggleAudioRecording() async {
    if (_isRecording) {
      final path = await _audioRecorder.stop();
      _recordTimer?.cancel();
      setState(() {
        _isRecording = false;
      });

      if (path != null && File(path).existsSync()) {
        _sendMessage(audioFile: File(path));
      }
      _recordDurationSeconds = 0;
    } else {
      if (await _audioRecorder.hasPermission()) {
        final dir = await getTemporaryDirectory();
        final filePath = '${dir.path}/support_voice_${DateTime.now().millisecondsSinceEpoch}.m4a';

        await _audioRecorder.start(
          const RecordConfig(encoder: AudioEncoder.aacLc),
          path: filePath,
        );

        setState(() {
          _isRecording = true;
          _recordDurationSeconds = 0;
        });

        _recordTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
          setState(() {
            _recordDurationSeconds++;
          });
        });
      }
    }
  }

  String _formatTime(DateTime dt) {
    final hour = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
    final min = dt.minute.toString().padLeft(2, '0');
    final amPm = dt.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$min $amPm';
  }

  void _showImagePreview(String imageUrl) {
    showDialog(
      context: context,
      barrierColor: Colors.black87,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(12),
        child: Stack(
          alignment: Alignment.topRight,
          children: [
            Center(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: imageUrl.startsWith('http')
                    ? CachedImageLoader(imageUrl: imageUrl, fit: BoxFit.contain)
                    : Image.file(File(imageUrl), fit: BoxFit.contain),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close_rounded, color: Colors.white, size: 28),
              onPressed: () => Navigator.pop(ctx),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF090710),
      appBar: AppBar(
        backgroundColor: const Color(0xFF100D1B),
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        titleSpacing: 0,
        title: Row(
          children: [
            // Admin Official Avatar with Verified Badge
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFE91E63), Color(0xFF9C27B0)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFFFFD54F), width: 1.5),
                  ),
                  child: const Center(
                    child: Icon(Icons.support_agent_rounded, color: Colors.white, size: 22),
                  ),
                ),
                Positioned(
                  bottom: -1,
                  right: -1,
                  child: Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: const Color(0xFF00E676),
                      shape: BoxShape.circle,
                      border: Border.all(color: const Color(0xFF100D1B), width: 2),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 10),

            // Title & Online Status
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Customer Service 24/7',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Row(
                    children: [
                      Text(
                        '100% Free Live Support',
                        style: TextStyle(
                          color: Color(0xFF00E676),
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.white70, size: 22),
            onPressed: () => _fetchMessages(),
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: Column(
        children: [
          // Top Notice Header Banner
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFFEC4899).withValues(alpha: 0.15),
                  const Color(0xFF8B5CF6).withValues(alpha: 0.12),
                ],
              ),
              border: Border(
                bottom: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
              ),
            ),
            child: const Row(
              children: [
                Icon(Icons.verified_user_rounded, color: Color(0xFFFF4081), size: 16),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Official ChinChins Support • Free assistance with Top-ups & Account',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Messages List View
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: AppColors.neonPink),
                  )
                : _messages.isEmpty
                    ? _buildEmptyState()
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        itemCount: _messages.length,
                        itemBuilder: (ctx, index) {
                          final msg = _messages[index];
                          return _buildMessageItem(msg);
                        },
                      ),
          ),

          if (_isSending)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Align(
                alignment: Alignment.centerRight,
                child: Text(
                  'Sending to support...',
                  style: TextStyle(color: Colors.white38, fontSize: 11),
                ),
              ),
            ),

          // Bottom Input Bar
          _buildBottomInputBar(),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: const Color(0xFFEC4899).withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.support_agent_rounded, color: Color(0xFFEC4899), size: 40),
            ),
            const SizedBox(height: 16),
            const Text(
              'How can we help you today?',
              style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Send your question, payment transaction ID, or screenshot. Our support administrators reply promptly 24/7.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white60, fontSize: 12.5, height: 1.4),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageItem(SupportMessageModel msg) {
    final isMe = msg.isMe;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMe) ...[
            Container(
              width: 32,
              height: 32,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFFE91E63), Color(0xFF9C27B0)],
                ),
                shape: BoxShape.circle,
              ),
              child: const Center(
                child: Icon(Icons.headset_mic_rounded, color: Colors.white, size: 18),
              ),
            ),
            const SizedBox(width: 8),
          ],

          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                gradient: isMe
                    ? const LinearGradient(
                        colors: [
                          Color(0xFFFF007F),
                          Color(0xFFE60067),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      )
                    : const LinearGradient(
                        colors: [
                          Color(0xFF1E192D),
                          Color(0xFF28203B),
                        ],
                      ),
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(18),
                  topRight: const Radius.circular(18),
                  bottomLeft: Radius.circular(isMe ? 18 : 4),
                  bottomRight: Radius.circular(isMe ? 4 : 18),
                ),
                boxShadow: [
                  BoxShadow(
                    color: isMe
                        ? const Color(0xFFFF007F).withValues(alpha: 0.3)
                        : Colors.black.withValues(alpha: 0.2),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                children: [
                  if (!isMe) ...[
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.verified_rounded, color: Color(0xFFFFD54F), size: 13),
                        const SizedBox(width: 4),
                        Text(
                          msg.senderName,
                          style: const TextStyle(
                            color: Color(0xFFFFD54F),
                            fontSize: 11.5,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                  ],

                  if (msg.type == 'image' && msg.mediaUrl != null && msg.mediaUrl!.isNotEmpty) ...[
                    GestureDetector(
                      onTap: () => _showImagePreview(msg.mediaUrl!),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: msg.mediaUrl!.startsWith('http')
                            ? CachedImageLoader(
                                imageUrl: msg.mediaUrl!,
                                width: 220,
                                fit: BoxFit.cover,
                              )
                            : Image.file(
                                File(msg.mediaUrl!),
                                width: 220,
                                fit: BoxFit.cover,
                              ),
                      ),
                    ),
                    const SizedBox(height: 6),
                  ],

                  if (msg.type == 'voice') ...[
                    const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.play_arrow_rounded, color: Colors.white, size: 22),
                        SizedBox(width: 6),
                        Text(
                          'Voice Note',
                          style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                  ],

                  if (msg.message != null && msg.message!.isNotEmpty && msg.message != 'Attachment')
                    Text(
                      msg.message!,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        height: 1.35,
                      ),
                    ),

                  const SizedBox(height: 4),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        msg.formattedTime,
                        style: const TextStyle(
                          color: Colors.white54,
                          fontSize: 10,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                      if (isMe) ...[
                        const SizedBox(width: 4),
                        Icon(
                          msg.isRead ? Icons.done_all_rounded : Icons.done_rounded,
                          color: msg.isRead ? const Color(0xFF00E676) : Colors.white54,
                          size: 13,
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomInputBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 14),
      decoration: BoxDecoration(
        color: const Color(0xFF100D1B),
        border: Border(
          top: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            // Image / Screenshot upload button
            IconButton(
              icon: const Icon(Icons.image_rounded, color: Color(0xFFFF2D87), size: 24),
              onPressed: _pickImage,
              tooltip: 'Send Screenshot / Image',
            ),

            // Voice recording button
            GestureDetector(
              onTap: _toggleAudioRecording,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _isRecording ? Colors.redAccent : Colors.transparent,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _isRecording ? Icons.stop_rounded : Icons.mic_rounded,
                  color: _isRecording ? Colors.white : Colors.white70,
                  size: 22,
                ),
              ),
            ),
            const SizedBox(width: 4),

            // Input Text Field
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E192D),
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                ),
                child: _isRecording
                    ? Row(
                        children: [
                          const Icon(Icons.fiber_manual_record_rounded, color: Colors.redAccent, size: 14),
                          const SizedBox(width: 6),
                          Text(
                            'Recording (${_recordDurationSeconds}s)... Tap mic to stop & send',
                            style: const TextStyle(color: Colors.redAccent, fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                        ],
                      )
                    : TextField(
                        controller: _messageController,
                        style: const TextStyle(color: Colors.white, fontSize: 14),
                        decoration: const InputDecoration(
                          hintText: 'Message Support...',
                          hintStyle: TextStyle(color: Colors.white38, fontSize: 13.5),
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(vertical: 10),
                        ),
                        maxLines: 4,
                        minLines: 1,
                        textInputAction: TextInputAction.send,
                        onSubmitted: (_) => _sendMessage(),
                      ),
              ),
            ),
            const SizedBox(width: 8),

            // Send Button
            GestureDetector(
              onTap: _isSending ? null : () => _sendMessage(),
              child: Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFF007F), Color(0xFFE60067)],
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFFF007F).withValues(alpha: 0.4),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const Center(
                  child: Icon(Icons.send_rounded, color: Colors.white, size: 20),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

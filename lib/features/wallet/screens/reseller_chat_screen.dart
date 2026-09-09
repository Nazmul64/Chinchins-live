import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/cached_image_loader.dart';
import '../../auth/services/auth_api_service.dart';
import '../models/reseller_chat_message_model.dart';
import '../models/reseller_model.dart';
import '../services/reseller_api_service.dart';

class ResellerChatScreen extends StatefulWidget {
  final ResellerModel reseller;
  final int requestedCoins;
  final double requestedAmount;
  final String? initialPrefillMessage;

  const ResellerChatScreen({
    super.key,
    required this.reseller,
    this.requestedCoins = 7560,
    this.requestedAmount = 150.0,
    this.initialPrefillMessage,
  });

  @override
  State<ResellerChatScreen> createState() => _ResellerChatScreenState();
}

class _ResellerChatScreenState extends State<ResellerChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final ImagePicker _picker = ImagePicker();
  final AudioRecorder _audioRecorder = AudioRecorder();

  List<ResellerChatMessage> _messages = [];
  bool _isLoading = true;
  bool _isSending = false;
  bool _isRecording = false;
  int _recordDurationSeconds = 0;
  Timer? _recordTimer;
  Timer? _pollingTimer;

  Map<String, dynamic>? _currentUser;
  String _userAccountId = '266813634';
  String? _userAvatarUrl;

  @override
  void initState() {
    super.initState();
    _loadUserAndChat();
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

  Future<void> _loadUserAndChat() async {
    try {
      final user = await AuthApiService.getSavedUser();
      if (user != null && mounted) {
        setState(() {
          _currentUser = user;
          _userAccountId = user['account_id']?.toString() ??
              user['id']?.toString() ??
              '266813634';
          _userAvatarUrl = user['avatar_url']?.toString() ??
              user['avatar']?.toString() ??
              user['profile_photo_url']?.toString();
        });
      }
    } catch (_) {}

    // Generate standard pre-fill message if input is currently empty
    final coins = widget.requestedCoins;
    final defaultPrefill = widget.initialPrefillMessage ??
        'Hello! My user ID is $_userAccountId. I want to recharge $coins gems. How much should I pay? 【GIVE THE BEST DISCOUNT 💎DIAMOND💎】';

    if (_messageController.text.isEmpty) {
      _messageController.text = defaultPrefill;
    }

    // Fetch message history from API
    await _fetchMessages();

    // Start light polling for real-time live chat updates
    _pollingTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      _fetchMessages(isBackground: true);
    });
  }

  Future<void> _fetchMessages({bool isBackground = false}) async {
    if (!isBackground) {
      setState(() => _isLoading = true);
    }

    final list = await ResellerApiService.getChatMessages(widget.reseller.id);

    if (mounted) {
      setState(() {
        if (list.isNotEmpty) {
          _messages = list;
        } else if (_messages.isEmpty) {
          // If no message history yet, provide clean initial state
          _messages = [];
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

  Future<void> _sendMessage({String? customText, File? imageFile, File? audioFile, int? duration}) async {
    final text = customText ?? _messageController.text.trim();
    if (text.isEmpty && imageFile == null && audioFile == null) return;

    if (customText == null && imageFile == null && audioFile == null) {
      _messageController.clear();
    }

    // Optimistically add message to UI
    final tempMsg = ResellerChatMessage(
      id: DateTime.now().millisecondsSinceEpoch,
      resellerId: widget.reseller.id,
      senderType: 'user',
      isMe: true,
      type: imageFile != null ? 'image' : (audioFile != null ? 'voice' : 'text'),
      message: text,
      mediaUrl: imageFile?.path ?? audioFile?.path,
      duration: duration,
      coinsAmount: widget.requestedCoins,
      isRead: false,
      createdAt: DateTime.now(),
      formattedTime: _formatTime(DateTime.now()),
    );

    setState(() {
      _messages.add(tempMsg);
      _isSending = true;
    });
    _scrollToBottom();

    final result = await ResellerApiService.sendMessage(
      resellerId: widget.reseller.id,
      message: text.isNotEmpty ? text : null,
      type: tempMsg.type,
      imageFile: imageFile,
      audioFile: audioFile,
      duration: duration,
      coinsAmount: widget.requestedCoins,
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
    }

    // Simulate instant reseller response if testing locally and no message from server yet
    _simulateResellerResponseIfNeeded(text);
  }

  void _simulateResellerResponseIfNeeded(String sentText) {
    if (sentText.contains('recharge') || sentText.contains('gems') || sentText.contains('pay')) {
      Future.delayed(const Duration(milliseconds: 1400), () {
        if (!mounted) return;
        final hasResellerReply = _messages.any((m) => !m.isMe);
        if (!hasResellerReply) {
          final reply = ResellerChatMessage(
            id: DateTime.now().millisecondsSinceEpoch + 1,
            resellerId: widget.reseller.id,
            senderType: 'reseller',
            isMe: false,
            type: 'text',
            message:
                'Hello Brother! For ${widget.requestedCoins} gems, send ৳${widget.requestedAmount > 15 ? (widget.requestedAmount - 10).toInt() : 140} to bKash/Nagad Personal: ${widget.reseller.phone} with your User ID $_userAccountId.',
            createdAt: DateTime.now(),
            formattedTime: _formatTime(DateTime.now()),
          );
          setState(() {
            _messages.add(reply);
          });
          _scrollToBottom();
        }
      });
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
                'Send Payment Proof / Screenshot',
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
                  _sendMessage(imageFile: File(picked.path), customText: 'Payment Screenshot');
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
                  _sendMessage(imageFile: File(picked.path), customText: 'Payment Screenshot');
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
      // Stop recording
      final path = await _audioRecorder.stop();
      _recordTimer?.cancel();
      setState(() {
        _isRecording = false;
      });

      if (path != null && File(path).existsSync()) {
        _sendMessage(audioFile: File(path), duration: _recordDurationSeconds);
      }
      _recordDurationSeconds = 0;
    } else {
      // Start recording
      if (await _audioRecorder.hasPermission()) {
        final dir = await getTemporaryDirectory();
        final filePath = '${dir.path}/voice_${DateTime.now().millisecondsSinceEpoch}.m4a';

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

  @override
  Widget build(BuildContext context) {
    final reseller = widget.reseller;

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
            // Reseller Avatar with badge
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFFFFD54F), width: 1.5),
                  ),
                  child: ClipOval(
                    child: CachedImageLoader(
                      imageUrl: reseller.avatarUrl,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                Positioned(
                  bottom: -2,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFC107),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        'Reseller',
                        style: TextStyle(
                          color: Colors.black,
                          fontSize: 7,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 10),

            // Reseller Name & status
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    reseller.name.length > 16
                        ? '${reseller.name.substring(0, 15)}...'
                        : reseller.name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Row(
                    children: [
                      Container(
                        width: 7,
                        height: 7,
                        decoration: const BoxDecoration(
                          color: Color(0xFF00E676),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Text(
                        '100% Free Live Chat',
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
            icon: const Icon(Icons.more_horiz_rounded, color: Colors.white, size: 24),
            onPressed: () {},
          ),
        ],
      ),
      body: Column(
        children: [
          // Chat Messages & Profile Card Feed
          Expanded(
            child: SingleChildScrollView(
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Column(
                children: [
                  const SizedBox(height: 6),

                  // 1. Reseller Profile Card at Top (Matching Screenshot 4 & 5)
                  _buildResellerProfileCard(reseller),

                  const SizedBox(height: 18),

                  // 2. Date Separator Pill: "Today 04:59"
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'Today ${_formatTime(DateTime.now())}',
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // 3. Message Bubbles
                  if (_isLoading)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 30),
                      child: Center(
                        child: CircularProgressIndicator(color: AppColors.neonPink),
                      ),
                    )
                  else
                    ..._messages.map((msg) => _buildMessageItem(msg)),

                  if (_isSending)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: Text(
                          'Sending...',
                          style: TextStyle(color: Colors.white38, fontSize: 11),
                        ),
                      ),
                    ),

                  const SizedBox(height: 10),
                ],
              ),
            ),
          ),

          // Bottom Input Bar & Actions (Matching Screenshot 4 & 5)
          _buildBottomInputBar(),
        ],
      ),
    );
  }

  Widget _buildResellerProfileCard(ResellerModel reseller) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFF38144D),
            Color(0xFF240E34),
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF6B21A8).withValues(alpha: 0.5), width: 1),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6B21A8).withValues(alpha: 0.15),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Reseller Title: MURAD ࿐ C🅾️INS RESELLER 💰
          Text(
            reseller.name.contains('RESELLER')
                ? reseller.name
                : '${reseller.name} 💰',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 8),

          // Badges Row: [👑 Lv5] [📍 Dhaka] [♂ 27]
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: [
              // Lv5 Badge (Purple)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF7C3AED), Color(0xFF9333EA)],
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.military_tech_rounded, color: Colors.white, size: 12),
                    const SizedBox(width: 2),
                    Text(
                      reseller.level,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10.5,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),

              // Dhaka Location Badge (Teal)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFF0D9488),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.location_on_rounded, color: Colors.white, size: 12),
                    const SizedBox(width: 2),
                    Text(
                      reseller.location.split(',').first,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10.5,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),

              // Gender & Age Badge (Cyan / Blue)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFF0284C7),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      reseller.gender == 'male' ? Icons.male_rounded : Icons.female_rounded,
                      color: Colors.white,
                      size: 13,
                    ),
                    const SizedBox(width: 2),
                    Text(
                      '${reseller.age}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10.5,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Reseller Golden Diamond Cards
          Row(
            children: [
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFFFD54F).withValues(alpha: 0.6)),
                ),
                child: const Center(
                  child: Icon(Icons.diamond_rounded, color: Color(0xFFFFD54F), size: 30),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  color: const Color(0xFF1E1428),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFFFC107).withValues(alpha: 0.8)),
                ),
                child: const Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('মুরাদ', style: TextStyle(color: Color(0xFFFFD54F), fontSize: 10, fontWeight: FontWeight.bold)),
                    Text('কয়েন সেলার', style: TextStyle(color: Colors.white, fontSize: 8)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Reseller Bengali Bio / Terms Text (Matching Screenshot 4)
          Text(
            reseller.bio,
            style: const TextStyle(
              color: Color(0xFFE2E8F0),
              fontSize: 12,
              height: 1.45,
              fontWeight: FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageItem(ResellerChatMessage msg) {
    final isMe = msg.isMe;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMe) ...[
            // Reseller Avatar
            CircleAvatar(
              radius: 16,
              backgroundImage: NetworkImage(widget.reseller.avatarUrl),
            ),
            const SizedBox(width: 8),
          ],

          // Bubble Container
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                gradient: isMe
                    ? const LinearGradient(
                        colors: [
                          Color(0xFFFF007F), // Neon Pink matching Screenshot 5
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
                  // Image Media Preview if present
                  if (msg.type == 'image' && msg.mediaUrl != null) ...[
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: msg.mediaUrl!.startsWith('http')
                          ? CachedImageLoader(
                              imageUrl: msg.mediaUrl!,
                              width: 200,
                              fit: BoxFit.cover,
                            )
                          : Image.file(
                              File(msg.mediaUrl!),
                              width: 200,
                              fit: BoxFit.cover,
                            ),
                    ),
                    const SizedBox(height: 6),
                  ],

                  // Voice Media Preview
                  if (msg.type == 'voice') ...[
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 22),
                        const SizedBox(width: 6),
                        Text(
                          'Voice Note (${msg.duration ?? 3}s)',
                          style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                  ],

                  // Text Message
                  if (msg.message.isNotEmpty)
                    Text(
                      msg.message,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        height: 1.35,
                      ),
                    ),

                  const SizedBox(height: 4),

                  // Timestamp
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        msg.formattedTime,
                        style: TextStyle(
                          color: isMe ? Colors.white70 : Colors.white38,
                          fontSize: 9.5,
                        ),
                      ),
                      if (isMe) ...[
                        const SizedBox(width: 4),
                        Icon(
                          msg.isRead ? Icons.done_all_rounded : Icons.done_rounded,
                          color: Colors.white70,
                          size: 13,
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),

          if (isMe) ...[
            const SizedBox(width: 8),
            // User Avatar (Matching Screenshot 5)
            CircleAvatar(
              radius: 16,
              backgroundImage: _userAvatarUrl != null && _userAvatarUrl!.isNotEmpty
                  ? NetworkImage(_userAvatarUrl!)
                  : null,
              child: _userAvatarUrl == null || _userAvatarUrl!.isEmpty
                  ? const Icon(Icons.person, color: Colors.white, size: 18)
                  : null,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBottomInputBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 16),
      decoration: const BoxDecoration(
        color: Color(0xFF0F0C1B),
        border: Border(top: BorderSide(color: Color(0xFF1E182D), width: 1)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            // Row 1: Mic + Text Input + Pink Send Button
            Row(
              children: [
                // Mic / Voice button
                GestureDetector(
                  onTap: _toggleAudioRecording,
                  child: Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: _isRecording ? Colors.redAccent : Colors.white.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      _isRecording ? Icons.stop_rounded : Icons.mic_none_rounded,
                      color: Colors.white,
                      size: 22,
                    ),
                  ),
                ),
                const SizedBox(width: 8),

                // Text Input Box
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF1A152A),
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(color: const Color(0xFF2E2644)),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    child: TextField(
                      controller: _messageController,
                      style: const TextStyle(color: Colors.white, fontSize: 13.5),
                      maxLines: 3,
                      minLines: 1,
                      decoration: const InputDecoration(
                        hintText: 'Send message',
                        hintStyle: TextStyle(color: Colors.white38, fontSize: 13.5),
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(vertical: 10),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),

                // Pink/Purple Send Button (Matching Screenshot 4 & 5)
                GestureDetector(
                  onTap: () => _sendMessage(),
                  child: Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [
                          Color(0xFFFF1493),
                          Color(0xFFE91E63),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFFF1493).withValues(alpha: 0.4),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.send_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Row 2: Media Attachment + Emoji + Call Rate Badge
            Row(
              children: [
                // Image / Screenshot Picker
                IconButton(
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  icon: const Icon(Icons.image_outlined, color: Color(0xFF00E676), size: 24),
                  onPressed: _pickImage,
                ),
                const SizedBox(width: 16),

                // Emoji Picker Icon
                const Icon(Icons.sentiment_satisfied_alt_rounded, color: Color(0xFFFFD54F), size: 24),

                const Spacer(),

                // Call Rate Badge: 💎 1800/min
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF59E0B),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.diamond_rounded, color: Colors.white, size: 12),
                      SizedBox(width: 3),
                      Text(
                        '1800/min',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),

                // Video Cam Icon
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: const BoxDecoration(
                    color: Color(0xFF6B21A8),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.videocam_rounded, color: Colors.white, size: 18),
                ),
                const SizedBox(width: 10),

                // Gift Icon
                const Icon(Icons.card_giftcard_rounded, color: Color(0xFFFF4081), size: 24),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/theme/app_colors.dart';
import '../services/webrtc_call_service.dart';

class WebRTCDebugModal extends StatefulWidget {
  final WebRTCCallService webrtcService;
  final int? callId;
  final bool isIncoming;
  final String? callerOrReceiverName;

  const WebRTCDebugModal({
    super.key,
    required this.webrtcService,
    this.callId,
    this.isIncoming = false,
    this.callerOrReceiverName,
  });

  static void show(
    BuildContext context, {
    required WebRTCCallService webrtcService,
    int? callId,
    bool isIncoming = false,
    String? callerOrReceiverName,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => WebRTCDebugModal(
        webrtcService: webrtcService,
        callId: callId,
        isIncoming: isIncoming,
        callerOrReceiverName: callerOrReceiverName,
      ),
    );
  }

  @override
  State<WebRTCDebugModal> createState() => _WebRTCDebugModalState();
}

class _WebRTCDebugModalState extends State<WebRTCDebugModal> {
  @override
  void initState() {
    super.initState();
    widget.webrtcService.onDebugUpdate = () {
      if (mounted) setState(() {});
    };
  }

  Color _getStateColor(String state) {
    final lower = state.toLowerCase();
    if (lower.contains('connect') || lower.contains('received') || lower.contains('sent') || lower.contains('success')) {
      return const Color(0xFF00E676);
    } else if (lower.contains('check') || lower.contains('start') || lower.contains('gather') || lower.contains('idle')) {
      return const Color(0xFFFFD600);
    } else if (lower.contains('fail') || lower.contains('error') || lower.contains('close') || lower.contains('disconn')) {
      return const Color(0xFFFF2D55);
    }
    return Colors.white70;
  }

  String _getBanglaIceExplanation(String state) {
    final lower = state.toLowerCase();
    if (lower.contains('connected') || lower.contains('completed')) {
      return '✅ দুই ফোনের মধ্যে অডিও-ভিডিও স্ট্রিম সফলভাবে সংযুক্ত হয়েছে।';
    } else if (lower.contains('checking')) {
      return '⏳ STUN/TURN সার্ভারের মাধ্যমে নেটওয়ার্ক পাথ ও পিয়ার খোঁজা হচ্ছে...';
    } else if (lower.contains('failed')) {
      return '❌ ভিন্ন নেটওয়ার্কের ফায়ারওয়াল বা TURN ব্লক থাকায় কানেকশন ফেইল করেছে। ICE রিস্টার্ট চেষ্টা চলছে।';
    } else if (lower.contains('disconnected')) {
      return '⚠️ ইন্টারনেটের গতি কমে যাওয়ায় সাময়িক সংযোগ বিচ্ছিন্ন। পুনরায় চেষ্টা করা হচ্ছে...';
    }
    return '🔄 সিগন্যালিং আদান-প্রদান চলছে...';
  }

  @override
  Widget build(BuildContext context) {
    final svc = widget.webrtcService;
    final hasRemote = svc.hasRemoteStream;
    final isConnected = svc.iceState.toLowerCase().contains('connected') || svc.iceState.toLowerCase().contains('completed');

    return Container(
      height: MediaQuery.of(context).size.height * 0.82,
      decoration: const BoxDecoration(
        color: Color(0xFF13101E),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(top: BorderSide(color: AppColors.neonPink, width: 2)),
      ),
      child: Column(
        children: [
          // Drag Handle
          const SizedBox(height: 10),
          Container(
            width: 44,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white30,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 12),

          // Title Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.neonPink.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.troubleshoot_rounded, color: AppColors.neonPink, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'WebRTC লাইভ ডায়াগনস্টিক প্যানেল',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'কল আইডি: #${widget.callId ?? 0} • মোড: ${widget.isIncoming ? "রিসিভার (Receiver)" : "কলার (Caller)"}',
                        style: const TextStyle(color: Colors.white60, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: Colors.white70),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          const Divider(color: Colors.white12, height: 20),

          // Scrollable Diagnostics Content
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              children: [
                // ১. স্ট্যাটাস ওভারভিউ কার্ড
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: isConnected
                        ? const Color(0xFF00E676).withValues(alpha: 0.1)
                        : const Color(0xFFFFD600).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isConnected
                          ? const Color(0xFF00E676).withValues(alpha: 0.4)
                          : const Color(0xFFFFD600).withValues(alpha: 0.4),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        isConnected ? Icons.check_circle_rounded : Icons.sync_rounded,
                        color: isConnected ? const Color(0xFF00E676) : const Color(0xFFFFD600),
                        size: 28,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isConnected ? 'ভিডিও স্ট্রিমিং লাইভ ও সচল' : 'মিডিয়া কানেকশন প্রক্রিয়াধীন',
                              style: TextStyle(
                                color: isConnected ? const Color(0xFF00E676) : const Color(0xFFFFD600),
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _getBanglaIceExplanation(svc.iceState),
                              style: const TextStyle(color: Colors.white70, fontSize: 12, height: 1.3),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // ২. মেট্রিক্স গ্রিড (Server, ICE, Signaling, Media)
                const Text(
                  '📊 কানেকশন ও সিগন্যালিং মেট্রিক্স:',
                  style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),

                Row(
                  children: [
                    Expanded(
                      child: _buildMetricCard(
                        title: '🌐 লাইভ সার্ভার',
                        value: 'chinchins.live',
                        subvalue: 'HTTPS / RESTful',
                        color: const Color(0xFF00E676),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildMetricCard(
                        title: '🧊 ICE স্ট্যাটাস',
                        value: svc.iceState,
                        subvalue: 'Sent: ${svc.iceCandidatesSent} | Recv: ${svc.iceCandidatesReceived}',
                        color: _getStateColor(svc.iceState),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                Row(
                  children: [
                    Expanded(
                      child: _buildMetricCard(
                        title: '📡 Offer / Answer',
                        value: 'O: ${svc.offerState} | A: ${svc.answerState}',
                        subvalue: svc.hasRemoteAnswer ? 'SDP হ্যান্ডশেক সম্পন্ন' : 'SDP বিনিময় হচ্ছে...',
                        color: _getStateColor(svc.hasRemoteAnswer ? 'success' : svc.offerState),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildMetricCard(
                        title: '📹 রিমোট ভিডিও স্ট্রিম',
                        value: hasRemote ? 'সক্রিয় (Active)' : 'অপেক্ষমান (Waiting)',
                        subvalue: hasRemote ? 'রেন্ডারার লোডেড' : 'ভিডিও ফ্রেমের অপেক্ষা...',
                        color: hasRemote ? const Color(0xFF00E676) : const Color(0xFFFFD600),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),

                // ৩. লাইভ ডায়াগনস্টিক বাংলা লগ
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      '📋 লাইভ অ্যাকশন লগ (Live Event Log):',
                      style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                    InkWell(
                      onTap: () {
                        Clipboard.setData(ClipboardData(text: svc.debugLogs.join('\n')));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('লগ কপি করা হয়েছে!'),
                            duration: Duration(seconds: 1),
                          ),
                        );
                      },
                      child: const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        child: Text(
                          'কপি করুন',
                          style: TextStyle(color: AppColors.neonPink, fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                Container(
                  height: 220,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: svc.debugLogs.isEmpty
                      ? const Center(
                          child: Text('কোনো লগ পাওয়া যায়নি', style: TextStyle(color: Colors.white38)),
                        )
                      : ListView.builder(
                          itemCount: svc.debugLogs.length,
                          itemBuilder: (context, index) {
                            final log = svc.debugLogs[index];
                            Color logColor = Colors.white70;
                            if (log.contains('ERROR') || log.contains('FAIL')) {
                              logColor = const Color(0xFFFF5252);
                            } else if (log.contains('SUCCESS') || log.contains('ATTACHED') || log.contains('CONNECTED')) {
                              logColor = const Color(0xFF69F0AE);
                            } else if (log.contains('OFFER') || log.contains('ANSWER') || log.contains('CANDIDATE')) {
                              logColor = const Color(0xFFFFD740);
                            }
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 2),
                              child: Text(
                                log,
                                style: TextStyle(
                                  color: logColor,
                                  fontSize: 11,
                                  fontFamily: 'monospace',
                                ),
                              ),
                            );
                          },
                        ),
                ),
                const SizedBox(height: 16),

                // ৪. অ্যাকশন বাটনস
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.refresh_rounded, size: 18),
                        label: const Text('ICE রিস্টার্ট করুন'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2E244C),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: () {
                          try {
                            svc.peerConnection?.restartIce();
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('ICE Restart ট্রিগার করা হয়েছে...')),
                            );
                          } catch (e) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Error: $e')),
                            );
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.done_rounded, size: 18),
                        label: const Text('বন্ধ করুন'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.neonPink,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricCard({
    required String title,
    required String value,
    required String subvalue,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(color: Colors.white60, fontSize: 11)),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.bold),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            subvalue,
            style: const TextStyle(color: Colors.white38, fontSize: 10),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

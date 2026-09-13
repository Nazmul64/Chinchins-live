import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import 'call_api_service.dart';

class PiPCallOverlay {
  static OverlayEntry? _overlayEntry;
  static bool isMinimized = false;
  static dynamic _activeCallSessionId;

  static void showMiniWindow(
    BuildContext context, {
    required Widget remoteVideoView,
    required String peerName,
    required String callDurationText,
    required dynamic callSessionId,
    required VoidCallback onTapRestore,
    required VoidCallback onEndCall,
  }) {
    if (_overlayEntry != null) {
      hideMiniWindow();
    }

    isMinimized = true;
    _activeCallSessionId = callSessionId;

    if (callSessionId != null) {
      CallApiService.minimizeCall(callSessionId: callSessionId);
    }

    final overlayState = Overlay.maybeOf(context, rootOverlay: true) ?? Overlay.of(context);

    // Initial position bottom-right
    final mediaQuery = MediaQuery.of(context);
    double top = mediaQuery.size.height - 250;
    double left = mediaQuery.size.width - 150;

    _overlayEntry = OverlayEntry(
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) {
          final size = MediaQuery.of(ctx).size;
          return Stack(
            children: [
              Positioned(
                top: top.clamp(40.0, size.height - 210.0),
                left: left.clamp(10.0, size.width - 150.0),
                child: Material(
                  color: Colors.transparent,
                  child: GestureDetector(
                    onPanUpdate: (details) {
                      setState(() {
                        top += details.delta.dy;
                        left += details.delta.dx;
                      });
                    },
                    onTap: () {
                      hideMiniWindow();
                      if (_activeCallSessionId != null) {
                        CallApiService.restoreCall(callSessionId: _activeCallSessionId);
                      }
                      onTapRestore();
                    },
                    child: Container(
                      width: 140,
                      height: 195,
                      decoration: BoxDecoration(
                        color: const Color(0xFF140F22),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppColors.neonPink, width: 2.2),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.neonPink.withValues(alpha: 0.4),
                            blurRadius: 18,
                            spreadRadius: 2,
                            offset: const Offset(0, 6),
                          ),
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.8),
                            blurRadius: 12,
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(18),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            // Video / Stream Preview
                            remoteVideoView,

                            // Gradient Top & Bottom Overlays
                            Positioned(
                              top: 0,
                              left: 0,
                              right: 0,
                              height: 45,
                              child: Container(
                                decoration: const BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [Colors.black87, Colors.transparent],
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                  ),
                                ),
                              ),
                            ),

                            // Top Info Bar: Name & Mini Live Call Indicator
                            Positioned(
                              top: 6,
                              left: 8,
                              right: 36,
                              child: Row(
                                children: [
                                  Container(
                                    width: 7,
                                    height: 7,
                                    decoration: const BoxDecoration(
                                      color: AppColors.onlineGreen,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Text(
                                      peerName,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.bold,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            // Top-Right Quick End Call Button (Red Circle ⏻)
                            Positioned(
                              top: 6,
                              right: 6,
                              child: GestureDetector(
                                onTap: () {
                                  hideMiniWindow();
                                  onEndCall();
                                },
                                child: Container(
                                  width: 26,
                                  height: 26,
                                  decoration: const BoxDecoration(
                                    color: Colors.redAccent,
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(color: Colors.black45, blurRadius: 4),
                                    ],
                                  ),
                                  child: const Icon(
                                    Icons.call_end_rounded,
                                    size: 14,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),

                            // Bottom Duration Badge & Tap-To-Expand Cue
                            Positioned(
                              bottom: 6,
                              left: 8,
                              right: 8,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.75),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: Colors.white24, width: 0.8),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.fullscreen_rounded, color: AppColors.neonPink, size: 12),
                                    const SizedBox(width: 3),
                                    Text(
                                      callDurationText,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );

    overlayState.insert(_overlayEntry!);
  }

  static void hideMiniWindow() {
    try {
      _overlayEntry?.remove();
    } catch (_) {}
    _overlayEntry = null;
    isMinimized = false;
  }
}

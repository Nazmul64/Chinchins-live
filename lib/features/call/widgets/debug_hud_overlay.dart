import 'package:flutter/material.dart';

/// Admin Remote Debugging Mode & Diagnostics HUD (Section 11)
/// Only visible when enabled remotely via remote config / admin settings
class DebugHudOverlay extends StatelessWidget {
  final bool isEnabled;
  final int fps;
  final int bitrateKbps;
  final int packetLossPercent;
  final int latencyMs;
  final int apiLatencyMs;

  const DebugHudOverlay({
    super.key,
    required this.isEnabled,
    this.fps = 30,
    this.bitrateKbps = 1200,
    this.packetLossPercent = 0,
    this.latencyMs = 45,
    this.apiLatencyMs = 120,
  });

  @override
  Widget build(BuildContext context) {
    if (!isEnabled) return const SizedBox.shrink();

    return Positioned(
      top: MediaQuery.of(context).padding.top + 70,
      left: 12,
      child: IgnorePointer(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.75),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.greenAccent, width: 1),
            boxShadow: const [
              BoxShadow(
                color: Colors.black54,
                blurRadius: 8,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: Colors.greenAccent,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Text(
                    "DEBUG MODE (ADMIN ON)",
                    style: TextStyle(
                      color: Colors.greenAccent,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.4,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                "WebRTC: $fps FPS | $bitrateKbps kbps",
                style: const TextStyle(color: Colors.white, fontSize: 10, fontFamily: 'monospace'),
              ),
              Text(
                "Latency: $latencyMs ms | Loss: $packetLossPercent%",
                style: TextStyle(
                  color: packetLossPercent > 5 ? Colors.redAccent : Colors.white70,
                  fontSize: 10,
                  fontFamily: 'monospace',
                ),
              ),
              Text(
                "API Response: $apiLatencyMs ms",
                style: TextStyle(
                  color: apiLatencyMs < 500 ? Colors.cyanAccent : Colors.orangeAccent,
                  fontSize: 10,
                  fontFamily: 'monospace',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

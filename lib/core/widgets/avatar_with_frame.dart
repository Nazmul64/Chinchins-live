import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'cached_image_loader.dart';

/// Helper class for parsing Hex strings to Color
class HexColor {
  static Color fromHex(String? hexString, {Color defaultColor = const Color(0xFFF59E0B)}) {
    if (hexString == null || hexString.isEmpty) return defaultColor;
    String hex = hexString.replaceAll('#', '').trim();
    if (hex.startsWith('rgba') || hex.startsWith('rgb')) {
      return defaultColor;
    }
    if (hex.length == 6) {
      hex = 'FF$hex';
    } else if (hex.length == 8) {
      // Already has alpha
    } else {
      return defaultColor;
    }
    final val = int.tryParse(hex, radix: 16);
    return val != null ? Color(val) : defaultColor;
  }
}

class AvatarWithFrame extends StatelessWidget {
  final String avatarUrl;
  final String? frameUrl;
  final int level;
  final String? badgeColor;
  final String? badgeIcon;
  final String? glowColor;
  final double size;
  final bool showLevelBadge;
  final VoidCallback? onTap;

  const AvatarWithFrame({
    super.key,
    required this.avatarUrl,
    this.frameUrl,
    this.level = 0,
    this.badgeColor,
    this.badgeIcon,
    this.glowColor,
    this.size = 80.0,
    this.showLevelBadge = true,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final double frameSize = size * 1.38;
    final color = HexColor.fromHex(badgeColor);
    final String cleanFrame = frameUrl != null ? CachedImageLoader.normalize(frameUrl) : '';

    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: frameSize,
        height: frameSize,
        child: Stack(
          alignment: Alignment.center,
          clipBehavior: Clip.none,
          children: [
            // 1. Circular User Avatar
            ClipOval(
              child: SizedBox(
                width: size,
                height: size,
                child: CachedImageLoader(
                  imageUrl: avatarUrl,
                  width: size,
                  height: size,
                  fit: BoxFit.cover,
                ),
              ),
            ),

            // 2. Overlaid Animated / Static Base Frame (SVG / PNG)
            if (cleanFrame.isNotEmpty)
              Positioned.fill(
                child: IgnorePointer(
                  child: cleanFrame.toLowerCase().contains('.svg')
                      ? SvgPicture.network(
                          cleanFrame,
                          width: frameSize,
                          height: frameSize,
                          fit: BoxFit.contain,
                          placeholderBuilder: (_) => const SizedBox.shrink(),
                        )
                      : CachedImageLoader(
                          imageUrl: cleanFrame,
                          width: frameSize,
                          height: frameSize,
                          fit: BoxFit.contain,
                        ),
                ),
              ),

            // 3. Level Badge Pill (Bottom Center)
            if (showLevelBadge)
              Positioned(
                bottom: -2,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1.5),
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.white, width: 1.2),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.4),
                        blurRadius: 4,
                        offset: const Offset(0, 1.5),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (level >= 7) ...[
                        const Icon(
                          Icons.workspace_premium_rounded,
                          color: Colors.white,
                          size: 9,
                        ),
                        const SizedBox(width: 2),
                      ] else if (level >= 3) ...[
                        const Icon(
                          Icons.star_rounded,
                          color: Colors.white,
                          size: 9,
                        ),
                        const SizedBox(width: 2),
                      ],
                      Text(
                        'Lv.$level',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 9.5,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

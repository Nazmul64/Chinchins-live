import 'package:flutter/material.dart';
import '../../../core/widgets/cached_image_loader.dart';

class InCallImageViewerModal extends StatelessWidget {
  final String imageUrl;

  const InCallImageViewerModal({super.key, required this.imageUrl});

  static void show(BuildContext context, String imageUrl) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.9),
      builder: (ctx) => InCallImageViewerModal(imageUrl: imageUrl),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(12),
      child: Stack(
        alignment: Alignment.center,
        children: [
          InteractiveViewer(
            panEnabled: true,
            minScale: 0.8,
            maxScale: 4.0,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: CachedImageLoader(
                imageUrl: imageUrl,
                fit: BoxFit.contain,
              ),
            ),
          ),
          Positioned(
            top: 10,
            right: 10,
            child: GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: const BoxDecoration(
                  color: Colors.black54,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.close_rounded, color: Colors.white, size: 22),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

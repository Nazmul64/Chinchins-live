import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../theme/app_colors.dart';
import '../constants/api_constants.dart';

class CachedImageLoader extends StatelessWidget {
  final String imageUrl;
  final BoxFit fit;
  final double? width;
  final double? height;
  final BorderRadius? borderRadius;

  const CachedImageLoader({
    super.key,
    required this.imageUrl,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
    this.borderRadius,
  });

  /// Automatically normalizes relative paths, local files, or placeholder hosts
  static String normalize(String? rawUrl) {
    if (rawUrl == null || rawUrl.trim().isEmpty) return '';
    String url = rawUrl.trim().replaceAll('\\', '/');

    if (url.startsWith('file://')) {
      return url.replaceFirst('file://', '');
    }

    // If it is a local device absolute file path
    if (File(url).existsSync() ||
        (url.startsWith('/') &&
            !url.startsWith('/storage') &&
            !url.startsWith('/uploads') &&
            !url.startsWith('/profiles') &&
            !url.startsWith('/avatars'))) {
      return url;
    }

    String baseHost = ApiConstants.liveDomain;
    if (baseHost.endsWith('/')) {
      baseHost = baseHost.substring(0, baseHost.length - 1);
    }

    // Convert any cleartext http://chinchins.live to secure https://
    if (url.startsWith('http://chinchins.live')) {
      url = url.replaceFirst('http://', 'https://');
    }

    // Replace placeholder domains or local hostnames
    if (url.contains('your-domain.com')) {
      url = url.replaceAll('https://your-domain.com', baseHost).replaceAll('http://your-domain.com', baseHost);
    }
    if (url.contains('localhost')) {
      url = url.replaceAll('http://localhost:8000', baseHost).replaceAll('https://localhost:8000', baseHost).replaceAll('http://localhost', baseHost);
    }
    if (url.contains('127.0.0.1')) {
      url = url.replaceAll('http://127.0.0.1:8000', baseHost).replaceAll('https://127.0.0.1:8000', baseHost).replaceAll('http://127.0.0.1', baseHost);
    }
    if (url.contains('10.0.2.2')) {
      url = url.replaceAll('http://10.0.2.2:8000', baseHost).replaceAll('https://10.0.2.2:8000', baseHost).replaceAll('http://10.0.2.2', baseHost);
    }

    // If it's a relative path from Laravel (e.g. "storage/avatars/host.jpg", "profiles/...", "uploads/...")
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      if (url.startsWith('/')) {
        url = url.substring(1);
      }
      if (url.startsWith('uploads/') || url.startsWith('storage/') || url.startsWith('profiles/') || url.startsWith('avatars/')) {
        url = '$baseHost/$url';
      } else {
        url = '$baseHost/storage/$url';
      }
    }

    return url;
  }

  @override
  Widget build(BuildContext context) {
    final cleanUrl = normalize(imageUrl);

    Widget imageWidget;

    // 1. Local device file check
    if (cleanUrl.isNotEmpty &&
        (File(cleanUrl).existsSync() || (cleanUrl.startsWith('/') && !cleanUrl.startsWith('http')))) {
      final file = File(cleanUrl);
      if (file.existsSync()) {
        imageWidget = Image.file(
          file,
          width: width,
          height: height,
          fit: fit,
          errorBuilder: (context, error, stackTrace) {
            return _buildErrorWidget();
          },
        );
      } else {
        imageWidget = _buildErrorWidget();
      }
    }
    // 2. Network image with caching and direct fallback
    else if (cleanUrl.isNotEmpty && (cleanUrl.startsWith('http://') || cleanUrl.startsWith('https://'))) {
      imageWidget = CachedNetworkImage(
        imageUrl: cleanUrl,
        width: width,
        height: height,
        fit: fit,
        placeholder: (context, url) => Container(
          width: width,
          height: height,
          color: AppColors.cardDark,
          child: const Center(
            child: SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(AppColors.neonPink),
              ),
            ),
          ),
        ),
        errorWidget: (context, url, error) {
          return Image.network(
            cleanUrl,
            width: width,
            height: height,
            fit: fit,
            errorBuilder: (context, err, stack) {
              return _buildErrorWidget();
            },
          );
        },
      );
    } else {
      imageWidget = _buildErrorWidget();
    }

    if (borderRadius != null) {
      return ClipRRect(
        borderRadius: borderRadius!,
        child: imageWidget,
      );
    }

    return imageWidget;
  }

  Widget _buildErrorWidget() {
    final isLargePhoto = width != null && width! > 80;
    return Container(
      width: width,
      height: height,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF2E1A47), Color(0xFF1B112C)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Icon(
          isLargePhoto ? Icons.photo_size_select_actual_outlined : Icons.person_rounded,
          color: const Color(0xFFCE93D8),
          size: isLargePhoto ? 32 : 24,
        ),
      ),
    );
  }
}

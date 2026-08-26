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
    String url = rawUrl.trim();

    if (url.startsWith('file://')) {
      return url.replaceFirst('file://', '');
    }

    // If it is a local device absolute file path
    if (File(url).existsSync() ||
        (url.startsWith('/') &&
            !url.startsWith('/storage') &&
            !url.startsWith('/uploads') &&
            !url.startsWith('/profiles'))) {
      return url;
    }

    String baseHost = ApiConstants.baseUrl.replaceAll(RegExp(r'/api/?$'), '');
    if (baseHost.endsWith('/')) {
      baseHost = baseHost.substring(0, baseHost.length - 1);
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

    // If it's a relative path from Laravel (e.g. "profiles/15/avatar.jpg", "/uploads/...", "/storage/...")
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      if (url.startsWith('/')) {
        url = url.substring(1);
      }
      if (url.startsWith('uploads/') || url.startsWith('storage/')) {
        url = '$baseHost/$url';
      } else {
        url = '$baseHost/uploads/$url';
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
            debugPrint('[Local Image Error] Path: $cleanUrl | Error: $error');
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
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(AppColors.neonPink),
              ),
            ),
          ),
        ),
        errorWidget: (context, url, error) {
          debugPrint('[Network Image Cache Error] URL: $cleanUrl | Error: $error');
          // Graceful fallback to Image.network if cached_network_image has an issue
          return Image.network(
            cleanUrl,
            width: width,
            height: height,
            fit: fit,
            errorBuilder: (context, err, stack) {
              debugPrint('[Network Image Direct Error] URL: $cleanUrl | Error: $err');
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
    return Container(
      width: width,
      height: height,
      color: AppColors.cardDarkElevated,
      child: const Center(
        child: Icon(
          Icons.person,
          color: AppColors.textMuted,
          size: 28,
        ),
      ),
    );
  }
}

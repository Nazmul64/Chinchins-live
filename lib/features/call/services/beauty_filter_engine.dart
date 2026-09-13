import 'package:flutter/material.dart';

/// Preset definition for TikTok-style camera and beauty filters
class FilterPreset {
  final String id;
  final String name;
  final String nameBn;
  final String category;
  final IconData icon;
  final double smoothness;
  final double brightness;
  final double contrast;
  final double saturation;
  final double whitening;
  final double rosy;
  final Color tintColor;
  final double tintOpacity;

  const FilterPreset({
    required this.id,
    required this.name,
    required this.nameBn,
    this.category = 'beauty',
    this.icon = Icons.auto_awesome_rounded,
    this.smoothness = 0.0,
    this.brightness = 1.0,
    this.contrast = 1.0,
    this.saturation = 1.0,
    this.whitening = 0.0,
    this.rosy = 0.0,
    this.tintColor = Colors.transparent,
    this.tintOpacity = 0.0,
  });

  /// Generate a 4x5 ColorMatrix for GPU-accelerated real-time color grading
  List<double> toColorMatrix() {
    final b = (brightness - 1.0) * 255;
    final c = contrast;
    final s = saturation;
    final w = whitening * 30.0; // Skin whitening luminance boost
    final r = rosy * 25.0; // Rosy blush red-tone boost

    // Lum weights for saturation
    const lr = 0.2126;
    const lg = 0.7152;
    const lb = 0.0722;

    final sr = (1 - s) * lr;
    final sg = (1 - s) * lg;
    final sb = (1 - s) * lb;

    return <double>[
      (sr + s) * c, sg * c, sb * c, 0, b + w + r,
      sr * c, (sg + s) * c, sb * c, 0, b + w + (r * 0.3),
      sr * c, sg * c, (sb + s) * c, 0, b + w + (r * 0.2),
      0, 0, 0, 1, 0,
    ];
  }
}

class BeautyFilterEngine {
  BeautyFilterEngine._();
  static final BeautyFilterEngine instance = BeautyFilterEngine._();

  static const List<FilterPreset> presets = [
    FilterPreset(
      id: 'none',
      name: 'Original',
      nameBn: 'স্বাভাবিক',
      category: 'none',
      icon: Icons.camera_alt_outlined,
      smoothness: 0.0,
      brightness: 1.0,
      contrast: 1.0,
      saturation: 1.0,
    ),
    FilterPreset(
      id: 'beauty_glow',
      name: 'Beauty Glow',
      nameBn: 'বিউটি গ্লো',
      category: 'beauty',
      icon: Icons.face_retouching_natural_rounded,
      smoothness: 0.65,
      brightness: 1.15,
      contrast: 1.05,
      saturation: 1.10,
      whitening: 0.40,
      rosy: 0.25,
      tintColor: Color(0xFFFFD1DC),
      tintOpacity: 0.08,
    ),
    FilterPreset(
      id: 'smooth_skin',
      name: 'Smooth Skin',
      nameBn: 'স্মুথ স্কিন',
      category: 'beauty',
      icon: Icons.spa_rounded,
      smoothness: 0.85,
      brightness: 1.08,
      contrast: 1.02,
      saturation: 1.05,
      whitening: 0.50,
      rosy: 0.15,
    ),
    FilterPreset(
      id: 'rosy_cheeks',
      name: 'Rosy Pink',
      nameBn: 'গোলাপি আভা',
      category: 'beauty',
      icon: Icons.favorite_rounded,
      smoothness: 0.50,
      brightness: 1.10,
      contrast: 1.08,
      saturation: 1.25,
      whitening: 0.30,
      rosy: 0.55,
      tintColor: Color(0xFFFF4081),
      tintOpacity: 0.10,
    ),
    FilterPreset(
      id: 'warm_sunshine',
      name: 'Warm Sun',
      nameBn: 'উষ্ণ রোদ',
      category: 'color',
      icon: Icons.wb_sunny_rounded,
      smoothness: 0.30,
      brightness: 1.12,
      contrast: 1.10,
      saturation: 1.18,
      whitening: 0.20,
      rosy: 0.20,
      tintColor: Color(0xFFFFB300),
      tintOpacity: 0.12,
    ),
    FilterPreset(
      id: 'cool_breeze',
      name: 'Cool Breeze',
      nameBn: 'শীতল আভা',
      category: 'color',
      icon: Icons.ac_unit_rounded,
      smoothness: 0.20,
      brightness: 1.06,
      contrast: 1.05,
      saturation: 0.95,
      tintColor: Color(0xFF00E5FF),
      tintOpacity: 0.10,
    ),
    FilterPreset(
      id: 'vintage_film',
      name: 'Vintage',
      nameBn: 'ভিন্টেজ ফিল্ম',
      category: 'effects',
      icon: Icons.camera_roll_rounded,
      smoothness: 0.15,
      brightness: 1.02,
      contrast: 1.15,
      saturation: 0.85,
      tintColor: Color(0xFF8D6E63),
      tintOpacity: 0.12,
    ),
    FilterPreset(
      id: 'cyber_neon',
      name: 'Cyber Neon',
      nameBn: 'সাইবার নিয়ন',
      category: 'effects',
      icon: Icons.bolt_rounded,
      smoothness: 0.40,
      brightness: 1.20,
      contrast: 1.30,
      saturation: 1.40,
      tintColor: Color(0xFFE040FB),
      tintOpacity: 0.14,
    ),
  ];

  /// Wraps any video widget with the active beauty filter shader, color matrix, and whitening/rosy overlay
  static Widget applyFilterToWidget({
    required Widget child,
    required FilterPreset filter,
  }) {
    if (filter.id == 'none') {
      return child;
    }

    final matrix = filter.toColorMatrix();

    Widget filtered = ColorFiltered(
      colorFilter: ColorFilter.matrix(matrix),
      child: child,
    );

    // Apply Soft Beauty Glow & Rosy Skin layer if whitening or tint is present
    if (filter.whitening > 0 || filter.tintOpacity > 0) {
      filtered = Stack(
        fit: StackFit.passthrough,
        children: [
          filtered,
          if (filter.whitening > 0)
            Positioned.fill(
              child: IgnorePointer(
                child: Container(
                  color: Colors.white.withValues(alpha: (filter.whitening * 0.08).clamp(0.0, 0.18)),
                ),
              ),
            ),
          if (filter.tintOpacity > 0 && filter.tintColor != Colors.transparent)
            Positioned.fill(
              child: IgnorePointer(
                child: Container(
                  color: filter.tintColor.withValues(alpha: filter.tintOpacity),
                ),
              ),
            ),
        ],
      );
    }

    return filtered;
  }
}

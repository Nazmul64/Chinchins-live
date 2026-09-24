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

  /// Generate a 4x5 ColorMatrix for GPU-accelerated real-time color grading (TikTok / Bigo style)
  List<double> toColorMatrix() {
    final b = (brightness - 1.0) * 80;
    final c = contrast;
    final s = saturation;
    final w = whitening * 12.0; // Clean skin whitening luminance boost without wash-out
    final r = rosy * 10.0;      // Natural rosy blush tone

    // Lum weights for saturation
    const lr = 0.2126;
    const lg = 0.7152;
    const lb = 0.0722;

    final sr = (1 - s) * lr;
    final sg = (1 - s) * lg;
    final sb = (1 - s) * lb;

    final redOffset = (b + w + (r * 1.2)).clamp(-50.0, 50.0);
    final greenOffset = (b + w + (r * 0.4)).clamp(-50.0, 50.0);
    final blueOffset = (b + w + (r * 0.5)).clamp(-50.0, 50.0);

    return <double>[
      (sr + s) * c, sg * c, sb * c, 0, redOffset,
      sr * c, (sg + s) * c, sb * c, 0, greenOffset,
      sr * c, sg * c, (sb + s) * c, 0, blueOffset,
      0, 0, 0, 1, 0,
    ];
  }

  /// Convenience getter for matrix
  List<double> get matrix => toColorMatrix();
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
      brightness: 1.05,
      contrast: 1.02,
      saturation: 1.04,
      whitening: 0.35,
      rosy: 0.30,
    ),
    FilterPreset(
      id: 'smooth_skin',
      name: 'Smooth Skin',
      nameBn: 'স্মুথ স্কিন',
      category: 'beauty',
      icon: Icons.spa_rounded,
      smoothness: 0.85,
      brightness: 1.04,
      contrast: 1.01,
      saturation: 1.02,
      whitening: 0.40,
      rosy: 0.20,
    ),
    FilterPreset(
      id: 'rosy_cheeks',
      name: 'Rosy Pink',
      nameBn: 'গোলাপি আভা',
      category: 'beauty',
      icon: Icons.favorite_rounded,
      smoothness: 0.50,
      brightness: 1.06,
      contrast: 1.04,
      saturation: 1.10,
      whitening: 0.25,
      rosy: 0.50,
    ),
    FilterPreset(
      id: 'warm_sunshine',
      name: 'Warm Sun',
      nameBn: 'উষ্ণ রোদ',
      category: 'color',
      icon: Icons.wb_sunny_rounded,
      smoothness: 0.30,
      brightness: 1.05,
      contrast: 1.05,
      saturation: 1.08,
      whitening: 0.15,
      rosy: 0.20,
    ),
    FilterPreset(
      id: 'cool_breeze',
      name: 'Cool Breeze',
      nameBn: 'শীতল আভা',
      category: 'color',
      icon: Icons.ac_unit_rounded,
      smoothness: 0.20,
      brightness: 1.03,
      contrast: 1.02,
      saturation: 0.98,
    ),
    FilterPreset(
      id: 'vintage_film',
      name: 'Vintage',
      nameBn: 'ভিন্টেজ ফিল্ম',
      category: 'effects',
      icon: Icons.camera_roll_rounded,
      smoothness: 0.15,
      brightness: 1.02,
      contrast: 1.08,
      saturation: 0.90,
    ),
    FilterPreset(
      id: 'cyber_neon',
      name: 'Cyber Neon',
      nameBn: 'সাইবার নিয়ন',
      category: 'effects',
      icon: Icons.bolt_rounded,
      smoothness: 0.40,
      brightness: 1.10,
      contrast: 1.15,
      saturation: 1.25,
    ),
  ];

  /// Smoothly renders video with real-time ColorFilter matrix without destructive overlays or face darkening
  static Widget applyFilterToWidget({
    required Widget child,
    required FilterPreset filter,
  }) {
    if (filter.id == 'none') {
      return child;
    }

    return ColorFiltered(
      colorFilter: ColorFilter.matrix(filter.toColorMatrix()),
      child: child,
    );
  }
}

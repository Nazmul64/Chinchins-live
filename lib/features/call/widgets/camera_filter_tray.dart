import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../services/beauty_filter_engine.dart';

class CameraFilterTray extends StatefulWidget {
  final FilterPreset currentFilter;
  final ValueChanged<FilterPreset> onFilterSelected;
  final VoidCallback? onClose;

  const CameraFilterTray({
    super.key,
    required this.currentFilter,
    required this.onFilterSelected,
    this.onClose,
  });

  static void show(
    BuildContext context, {
    required FilterPreset currentFilter,
    required ValueChanged<FilterPreset> onFilterSelected,
  }) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => CameraFilterTray(
        currentFilter: currentFilter,
        onFilterSelected: onFilterSelected,
        onClose: () => Navigator.pop(ctx),
      ),
    );
  }

  @override
  State<CameraFilterTray> createState() => _CameraFilterTrayState();
}

class _CameraFilterTrayState extends State<CameraFilterTray> {
  late FilterPreset _selected;
  double _smoothness = 0.65;
  double _whitening = 0.40;
  double _rosy = 0.25;

  @override
  void initState() {
    super.initState();
    _selected = widget.currentFilter;
    _smoothness = _selected.smoothness;
    _whitening = _selected.whitening;
    _rosy = _selected.rosy;
  }

  void _updateFilter(FilterPreset preset) {
    setState(() {
      _selected = preset;
      _smoothness = preset.smoothness;
      _whitening = preset.whitening;
      _rosy = preset.rosy;
    });
    widget.onFilterSelected(preset);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.only(top: 14, bottom: 24, left: 16, right: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF140F22).withValues(alpha: 0.95),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(color: AppColors.neonPink.withValues(alpha: 0.3), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.6),
            blurRadius: 20,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Bar
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      gradient: AppColors.primaryGradient,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.auto_fix_high_rounded, color: Colors.white, size: 16),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Beauty & HD Camera Filters',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded, color: Colors.white70, size: 22),
                onPressed: widget.onClose ?? () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Horizontal Filter Selector
          SizedBox(
            height: 90,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              itemCount: BeautyFilterEngine.presets.length,
              itemBuilder: (context, index) {
                final preset = BeautyFilterEngine.presets[index];
                final isSelected = _selected.id == preset.id;
                return GestureDetector(
                  onTap: () => _updateFilter(preset),
                  child: Container(
                    width: 72,
                    margin: const EdgeInsets.only(right: 12),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          width: 52,
                          height: 52,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: isSelected
                                ? AppColors.primaryGradient
                                : LinearGradient(
                                    colors: [
                                      Colors.white.withValues(alpha: 0.15),
                                      Colors.white.withValues(alpha: 0.05),
                                    ],
                                  ),
                            border: Border.all(
                              color: isSelected ? Colors.white : Colors.white24,
                              width: isSelected ? 2.5 : 1.0,
                            ),
                            boxShadow: isSelected
                                ? [
                                    BoxShadow(
                                      color: AppColors.neonPink.withValues(alpha: 0.5),
                                      blurRadius: 10,
                                      spreadRadius: 2,
                                    ),
                                  ]
                                : null,
                          ),
                          child: Icon(
                            preset.icon,
                            color: isSelected ? Colors.white : Colors.white70,
                            size: 24,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          preset.name,
                          style: TextStyle(
                            color: isSelected ? AppColors.neonPink : Colors.white70,
                            fontSize: 11,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          // Fine-tuning Beauty Sliders (when a beauty filter is active)
          if (_selected.id != 'none') ...[
            const SizedBox(height: 10),
            const Divider(color: Colors.white12, height: 1),
            const SizedBox(height: 10),

            // Smoothness Slider
            _buildSliderRow(
              icon: Icons.spa_rounded,
              title: 'Skin Smoothing',
              value: _smoothness,
              onChanged: (val) {
                setState(() => _smoothness = val);
                final updated = FilterPreset(
                  id: _selected.id,
                  name: _selected.name,
                  nameBn: _selected.nameBn,
                  category: _selected.category,
                  icon: _selected.icon,
                  smoothness: val,
                  brightness: _selected.brightness,
                  contrast: _selected.contrast,
                  saturation: _selected.saturation,
                  whitening: _whitening,
                  rosy: _rosy,
                  tintColor: _selected.tintColor,
                  tintOpacity: _selected.tintOpacity,
                );
                widget.onFilterSelected(updated);
              },
            ),

            // Whitening / Brightness Glow Slider
            _buildSliderRow(
              icon: Icons.wb_sunny_rounded,
              title: 'Skin Whitening & Glow',
              value: _whitening,
              onChanged: (val) {
                setState(() => _whitening = val);
                final updated = FilterPreset(
                  id: _selected.id,
                  name: _selected.name,
                  nameBn: _selected.nameBn,
                  category: _selected.category,
                  icon: _selected.icon,
                  smoothness: _smoothness,
                  brightness: 1.0 + (val * 0.25),
                  contrast: _selected.contrast,
                  saturation: _selected.saturation,
                  whitening: val,
                  rosy: _rosy,
                  tintColor: _selected.tintColor,
                  tintOpacity: _selected.tintOpacity,
                );
                widget.onFilterSelected(updated);
              },
            ),

            // Rosy Blush Slider
            _buildSliderRow(
              icon: Icons.favorite_rounded,
              title: 'Rosy Blush Tone',
              value: _rosy,
              onChanged: (val) {
                setState(() => _rosy = val);
                final updated = FilterPreset(
                  id: _selected.id,
                  name: _selected.name,
                  nameBn: _selected.nameBn,
                  category: _selected.category,
                  icon: _selected.icon,
                  smoothness: _smoothness,
                  brightness: _selected.brightness,
                  contrast: _selected.contrast,
                  saturation: _selected.saturation,
                  whitening: _whitening,
                  rosy: val,
                  tintColor: _selected.tintColor,
                  tintOpacity: _selected.tintOpacity,
                );
                widget.onFilterSelected(updated);
              },
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSliderRow({
    required IconData icon,
    required String title,
    required double value,
    required ValueChanged<double> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Icon(icon, color: AppColors.neonPink, size: 16),
          const SizedBox(width: 8),
          SizedBox(
            width: 120,
            child: Text(
              title,
              style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                activeTrackColor: AppColors.neonPink,
                inactiveTrackColor: Colors.white24,
                thumbColor: Colors.white,
                trackHeight: 3,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
              ),
              child: Slider(
                value: value,
                min: 0.0,
                max: 1.0,
                onChanged: onChanged,
              ),
            ),
          ),
          Text(
            '${(value * 100).toInt()}%',
            style: const TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}

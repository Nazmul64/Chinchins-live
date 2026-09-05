import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';

class ExploreHeader extends StatelessWidget {
  final int selectedTabIndex;
  final ValueChanged<int> onTabSelected;
  final VoidCallback onSearchTap;
  final VoidCallback onCountryTap;
  final VoidCallback? onDebugTap;
  final String selectedCountryCode;

  const ExploreHeader({
    super.key,
    required this.selectedTabIndex,
    required this.onTabSelected,
    required this.onSearchTap,
    required this.onCountryTap,
    this.onDebugTap,
    this.selectedCountryCode = 'BGD',
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: AppColors.backgroundDark,
      child: Row(
        children: [
          // Left Tabs: Hot & Match
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildTabItem(title: 'Hot', index: 0),
              const SizedBox(width: 18),
              _buildTabItem(title: 'Match', index: 1),
            ],
          ),

          const Spacer(),

          // Right Actions: Debug Icon, Search Icon & Country Pill (🔴 BGD ⌄)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // WebRTC Diagnostics Button
              if (onDebugTap != null)
                IconButton(
                  tooltip: 'WebRTC লাইভ স্ট্যাটাস',
                  icon: const Icon(Icons.network_check_rounded, color: AppColors.neonPink, size: 22),
                  onPressed: onDebugTap,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                ),
              // Search Icon
              IconButton(
                icon: const Icon(Icons.search_rounded, color: Colors.white, size: 26),
                onPressed: onSearchTap,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
              ),
              // Country Pill (🔴 BGD ⌄) matching Screenshot (Shown on Hot tab)
              if (selectedTabIndex == 0) ...[
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: onCountryTap,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: const Color(0xFF5B1066),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 9,
                          height: 9,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: Color(0xFFFF2A6D),
                          ),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          selectedCountryCode,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12.5,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 3),
                        const Icon(
                          Icons.keyboard_arrow_down_rounded,
                          color: Colors.white,
                          size: 16,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTabItem({required String title, required int index}) {
    final isSelected = selectedTabIndex == index;
    return GestureDetector(
      onTap: () => onTabSelected(index),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            title,
            style: TextStyle(
              color: isSelected ? Colors.white : AppColors.textMuted,
              fontSize: isSelected ? 22 : 18,
              fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
            ),
          ),
          const SizedBox(height: 3),
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            height: 2.5,
            width: isSelected ? 20 : 0,
            decoration: BoxDecoration(
              gradient: AppColors.primaryGradient,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';

class ExploreHeader extends StatelessWidget {
  final int selectedTabIndex;
  final ValueChanged<int> onTabSelected;
  final VoidCallback onSearchTap;
  final VoidCallback onLanguageTap;
  final VoidCallback onSayHelloTap;

  const ExploreHeader({
    super.key,
    required this.selectedTabIndex,
    required this.onTabSelected,
    required this.onSearchTap,
    required this.onLanguageTap,
    required this.onSayHelloTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      color: AppColors.backgroundDark,
      child: Row(
        children: [
          // Left Tabs: Hot, Party, Match
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildTabItem(title: 'Hot', index: 0),
                  const SizedBox(width: 14),
                  _buildTabItem(title: 'Party 🎉', index: 1),
                  const SizedBox(width: 14),
                  _buildTabItem(title: 'Match', index: 2),
                ],
              ),
            ),
          ),

          const SizedBox(width: 8),

          // Action buttons: Search & Globe Language Pill matching Screenshot 1
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Search Icon matching Screenshot 1
              IconButton(
                icon: const Icon(Icons.search, color: Colors.white, size: 22),
                onPressed: onSearchTap,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              ),
              const SizedBox(width: 6),

              // Globe/Language Purple Pill matching Screenshot 1
              GestureDetector(
                onTap: onLanguageTap,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF6A1B9A),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.language_rounded,
                        color: Colors.white,
                        size: 15,
                      ),
                      SizedBox(width: 2),
                      Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: Colors.white,
                        size: 14,
                      ),
                    ],
                  ),
                ),
              ),
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
              fontSize: isSelected ? 18 : 15,
              fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
            ),
          ),
          const SizedBox(height: 3),
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            height: 2.5,
            width: isSelected ? 18 : 0,
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

import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';

class ExploreHeader extends StatelessWidget {
  final int selectedTabIndex;
  final ValueChanged<int> onTabSelected;
  final VoidCallback onSearchTap;
  final VoidCallback onCountryTap;
  final VoidCallback? onRankTap;
  final VoidCallback? onMenuTap;
  final String selectedCountryCode;

  const ExploreHeader({
    super.key,
    required this.selectedTabIndex,
    required this.onTabSelected,
    required this.onSearchTap,
    required this.onCountryTap,
    this.onRankTap,
    this.onMenuTap,
    this.selectedCountryCode = 'ALL',
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      color: AppColors.backgroundDark,
      child: Row(
        children: [
          // Left Tabs: Hot, Live, Party, Match matching Screenshot 1 & 2
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildTabItem(title: 'Hot', index: 0),
                  const SizedBox(width: 14),
                  _buildTabItem(title: 'Live', index: 1),
                  const SizedBox(width: 14),
                  _buildTabItem(title: 'Party', index: 2),
                  const SizedBox(width: 14),
                  _buildTabItem(title: 'Match', index: 3),
                ],
              ),
            ),
          ),

          const SizedBox(width: 6),

          // Right Action Icons: Search 🔍, Globe/Country 🌐, Trophy/Rank 🏆 (Screenshot 1 & 2)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Search Icon 🔍
              IconButton(
                icon: const Icon(Icons.search_rounded, color: Colors.white, size: 22),
                onPressed: onSearchTap,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
              ),
              const SizedBox(width: 2),

              // Globe / Country Selector 🌐 (Screenshot 1)
              GestureDetector(
                onTap: onCountryTap,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFF6B21A8).withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Icon(Icons.language_rounded, color: Color(0xFFE9D5FF), size: 16),
                      SizedBox(width: 2),
                      Icon(Icons.keyboard_arrow_down_rounded, color: Colors.white70, size: 13),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 6),

              // Trophy / Leaderboard 🏆 (Screenshot 1 & 2)
              GestureDetector(
                onTap: onRankTap ?? onSearchTap,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  child: const Text('🏆', style: TextStyle(fontSize: 18)),
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
              fontSize: isSelected ? 19 : 16,
              fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
            ),
          ),
          const SizedBox(height: 3),
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            height: 2.5,
            width: isSelected ? 20 : 0,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFFF2A6D), Color(0xFF9333EA)],
              ),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ],
      ),
    );
  }
}



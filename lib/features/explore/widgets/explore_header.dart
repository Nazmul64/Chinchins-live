import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';

class ExploreHeader extends StatelessWidget {
  final int selectedTabIndex;
  final ValueChanged<int> onTabSelected;
  final VoidCallback onSearchTap;
  final VoidCallback onCountryTap;
  final VoidCallback? onDebugTap;
  final VoidCallback? onMenuTap;
  final String selectedCountryCode;

  const ExploreHeader({
    super.key,
    required this.selectedTabIndex,
    required this.onTabSelected,
    required this.onSearchTap,
    required this.onCountryTap,
    this.onDebugTap,
    this.onMenuTap,
    this.selectedCountryCode = 'ALL',
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      color: AppColors.backgroundDark,
      child: Row(
        children: [
          // Left Toggle Menu Hamburger Icon (Opens Drawer with Logout & Profile shortcuts)
          if (onMenuTap != null) ...[
            IconButton(
              tooltip: 'Menu',
              icon: const Icon(Icons.menu_rounded, color: Colors.white, size: 24),
              onPressed: onMenuTap,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
            ),
            const SizedBox(width: 6),
          ],

          // Left Tabs: Hot, Match & [🔴 LIVE] (Broadcasting)
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildTabItem(title: 'Hot', index: 0),
                  const SizedBox(width: 14),
                  _buildTabItem(title: 'Match', index: 1),
                  const SizedBox(width: 14),
                  _buildTabItem(title: 'Live', index: 2, isLiveTab: true),
                ],
              ),
            ),
          ),

          const SizedBox(width: 4),

          // Right Actions: Search Icon & Country Pill (🔴 BGD ⌄)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Search Icon
              IconButton(
                icon: const Icon(Icons.search_rounded, color: Colors.white, size: 22),
                onPressed: onSearchTap,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
              ),
              // Country Pill (🔴 BGD ⌄) matching Screenshot (Shown on Hot tab)
              if (selectedTabIndex == 0) ...[
                const SizedBox(width: 4),
                GestureDetector(
                  onTap: onCountryTap,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3.5),
                    decoration: BoxDecoration(
                      color: const Color(0xFF5B1066),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 7,
                          height: 7,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: Color(0xFFFF2A6D),
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          selectedCountryCode,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 1),
                        const Icon(
                          Icons.keyboard_arrow_down_rounded,
                          color: Colors.white,
                          size: 14,
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

  Widget _buildTabItem({required String title, required int index, bool isLiveTab = false}) {
    final isSelected = selectedTabIndex == index;
    return GestureDetector(
      onTap: () => onTabSelected(index),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (!isLiveTab)
            Text(
              title,
              style: TextStyle(
                color: isSelected ? Colors.white : AppColors.textMuted,
                fontSize: isSelected ? 20 : 17,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
              ),
            )
          else
            // Clean [🔴 LIVE] pill badge without duplicate 'Live' text
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFFF007F), Color(0xFFFF5252)],
                ),
                borderRadius: BorderRadius.circular(10),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: const Color(0xFFFF007F).withValues(alpha: 0.6),
                          blurRadius: 6,
                        ),
                      ]
                    : null,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 3.5),
                  const Text(
                    'LIVE',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 3),
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            height: 2.5,
            width: isSelected ? (isLiveTab ? 26 : 22) : 0,
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


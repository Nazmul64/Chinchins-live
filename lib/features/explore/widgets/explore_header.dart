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
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
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

          // Left Tabs: Hot, Match & Live (Broadcasting)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildTabItem(title: 'Hot', index: 0),
              const SizedBox(width: 14),
              _buildTabItem(title: 'Match', index: 1),
              const SizedBox(width: 14),
              _buildTabItem(title: 'Live', index: 2, isLiveTab: true),
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
                  icon: const Icon(Icons.network_check_rounded, color: AppColors.neonPink, size: 20),
                  onPressed: onDebugTap,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                ),
              // Search Icon
              IconButton(
                icon: const Icon(Icons.search_rounded, color: Colors.white, size: 24),
                onPressed: onSearchTap,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
              ),
              // Country Pill (🔴 BGD ⌄) matching Screenshot (Shown on Hot tab)
              if (selectedTabIndex == 0) ...[
                const SizedBox(width: 6),
                GestureDetector(
                  onTap: onCountryTap,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF5B1066),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 8,
                          height: 8,
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
                            fontSize: 11.5,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 2),
                        const Icon(
                          Icons.keyboard_arrow_down_rounded,
                          color: Colors.white,
                          size: 15,
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
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: isSelected ? Colors.white : AppColors.textMuted,
                  fontSize: isSelected ? 22 : 18,
                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                ),
              ),
              if (isLiveTab) ...[
                const SizedBox(width: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFFF007F), Color(0xFFFF5252)],
                    ),
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFFF007F).withValues(alpha: 0.6),
                        blurRadius: 6,
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 5,
                        height: 5,
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 2),
                      const Text(
                        'LIVE',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 8.5,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 3),
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            height: 2.5,
            width: isSelected ? 24 : 0,
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


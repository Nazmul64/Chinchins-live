import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../explore/screens/hot_explore_screen.dart';
import '../../messages/screens/messages_screen.dart';
import '../../me/screens/me_screen.dart';

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 0;

  final List<Widget> _screens = const [
    HotExploreScreen(),
    MessagesScreen(),
    MeScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: AppColors.bottomBarBg,
          border: Border(
            top: BorderSide(color: AppColors.cardBorder, width: 0.6),
          ),
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) {
            setState(() {
              _currentIndex = index;
            });
          },
          backgroundColor: AppColors.bottomBarBg,
          selectedItemColor: Colors.white,
          unselectedItemColor: AppColors.textMuted,
          selectedFontSize: 11,
          unselectedFontSize: 11,
          type: BottomNavigationBarType.fixed,
          items: [
            // "For You" Tab with Thumbs-Up 👍 Icon matching Screenshot 1 & 2
            BottomNavigationBarItem(
              icon: Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Icon(
                  Icons.thumb_up_rounded,
                  color: _currentIndex == 0 ? Colors.white : AppColors.textMuted,
                  size: 24,
                ),
              ),
              label: 'For You',
            ),

            // "Messages" Tab with unread badge '22' matching Screenshot 1
            BottomNavigationBarItem(
              icon: Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Icon(
                      _currentIndex == 1 ? Icons.chat_bubble_rounded : Icons.chat_bubble_outline_rounded,
                      color: _currentIndex == 1 ? Colors.white : AppColors.textMuted,
                      size: 24,
                    ),
                    Positioned(
                      top: -4,
                      right: -8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE91E63),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          '22',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              label: 'Messages',
            ),

            // "Me" Tab
            BottomNavigationBarItem(
              icon: Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Icon(
                  _currentIndex == 2 ? Icons.sentiment_satisfied_alt_rounded : Icons.sentiment_satisfied_rounded,
                  color: _currentIndex == 2 ? Colors.white : AppColors.textMuted,
                  size: 24,
                ),
              ),
              label: 'Me',
            ),
          ],
        ),
      ),
    );
  }
}

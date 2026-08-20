import 'package:flutter/material.dart';
import '../../../core/data/mock_data.dart';
import '../../../core/models/model_profile.dart';
import '../../../core/theme/app_colors.dart';
import '../widgets/explore_header.dart';
import '../widgets/model_grid_card.dart';
import '../../profile/screens/host_profile_screen.dart';
import '../../call/screens/video_call_screen.dart';
import '../../call/screens/incoming_call_screen.dart';
import '../../party/screens/party_rooms_screen.dart';
import '../../party/screens/create_room_screen.dart';

class HotExploreScreen extends StatefulWidget {
  const HotExploreScreen({super.key});

  @override
  State<HotExploreScreen> createState() => _HotExploreScreenState();
}

class _HotExploreScreenState extends State<HotExploreScreen> {
  int _selectedTabIndex = 0;
  List<ModelProfile> _models = [];
  String _selectedLanguage = 'All';

  @override
  void initState() {
    super.initState();
    _models = List.from(MockData.models);
  }

  void _onTabSelected(int index) {
    setState(() {
      _selectedTabIndex = index;
    });
  }

  void _openHostProfile(ModelProfile model) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => HostProfileScreen(model: model),
      ),
    );
  }

  void _startVideoCall(ModelProfile model) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => VideoCallScreen(model: model),
      ),
    );
  }

  void _simulateIncomingCall() {
    final caller = _models.firstWhere(
      (m) => m.name.contains('Nosimon') || m.name.contains('sexy'),
      orElse: () => _models.first,
    );

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => IncomingCallScreen(model: caller),
      ),
    );
  }

  void _showSayHelloDialog() {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: AppColors.cardDarkElevated,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: AppColors.orangeGradient,
                ),
                child: const Icon(Icons.waving_hand_rounded, color: Colors.white, size: 30),
              ),
              const SizedBox(height: 16),
              const Text(
                'Say Hello to Online Hosts!',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Send an instant wave to 5 available hosts in your area to start chatting.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel', style: TextStyle(color: AppColors.textMuted)),
                    ),
                  ),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.warmOrange,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      ),
                      onPressed: () {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('✨ Greetings sent to 5 online hosts!'),
                            backgroundColor: AppColors.neonPurple,
                          ),
                        );
                      },
                      child: const Text('Say Hello', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showLanguageSelector() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.cardDarkElevated,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        final languages = ['All', 'Bengali', 'English', 'Hindi', 'Spanish'];
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Select Language Region',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              ...languages.map((lang) {
                final isSelected = _selectedLanguage == lang;
                return ListTile(
                  title: Text(
                    lang,
                    style: TextStyle(
                      color: isSelected ? AppColors.neonPink : Colors.white,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                  trailing: isSelected
                      ? const Icon(Icons.check_circle, color: AppColors.neonPink)
                      : null,
                  onTap: () {
                    setState(() {
                      _selectedLanguage = lang;
                      if (lang == 'All') {
                        _models = List.from(MockData.models);
                      } else {
                        _models = MockData.models
                            .where((m) => m.languages.contains(lang))
                            .toList();
                      }
                    });
                    Navigator.pop(context);
                  },
                );
              }),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      body: SafeArea(
        child: Column(
          children: [
            // Top App Bar matching Screenshot 1
            ExploreHeader(
              selectedTabIndex: _selectedTabIndex,
              onTabSelected: _onTabSelected,
              onSearchTap: _simulateIncomingCall,
              onLanguageTap: _showLanguageSelector,
              onSayHelloTap: _showSayHelloDialog,
            ),

            // Body Content based on Tab
            Expanded(
              child: _selectedTabIndex == 1
                  ? const PartyRoomsScreen()
                  : RefreshIndicator(
                      color: AppColors.neonPink,
                      backgroundColor: AppColors.cardDark,
                      onRefresh: () async {
                        await Future.delayed(const Duration(milliseconds: 600));
                        setState(() {
                          _models = List.from(MockData.models);
                        });
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        child: GridView.builder(
                          itemCount: _models.length,
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            childAspectRatio: 0.72,
                            crossAxisSpacing: 10,
                            mainAxisSpacing: 10,
                          ),
                          itemBuilder: (context, index) {
                            final model = _models[index];
                            return ModelGridCard(
                              model: model,
                              onTap: () => _openHostProfile(model),
                              onVideoCallTap: () => _startVideoCall(model),
                            );
                          },
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            builder: (context) => const CreateRoomScreen(),
          );
        },
        backgroundColor: AppColors.neonPink,
        elevation: 8,
        icon: const Icon(Icons.mic_external_on_rounded, color: Colors.white),
        label: const Text(
          'Host Room',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/theme/app_colors.dart';
import '../../auth/widgets/logout_confirmation_dialog.dart';
import 'blocklist_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String _selectedLanguage = 'English';
  bool _notificationSound = true;
  bool _notificationVibration = true;
  String _cacheSize = '387.77 MB';
  bool _isGoogleBound = false;

  final List<Map<String, String>> _languages = [
    {'name': 'English', 'native': 'English', 'flag': '🇺🇸'},
    {'name': 'Bengali', 'native': 'বাংলা', 'flag': '🇧🇩'},
    {'name': 'Hindi', 'native': 'हिन्दी', 'flag': '🇮🇳'},
    {'name': 'Spanish', 'native': 'Español', 'flag': '🇪🇸'},
    {'name': 'Nepali', 'native': 'नेपाली', 'flag': '🇳🇵'},
    {'name': 'Urdu', 'native': 'اردو', 'flag': '🇵🇰'},
    {'name': 'Arabic', 'native': 'العربية', 'flag': '🇸🇦'},
  ];

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _selectedLanguage = prefs.getString('app_language') ?? 'English';
        _notificationSound = prefs.getBool('notification_sound') ?? true;
        _notificationVibration = prefs.getBool('notification_vibration') ?? true;
        _isGoogleBound = prefs.getBool('google_account_bound') ?? false;
      });
    }
  }

  Future<void> _saveBoolSetting(String key, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);
  }

  void _showLanguageSelector() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1B2E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Select App Language',
                          style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded, color: Colors.white70),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ..._languages.map((lang) {
                      final isSelected = _selectedLanguage == lang['name'];
                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        leading: Text(lang['flag']!, style: const TextStyle(fontSize: 22)),
                        title: Text(
                          lang['name']!,
                          style: TextStyle(
                            color: isSelected ? AppColors.neonPink : Colors.white,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                        subtitle: Text(lang['native']!, style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
                        trailing: isSelected
                            ? const Icon(Icons.check_circle_rounded, color: AppColors.neonPink)
                            : null,
                        onTap: () async {
                          final prefs = await SharedPreferences.getInstance();
                          await prefs.setString('app_language', lang['name']!);
                          setState(() {
                            _selectedLanguage = lang['name']!;
                          });
                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('App language changed to ${lang['name']}'),
                              backgroundColor: AppColors.cardDarkElevated,
                              duration: const Duration(seconds: 1),
                            ),
                          );
                        },
                      );
                    }),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showChangeIconModal() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1B2E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Change App Icon', style: TextStyle(color: Colors.white, fontSize: 18)),
        content: const Text(
          'Dynamic Launcher Icon themes: Default Dark, Neon Purple, and Gold VIP are active based on your VIP level.',
          style: TextStyle(color: Colors.white70, fontSize: 13.5),
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.neonPink,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _clearCache() {
    setState(() {
      _cacheSize = '0.00 MB';
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Cache cleaned successfully! (0.00 MB)'),
        backgroundColor: Color(0xFF00E676),
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _showAboutUs() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1B2E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.neonPink.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.info_outline_rounded, color: AppColors.neonPink, size: 22),
            ),
            const SizedBox(width: 10),
            const Text('About Us', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Chinchins Live', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
            SizedBox(height: 4),
            Text('Version: 1.0.1 (Build 2)', style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
            SizedBox(height: 12),
            Text(
              'Chinchins Live is a world-class premier live video streaming, voice party, and 1-on-1 private calling entertainment ecosystem with instant coin rewards.',
              style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
            ),
            SizedBox(height: 12),
            Text('© 2026 Chinchins Live Inc. All rights reserved.', style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
          ],
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.neonPink,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showPrivacyPolicy() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1B2E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Privacy Policy', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
        content: const SizedBox(
          height: 300,
          child: SingleChildScrollView(
            child: Text(
              'Chinchins Live respects user privacy and data security. All WebRTC calls are encrypted end-to-end. We do not sell or share personal data with third parties. Users have full control over their account data, blocklist, and profile visibility.',
              style: TextStyle(color: Colors.white70, fontSize: 13.5, height: 1.5),
            ),
          ),
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.neonPink,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showDeleteAccountDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1B2E),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: Color(0xFFFF5252), width: 1),
        ),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Color(0xFFFF5252), size: 24),
            SizedBox(width: 8),
            Text('Delete Account', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
        content: const Text(
          'Are you sure you want to delete your Chinchins Live account? All your coins, diamond gems, levels, and chat history will be permanently erased.',
          style: TextStyle(color: Colors.white70, fontSize: 13.5, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF5252),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () {
              Navigator.pop(ctx);
              LogoutConfirmationDialog.show(context);
            },
            child: const Text('Delete', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _toggleGoogleAccount() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _isGoogleBound = !_isGoogleBound;
    });
    await prefs.setBool('google_account_bound', _isGoogleBound);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_isGoogleBound ? 'Google Account bound successfully.' : 'Google Account unlinked.'),
          backgroundColor: AppColors.cardDarkElevated,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF131122),
      appBar: AppBar(
        backgroundColor: const Color(0xFF131122),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Settings',
          style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        children: [
          // 1. App Language
          _buildSettingsTile(
            title: 'App language',
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(_selectedLanguage, style: const TextStyle(color: AppColors.textMuted, fontSize: 13)),
                const SizedBox(width: 4),
                const Icon(Icons.chevron_right_rounded, color: Colors.white38, size: 22),
              ],
            ),
            onTap: _showLanguageSelector,
          ),

          // 2. Change Icon
          _buildSettingsTile(
            title: 'Change Icon',
            trailing: const Icon(Icons.chevron_right_rounded, color: Colors.white38, size: 22),
            onTap: _showChangeIconModal,
          ),

          // 3. Blocklist
          _buildSettingsTile(
            title: 'Blocklist',
            trailing: const Icon(Icons.chevron_right_rounded, color: Colors.white38, size: 22),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const BlocklistScreen()),
              );
            },
          ),

          // 4. Notification Sound Toggle
          _buildSettingsTile(
            title: 'Notification Sound',
            trailing: Switch(
              value: _notificationSound,
              activeColor: const Color(0xFF00E676),
              activeTrackColor: const Color(0xFF00E676).withValues(alpha: 0.35),
              inactiveThumbColor: Colors.white60,
              inactiveTrackColor: Colors.white12,
              onChanged: (val) {
                setState(() => _notificationSound = val);
                _saveBoolSetting('notification_sound', val);
              },
            ),
            onTap: () {
              setState(() => _notificationSound = !_notificationSound);
              _saveBoolSetting('notification_sound', _notificationSound);
            },
          ),

          // 5. Notification Vibration Toggle
          _buildSettingsTile(
            title: 'Notification Vibration',
            trailing: Switch(
              value: _notificationVibration,
              activeColor: const Color(0xFF00E676),
              activeTrackColor: const Color(0xFF00E676).withValues(alpha: 0.35),
              inactiveThumbColor: Colors.white60,
              inactiveTrackColor: Colors.white12,
              onChanged: (val) {
                setState(() => _notificationVibration = val);
                _saveBoolSetting('notification_vibration', val);
              },
            ),
            onTap: () {
              setState(() => _notificationVibration = !_notificationVibration);
              _saveBoolSetting('notification_vibration', _notificationVibration);
            },
          ),

          // 6. About Us
          _buildSettingsTile(
            title: 'About Us',
            trailing: const Icon(Icons.chevron_right_rounded, color: Colors.white38, size: 22),
            onTap: _showAboutUs,
          ),

          // 7. Delete Account
          _buildSettingsTile(
            title: 'Delete account',
            trailing: const Icon(Icons.chevron_right_rounded, color: Colors.white38, size: 22),
            onTap: _showDeleteAccountDialog,
          ),

          // 8. Privacy Policy
          _buildSettingsTile(
            title: 'Privacy Policy',
            trailing: const Icon(Icons.chevron_right_rounded, color: Colors.white38, size: 22),
            onTap: _showPrivacyPolicy,
          ),

          // 9. Clean Cache
          _buildSettingsTile(
            title: 'Clean Cache',
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(_cacheSize, style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600)),
                const SizedBox(width: 4),
                const Icon(Icons.chevron_right_rounded, color: Colors.white38, size: 22),
              ],
            ),
            onTap: _clearCache,
          ),

          // 10. Google Account
          _buildSettingsTile(
            title: 'Google account',
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _isGoogleBound ? 'Bound' : 'Not bound',
                  style: TextStyle(
                    color: _isGoogleBound ? const Color(0xFF00E676) : const Color(0xFFFF5252),
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(Icons.chevron_right_rounded, color: Colors.white38, size: 22),
              ],
            ),
            onTap: _toggleGoogleAccount,
          ),

          const SizedBox(height: 36),

          // 11. Switch Accounts / Log Out Action at bottom
          Center(
            child: TextButton(
              onPressed: () => LogoutConfirmationDialog.show(context),
              child: const Text(
                'Switch Accounts',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildSettingsTile({
    required String title,
    required Widget trailing,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 2),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Colors.white10, width: 0.6),
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        title: Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 15,
            fontWeight: FontWeight.w500,
          ),
        ),
        trailing: trailing,
        onTap: onTap,
      ),
    );
  }
}

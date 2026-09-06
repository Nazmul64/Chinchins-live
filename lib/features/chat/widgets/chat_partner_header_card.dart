import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/cached_image_loader.dart';

class ChatPartnerHeaderCard extends StatelessWidget {
  final String partnerName;
  final String avatarUrl;
  final String? countryFlag;
  final String? countryName;
  final int? age;
  final String? genderText;
  final String? genderIcon;
  final String? levelText;
  final String? greetingText;
  final VoidCallback? onTap;
  final VoidCallback? onCallTap;

  const ChatPartnerHeaderCard({
    super.key,
    required this.partnerName,
    required this.avatarUrl,
    this.countryFlag = '🇧🇩',
    this.countryName = 'Bangladesh',
    this.age = 22,
    this.genderText = 'Female',
    this.genderIcon = '♀',
    this.levelText = 'Lv. 5',
    this.greetingText = 'Hey handsome! Thanks for visiting my profile ❤️',
    this.onTap,
    this.onCallTap,
  });

  @override
  Widget build(BuildContext context) {
    final flag = (countryFlag != null && countryFlag!.isNotEmpty) ? countryFlag! : '🇧🇩';
    final country = (countryName != null && countryName!.isNotEmpty) ? countryName! : 'Bangladesh';
    final ageVal = age ?? 22;
    final gender = (genderText != null && genderText!.isNotEmpty) ? genderText! : 'Female';
    final gIcon = (genderIcon != null && genderIcon!.isNotEmpty) ? genderIcon! : '♀';
    final lvl = (levelText != null && levelText!.isNotEmpty) ? levelText! : 'Lv. 5';
    final quote = (greetingText != null && greetingText!.isNotEmpty)
        ? greetingText!
        : 'Hey handsome! Thanks for visiting my profile ❤️';

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF26183B), Color(0xFF191228)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: AppColors.neonPurple.withValues(alpha: 0.35),
            width: 1.0,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.25),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Left Avatar with Golden Border
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: const Color(0xFFFFB300),
                  width: 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFFFB300).withValues(alpha: 0.3),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: ClipOval(
                child: CachedImageLoader(
                  imageUrl: avatarUrl,
                  fit: BoxFit.cover,
                ),
              ),
            ),
            const SizedBox(width: 12),

            // Middle Information
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Row 1: Name + Star + Level
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          partnerName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(
                        Icons.star_rounded,
                        color: AppColors.gemYellow,
                        size: 16,
                      ),
                      const SizedBox(width: 6),
                      // Level Badge
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFFFFA000), Color(0xFFFF6F00)],
                          ),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          lvl,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9.5,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),

                  // Row 2: Country • Age • Gender • Level Summary
                  Text(
                    '$flag $country • $ageVal yrs • $gIcon $gender • $lvl',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.75),
                      fontSize: 11.5,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),

                  // Row 3: Greeting / Bio quote
                  Text(
                    '"$quote"',
                    style: const TextStyle(
                      color: Color(0xFFFFD1E3),
                      fontSize: 11.5,
                      fontStyle: FontStyle.italic,
                      fontWeight: FontWeight.w500,
                      height: 1.25,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

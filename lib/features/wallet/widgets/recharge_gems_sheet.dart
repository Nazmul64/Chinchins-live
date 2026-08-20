import 'package:flutter/material.dart';
import '../../../core/models/model_profile.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/cached_image_loader.dart';

class RechargeGemsSheet extends StatefulWidget {
  final ModelProfile? model;
  final VoidCallback? onRechargeSuccess;

  const RechargeGemsSheet({
    super.key,
    this.model,
    this.onRechargeSuccess,
  });

  @override
  State<RechargeGemsSheet> createState() => _RechargeGemsSheetState();
}

class _RechargeGemsSheetState extends State<RechargeGemsSheet> {
  int _selectedPackageIndex = 1; // Default to popular ৳550 package

  final List<Map<String, dynamic>> _packages = [
    {
      'gems': 6000,
      'bonus': 1000,
      'priceBDT': '৳120',
      'priceUSD': '\$0.99',
      'tag': '',
    },
    {
      'gems': 32000,
      'bonus': 8000,
      'priceBDT': '৳550',
      'priceUSD': '\$4.99',
      'tag': '🔥 50% OFF',
    },
    {
      'gems': 70000,
      'bonus': 20000,
      'priceBDT': '৳1,150',
      'priceUSD': '\$9.99',
      'tag': 'Best Value',
    },
    {
      'gems': 150000,
      'bonus': 50000,
      'priceBDT': '৳2,400',
      'priceUSD': '\$19.99',
      'tag': '+30% Free',
    },
    {
      'gems': 350000,
      'bonus': 120000,
      'priceBDT': '৳5,500',
      'priceUSD': '\$49.99',
      'tag': 'VIP Bonus',
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.88,
      ),
      decoration: const BoxDecoration(
        color: AppColors.surfaceDark,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.only(top: 12, left: 16, right: 16, bottom: 20),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Drag Handle
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
              const SizedBox(height: 12),

          // 1. Host Cute Speech Bubble Banner (as described in Voice Message!)
          if (widget.model != null)
            Container(
              margin: const EdgeInsets.only(bottom: 14),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF3B1F4B), Color(0xFF261536)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.neonPurple.withValues(alpha: 0.4)),
              ),
              child: Row(
                children: [
                  // Host Picture on the side
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.neonPink, width: 2),
                    ),
                    child: ClipOval(
                      child: CachedImageLoader(
                        imageUrl: widget.model!.avatarUrl,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Host Cute Message
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              widget.model!.name,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(width: 4),
                            const Icon(Icons.star_rounded, color: AppColors.gemYellow, size: 14),
                          ],
                        ),
                        const SizedBox(height: 3),
                        const Text(
                          '"I want to talk more with you, recharge and call me back! ❤️"',
                          style: TextStyle(
                            color: Color(0xFFFFD1E3),
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

          // 2. Spend Less, Get More Promo Banner (50% Off)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF4A148C), Color(0xFF880E4F)],
              ),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Spend Less, Get More Gems!',
                      style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Update to Monthly Card',
                      style: TextStyle(color: Colors.white70, fontSize: 11),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.gemYellow,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Text(
                    '50% off',
                    style: TextStyle(color: Colors.black, fontSize: 11, fontWeight: FontWeight.w900),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // 3. Gems Packages Grid
          const Text(
            'Select Package (Bangla Taka ৳)',
            style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),

          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: List.generate(_packages.length, (index) {
              final pkg = _packages[index];
              final isSelected = _selectedPackageIndex == index;

              return GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedPackageIndex = index;
                  });
                },
                child: Container(
                  width: (MediaQuery.of(context).size.width - 42) / 2,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppColors.neonPink.withValues(alpha: 0.15)
                        : AppColors.cardDark,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isSelected ? AppColors.neonPink : AppColors.cardBorder,
                      width: isSelected ? 1.8 : 1,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (pkg['tag'].isNotEmpty)
                        Container(
                          margin: const EdgeInsets.only(bottom: 6),
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            gradient: AppColors.primaryGradient,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            pkg['tag'],
                            style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                          ),
                        ),
                      Row(
                        children: [
                          const Icon(Icons.diamond_rounded, color: AppColors.gemYellow, size: 18),
                          const SizedBox(width: 4),
                          Text(
                            '${pkg['gems']}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '+${pkg['bonus']} Bonus',
                        style: const TextStyle(color: AppColors.onlineGreen, fontSize: 11, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        decoration: BoxDecoration(
                          color: isSelected ? AppColors.neonPink : AppColors.cardDarkElevated,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Center(
                          child: Text(
                            pkg['priceBDT'],
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 16),

          // 4. Payment Gateways Logos (bKash / Nagad / Card)
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildPaymentChip('bKash 📱'),
              const SizedBox(width: 8),
              _buildPaymentChip('Nagad ⚡'),
              const SizedBox(width: 8),
              _buildPaymentChip('Card 💳'),
              const SizedBox(width: 8),
              _buildPaymentChip('Google Play'),
            ],
          ),
          const SizedBox(height: 14),

          // 5. Submit Recharge Action Button
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.neonPink,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
                elevation: 6,
              ),
              onPressed: () {
                final selectedPkg = _packages[_selectedPackageIndex];
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('🎉 Recharge of ${selectedPkg['gems']} Gems successful! Ready to call.'),
                    backgroundColor: AppColors.onlineGreen,
                    duration: const Duration(seconds: 2),
                  ),
                );
                widget.onRechargeSuccess?.call();
              },
              child: Text(
                'Recharge ${(_packages[_selectedPackageIndex]['gems'] as int) + (_packages[_selectedPackageIndex]['bonus'] as int)} Gems (${_packages[_selectedPackageIndex]['priceBDT']})',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    ),
    ),
    );
  }

  Widget _buildPaymentChip(String title) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.cardDarkElevated,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Text(
        title,
        style: const TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.w600),
      ),
    );
  }
}

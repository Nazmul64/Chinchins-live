import 'package:flutter/material.dart';
import '../../../core/models/model_profile.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/cached_image_loader.dart';
import '../screens/deposit_screen.dart';
import '../services/wallet_api_service.dart';

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
  int _selectedPackageIndex = 0;
  bool _isLoading = true;
  List<Map<String, dynamic>> _packages = [];

  @override
  void initState() {
    super.initState();
    _loadDynamicPackages();
  }

  Future<void> _loadDynamicPackages() async {
    final list = await WalletApiService.getCoinPackages();
    if (mounted) {
      setState(() {
        _packages = list;
        _isLoading = false;
        // Default to popular package if available
        final popIndex = _packages.indexWhere((p) => p['is_popular'] == true || p['popular'] == true);
        if (popIndex != -1) {
          _selectedPackageIndex = popIndex;
        } else if (_packages.isNotEmpty) {
          _selectedPackageIndex = 0;
        }
      });
    }
  }

  int _parseInt(dynamic val, [int def = 0]) {
    if (val == null) return def;
    if (val is int) return val;
    if (val is num) return val.toInt();
    if (val is String) {
      return int.tryParse(val.replaceAll(RegExp(r'[^0-9\-]'), '')) ?? def;
    }
    return def;
  }

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

              // 1. Host Cute Speech Bubble Banner (if model provided)
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

              if (_isLoading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 40),
                  child: Center(
                    child: CircularProgressIndicator(color: AppColors.neonPink),
                  ),
                )
              else if (_packages.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 30),
                  child: Center(
                    child: Column(
                      children: [
                        const Text('No packages available at the moment', style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
                        const SizedBox(height: 8),
                        TextButton(
                          onPressed: _loadDynamicPackages,
                          child: const Text('Retry', style: TextStyle(color: AppColors.neonPink)),
                        ),
                      ],
                    ),
                  ),
                )
              else
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: List.generate(_packages.length, (index) {
                    final pkg = _packages[index];
                    final isSelected = _selectedPackageIndex == index;
                    final int gems = _parseInt(pkg['coins'] ?? pkg['gems'] ?? pkg['base_coins']);
                    final int bonus = _parseInt(pkg['bonus_coins'] ?? pkg['bonus']);
                    final String priceStr = pkg['formatted_price'] ??
                        (pkg['price_bdt'] != null ? '৳${pkg['price_bdt']}' : (pkg['price'] != null ? '৳${pkg['price']}' : '৳0'));
                    final String tag = (pkg['badge'] ?? pkg['offer_tag'] ?? pkg['tag'] ?? '').toString();

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
                            if (tag.isNotEmpty)
                              Container(
                                margin: const EdgeInsets.only(bottom: 6),
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  gradient: AppColors.primaryGradient,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  tag,
                                  style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                                ),
                              ),
                            Row(
                              children: [
                                const Icon(Icons.diamond_rounded, color: AppColors.gemYellow, size: 18),
                                const SizedBox(width: 4),
                                Text(
                                  '$gems',
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
                              '+$bonus Bonus',
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
                                  priceStr,
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

              // 5. Submit Recharge Action Button -> Navigates to DepositScreen
              if (_packages.isNotEmpty)
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
                      if (_selectedPackageIndex >= _packages.length) return;
                      final selectedPkg = _packages[_selectedPackageIndex];
                      Navigator.pop(context); // Close bottom sheet
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => DepositScreen(
                            selectedPackage: selectedPkg,
                            onDepositSuccess: widget.onRechargeSuccess,
                          ),
                        ),
                      );
                    },
                    child: Builder(
                      builder: (context) {
                        final current = (_selectedPackageIndex < _packages.length)
                            ? _packages[_selectedPackageIndex]
                            : _packages.first;
                        final int cGems = _parseInt(current['coins'] ?? current['gems'] ?? current['base_coins']);
                        final int cBonus = _parseInt(current['bonus_coins'] ?? current['bonus']);
                        final int cTotal = _parseInt(current['total_coins'], cGems + cBonus);
                        final String cPrice = current['formatted_price'] ??
                            (current['price_bdt'] != null ? '৳${current['price_bdt']}' : (current['price'] != null ? '৳${current['price']}' : '৳0'));
                        return Text(
                          'Recharge $cTotal Gems ($cPrice)',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        );
                      },
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

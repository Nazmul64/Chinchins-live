import 'package:flutter/material.dart';
import '../../../core/models/model_profile.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/cached_image_loader.dart';
import '../../auth/services/auth_api_service.dart';
import '../screens/deposit_screen.dart';
import '../services/wallet_api_service.dart';

class RechargeGemsSheet extends StatefulWidget {
  final ModelProfile? model;
  final dynamic receiverId;
  final String? receiverName;
  final String? receiverAvatarUrl;
  final String? customHeaderTitle;
  final VoidCallback? onRechargeSuccess;

  const RechargeGemsSheet({
    super.key,
    this.model,
    this.receiverId,
    this.receiverName,
    this.receiverAvatarUrl,
    this.customHeaderTitle,
    this.onRechargeSuccess,
  });

  /// Static helper method to show the recharge modal anywhere
  static Future<void> show(
    BuildContext context, {
    ModelProfile? model,
    dynamic receiverId,
    String? receiverName,
    String? receiverAvatarUrl,
    String? customHeaderTitle,
    VoidCallback? onRechargeSuccess,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black54,
      builder: (ctx) => RechargeGemsSheet(
        model: model,
        receiverId: receiverId,
        receiverName: receiverName,
        receiverAvatarUrl: receiverAvatarUrl,
        customHeaderTitle: customHeaderTitle,
        onRechargeSuccess: onRechargeSuccess,
      ),
    );
  }

  @override
  State<RechargeGemsSheet> createState() => _RechargeGemsSheetState();
}

class _RechargeGemsSheetState extends State<RechargeGemsSheet> {
  int _selectedPackageIndex = 0;
  bool _isLoading = true;
  List<Map<String, dynamic>> _packages = [];
  int _userGems = 60;
  String? _headerTitle;
  String? _avatarUrl;

  @override
  void initState() {
    super.initState();
    _headerTitle = widget.customHeaderTitle ??
        '✨ Chat all you want & connect face-to-face — upgrade for more fun!';
    _avatarUrl = widget.receiverAvatarUrl ?? widget.model?.avatarUrl;
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    // 1. Fetch user gems in real-time
    _fetchUserGems();

    // 2. Fetch modal data & coin packages from backend
    final effectiveReceiverId = widget.receiverId ?? widget.model?.id;
    try {
      final modalData = await WalletApiService.getRechargeModalData(
        receiverId: effectiveReceiverId,
        action: 'chat',
      );

      if (modalData != null && mounted) {
        setState(() {
          if (modalData['header_title'] != null) {
            _headerTitle = modalData['header_title'].toString();
          }
          if (modalData['user_gems'] != null) {
            _userGems = _parseInt(modalData['user_gems'], 60);
          }
          if (modalData['receiver'] != null && modalData['receiver'] is Map) {
            final rec = modalData['receiver'] as Map;
            if (rec['avatar_url'] != null && _avatarUrl == null) {
              _avatarUrl = rec['avatar_url'].toString();
            }
          }
          if (modalData['packages'] is List && (modalData['packages'] as List).isNotEmpty) {
            _packages = List<Map<String, dynamic>>.from(modalData['packages']);
          }
        });
      }
    } catch (_) {}

    // Fallback to standard coin packages if modal data was empty
    if (_packages.isEmpty) {
      final list = await WalletApiService.getCoinPackages();
      if (mounted) {
        setState(() {
          _packages = list.isNotEmpty ? list : _getChinchinsDefaultPackages();
        });
      }
    }

    if (mounted) {
      setState(() {
        _isLoading = false;
        // Default to first package (or one marked popular/once offer)
        _selectedPackageIndex = 0;
      });
    }
  }

  Future<void> _fetchUserGems() async {
    try {
      final balanceData = await WalletApiService.getWalletBalance();
      if (balanceData != null && mounted) {
        final gems = _parseInt(balanceData['coins'] ?? balanceData['gems'] ?? balanceData['balance'], 60);
        setState(() {
          _userGems = gems;
        });
      } else {
        final user = await AuthApiService.getSavedUser();
        if (user != null && mounted) {
          final gems = _parseInt(user['coins'] ?? user['gems'] ?? user['wallet_balance'], 60);
          setState(() {
            _userGems = gems;
          });
        }
      }
    } catch (_) {}
  }

  List<Map<String, dynamic>> _getChinchinsDefaultPackages() {
    return [
      {
        'id': 1,
        'title': 'Starter Pack',
        'coins': 7560,
        'bonus_coins': 0,
        'total_coins': 7560,
        'price': 150.0,
        'price_bdt': 150.0,
        'formatted_price': 'BDT 150.00',
        'badge': '50%off',
        'is_once_offer': true,
        'tier': 1,
      },
      {
        'id': 2,
        'title': 'Basic Pack',
        'coins': 8100,
        'bonus_coins': 0,
        'total_coins': 8100,
        'price': 300.0,
        'price_bdt': 300.0,
        'formatted_price': 'BDT 300.00',
        'badge': '17%off',
        'is_once_offer': false,
        'tier': 2,
      },
      {
        'id': 3,
        'title': 'Popular Pack',
        'coins': 16380,
        'bonus_coins': 0,
        'total_coins': 16380,
        'price': 600.0,
        'price_bdt': 600.0,
        'formatted_price': 'BDT 600.00',
        'badge': '17%off',
        'is_once_offer': false,
        'tier': 3,
      },
      {
        'id': 4,
        'title': 'Super Pack',
        'coins': 32940,
        'bonus_coins': 0,
        'total_coins': 32940,
        'price': 1200.0,
        'price_bdt': 1200.0,
        'formatted_price': 'BDT 1,200.00',
        'badge': '30%off',
        'is_once_offer': false,
        'tier': 4,
      },
      {
        'id': 5,
        'title': 'Mega Pack',
        'coins': 66600,
        'bonus_coins': 0,
        'total_coins': 66600,
        'price': 2400.0,
        'price_bdt': 2400.0,
        'formatted_price': 'BDT 2,400.00',
        'badge': '60%off',
        'is_once_offer': false,
        'tier': 5,
      },
      {
        'id': 6,
        'title': 'VIP King Pack',
        'coins': 167400,
        'bonus_coins': 0,
        'total_coins': 167400,
        'price': 6100.0,
        'price_bdt': 6100.0,
        'formatted_price': 'BDT 6,100.00',
        'badge': '80%off',
        'is_once_offer': false,
        'tier': 6,
      },
    ];
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

  void _onContinueTap() {
    if (_packages.isEmpty) return;
    final selectedPkg = (_selectedPackageIndex < _packages.length)
        ? _packages[_selectedPackageIndex]
        : _packages.first;

    Navigator.pop(context); // Dismiss modal sheet

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => DepositScreen(
          selectedPackage: selectedPkg,
          onDepositSuccess: () {
            _fetchUserGems();
            widget.onRechargeSuccess?.call();
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFFFAF7FC),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. Header Row (Avatar + Catchy Title + Close Button)
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Host Avatar
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: const Color(0xFFFFB300),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.08),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: ClipOval(
                    child: _avatarUrl != null && _avatarUrl!.isNotEmpty
                        ? CachedImageLoader(
                            imageUrl: _avatarUrl!,
                            fit: BoxFit.cover,
                          )
                        : Container(
                            color: const Color(0xFFE1BEE7),
                            child: const Icon(Icons.person, color: Colors.white, size: 26),
                          ),
                  ),
                ),
                const SizedBox(width: 10),

                // Title Text
                Expanded(
                  child: Text(
                    _headerTitle ?? '✨ Chat all you want & connect face-to-face — upgrade for more fun!',
                    style: const TextStyle(
                      color: Color(0xFF2E2437),
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      height: 1.3,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 6),

                // Close Button [X]
                IconButton(
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  icon: const Icon(Icons.close_rounded, color: Color(0xFF756A80), size: 22),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // 2. 3x2 Packages Grid (Exact visual match to screenshot)
            if (_isLoading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 60),
                child: Center(
                  child: CircularProgressIndicator(color: AppColors.neonPink),
                ),
              )
            else
              _buildPackagesGrid(),

            const SizedBox(height: 18),

            // 3. Dynamic User Balance: 💎 My Gems: 60
            Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.diamond_rounded,
                    color: Color(0xFFFF9800),
                    size: 18,
                  ),
                  const SizedBox(width: 6),
                  RichText(
                    text: TextSpan(
                      children: [
                        const TextSpan(
                          text: 'My Gems: ',
                          style: TextStyle(
                            color: Color(0xFF42374E),
                            fontSize: 14.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        TextSpan(
                          text: '$_userGems',
                          style: const TextStyle(
                            color: Color(0xFFB71C5A),
                            fontSize: 15.5,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // 4. Gradient "Continue" Action Button
            GestureDetector(
              onTap: _onContinueTap,
              child: Container(
                width: double.infinity,
                height: 50,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [
                      Color(0xFF3F0A59),
                      Color(0xFF8B125B),
                    ],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
                  borderRadius: BorderRadius.circular(25),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF8B125B).withValues(alpha: 0.35),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Center(
                  child: Text(
                    'Continue',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPackagesGrid() {
    final displayList = _packages.take(6).toList();
    while (displayList.length < 6) {
      displayList.addAll(_getChinchinsDefaultPackages().skip(displayList.length));
    }

    return Column(
      children: [
        // Row 1 (Items 0, 1, 2)
        Row(
          children: [
            Expanded(child: _buildPackageCard(displayList[0], 0)),
            const SizedBox(width: 10),
            Expanded(child: _buildPackageCard(displayList[1], 1)),
            const SizedBox(width: 10),
            Expanded(child: _buildPackageCard(displayList[2], 2)),
          ],
        ),
        const SizedBox(height: 10),
        // Row 2 (Items 3, 4, 5)
        Row(
          children: [
            Expanded(child: _buildPackageCard(displayList[3], 3)),
            const SizedBox(width: 10),
            Expanded(child: _buildPackageCard(displayList[4], 4)),
            const SizedBox(width: 10),
            Expanded(child: _buildPackageCard(displayList[5], 5)),
          ],
        ),
      ],
    );
  }

  Widget _buildPackageCard(Map<String, dynamic> pkg, int index) {
    final bool isSelected = _selectedPackageIndex == index;
    final int coins = _parseInt(pkg['coins'] ?? pkg['gems'] ?? pkg['total_coins']);
    final String badge = (pkg['badge'] ?? '').toString();
    final bool isOnce = pkg['is_once_offer'] == true || index == 0;
    final String priceStr = pkg['formatted_price'] ??
        (pkg['price_bdt'] != null ? 'BDT ${pkg['price_bdt']}.00' : 'BDT ${pkg['price'] ?? 150}.00');

    // Card 1 or selected item gets the warm Orange Amber Gradient matching Screenshot
    final bool useOrangeTheme = isSelected;

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedPackageIndex = index;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: 148,
        decoration: BoxDecoration(
          gradient: useOrangeTheme
              ? const LinearGradient(
                  colors: [
                    Color(0xFFFF9100),
                    Color(0xFFFF5200),
                    Color(0xFFE64A00),
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                )
              : null,
          color: useOrangeTheme ? null : const Color(0xFFF3EDF7),
          borderRadius: BorderRadius.circular(16),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: const Color(0xFFFF5200).withValues(alpha: 0.35),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ]
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ],
        ),
        child: Stack(
          children: [
            // Top Left Discount Badge (e.g. 50%off, 17%off, 30%off, 60%off, 80%off)
            if (badge.isNotEmpty)
              Positioned(
                top: 0,
                left: 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
                  decoration: const BoxDecoration(
                    color: Color(0xFFE53935),
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(16),
                      bottomRight: Radius.circular(10),
                    ),
                  ),
                  child: Text(
                    badge,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 9.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),

            // Top Right ONCE Flame Badge for Tier 1
            if (isOnce)
              Positioned(
                top: 3,
                right: 5,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1.5),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF6D00),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.local_fire_department_rounded, color: Colors.white, size: 9),
                      SizedBox(width: 1),
                      Text(
                        'ONCE',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 8.5,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            // Center Content: Artwork + Coins + Price
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const SizedBox(height: 12),
                  // Gem Tier Artwork (Dynamic backend URL if present, or custom geometric jewel)
                  Builder(
                    builder: (context) {
                      final String? pkgImg = pkg['png_url'] ?? pkg['svg_url'] ?? pkg['icon_full_url'] ?? pkg['image_url'] ?? pkg['icon_url'];
                      if (pkgImg != null && pkgImg.toString().trim().isNotEmpty) {
                        return CachedImageLoader(
                          imageUrl: pkgImg.toString(),
                          width: 38,
                          height: 38,
                          fit: BoxFit.contain,
                          placeholder: _buildGemArtwork(index, useOrangeTheme),
                        );
                      }
                      return _buildGemArtwork(index, useOrangeTheme);
                    },
                  ),
                  const SizedBox(height: 6),

                  // Coin Count Text
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      '$coins',
                      style: TextStyle(
                        color: useOrangeTheme ? Colors.white : const Color(0xFF221A2C),
                        fontSize: 16.5,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),

                  // Bottom Price
                  if (useOrangeTheme)
                    // White pill for selected/orange card
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 3.5),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Center(
                        child: Text(
                          priceStr,
                          style: const TextStyle(
                            color: Color(0xFFE64A00),
                            fontSize: 10.5,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    )
                  else
                    // Normal muted price
                    Text(
                      priceStr,
                      style: const TextStyle(
                        color: Color(0xFF756A80),
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Exact gemstone artwork for all 6 tiers
  Widget _buildGemArtwork(int index, bool isOrangeCard) {
    switch (index) {
      case 0:
        // Tier 1: Single sparkling golden diamond
        return const Icon(
          Icons.diamond_rounded,
          color: Color(0xFFFFD54F),
          size: 34,
          shadows: [
            Shadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 2)),
          ],
        );
      case 1:
        // Tier 2: Double diamonds
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.diamond_rounded, color: Color(0xFFFFB300), size: 24),
            Transform(
              transform: Matrix4.translationValues(-6, 4, 0),
              child: const Icon(Icons.diamond_rounded, color: Color(0xFFFFD54F), size: 24),
            ),
          ],
        );
      case 2:
        // Tier 3: Triple diamonds
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.diamond_rounded, color: Color(0xFFFFB300), size: 22),
            Transform(
              transform: Matrix4.translationValues(-4, -3, 0),
              child: const Icon(Icons.diamond_rounded, color: Color(0xFFFFE082), size: 26),
            ),
            Transform(
              transform: Matrix4.translationValues(-8, 3, 0),
              child: const Icon(Icons.diamond_rounded, color: Color(0xFFFFB300), size: 22),
            ),
          ],
        );
      case 3:
        // Tier 4: Diamond Pyramid Stack
        return const Column(
          children: [
            Icon(Icons.diamond_rounded, color: Color(0xFFFFE082), size: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.diamond_rounded, color: Color(0xFFFFB300), size: 18),
                SizedBox(width: 2),
                Icon(Icons.diamond_rounded, color: Color(0xFFFFD54F), size: 20),
                SizedBox(width: 2),
                Icon(Icons.diamond_rounded, color: Color(0xFFFFB300), size: 18),
              ],
            ),
          ],
        );
      case 4:
        // Tier 5: Velvet Tray with Gems
        return Stack(
          alignment: Alignment.center,
          children: [
            Container(
              margin: const EdgeInsets.only(top: 14),
              width: 48,
              height: 12,
              decoration: BoxDecoration(
                color: const Color(0xFF7E57C2),
                borderRadius: BorderRadius.circular(4),
                boxShadow: const [
                  BoxShadow(color: Color(0xFF512DA8), blurRadius: 2, offset: Offset(0, 2)),
                ],
              ),
            ),
            const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.diamond_rounded, color: Color(0xFFFFB300), size: 18),
                Icon(Icons.diamond_rounded, color: Color(0xFFFFE082), size: 24),
                Icon(Icons.diamond_rounded, color: Color(0xFFFFB300), size: 18),
              ],
            ),
          ],
        );
      case 5:
      default:
        // Tier 6: Golden Luxury Chest / Overflowing Treasure
        return Stack(
          alignment: Alignment.center,
          children: [
            Container(
              margin: const EdgeInsets.only(top: 14),
              width: 54,
              height: 14,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF5E35B1), Color(0xFF311B92)],
                ),
                borderRadius: BorderRadius.circular(5),
                border: Border.all(color: const Color(0xFFFFD54F), width: 1),
              ),
            ),
            const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.diamond_rounded, color: Color(0xFFFFD54F), size: 18),
                Icon(Icons.diamond_rounded, color: Color(0xFFFFF176), size: 26),
                Icon(Icons.diamond_rounded, color: Color(0xFFFFD54F), size: 18),
              ],
            ),
          ],
        );
    }
  }
}

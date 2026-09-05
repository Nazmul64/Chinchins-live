import 'package:flutter/material.dart';
import '../../../core/models/model_profile.dart';
import '../../../core/widgets/cached_image_loader.dart';
import '../screens/deposit_screen.dart';
import '../services/wallet_api_service.dart';

class InCallRechargeGemsSheet extends StatefulWidget {
  final ModelProfile? model;
  final int userGems;
  final int ratePerMinute;
  final String? teaserText;
  final VoidCallback? onClose;
  final Function(int addedGems)? onRechargeSuccess;

  const InCallRechargeGemsSheet({
    super.key,
    this.model,
    this.userGems = 0,
    this.ratePerMinute = 1800,
    this.teaserText,
    this.onClose,
    this.onRechargeSuccess,
  });

  static Future<void> show(
    BuildContext context, {
    ModelProfile? model,
    int userGems = 0,
    int ratePerMinute = 1800,
    String? teaserText,
    VoidCallback? onClose,
    Function(int addedGems)? onRechargeSuccess,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.70),
      builder: (ctx) => InCallRechargeGemsSheet(
        model: model,
        userGems: userGems,
        ratePerMinute: ratePerMinute,
        teaserText: teaserText,
        onClose: onClose,
        onRechargeSuccess: onRechargeSuccess,
      ),
    );
  }

  @override
  State<InCallRechargeGemsSheet> createState() => _InCallRechargeGemsSheetState();
}

class _InCallRechargeGemsSheetState extends State<InCallRechargeGemsSheet> {
  // Default Promo Offer matching Screenshot 1 & Section 4 API
  int _promoCoins = 7560;
  double _promoPriceBdt = 150.00;
  String _formattedPromoPrice = 'BDT 150.00';
  String _teaserText =
      'Girls are still eagerly waiting for your reply. Recharge and enjoy happy time with her now~';

  @override
  void initState() {
    super.initState();
    if (widget.teaserText != null && widget.teaserText!.isNotEmpty) {
      _teaserText = widget.teaserText!;
    }
    _loadOfferConfig();
  }

  Future<void> _loadOfferConfig() async {
    try {
      final remoteList = await WalletApiService.getCoinPackages();
      if (remoteList.isNotEmpty && mounted) {
        final firstPkg = remoteList.first;
        setState(() {
          _promoCoins = _parseInt(firstPkg['coins'] ?? firstPkg['gems'], 7560);
          final pNum = double.tryParse(firstPkg['price']?.toString() ?? '150') ?? 150.00;
          _promoPriceBdt = pNum;
          _formattedPromoPrice = firstPkg['price_formatted']?.toString() ??
              firstPkg['formatted_price']?.toString() ??
              'BDT ${pNum.toStringAsFixed(2)}';
        });
      }
    } catch (_) {}
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

  void _onGetCoinsTap() {
    final selectedPackage = {
      'id': 1,
      'coins': _promoCoins,
      'gems': _promoCoins,
      'price': _promoPriceBdt,
      'price_bdt': _promoPriceBdt,
      'price_formatted': _formattedPromoPrice,
      'title': 'Quick Promo $_promoCoins Coins',
    };

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => DepositScreen(
          selectedPackage: selectedPackage,
          onDepositSuccess: () {
            widget.onRechargeSuccess?.call(_promoCoins);
            Navigator.pop(context); // close recharge modal
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final rate = widget.ratePerMinute > 0
        ? widget.ratePerMinute
        : (widget.model?.pricePerMin ?? 1800);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 1. Top Pill Badge: "Continue Video Call 💎 1800/min"
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.85),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.15),
                  width: 1.0,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.6),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Continue Video Call',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.2,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(Icons.diamond_rounded, color: Color(0xFFFFD700), size: 15),
                  const SizedBox(width: 4),
                  Text(
                    '$rate/min',
                    style: const TextStyle(
                      color: Color(0xFFFFD700),
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 14),

            // 2. Main Modal Card with Festive Diamond Ribbon Header
            Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.topCenter,
              children: [
                // White / Soft Cream Card Body
                Container(
                  margin: const EdgeInsets.only(top: 26),
                  padding: const EdgeInsets.fromLTRB(16, 36, 16, 20),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF9F6FA),
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.4),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Top Row: Host Portrait Card (Left) + Description & Promo Offer (Right)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Host Portrait Box with Border
                          Container(
                            width: 82,
                            height: 106,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: const Color(0xFFFF5252),
                                width: 2.0,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFFFF5252).withValues(alpha: 0.25),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: widget.model?.avatarUrl != null &&
                                      widget.model!.avatarUrl.isNotEmpty
                                  ? CachedImageLoader(
                                      imageUrl: widget.model!.avatarUrl,
                                      fit: BoxFit.cover,
                                    )
                                  : Container(
                                      color: const Color(0xFFE1BEE7),
                                      child: const Icon(Icons.person, color: Colors.white, size: 40),
                                    ),
                            ),
                          ),

                          const SizedBox(width: 14),

                          // Description Text & Promo Box
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Teaser Text
                                Text(
                                  _teaserText,
                                  style: const TextStyle(
                                    color: Color(0xFF5D5365),
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w500,
                                    height: 1.35,
                                  ),
                                ),

                                const SizedBox(height: 12),

                                // Promo Offer Pill (💎 7560 | BDT 150.00)
                                Container(
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFEDE7F2),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: const Color(0xFFFF7043).withValues(alpha: 0.3),
                                      width: 1.0,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      // Coins part
                                      Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                        child: Row(
                                          children: [
                                            const Icon(
                                              Icons.diamond_rounded,
                                              color: Color(0xFFFFB300),
                                              size: 16,
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              '$_promoCoins',
                                              style: const TextStyle(
                                                color: Color(0xFF2E2437),
                                                fontSize: 14,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),

                                      // Price Orange Pill
                                      Expanded(
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(vertical: 8),
                                          decoration: BoxDecoration(
                                            gradient: const LinearGradient(
                                              colors: [Color(0xFFFF7043), Color(0xFFFF5722)],
                                            ),
                                            borderRadius: const BorderRadius.horizontal(
                                              right: Radius.circular(11),
                                            ),
                                          ),
                                          child: Center(
                                            child: Text(
                                              _formattedPromoPrice,
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 13,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 20),

                      // 3. Full-width Orange "Get Coins" Action Button
                      GestureDetector(
                        onTap: _onGetCoinsTap,
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [
                                Color(0xFFFF7043),
                                Color(0xFFFF5722),
                                Color(0xFFE64A19),
                              ],
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                            ),
                            borderRadius: BorderRadius.circular(28),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFFFF5722).withValues(alpha: 0.45),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: const Center(
                            child: Text(
                              'Get Coins',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.3,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Top Floating Diamond Ribbon Ornament
                Positioned(
                  top: 0,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // Ribbon background
                        Container(
                          width: 140,
                          height: 38,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFFFF8A65), Color(0xFFFF5722)],
                            ),
                            borderRadius: BorderRadius.circular(18),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFFFF5722).withValues(alpha: 0.35),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                        ),

                        // Center Sparkling Diamond
                        Container(
                          width: 48,
                          height: 48,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: RadialGradient(
                              colors: [
                                Color(0xFFFFF9C4),
                                Color(0xFFFFD54F),
                                Color(0xFFFFB300),
                              ],
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Color(0xFFFFD54F),
                                blurRadius: 10,
                                spreadRadius: 1,
                              ),
                            ],
                          ),
                          child: const Center(
                            child: Icon(
                              Icons.diamond_rounded,
                              color: Colors.white,
                              size: 28,
                              shadows: [
                                Shadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 1)),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Close (X) button on top right of the card
                Positioned(
                  top: 34,
                  right: 12,
                  child: GestureDetector(
                    onTap: () {
                      Navigator.pop(context);
                      widget.onClose?.call();
                    },
                    child: Container(
                      padding: const EdgeInsets.all(5),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.08),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.close_rounded,
                        color: Color(0xFF756A80),
                        size: 18,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

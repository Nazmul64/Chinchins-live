import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/cached_image_loader.dart';
import '../models/payment_option_model.dart';
import '../services/reseller_api_service.dart';
import '../services/wallet_api_service.dart';
import '../widgets/reseller_bottom_sheet.dart';
import 'deposit_screen.dart';

class PaymentOptionsScreen extends StatefulWidget {
  final Map<String, dynamic> selectedPackage;
  final VoidCallback? onRechargeSuccess;

  const PaymentOptionsScreen({
    super.key,
    required this.selectedPackage,
    this.onRechargeSuccess,
  });

  @override
  State<PaymentOptionsScreen> createState() => _PaymentOptionsScreenState();
}

class _PaymentOptionsScreenState extends State<PaymentOptionsScreen> {
  List<PaymentOption> _options = [];
  String _selectedKey = 'reseller';
  bool _isLoading = true;
  bool _isProcessingGooglePlay = false;

  @override
  void initState() {
    super.initState();
    _loadPaymentOptions();
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

  double _parseDouble(dynamic val, [double def = 150.0]) {
    if (val == null) return def;
    if (val is double) return val;
    if (val is num) return val.toDouble();
    if (val is String) {
      return double.tryParse(val.replaceAll(RegExp(r'[^0-9.\-]'), '')) ?? def;
    }
    return def;
  }

  Future<void> _loadPaymentOptions() async {
    final pkg = widget.selectedPackage;
    final int? packageId = pkg['id'] != null ? _parseInt(pkg['id']) : null;
    final double amount = _parseDouble(pkg['price'] ?? pkg['price_bdt'] ?? pkg['rate_bdt'] ?? 150.0);
    final int coins = _parseInt(pkg['coins'] ?? pkg['total_coins'] ?? 7560);

    final list = await ResellerApiService.getPaymentOptions(
      packageId: packageId,
      amount: amount,
      coins: coins,
    );

    if (mounted) {
      setState(() {
        _options = list;
        _isLoading = false;
        // If 'reseller' exists, keep it as default; otherwise select first option
        if (_options.any((o) => o.key == 'reseller')) {
          _selectedKey = 'reseller';
        } else if (_options.isNotEmpty) {
          _selectedKey = _options.first.key;
        }
      });
    }
  }

  void _onOptionSelected(String key) {
    setState(() {
      _selectedKey = key;
    });

    if (key == 'reseller') {
      _openResellerSheet();
    }
  }

  Future<void> _onContinue() async {
    if (_selectedKey == 'reseller') {
      _openResellerSheet();
    } else if (_selectedKey == 'google_play') {
      await _handleGooglePlayPurchase();
    } else {
      // Standard gateway / deposit flow (bKash / Nagad / Upay / etc.)
      final currentOpt = _options.firstWhere(
        (o) => o.key == _selectedKey,
        orElse: () => _options.first,
      );

      final modifiedPackage = Map<String, dynamic>.from(widget.selectedPackage);
      modifiedPackage['payment_method_code'] = currentOpt.key;
      modifiedPackage['payment_method_name'] = currentOpt.name;
      if (currentOpt.accountNumber != null) {
        modifiedPackage['account_number'] = currentOpt.accountNumber;
      }

      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => DepositScreen(
            selectedPackage: modifiedPackage,
            onDepositSuccess: widget.onRechargeSuccess,
          ),
        ),
      );
    }
  }

  void _openResellerSheet() {
    final pkg = widget.selectedPackage;
    final double amount = _parseDouble(pkg['price'] ?? pkg['price_bdt'] ?? 150.0);
    final int coins = _parseInt(pkg['coins'] ?? pkg['total_coins'] ?? 7560);

    ResellerBottomSheet.show(
      context,
      selectedCoins: coins,
      selectedAmount: amount,
    );
  }

  Future<void> _handleGooglePlayPurchase() async {
    final pkg = widget.selectedPackage;
    final int packageId = _parseInt(pkg['id'] ?? pkg['package_id'] ?? 1, 1);
    final int coins = _parseInt(pkg['coins'] ?? pkg['total_coins'] ?? 7560);

    setState(() => _isProcessingGooglePlay = true);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Center(
        child: Card(
          color: Color(0xFF1E1B2E),
          child: Padding(
            padding: EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(color: Color(0xFF00E676)),
                SizedBox(height: 16),
                Text(
                  'Connecting to Google Play Billing...',
                  style: TextStyle(color: Colors.white, fontSize: 14),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    // Simulate standard Google Play token and verify on backend
    await Future.delayed(const Duration(milliseconds: 1500));

    final String mockToken = 'gplay_${DateTime.now().millisecondsSinceEpoch}_tok';
    final String orderId = 'GPA.${DateTime.now().millisecondsSinceEpoch}';

    final result = await ResellerApiService.verifyGooglePlayPurchase(
      packageId: packageId,
      productId: 'com.chinchins.live.gems$coins',
      purchaseToken: mockToken,
      orderId: orderId,
    );

    if (mounted) {
      Navigator.pop(context); // Close loading dialog
      setState(() => _isProcessingGooglePlay = false);

      final isSuccess = result['status'] == true || result['success'] == true;

      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: const Color(0xFF1E1B2E),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              Icon(
                isSuccess ? Icons.check_circle_rounded : Icons.error_outline_rounded,
                color: isSuccess ? const Color(0xFF00E676) : Colors.redAccent,
                size: 26,
              ),
              const SizedBox(width: 10),
              Text(
                isSuccess ? 'Purchase Successful!' : 'Purchase Error',
                style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          content: Text(
            isSuccess
                ? 'Successfully purchased $coins gems via Google Play! Your gems have been credited to your wallet.'
                : (result['message'] ?? 'Failed to complete Google Play transaction. Please try again.'),
            style: const TextStyle(color: Colors.white70, fontSize: 13.5, height: 1.4),
          ),
          actions: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: isSuccess ? const Color(0xFF00E676) : AppColors.neonPink,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () {
                Navigator.pop(ctx);
                if (isSuccess) {
                  WalletApiService.getWalletBalance(forceRefresh: true);
                  widget.onRechargeSuccess?.call();
                  Navigator.pop(context);
                }
              },
              child: Text(isSuccess ? 'Done' : 'OK', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final pkg = widget.selectedPackage;
    final double amount = _parseDouble(pkg['price'] ?? pkg['price_bdt'] ?? 150.0);
    final String formattedPrice = pkg['formatted_price']?.toString() ??
        pkg['price_formatted']?.toString() ??
        'BDT ${amount.toStringAsFixed(2)}';

    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFF1F2937), size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Payment options',
          style: TextStyle(
            color: Color(0xFF1F2937),
            fontSize: 17,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const SizedBox(height: 12),

                    // Big Bold Price Header: BDT 6,100.00 / BDT 150.00
                    Text(
                      formattedPrice,
                      style: const TextStyle(
                        color: Color(0xFF111827),
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.5,
                      ),
                    ),

                    const SizedBox(height: 28),

                    // Options Container Card: "Options for you"
                    Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.04),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                        border: Border.all(color: const Color(0xFFF3F4F6), width: 1),
                      ),
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Options for you',
                            style: TextStyle(
                              color: Color(0xFF4B5563),
                              fontSize: 14.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 14),

                          if (_isLoading)
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 40),
                              child: Center(
                                child: CircularProgressIndicator(color: AppColors.neonPink),
                              ),
                            )
                          else if (_options.isEmpty)
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 30),
                              child: Center(
                                child: Text(
                                  'No payment options currently available.',
                                  style: TextStyle(color: Color(0xFF6B7280), fontSize: 13),
                                ),
                              ),
                            )
                          else
                            ListView.separated(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: _options.length,
                              separatorBuilder: (ctx, i) => const Divider(
                                color: Color(0xFFF3F4F6),
                                height: 20,
                              ),
                              itemBuilder: (ctx, index) {
                                final opt = _options[index];
                                final isSelected = _selectedKey == opt.key;
                                return _buildOptionRow(opt, isSelected);
                              },
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Bottom Gradient Continue Button
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
              child: GestureDetector(
                onTap: _isProcessingGooglePlay ? null : _onContinue,
                child: Container(
                  width: double.infinity,
                  height: 52,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [
                        Color(0xFF4A0E4E),
                        Color(0xFFC2185B),
                      ],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    ),
                    borderRadius: BorderRadius.circular(26),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFC2185B).withValues(alpha: 0.4),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Center(
                    child: _isProcessingGooglePlay
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                          )
                        : const Text(
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
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOptionRow(PaymentOption opt, bool isSelected) {
    return InkWell(
      onTap: () => _onOptionSelected(opt.key),
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
        child: Row(
          children: [
            // Dynamic Payment Gateway / Method Icon from server database
            _buildOptionIcon(opt),
            const SizedBox(width: 14),

            // Name & Optional Discount Badge
            Expanded(
              child: Row(
                children: [
                  Text(
                    opt.name,
                    style: const TextStyle(
                      color: Color(0xFF111827),
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (opt.badge != null && opt.badge!.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [
                            Color(0xFFFF5722),
                            Color(0xFFE53935),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(6),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFFF5722).withValues(alpha: 0.3),
                            blurRadius: 4,
                            offset: const Offset(0, 1),
                          ),
                        ],
                      ),
                      child: Text(
                        opt.badge!,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10.5,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),

            // Custom Radio Button
            Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? const Color(0xFFFF5722) : const Color(0xFFD1D5DB),
                  width: isSelected ? 2 : 1.5,
                ),
              ),
              child: isSelected
                  ? Center(
                      child: Container(
                        width: 10,
                        height: 10,
                        decoration: const BoxDecoration(
                          color: Color(0xFFFF5722),
                          shape: BoxShape.circle,
                        ),
                      ),
                    )
                  : null,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOptionIcon(PaymentOption opt) {
    final iconUrl = opt.icon;

    if (iconUrl != null && iconUrl.isNotEmpty) {
      if (iconUrl.toLowerCase().endsWith('.svg') || iconUrl.toLowerCase().contains('.svg')) {
        return Container(
          width: 40,
          height: 40,
          padding: const EdgeInsets.all(5),
          decoration: BoxDecoration(
            color: const Color(0xFFF9FAFB),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFE5E7EB), width: 1),
          ),
          child: SvgPicture.network(
            iconUrl,
            fit: BoxFit.contain,
            placeholderBuilder: (ctx) => const Center(
              child: SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 1.5, color: Color(0xFFD1D5DB)),
              ),
            ),
          ),
        );
      }

      if (iconUrl.startsWith('http://') || iconUrl.startsWith('https://')) {
        return Container(
          width: 40,
          height: 40,
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: const Color(0xFFF9FAFB),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFE5E7EB), width: 1),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: CachedImageLoader(
              imageUrl: iconUrl,
              fit: BoxFit.contain,
            ),
          ),
        );
      }

      if (iconUrl.startsWith('assets/')) {
        return Container(
          width: 40,
          height: 40,
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: const Color(0xFFF9FAFB),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFE5E7EB), width: 1),
          ),
          child: Image.asset(
            iconUrl,
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => _buildFallbackGenericIcon(opt.key),
          ),
        );
      }
    }

    return _buildFallbackGenericIcon(opt.key);
  }

  Widget _buildFallbackGenericIcon(String key) {
    final lowerKey = key.toLowerCase();

    if (lowerKey.contains('bkash')) {
      return Container(
        width: 40,
        height: 40,
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF0F5),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFFFE0EB)),
        ),
        child: const Center(
          child: Text(
            'bKash',
            style: TextStyle(
              color: Color(0xFFD81B60),
              fontSize: 10,
              fontWeight: FontWeight.w900,
              fontStyle: FontStyle.italic,
            ),
          ),
        ),
      );
    }

    if (lowerKey.contains('nagad') || lowerKey.contains('nogad')) {
      return Container(
        width: 40,
        height: 40,
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF7ED),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFFFEDD5)),
        ),
        child: const Center(
          child: Text(
            'নগদ',
            style: TextStyle(
              color: Color(0xFFEA580C),
              fontSize: 11,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      );
    }

    if (lowerKey.contains('google')) {
      return Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: const Color(0xFFF3F4F6),
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Center(
          child: Icon(
            Icons.play_arrow_rounded,
            color: Color(0xFF00C853),
            size: 24,
          ),
        ),
      );
    }

    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: const Color(0xFF1E1B4B),
        borderRadius: BorderRadius.circular(10),
      ),
      child: const Center(
        child: Icon(
          Icons.monetization_on_rounded,
          color: Color(0xFFFFC107),
          size: 22,
        ),
      ),
    );
  }
}

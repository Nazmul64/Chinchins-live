import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../models/payment_option_model.dart';
import '../services/reseller_api_service.dart';
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
  String _selectedKey = 'reseller'; // Default selected according to spec
  bool _isLoading = true;

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
        // Keep 'reseller' or first option selected
        if (!_options.any((o) => o.key == _selectedKey) && _options.isNotEmpty) {
          _selectedKey = _options.first.key;
        }
      });
    }
  }

  void _onOptionSelected(String key) {
    setState(() {
      _selectedKey = key;
    });

    // If tapped directly on reseller option, prompt bottom sheet immediately or allow continue tap
    if (key == 'reseller') {
      _openResellerSheet();
    }
  }

  void _onContinue() {
    if (_selectedKey == 'reseller') {
      _openResellerSheet();
    } else {
      // Navigate to standard deposit / gateway flow
      final currentOpt = _options.firstWhere(
        (o) => o.key == _selectedKey,
        orElse: () => _options.first,
      );

      final modifiedPackage = Map<String, dynamic>.from(widget.selectedPackage);
      modifiedPackage['payment_method_code'] = currentOpt.key;
      modifiedPackage['payment_method_name'] = currentOpt.name;

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

                    // Big Bold Price (Matching Screenshot 2: BDT 150.00)
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

                    // Options Container Card (Matching Screenshot 2: "Options for you")
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

            // Bottom Gradient Continue Button (Matching Screenshot 2)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
              child: GestureDetector(
                onTap: _onContinue,
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
            // Payment Gateway / Method Icon
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

            // Custom Radio Button (Orange ring when selected matching screenshot 2)
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
    final key = opt.key.toLowerCase();

    if (key == 'bkash') {
      return Container(
        width: 38,
        height: 38,
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF0F5),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFFFE0EB)),
        ),
        child: Center(
          child: Text(
            'bKash',
            style: TextStyle(
              color: const Color(0xFFD81B60),
              fontSize: 10,
              fontWeight: FontWeight.w900,
              fontStyle: FontStyle.italic,
            ),
          ),
        ),
      );
    }

    if (key == 'nagad') {
      return Container(
        width: 38,
        height: 38,
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF7ED),
          borderRadius: BorderRadius.circular(8),
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

    if (key == 'google_play') {
      return Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: const Color(0xFFF3F4F6),
          borderRadius: BorderRadius.circular(8),
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

    // Default / Reseller Icon
    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        color: const Color(0xFF1E1B4B),
        borderRadius: BorderRadius.circular(8),
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

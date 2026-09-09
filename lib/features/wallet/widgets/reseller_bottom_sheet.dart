import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/cached_image_loader.dart';
import '../models/reseller_model.dart';
import '../screens/reseller_chat_screen.dart';
import '../services/reseller_api_service.dart';

class ResellerBottomSheet extends StatefulWidget {
  final int? selectedCoins;
  final double? selectedAmount;
  final String? customPrefill;

  const ResellerBottomSheet({
    super.key,
    this.selectedCoins,
    this.selectedAmount,
    this.customPrefill,
  });

  static Future<void> show(
    BuildContext context, {
    int? selectedCoins,
    double? selectedAmount,
    String? customPrefill,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.65),
      builder: (ctx) => ResellerBottomSheet(
        selectedCoins: selectedCoins,
        selectedAmount: selectedAmount,
        customPrefill: customPrefill,
      ),
    );
  }

  @override
  State<ResellerBottomSheet> createState() => _ResellerBottomSheetState();
}

class _ResellerBottomSheetState extends State<ResellerBottomSheet> {
  List<ResellerModel> _resellers = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadResellers();
  }

  Future<void> _loadResellers() async {
    final list = await ResellerApiService.getResellers(coins: widget.selectedCoins);
    if (mounted) {
      setState(() {
        _resellers = list;
        _isLoading = false;
      });
    }
  }

  void _openChat(ResellerModel reseller) {
    Navigator.pop(context); // Close bottom sheet
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ResellerChatScreen(
          reseller: reseller,
          requestedCoins: widget.selectedCoins ?? 7560,
          requestedAmount: widget.selectedAmount ?? 150.0,
          initialPrefillMessage: widget.customPrefill,
        ),
      ),
    );
  }

  void _showHelpDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E182A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.help_outline_rounded, color: Color(0xFF00A3FF)),
            SizedBox(width: 8),
            Text('Reseller Recharge Help', style: TextStyle(color: Colors.white, fontSize: 16)),
          ],
        ),
        content: const Text(
          '1. Chat with an authorized reseller 100% FREE.\n'
          '2. Get exclusive discounts (up to 29% cheaper).\n'
          '3. Pay via bKash/Nagad & send screenshot/TrxID.\n'
          '4. Reseller transfers gems directly to your User ID instantly!',
          style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Got It', style: TextStyle(color: Color(0xFF00A3FF), fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Drag handle
            Center(
              child: Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 14),
                decoration: BoxDecoration(
                  color: Colors.black12,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Top Header Container (Matching Screenshot 3 design)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [
                    Color(0xFFFFFBEB),
                    Color(0xFFFEF3C7),
                    Color(0xFFFFF7ED),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFFDE68A), width: 1),
              ),
              child: Row(
                children: [
                  // Icon
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF59E0B),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFF59E0B).withValues(alpha: 0.25),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.electric_bolt_rounded,
                      color: Colors.white,
                      size: 26,
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Header Texts
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Recharge via Reseller',
                          style: TextStyle(
                            color: Color(0xFF1E1B4B),
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Fast🔥 & flexible🔥 & cheaper option',
                          style: TextStyle(
                            color: Color(0xFF78350F),
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Floating Coins graphic decoration
                  const Text('🪙✨', style: TextStyle(fontSize: 20)),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Resellers List
            if (_isLoading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: Center(
                  child: CircularProgressIndicator(color: AppColors.neonPink),
                ),
              )
            else if (_resellers.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 30),
                child: Center(
                  child: Text(
                    'No resellers currently online. Please check back soon.',
                    style: TextStyle(color: Colors.black54, fontSize: 13),
                  ),
                ),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _resellers.length,
                separatorBuilder: (ctx, i) => const Divider(color: Color(0xFFF3F4F6), height: 16),
                itemBuilder: (ctx, index) {
                  final reseller = _resellers[index];
                  return _buildResellerCard(reseller);
                },
              ),

            const SizedBox(height: 18),

            // Need help? footer link
            Center(
              child: GestureDetector(
                onTap: _showHelpDialog,
                child: const Text(
                  'Need help?',
                  style: TextStyle(
                    color: Color(0xFF0088FF),
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    decoration: TextDecoration.underline,
                    decorationColor: Color(0xFF0088FF),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResellerCard(ResellerModel reseller) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Reseller Avatar with online indicator
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFFE5E7EB), width: 1.5),
                ),
                child: ClipOval(
                  child: CachedImageLoader(
                    imageUrl: reseller.avatarUrl,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              if (reseller.isOnline)
                Positioned(
                  bottom: 2,
                  right: 2,
                  child: Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: const Color(0xFF00E676),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 12),

          // Reseller Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  reseller.name,
                  style: const TextStyle(
                    color: Color(0xFF111827),
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  'ID: ${reseller.resellerId}',
                  style: const TextStyle(
                    color: Color(0xFF6B7280),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Text(
                      'Sales: ${reseller.formattedSales}',
                      style: const TextStyle(
                        color: Color(0xFF374151),
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  'Success Rate: ${reseller.successRate}',
                  style: const TextStyle(
                    color: Color(0xFF4B5563),
                    fontSize: 11.5,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(width: 8),

          // Chat Button (Blue Pill matching screenshot 3)
          GestureDetector(
            onTap: () => _openChat(reseller),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 9),
              decoration: BoxDecoration(
                color: const Color(0xFF00A3FF),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF00A3FF).withValues(alpha: 0.35),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: const Text(
                'Chat',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 13.5,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

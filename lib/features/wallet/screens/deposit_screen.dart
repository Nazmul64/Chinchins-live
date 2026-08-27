import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/theme/app_colors.dart';
import '../services/wallet_api_service.dart';

class DepositScreen extends StatefulWidget {
  final Map<String, dynamic> selectedPackage;
  final VoidCallback? onDepositSuccess;

  const DepositScreen({
    super.key,
    required this.selectedPackage,
    this.onDepositSuccess,
  });

  @override
  State<DepositScreen> createState() => _DepositScreenState();
}

class _DepositScreenState extends State<DepositScreen> {
  final _formKey = GlobalKey<FormState>();
  final ImagePicker _picker = ImagePicker();

  List<Map<String, dynamic>> _paymentMethods = [];
  Map<String, dynamic>? _selectedMethod;
  bool _isLoadingMethods = true;
  bool _isSubmitting = false;

  final TextEditingController _senderNumberController = TextEditingController();
  final TextEditingController _trxIdController = TextEditingController();
  final TextEditingController _userNoteController = TextEditingController();

  File? _screenshotFile;

  @override
  void initState() {
    super.initState();
    _fetchPaymentMethods();
  }

  @override
  void dispose() {
    _senderNumberController.dispose();
    _trxIdController.dispose();
    _userNoteController.dispose();
    super.dispose();
  }

  Future<void> _fetchPaymentMethods() async {
    setState(() => _isLoadingMethods = true);
    final methods = await WalletApiService.getPaymentMethods();
    if (mounted) {
      setState(() {
        _paymentMethods = methods;
        if (methods.isNotEmpty) {
          final targetId = widget.selectedPackage['payment_method_id'];
          final targetCode = widget.selectedPackage['payment_method_code'] ?? widget.selectedPackage['code'];
          final match = methods.firstWhere(
            (m) => (targetId != null && m['id'] == targetId) || (targetCode != null && m['code'] == targetCode),
            orElse: () => methods.first,
          );
          _selectedMethod = match;
        }
        _isLoadingMethods = false;
      });
    }
  }

  Future<void> _pickScreenshot() async {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surfaceDark,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(
                'Upload Payment Receipt / Screenshot',
                style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
            const Divider(color: AppColors.cardBorder, height: 1),
            ListTile(
              leading: const Icon(Icons.camera_alt_rounded, color: AppColors.neonPink),
              title: const Text('Take Photo from Camera', style: TextStyle(color: Colors.white)),
              onTap: () async {
                Navigator.pop(ctx);
                final picked = await _picker.pickImage(
                  source: ImageSource.camera,
                  maxWidth: 1600,
                  maxHeight: 1600,
                  imageQuality: 88,
                );
                if (picked != null) {
                  setState(() => _screenshotFile = File(picked.path));
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_rounded, color: AppColors.neonPurple),
              title: const Text('Choose from Gallery / Screenshots', style: TextStyle(color: Colors.white)),
              onTap: () async {
                Navigator.pop(ctx);
                final picked = await _picker.pickImage(
                  source: ImageSource.gallery,
                  maxWidth: 1600,
                  maxHeight: 1600,
                  imageQuality: 88,
                );
                if (picked != null) {
                  setState(() => _screenshotFile = File(picked.path));
                }
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
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

  double _parseDouble(dynamic val, [double def = 0.0]) {
    if (val == null) return def;
    if (val is double) return val;
    if (val is num) return val.toDouble();
    if (val is String) {
      return double.tryParse(val.replaceAll(RegExp(r'[^0-9.\-]'), '')) ?? def;
    }
    return def;
  }

  Future<void> _submitDeposit() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedMethod == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a payment method'), backgroundColor: Colors.redAccent),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    final pkg = widget.selectedPackage;
    final int? packageId = pkg['id'] != null
        ? _parseInt(pkg['id'])
        : (pkg['package_id'] != null ? _parseInt(pkg['package_id']) : null);
    final double amount = _parseDouble(pkg['price'] ?? pkg['price_bdt'] ?? pkg['rate_bdt'] ?? 150.0);
    
    final int baseCoins = _parseInt(pkg['coins'] ?? pkg['base_coins'] ?? pkg['rate_coins'] ?? 7000);
    final int bonusCoins = _parseInt(pkg['bonus_coins'] ?? pkg['bonus'] ?? 600);
    final int coins = _parseInt(pkg['total_coins'], baseCoins + bonusCoins);

    final int? paymentMethodId = _selectedMethod?['id'] != null ? _parseInt(_selectedMethod!['id']) : null;
    final String paymentMethodCode = _selectedMethod?['code']?.toString().toLowerCase() ??
        _selectedMethod?['name']?.toString().toLowerCase().split(' ').first ?? 'bkash';

    final result = await WalletApiService.submitDepositRequest(
      packageId: packageId,
      paymentMethodId: paymentMethodId,
      paymentMethod: paymentMethodCode,
      amount: amount,
      coins: coins > 0 ? coins : null,
      senderNumber: _senderNumberController.text.trim(),
      transactionId: _trxIdController.text.trim().toUpperCase(),
      screenshot: _screenshotFile,
      userNote: _userNoteController.text.trim().isNotEmpty
          ? _userNoteController.text.trim()
          : 'Recharge for $coins gems',
    );

    if (!mounted) return;
    setState(() => _isSubmitting = false);

    if (result['success'] == true) {
      widget.onDepositSuccess?.call();
      _showSuccessDialog(result['message'] ?? 'Deposit request submitted successfully!');
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['message'] ?? 'Failed to submit deposit'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  void _showSuccessDialog(String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceDark,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: AppColors.cardBorder),
        ),
        title: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: const BoxDecoration(
                color: Color(0x2200E676),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_circle_rounded, color: AppColors.onlineGreen, size: 48),
            ),
            const SizedBox(height: 12),
            const Text(
              'Deposit Request Submitted!',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 13, height: 1.4),
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.amber.withValues(alpha: 0.5)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.hourglass_top_rounded, color: Colors.amber, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'TrxID: ${_trxIdController.text.trim().toUpperCase()}\nStatus: Pending Admin Approval',
                      style: const TextStyle(color: Colors.amber, fontSize: 11.5, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.neonPink,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pop(context);
            },
            child: const Text('Done', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showDepositHistoryModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surfaceDark,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.9,
        minChildSize: 0.4,
        expand: false,
        builder: (ctx, scrollController) {
          return FutureBuilder<List<Map<String, dynamic>>>(
            future: WalletApiService.getDepositHistory(),
            builder: (ctx, snapshot) {
              return Column(
                children: [
                  Container(
                    margin: const EdgeInsets.only(top: 12, bottom: 8),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Text(
                      'Deposit History',
                      style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const Divider(color: AppColors.cardBorder, height: 1),
                  if (snapshot.connectionState == ConnectionState.waiting)
                    const Expanded(child: Center(child: CircularProgressIndicator(color: AppColors.neonPink)))
                  else if (!snapshot.hasData || snapshot.data!.isEmpty)
                    const Expanded(
                      child: Center(
                        child: Text('No deposit requests found yet.', style: TextStyle(color: AppColors.textMuted)),
                      ),
                    )
                  else
                    Expanded(
                      child: ListView.separated(
                        controller: scrollController,
                        padding: const EdgeInsets.all(14),
                        itemCount: snapshot.data!.length,
                        separatorBuilder: (context, index) => const SizedBox(height: 10),
                        itemBuilder: (ctx, idx) {
                          final item = snapshot.data![idx];
                          final status = (item['status'] ?? 'pending').toString().toLowerCase();
                          Color statusColor = Colors.amber;
                          if (status == 'approved') statusColor = AppColors.onlineGreen;
                          if (status == 'rejected') statusColor = Colors.redAccent;

                          return Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.cardDark,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppColors.cardBorder),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: statusColor.withValues(alpha: 0.15),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    status == 'approved'
                                        ? Icons.check_circle_rounded
                                        : status == 'rejected'
                                            ? Icons.cancel_rounded
                                            : Icons.hourglass_bottom_rounded,
                                    color: statusColor,
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '৳${item['amount']} (${item['payment_method_name'] ?? item['payment_method'] ?? 'bKash'})',
                                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        'TrxID: ${item['transaction_id'] ?? 'N/A'}',
                                        style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
                                      ),
                                      if (item['coins'] != null)
                                        Text(
                                          'Coins: +${item['coins']} Gems',
                                          style: const TextStyle(color: AppColors.gemYellow, fontSize: 11, fontWeight: FontWeight.w600),
                                        ),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: statusColor.withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: statusColor, width: 0.8),
                                  ),
                                  child: Text(
                                    status.toUpperCase(),
                                    style: TextStyle(color: statusColor, fontSize: 10, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pkg = widget.selectedPackage;
    final int gems = _parseInt(pkg['coins'] ?? pkg['gems'] ?? pkg['base_coins'], 32000);
    final int bonus = _parseInt(pkg['bonus_coins'] ?? pkg['bonus'], 8000);
    final int totalGems = _parseInt(pkg['total_coins'], gems + bonus);
    final String priceStr = pkg['formatted_price'] ?? (pkg['price_bdt'] != null ? '৳${pkg['price_bdt']}' : (pkg['price'] != null ? '৳${pkg['price']}' : '৳550'));
    final String badge = (pkg['badge'] ?? pkg['tag'] ?? pkg['offer_tag'] ?? '').toString();

    final accountNumber = _selectedMethod?['account_number'] ?? '01700000000';
    final accountType = _selectedMethod?['account_type'] ?? 'Personal';
    final instructions = _selectedMethod?['instructions'] ??
        '1. Open ${_selectedMethod?['name'] ?? 'Payment App'}\n2. Select "Send Money"\n3. Enter Number: $accountNumber\n4. Copy Transaction ID (TrxID) and enter below.';

    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      appBar: AppBar(
        backgroundColor: AppColors.surfaceDark,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Manual Deposit (bKash/Nagad)',
          style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.history_rounded, color: AppColors.neonPink),
            tooltip: 'Deposit History',
            onPressed: _showDepositHistoryModal,
          ),
        ],
      ),
      body: _isLoadingMethods
          ? const Center(child: CircularProgressIndicator(color: AppColors.neonPink))
          : SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 1. Selected Package Summary Header Card
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF381F4B), Color(0xFF231433)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.neonPink.withValues(alpha: 0.5)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (badge.isNotEmpty)
                                Container(
                                  margin: const EdgeInsets.only(bottom: 4),
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    gradient: AppColors.primaryGradient,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    badge,
                                    style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              Row(
                                children: [
                                  const Icon(Icons.diamond_rounded, color: AppColors.gemYellow, size: 20),
                                  const SizedBox(width: 6),
                                  Text(
                                    '$totalGems Gems',
                                    style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '$gems + $bonus Bonus',
                                style: const TextStyle(color: AppColors.onlineGreen, fontSize: 11, fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            decoration: BoxDecoration(
                              color: AppColors.neonPink,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              priceStr,
                              style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // 2. Payment Method Selector / Dropdown
                    const Text(
                      '1. Select Payment Method',
                      style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceDark,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.cardBorder),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<Map<String, dynamic>>(
                          value: _selectedMethod,
                          isExpanded: true,
                          dropdownColor: AppColors.surfaceDark,
                          icon: const Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.neonPink),
                          items: _paymentMethods.map((method) {
                            final isBkash = (method['code'] ?? '').toString().contains('bkash');
                            return DropdownMenuItem<Map<String, dynamic>>(
                              value: method,
                              child: Row(
                                children: [
                                  Icon(
                                    isBkash ? Icons.phone_android_rounded : Icons.flash_on_rounded,
                                    color: isBkash ? const Color(0xFFE2136E) : const Color(0xFFF7941D),
                                    size: 18,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    method['name'] ?? 'Payment Method',
                                    style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                                  ),
                                  const Spacer(),
                                  Text(
                                    '(${method['account_type'] ?? 'Personal'})',
                                    style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                          onChanged: (newVal) {
                            if (newVal != null) {
                              setState(() => _selectedMethod = newVal);
                            }
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // 3. Admin Payment Account Number Box with Copy Button
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.cardDark,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.cardBorder),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                '${_selectedMethod?['name'] ?? 'bKash'} ($accountType Number):',
                                style: const TextStyle(color: AppColors.textSecondary, fontSize: 12, fontWeight: FontWeight.w600),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.blue.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  accountType,
                                  style: const TextStyle(color: Colors.blueAccent, fontSize: 10, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  accountNumber,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 1.2,
                                  ),
                                ),
                              ),
                              ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.neonPurple,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                ),
                                icon: const Icon(Icons.copy_rounded, color: Colors.white, size: 14),
                                label: const Text('Copy', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                                onPressed: () {
                                  Clipboard.setData(ClipboardData(text: accountNumber));
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Number $accountNumber copied! 📋'),
                                      duration: const Duration(seconds: 1),
                                      backgroundColor: AppColors.neonPurple,
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                          const Divider(color: AppColors.cardBorder, height: 20),
                          Text(
                            instructions,
                            style: const TextStyle(color: AppColors.textMuted, fontSize: 11.5, height: 1.4),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // 4. Deposit Submission Form
                    const Text(
                      '2. Enter Payment Details',
                      style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 10),

                    // Sender Phone Number
                    TextFormField(
                      controller: _senderNumberController,
                      keyboardType: TextInputType.phone,
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                      decoration: _inputDecoration(
                        label: 'Your Sender Number (যে নাম্বার থেকে পাঠিয়েছেন)',
                        hint: '017XXXXXXXX',
                        icon: Icons.phone_android_rounded,
                      ),
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) {
                          return 'Please enter your sender phone number';
                        }
                        if (val.trim().length < 11) {
                          return 'Enter valid 11-digit phone number';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),

                    // Transaction ID (TrxID)
                    TextFormField(
                      controller: _trxIdController,
                      textCapitalization: TextCapitalization.characters,
                      style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 1),
                      decoration: _inputDecoration(
                        label: 'Transaction ID / TrxID (ট্রানজেকশন আইডি)',
                        hint: 'e.g. 9G28KLA9',
                        icon: Icons.tag_rounded,
                      ),
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) {
                          return 'Please enter the TrxID received from bKash/Nagad';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),

                    // Optional User Note
                    TextFormField(
                      controller: _userNoteController,
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                      decoration: _inputDecoration(
                        label: 'Remark / Note (Optional)',
                        hint: 'e.g. Sent via bKash personal',
                        icon: Icons.edit_note_rounded,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // 5. Upload Payment Screenshot
                    const Text(
                      '3. Payment Receipt Screenshot (Optional)',
                      style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Attach a screenshot of the successful transaction for instant approval.',
                      style: TextStyle(color: AppColors.textMuted, fontSize: 11),
                    ),
                    const SizedBox(height: 10),

                    GestureDetector(
                      onTap: _pickScreenshot,
                      child: Container(
                        height: 120,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: AppColors.cardDark,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: _screenshotFile != null ? AppColors.neonPink : AppColors.cardBorder,
                            width: 1.2,
                          ),
                        ),
                        child: _screenshotFile != null
                            ? Stack(
                                fit: StackFit.expand,
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(13),
                                    child: Image.file(_screenshotFile!, fit: BoxFit.cover),
                                  ),
                                  Container(
                                    decoration: const BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [Colors.black45, Colors.transparent, Colors.black87],
                                        begin: Alignment.topCenter,
                                        end: Alignment.bottomCenter,
                                      ),
                                    ),
                                  ),
                                  Positioned(
                                    top: 8,
                                    right: 8,
                                    child: GestureDetector(
                                      onTap: () => setState(() => _screenshotFile = null),
                                      child: Container(
                                        padding: const EdgeInsets.all(4),
                                        decoration: const BoxDecoration(
                                          color: Colors.black87,
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(Icons.close_rounded, color: Colors.redAccent, size: 16),
                                      ),
                                    ),
                                  ),
                                  const Positioned(
                                    bottom: 8,
                                    left: 8,
                                    child: Text(
                                      'Receipt Attached ✅',
                                      style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                ],
                              )
                            : Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: AppColors.neonPurple.withValues(alpha: 0.15),
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(Icons.add_photo_alternate_rounded, color: AppColors.neonPink, size: 22),
                                    ),
                                    const SizedBox(height: 6),
                                    const Text(
                                      'Tap to upload screenshot',
                                      style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                                    ),
                                    const SizedBox(height: 2),
                                    const Text('JPG, PNG, or WebP', style: TextStyle(color: AppColors.textMuted, fontSize: 10)),
                                  ],
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Submit Button
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          padding: EdgeInsets.zero,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        onPressed: _isSubmitting ? null : _submitDeposit,
                        child: Ink(
                          decoration: BoxDecoration(
                            gradient: AppColors.primaryGradient,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Container(
                            alignment: Alignment.center,
                            child: _isSubmitting
                                ? const Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
                                      SizedBox(width: 10),
                                      Text('Submitting Deposit...', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                                    ],
                                  )
                                : Text(
                                    'Submit Deposit Request ($priceStr)',
                                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                                  ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
    );
  }

  InputDecoration _inputDecoration({
    required String label,
    required String hint,
    required IconData icon,
  }) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
      hintText: hint,
      hintStyle: const TextStyle(color: AppColors.textHint, fontSize: 12),
      prefixIcon: Icon(icon, color: AppColors.neonPurple, size: 18),
      filled: true,
      fillColor: AppColors.surfaceDark,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.cardBorder),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.cardBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.neonPink, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.redAccent),
      ),
    );
  }
}

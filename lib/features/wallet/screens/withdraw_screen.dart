import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/theme/app_colors.dart';
import '../services/withdraw_api_service.dart';

class WithdrawScreen extends StatefulWidget {
  final VoidCallback? onWithdrawSuccess;

  const WithdrawScreen({
    super.key,
    this.onWithdrawSuccess,
  });

  @override
  State<WithdrawScreen> createState() => _WithdrawScreenState();
}

class _WithdrawScreenState extends State<WithdrawScreen> {
  final _formKey = GlobalKey<FormState>();

  bool _isLoading = true;
  bool _isSubmitting = false;

  List<Map<String, dynamic>> _paymentMethods = [];
  Map<String, dynamic>? _selectedMethod;

  final TextEditingController _coinsController = TextEditingController();
  final TextEditingController _accountNumberController = TextEditingController();
  final TextEditingController _userNoteController = TextEditingController();

  String _accountType = 'Personal';
  int _userCoins = 0;
  int _minCoins = 1000;
  int _maxCoins = 100000;
  double _commissionPercent = 5.0;
  double _ratePerBdt = 10.0; // 10 coins = 1 BDT
  String _rateText = '100 Coins = ৳10.00 BDT (1 BDT = 10 Coins)';
  String _noticeText = 'Withdrawals are processed manually via bKash, Nagad, and Rocket within 1-24 hours.';

  // Calculation breakdown
  double _grossBdt = 0.0;
  double _commissionBdt = 0.0;
  double _netBdt = 0.0;
  bool _isValidAmount = false;
  String? _calcError;

  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    _fetchWithdrawInfo();
    _coinsController.addListener(_onCoinsChanged);
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _coinsController.dispose();
    _accountNumberController.dispose();
    _userNoteController.dispose();
    super.dispose();
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

  Future<void> _fetchWithdrawInfo() async {
    setState(() => _isLoading = true);
    final data = await WithdrawApiService.getWithdrawInfo();

    if (mounted) {
      if (data != null) {
        final userData = data['user'] is Map ? data['user'] as Map<String, dynamic> : null;
        final methods = data['payment_methods'] is List ? List<Map<String, dynamic>>.from(data['payment_methods']) : <Map<String, dynamic>>[];

        setState(() {
          _minCoins = _parseInt(data['min_withdraw_coins'], 1000);
          _maxCoins = _parseInt(data['max_withdraw_coins'], 100000);
          _commissionPercent = _parseDouble(data['commission_percent'], 5.0);
          _ratePerBdt = _parseDouble(data['rate_per_bdt'], 10.0);
          if (_ratePerBdt <= 0) _ratePerBdt = 10.0;
          _rateText = data['rate_text']?.toString() ?? '100 Coins = ৳10.00 BDT';
          _noticeText = data['notice']?.toString() ?? 'Withdrawals are processed manually within 1-24 hours.';

          if (userData != null) {
            _userCoins = _parseInt(userData['coins'], 0);
            if (_accountNumberController.text.isEmpty && userData['phone'] != null) {
              _accountNumberController.text = userData['phone'].toString();
            }
          }

          _paymentMethods = methods;
          if (methods.isNotEmpty) {
            _selectedMethod = methods.first;
          }

          _isLoading = false;
        });

        // Initial default calculation if coins entered
        if (_coinsController.text.isNotEmpty) {
          _recalculate();
        } else if (_minCoins > 0 && _userCoins >= _minCoins) {
          _coinsController.text = _minCoins.toString();
        }
      } else {
        setState(() => _isLoading = false);
      }
    }
  }

  void _onCoinsChanged() {
    _recalculate();
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 400), () {
      final coins = _parseInt(_coinsController.text.trim(), 0);
      if (coins >= _minCoins) {
        _fetchLiveCalculation(coins);
      }
    });
  }

  void _recalculate() {
    final coins = _parseInt(_coinsController.text.trim(), 0);

    if (coins <= 0) {
      setState(() {
        _grossBdt = 0.0;
        _commissionBdt = 0.0;
        _netBdt = 0.0;
        _isValidAmount = false;
        _calcError = null;
      });
      return;
    }

    final gross = coins / _ratePerBdt;
    final commission = gross * (_commissionPercent / 100.0);
    final net = gross - commission;

    String? error;
    if (coins < _minCoins) {
      error = 'Minimum withdrawal is $_minCoins Coins (৳${(_minCoins / _ratePerBdt).toStringAsFixed(0)})';
    } else if (coins > _maxCoins) {
      error = 'Maximum withdrawal is $_maxCoins Coins (৳${(_maxCoins / _ratePerBdt).toStringAsFixed(0)})';
    } else if (coins > _userCoins) {
      error = 'Insufficient balance! You have $_userCoins Coins';
    }

    setState(() {
      _grossBdt = gross;
      _commissionBdt = commission;
      _netBdt = net > 0 ? net : 0.0;
      _calcError = error;
      _isValidAmount = error == null && coins > 0;
    });
  }

  Future<void> _fetchLiveCalculation(int coins) async {
    final res = await WithdrawApiService.calculateWithdrawal(coins: coins);
    if (mounted && res != null) {
      setState(() {
        _grossBdt = _parseDouble(res['gross_amount'], _grossBdt);
        _commissionBdt = _parseDouble(res['commission_amount'], _commissionBdt);
        _netBdt = _parseDouble(res['net_payable_amount'], _netBdt);
        if (res['is_valid'] == false && res['error_message'] != null) {
          _calcError = res['error_message'];
          _isValidAmount = false;
        }
      });
    }
  }

  void _selectQuickCoins(int amount) {
    if (amount > _userCoins) {
      _coinsController.text = _userCoins.toString();
    } else {
      _coinsController.text = amount.toString();
    }
    _coinsController.selection = TextSelection.fromPosition(
      TextPosition(offset: _coinsController.text.length),
    );
  }

  Future<void> _submitWithdrawal() async {
    if (!_formKey.currentState!.validate()) return;

    final coins = _parseInt(_coinsController.text.trim(), 0);
    if (coins <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid amount of coins to cash out'), backgroundColor: Colors.redAccent),
      );
      return;
    }

    if (coins > _userCoins) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Insufficient balance. You currently have $_userCoins Coins.'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    if (_selectedMethod == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a payment method'), backgroundColor: Colors.redAccent),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    final res = await WithdrawApiService.submitWithdrawal(
      coins: coins,
      paymentMethodId: _selectedMethod?['id'] != null ? _parseInt(_selectedMethod!['id']) : null,
      paymentMethod: _selectedMethod?['code'] ?? _selectedMethod?['name'] ?? 'bkash',
      accountNumber: _accountNumberController.text.trim(),
      accountType: _accountType,
      userNote: _userNoteController.text.trim(),
    );

    if (!mounted) return;
    setState(() => _isSubmitting = false);

    if (res['success'] == true) {
      widget.onWithdrawSuccess?.call();
      _showSuccessDialog(
        coins: coins,
        netBdt: _netBdt,
        methodName: _selectedMethod?['name'] ?? 'bKash',
        accountNumber: _accountNumberController.text.trim(),
        message: res['message'] ?? 'Withdrawal request submitted successfully!',
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res['message'] ?? 'Failed to submit withdrawal request'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  void _showSuccessDialog({
    required int coins,
    required double netBdt,
    required String methodName,
    required String accountNumber,
    required String message,
  }) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceDark,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
          side: const BorderSide(color: AppColors.cardBorder),
        ),
        title: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: const BoxDecoration(
                color: Color(0x2200E676),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_circle_rounded, color: AppColors.onlineGreen, size: 50),
            ),
            const SizedBox(height: 12),
            const Text(
              'Cash Out Submitted! 🎉',
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
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 12.5, height: 1.4),
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.amber.withValues(alpha: 0.4)),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Coins Requested:', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
                      Text('$coins Coins', style: const TextStyle(color: AppColors.gemYellow, fontWeight: FontWeight.bold, fontSize: 13)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('You Will Receive:', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
                      Text('৳${netBdt.toStringAsFixed(2)} BDT', style: const TextStyle(color: AppColors.onlineGreen, fontWeight: FontWeight.w900, fontSize: 14)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Payout Account:', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
                      Text('$methodName ($accountNumber)', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
                    ],
                  ),
                  const Divider(color: Colors.white12, height: 16),
                  const Row(
                    children: [
                      Icon(Icons.hourglass_top_rounded, color: Colors.amber, size: 16),
                      SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Status: Pending Admin Approval\nProcessing Time: 1 - 24 Hours',
                          style: TextStyle(color: Colors.amber, fontSize: 11, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
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
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
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

  void _showWithdrawHistorySheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surfaceDark,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.75,
        maxChildSize: 0.92,
        minChildSize: 0.4,
        expand: false,
        builder: (ctx, scrollController) {
          return FutureBuilder<List<Map<String, dynamic>>>(
            future: WithdrawApiService.getWithdrawHistory(),
            builder: (ctx, snapshot) {
              return Column(
                children: [
                  Container(
                    margin: const EdgeInsets.only(top: 12, bottom: 8),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.history_rounded, color: AppColors.neonPink, size: 20),
                            SizedBox(width: 8),
                            Text(
                              'Withdrawal History',
                              style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded, color: Colors.white60, size: 20),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                  ),
                  const Divider(color: AppColors.cardBorder, height: 1),
                  if (snapshot.connectionState == ConnectionState.waiting)
                    const Expanded(child: Center(child: CircularProgressIndicator(color: AppColors.neonPink)))
                  else if (!snapshot.hasData || snapshot.data!.isEmpty)
                    const Expanded(
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.receipt_long_rounded, color: AppColors.textMuted, size: 44),
                            SizedBox(height: 10),
                            Text('No withdrawal requests found yet.', style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
                          ],
                        ),
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
                          final coins = item['coins'] ?? 0;
                          final netBdt = item['net_payable_amount'] ?? item['gross_amount'] ?? '0';
                          final methodName = item['payment_method_name'] ?? item['payment_method'] ?? 'bKash';
                          final accountNumber = item['account_number'] ?? '';
                          final trxId = item['transaction_id'];
                          final adminNote = item['admin_note'];
                          final createdAt = item['created_at']?.toString() ?? '';

                          Color statusColor = Colors.amber;
                          String statusLabel = 'Pending';
                          IconData statusIcon = Icons.hourglass_bottom_rounded;

                          if (status == 'approved' || status == 'completed') {
                            statusColor = AppColors.onlineGreen;
                            statusLabel = 'Approved';
                            statusIcon = Icons.check_circle_rounded;
                          } else if (status == 'rejected' || status == 'failed') {
                            statusColor = Colors.redAccent;
                            statusLabel = 'Rejected';
                            statusIcon = Icons.cancel_rounded;
                          }

                          return Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: AppColors.cardDark,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: statusColor.withValues(alpha: 0.3)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(6),
                                          decoration: BoxDecoration(
                                            color: statusColor.withValues(alpha: 0.15),
                                            shape: BoxShape.circle,
                                          ),
                                          child: Icon(statusIcon, color: statusColor, size: 16),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          '$methodName ($accountNumber)',
                                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                                        ),
                                      ],
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: statusColor.withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(color: statusColor.withValues(alpha: 0.5), width: 0.8),
                                      ),
                                      child: Text(
                                        statusLabel,
                                        style: TextStyle(color: statusColor, fontSize: 10.5, fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text('Coins: $coins Gems', style: const TextStyle(color: AppColors.gemYellow, fontWeight: FontWeight.w600, fontSize: 12)),
                                    Text('Payout: ৳$netBdt BDT', style: const TextStyle(color: AppColors.onlineGreen, fontWeight: FontWeight.bold, fontSize: 13)),
                                  ],
                                ),
                                if (trxId != null && trxId.toString().isNotEmpty) ...[
                                  const SizedBox(height: 4),
                                  Text('TrxID: $trxId', style: const TextStyle(color: AppColors.textSecondary, fontSize: 11, fontFamily: 'monospace')),
                                ],
                                if (adminNote != null && adminNote.toString().isNotEmpty) ...[
                                  const SizedBox(height: 6),
                                  Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: BoxDecoration(color: Colors.black38, borderRadius: BorderRadius.circular(6)),
                                    child: Text('Note: $adminNote', style: const TextStyle(color: Colors.white70, fontSize: 11, fontStyle: FontStyle.italic)),
                                  ),
                                ],
                                if (createdAt.isNotEmpty) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    createdAt.length > 19 ? createdAt.substring(0, 19).replaceAll('T', ' ') : createdAt,
                                    style: const TextStyle(color: Colors.white38, fontSize: 10),
                                  ),
                                ],
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
          'Withdraw / Cash Out',
          style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.history_rounded, color: AppColors.neonPink),
            tooltip: 'Withdrawal History',
            onPressed: _showWithdrawHistorySheet,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.neonPink))
          : RefreshIndicator(
              color: AppColors.neonPink,
              backgroundColor: AppColors.surfaceDark,
              onRefresh: _fetchWithdrawInfo,
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 1. User Balance & Exchange Rate Card
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF38144D), Color(0xFF1E102E)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: AppColors.neonPurple.withValues(alpha: 0.4)),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.neonPurple.withValues(alpha: 0.15),
                              blurRadius: 16,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Expanded(
                                  child: Row(
                                    children: [
                                      Icon(Icons.account_balance_wallet_rounded, color: AppColors.gemYellow, size: 20),
                                      SizedBox(width: 8),
                                      Flexible(
                                        child: Text(
                                          'Available Coins Balance',
                                          style: TextStyle(color: AppColors.textSecondary, fontSize: 12.5, fontWeight: FontWeight.w600),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: AppColors.neonPink.withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: AppColors.neonPink.withValues(alpha: 0.4), width: 0.8),
                                  ),
                                  child: Text('Fee: ${_commissionPercent.toStringAsFixed(1)}%', style: const TextStyle(color: AppColors.neonPink, fontSize: 10.5, fontWeight: FontWeight.bold)),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                const Icon(Icons.diamond_rounded, color: AppColors.gemYellow, size: 28),
                                const SizedBox(width: 8),
                                Text(
                                  _userCoins.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},'),
                                  style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w900, letterSpacing: 0.5),
                                ),
                                const SizedBox(width: 6),
                                const Text('Gems', style: TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.bold)),
                              ],
                            ),
                            const Divider(color: Colors.white12, height: 20),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    _rateText,
                                    style: const TextStyle(color: Colors.cyanAccent, fontSize: 11.5, fontWeight: FontWeight.w600),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text('Min: $_minCoins Coins', style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // 2. Payment Method Selector
                      const Text(
                        '1. Select Cash Out Method',
                        style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),

                      if (_paymentMethods.isNotEmpty)
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
                                final isNagad = (method['code'] ?? '').toString().contains('nagad');
                                return DropdownMenuItem<Map<String, dynamic>>(
                                  value: method,
                                  child: Row(
                                    children: [
                                      Icon(
                                        isBkash ? Icons.phone_android_rounded : (isNagad ? Icons.flash_on_rounded : Icons.payments_rounded),
                                        color: isBkash ? const Color(0xFFE2136E) : (isNagad ? const Color(0xFFF7941D) : const Color(0xFF8E24AA)),
                                        size: 18,
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          method['name'] ?? 'bKash Personal',
                                          style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      const SizedBox(width: 6),
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

                      // 3. User Phone / Account Number Input
                      const Text(
                        '2. Enter Payout Mobile Account Number',
                        style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _accountNumberController,
                        keyboardType: TextInputType.phone,
                        style: const TextStyle(color: Colors.white, fontSize: 14),
                        decoration: _inputDecoration(
                          label: 'Your ${_selectedMethod?['name'] ?? 'bKash'} Account Number',
                          hint: '017XXXXXXXX',
                          icon: Icons.phone_android_rounded,
                        ),
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) {
                            return 'Please enter your mobile banking account number';
                          }
                          if (val.trim().length < 11) {
                            return 'Enter a valid 11-digit mobile number';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),

                      // Account Type Radio Chips (Personal / Agent)
                      Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          const Text('Account Type:', style: TextStyle(color: AppColors.textSecondary, fontSize: 12.5)),
                          _buildAccountTypeChip('Personal'),
                          _buildAccountTypeChip('Agent'),
                          _buildAccountTypeChip('Merchant'),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // 4. Coins Amount to Withdraw Input & Quick Chips
                      const Text(
                        '3. Enter Coins to Cash Out',
                        style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _coinsController,
                        keyboardType: TextInputType.number,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 0.8),
                        decoration: _inputDecoration(
                          label: 'Coins Amount (Gems)',
                          hint: 'e.g. 5000',
                          icon: Icons.diamond_rounded,
                        ),
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) {
                            return 'Please enter coins to withdraw';
                          }
                          final entered = int.tryParse(val.trim()) ?? 0;
                          if (entered < _minCoins) {
                            return 'Minimum withdrawal is $_minCoins Coins';
                          }
                          if (entered > _maxCoins) {
                            return 'Maximum withdrawal is $_maxCoins Coins';
                          }
                          if (entered > _userCoins) {
                            return 'Amount exceeds your available balance ($_userCoins Coins)';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 8),

                      // Quick Preset Chips
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _buildQuickCoinChip(1000),
                          _buildQuickCoinChip(5000),
                          _buildQuickCoinChip(10000),
                          _buildQuickCoinChip(20000),
                          _buildQuickCoinChip(50000),
                          _buildAllCoinsChip(),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // 5. Live Calculation & Payout Breakdown Card
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1B1B2C),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: _isValidAmount ? AppColors.onlineGreen.withValues(alpha: 0.5) : AppColors.cardBorder,
                            width: 1.2,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.calculate_rounded, color: AppColors.neonPink, size: 18),
                                SizedBox(width: 6),
                                Text('Estimated Payout Breakdown', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Gross BDT Value:', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                                Text('৳${_grossBdt.toStringAsFixed(2)}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 12.5)),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('Platform Commission (${_commissionPercent.toStringAsFixed(1)}%):', style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
                                Text('-৳${_commissionBdt.toStringAsFixed(2)}', style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w600, fontSize: 12.5)),
                              ],
                            ),
                            const Divider(color: Colors.white12, height: 16),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Net Payable Amount:', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                                Text(
                                  '৳${_netBdt.toStringAsFixed(2)} BDT',
                                  style: const TextStyle(color: AppColors.onlineGreen, fontSize: 16, fontWeight: FontWeight.w900),
                                ),
                              ],
                            ),
                            if (_calcError != null) ...[
                              const SizedBox(height: 8),
                              Text(
                                _calcError!,
                                style: const TextStyle(color: Colors.redAccent, fontSize: 11.5, fontWeight: FontWeight.w500),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Optional User Note
                      TextFormField(
                        controller: _userNoteController,
                        style: const TextStyle(color: Colors.white, fontSize: 13),
                        decoration: _inputDecoration(
                          label: 'Remark / Note for Admin (Optional)',
                          hint: 'e.g. Please process fast to my personal account',
                          icon: Icons.edit_note_rounded,
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Notice Text Box
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFF141926),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.blueAccent.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.info_outline_rounded, color: Colors.blueAccent, size: 16),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _noticeText,
                                style: const TextStyle(color: Colors.white70, fontSize: 11, height: 1.35),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 22),

                      // Submit Cash Out Button
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            padding: EdgeInsets.zero,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                          onPressed: (_isSubmitting || !_isValidAmount) ? null : _submitWithdrawal,
                          child: Ink(
                            decoration: BoxDecoration(
                              gradient: (_isValidAmount && !_isSubmitting)
                                  ? AppColors.primaryGradient
                                  : LinearGradient(colors: [Colors.grey.shade800, Colors.grey.shade700]),
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
                                        Text('Submitting Cash Out...', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                                      ],
                                    )
                                  : Text(
                                      'Request Cash Out (৳${_netBdt.toStringAsFixed(2)})',
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
            ),
    );
  }

  Widget _buildAccountTypeChip(String type) {
    final isSelected = _accountType == type;
    return GestureDetector(
      onTap: () => setState(() => _accountType = type),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.neonPurple.withValues(alpha: 0.3) : AppColors.cardDark,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: isSelected ? AppColors.neonPink : AppColors.cardBorder),
        ),
        child: Text(
          type,
          style: TextStyle(
            color: isSelected ? Colors.white : AppColors.textMuted,
            fontSize: 11.5,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildQuickCoinChip(int amount) {
    return GestureDetector(
      onTap: () => _selectQuickCoins(amount),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.surfaceDark,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.cardBorder),
        ),
        child: Text(
          '$amount',
          style: const TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  Widget _buildAllCoinsChip() {
    return GestureDetector(
      onTap: () => _selectQuickCoins(_userCoins),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.neonPurple.withValues(alpha: 0.25),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.neonPink.withValues(alpha: 0.6)),
        ),
        child: const Text(
          'Max / All',
          style: TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.bold),
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
      labelStyle: const TextStyle(color: AppColors.textSecondary, fontSize: 12.5),
      hintText: hint,
      hintStyle: const TextStyle(color: AppColors.textHint, fontSize: 11.5),
      prefixIcon: Icon(icon, color: AppColors.neonPink, size: 18),
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

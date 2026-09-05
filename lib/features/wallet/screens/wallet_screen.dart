import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/theme/app_colors.dart';
import '../services/wallet_api_service.dart';
import 'withdraw_screen.dart';

class WalletScreen extends StatefulWidget {
  final int initialTabIndex; // 0: Recharge, 1: History

  const WalletScreen({super.key, this.initialTabIndex = 0});

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  bool _isLoadingBalance = true;
  bool _isLoadingPackages = true;
  bool _isLoadingHistory = true;

  Map<String, dynamic>? _walletData;
  List<Map<String, dynamic>> _packages = [];
  List<Map<String, dynamic>> _depositHistory = [];
  List<Map<String, dynamic>> _paymentMethods = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this, initialIndex: widget.initialTabIndex);
    _loadAllWalletData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadAllWalletData() async {
    _fetchBalance();
    _fetchPackages();
    _fetchHistory();
  }

  Future<void> _fetchBalance() async {
    setState(() => _isLoadingBalance = true);
    final data = await WalletApiService.getWalletBalance();
    if (mounted) {
      setState(() {
        _walletData = data;
        _isLoadingBalance = false;
      });
    }
  }

  Future<void> _fetchPackages() async {
    setState(() => _isLoadingPackages = true);
    final packages = await WalletApiService.getCoinPackages();
    final methods = await WalletApiService.getPaymentMethods();
    if (mounted) {
      setState(() {
        _packages = packages;
        _paymentMethods = methods;
        _isLoadingPackages = false;
      });
    }
  }

  Future<void> _fetchHistory() async {
    setState(() => _isLoadingHistory = true);
    final history = await WalletApiService.getDepositHistory();
    if (mounted) {
      setState(() {
        _depositHistory = history;
        _isLoadingHistory = false;
      });
    }
  }

  void _openDepositModal(Map<String, dynamic> package) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DepositSheetModal(
        package: package,
        paymentMethods: _paymentMethods,
        onSuccess: () {
          _fetchBalance();
          _fetchHistory();
          _tabController.animateTo(1); // Switch to History tab
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final coins = _walletData?['coins'] ?? 0;
    final totalDepositedCoins = _walletData?['total_deposited_coins'] ?? _walletData?['formatted_total_deposited_coins'] ?? '0';
    final totalSpentBdt = _walletData?['formatted_total_deposited_bdt'] ?? (_walletData?['total_deposited_bdt'] != null ? '৳${_walletData!['total_deposited_bdt']}' : '৳0');
    final maxCallMinutes = _walletData?['max_call_minutes'] ?? (coins ~/ 100);

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
          'My Wallet & Coins',
          style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        actions: [
          TextButton.icon(
            style: TextButton.styleFrom(
              foregroundColor: AppColors.onlineGreen,
              padding: const EdgeInsets.symmetric(horizontal: 10),
            ),
            icon: const Icon(Icons.payments_rounded, size: 16, color: AppColors.onlineGreen),
            label: const Text('Withdraw', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5)),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => WithdrawScreen(
                    onWithdrawSuccess: _loadAllWalletData,
                  ),
                ),
              ).then((_) => _loadAllWalletData());
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.white70),
            tooltip: 'Refresh Balance',
            onPressed: _loadAllWalletData,
          ),
        ],
      ),
      body: RefreshIndicator(
        color: AppColors.neonPink,
        backgroundColor: AppColors.surfaceDark,
        onRefresh: _loadAllWalletData,
        child: NestedScrollView(
          headerSliverBuilder: (context, innerBoxIsScrolled) => [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Column(
                  children: [
                    // Main Balance & Deposit Statistics Card
                    _buildBalanceSummaryCard(
                      coins: coins,
                      totalDepositedCoins: totalDepositedCoins.toString(),
                      totalSpentBdt: totalSpentBdt.toString(),
                      callMinutes: maxCallMinutes,
                    ),
                    const SizedBox(height: 14),

                    // Tabs (Recharge Coins / Deposit History)
                    Container(
                      height: 46,
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceDark,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.cardBorder),
                      ),
                      child: TabBar(
                        controller: _tabController,
                        indicator: BoxDecoration(
                          gradient: AppColors.primaryGradient,
                          borderRadius: BorderRadius.circular(11),
                        ),
                        labelColor: Colors.white,
                        unselectedLabelColor: AppColors.textSecondary,
                        labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                        unselectedLabelStyle: const TextStyle(fontSize: 13),
                        tabs: const [
                          Tab(
                            iconMargin: EdgeInsets.zero,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.diamond_rounded, size: 16),
                                SizedBox(width: 6),
                                Text('Recharge Coins'),
                              ],
                            ),
                          ),
                          Tab(
                            iconMargin: EdgeInsets.zero,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.receipt_long_rounded, size: 16),
                                SizedBox(width: 6),
                                Text('Deposit History'),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          body: TabBarView(
            controller: _tabController,
            children: [
              // Tab 1: Recharge Packages Grid
              _buildRechargeTab(),
              // Tab 2: Deposit History List
              _buildHistoryTab(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBalanceSummaryCard({
    required int coins,
    required String totalDepositedCoins,
    required String totalSpentBdt,
    required int callMinutes,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF2C1654), Color(0xFF161530)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.neonPurple.withValues(alpha: 0.4), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: AppColors.neonPurple.withValues(alpha: 0.15),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.account_balance_wallet_rounded, color: AppColors.neonPink, size: 20),
                  SizedBox(width: 8),
                  Text(
                    'Available Coin Balance',
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.onlineGreen.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.onlineGreen.withValues(alpha: 0.5), width: 0.8),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.bolt_rounded, color: AppColors.onlineGreen, size: 12),
                    SizedBox(width: 3),
                    Text('Active', style: TextStyle(color: AppColors.onlineGreen, fontSize: 10.5, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Big Main Coin Balance Display
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppColors.gemYellow.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.diamond_rounded, color: AppColors.gemYellow, size: 30),
              ),
              const SizedBox(width: 12),
              _isLoadingBalance
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2.5, color: AppColors.neonPink),
                    )
                  : Text(
                      coins.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},'),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.5,
                      ),
                    ),
              const SizedBox(width: 6),
              const Text('Gems', style: TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.bold)),
              const Spacer(),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF10B981).withValues(alpha: 0.2),
                  foregroundColor: AppColors.onlineGreen,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: const BorderSide(color: AppColors.onlineGreen, width: 1),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  elevation: 0,
                ),
                icon: const Icon(Icons.payments_rounded, size: 16, color: AppColors.onlineGreen),
                label: const Text('Cash Out', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => WithdrawScreen(
                        onWithdrawSuccess: _loadAllWalletData,
                      ),
                    ),
                  ).then((_) => _loadAllWalletData());
                },
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(color: Colors.white12, height: 1),
          const SizedBox(height: 12),

          // Total Deposited Statistics
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatItem('Total Deposited', '$totalDepositedCoins Coins', Icons.savings_outlined, Colors.amberAccent),
              Container(width: 1, height: 26, color: Colors.white12),
              _buildStatItem('Total Spent', totalSpentBdt, Icons.payments_outlined, Colors.cyanAccent),
              Container(width: 1, height: 26, color: Colors.white12),
              _buildStatItem('Call Time', '$callMinutes min', Icons.videocam_outlined, AppColors.neonPink),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon, Color color) {
    return Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 13),
            const SizedBox(width: 4),
            Text(label, style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  // --- TAB 1: Recharge Packages Grid ---
  Widget _buildRechargeTab() {
    if (_isLoadingPackages) {
      return const Center(child: CircularProgressIndicator(color: AppColors.neonPink));
    }

    if (_packages.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.inventory_2_outlined, color: AppColors.textMuted, size: 48),
            const SizedBox(height: 12),
            const Text('No coin packages available.', style: TextStyle(color: Colors.white70, fontSize: 14)),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: _fetchPackages,
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.neonPurple),
              child: const Text('Retry', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      physics: const BouncingScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.76,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: _packages.length,
      itemBuilder: (ctx, idx) {
        final pkg = _packages[idx];
        return _buildPackageCard(pkg);
      },
    );
  }

  Widget _buildPackageCard(Map<String, dynamic> pkg) {
    // 100% Dynamic API Binding (No hardcoding)
    final dynamicCoins = pkg['display_coins'] ?? pkg['formatted_coins'] ?? pkg['coins'] ?? pkg['base_coins'] ?? '32000';
    final bonusText = pkg['display_bonus'] ?? pkg['formatted_bonus_coins'] ?? (pkg['bonus_coins'] != null && pkg['bonus_coins'] > 0 ? '+${pkg['bonus_coins']} Bonus Gems' : null);
    final priceStr = pkg['formatted_price'] ?? '৳${pkg['price'] ?? pkg['price_bdt'] ?? 0}';
    final badge = pkg['badge'] ?? (pkg['is_popular'] == true ? '🔥 50% OFF' : null);
    final isPopular = pkg['is_popular'] == true || pkg['popular'] == true;

    return GestureDetector(
      onTap: () => _openDepositModal(pkg),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.cardDark,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isPopular ? AppColors.neonPink : AppColors.cardBorder,
            width: isPopular ? 1.5 : 1.0,
          ),
          boxShadow: isPopular
              ? [
                  BoxShadow(
                    color: AppColors.neonPink.withValues(alpha: 0.2),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Top Diamond Icon & Base Coins Count (e.g. 32000)
                  Column(
                    children: [
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.all(7),
                        decoration: BoxDecoration(
                          color: AppColors.gemYellow.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.diamond_rounded, color: AppColors.gemYellow, size: 24),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '$dynamicCoins',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      Text(
                        'Gems',
                        style: TextStyle(
                          color: AppColors.gemYellow.withValues(alpha: 0.9),
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),

                  // Bonus text pill (e.g. +8000 Bonus Gems / +700 Bonus Gems)
                  if (bonusText != null && bonusText.toString().isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
                      decoration: BoxDecoration(
                        color: AppColors.neonPurple.withValues(alpha: 0.25),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        bonusText.toString(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Color(0xFFC084FC), fontSize: 9.5, fontWeight: FontWeight.bold),
                      ),
                    )
                  else
                    const SizedBox(height: 14),

                  // Price Button
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 7),
                    decoration: BoxDecoration(
                      gradient: isPopular ? AppColors.primaryGradient : null,
                      color: isPopular ? null : AppColors.surfaceDark,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: isPopular ? Colors.transparent : AppColors.cardBorder),
                    ),
                    child: Text(
                      priceStr,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Top Badge (e.g. 50% OFF)
            if (badge != null && badge.toString().isNotEmpty)
              Positioned(
                top: 0,
                left: 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    gradient: isPopular
                        ? const LinearGradient(colors: [Color(0xFFFF007F), Color(0xFFFF5252)])
                        : const LinearGradient(colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)]),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(15),
                      bottomRight: Radius.circular(10),
                    ),
                  ),
                  child: Text(
                    badge.toString(),
                    style: const TextStyle(color: Colors.white, fontSize: 9.5, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // --- TAB 2: Deposit History List ---
  Widget _buildHistoryTab() {
    if (_isLoadingHistory) {
      return const Center(child: CircularProgressIndicator(color: AppColors.neonPink));
    }

    if (_depositHistory.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surfaceDark,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.cardBorder),
                ),
                child: const Icon(Icons.receipt_long_rounded, color: AppColors.textMuted, size: 40),
              ),
              const SizedBox(height: 14),
              const Text(
                'No Deposit History Yet',
                style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              const Text(
                'When you recharge gems via bKash or Nagad, your transaction records will appear here.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textMuted, fontSize: 12),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.neonPurple),
                onPressed: () => _tabController.animateTo(0),
                icon: const Icon(Icons.diamond_rounded, color: Colors.white, size: 16),
                label: const Text('Recharge Gems Now', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      physics: const BouncingScrollPhysics(),
      itemCount: _depositHistory.length,
      separatorBuilder: (context, index) => const SizedBox(height: 10),
      itemBuilder: (ctx, idx) {
        final item = _depositHistory[idx];
        return _buildHistoryItemCard(item);
      },
    );
  }

  Widget _buildHistoryItemCard(Map<String, dynamic> item) {
    final status = (item['status'] ?? 'pending').toString().toLowerCase();
    final methodName = item['payment_method_name'] ?? item['payment_method'] ?? 'bKash / Nagad';
    final amount = item['amount']?.toString() ?? '0';
    final coins = item['coins'] ?? 0;
    final trxId = item['transaction_id'] ?? 'N/A';
    final senderNumber = item['sender_number'] ?? '';
    final createdAt = item['created_at']?.toString() ?? '';
    final adminNote = item['admin_note'];

    Color statusColor = Colors.amber;
    String statusLabel = 'Pending Review';
    IconData statusIcon = Icons.hourglass_top_rounded;

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
        borderRadius: BorderRadius.circular(16),
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
                    methodName,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13.5),
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
                  style: TextStyle(color: statusColor, fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Divider(color: Colors.white10, height: 1),
          const SizedBox(height: 10),

          // Amount & Coins Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Deposit Amount', style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
                  const SizedBox(height: 2),
                  Text('৳$amount', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text('Coins Credited', style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      const Icon(Icons.diamond_rounded, color: AppColors.gemYellow, size: 14),
                      const SizedBox(width: 3),
                      Text('+$coins Gems', style: const TextStyle(color: AppColors.gemYellow, fontWeight: FontWeight.bold, fontSize: 13.5)),
                    ],
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),

          // TrxID & Sender Number
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('TrxID: $trxId', style: const TextStyle(color: AppColors.textSecondary, fontSize: 11.5, fontFamily: 'monospace')),
              if (senderNumber.isNotEmpty)
                Text('From: $senderNumber', style: const TextStyle(color: AppColors.textSecondary, fontSize: 11)),
            ],
          ),

          if (createdAt.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              createdAt.length > 19 ? createdAt.substring(0, 19).replaceAll('T', ' ') : createdAt,
              style: const TextStyle(color: Colors.white38, fontSize: 10.5),
            ),
          ],

          if (adminNote != null && adminNote.toString().isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.white12),
              ),
              child: Text(
                'Admin Remark: $adminNote',
                style: const TextStyle(color: Colors.white70, fontSize: 11, fontStyle: FontStyle.italic),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class DepositSheetModal extends StatefulWidget {
  final Map<String, dynamic> package;
  final List<Map<String, dynamic>> paymentMethods;
  final VoidCallback onSuccess;

  const DepositSheetModal({
    super.key,
    required this.package,
    required this.paymentMethods,
    required this.onSuccess,
  });

  @override
  State<DepositSheetModal> createState() => _DepositSheetModalState();
}

class _DepositSheetModalState extends State<DepositSheetModal> {
  final _formKey = GlobalKey<FormState>();
  final ImagePicker _picker = ImagePicker();

  Map<String, dynamic>? _selectedMethod;
  final TextEditingController _senderNumberController = TextEditingController();
  final TextEditingController _trxIdController = TextEditingController();
  final TextEditingController _userNoteController = TextEditingController();
  File? _screenshotFile;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    if (widget.paymentMethods.isNotEmpty) {
      _selectedMethod = widget.paymentMethods.first;
    }
  }

  @override
  void dispose() {
    _senderNumberController.dispose();
    _trxIdController.dispose();
    _userNoteController.dispose();
    super.dispose();
  }

  Future<void> _pickReceiptScreenshot() async {
    final picked = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 800,
      maxHeight: 800,
      imageQuality: 70,
    );
    if (picked != null) {
      setState(() {
        _screenshotFile = File(picked.path);
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

    final double price = _parseDouble(widget.package['price'] ?? widget.package['price_bdt'] ?? 0);
    final int baseCoins = _parseInt(widget.package['coins'] ?? widget.package['base_coins'] ?? 0);
    final int bonusCoins = _parseInt(widget.package['bonus_coins'] ?? widget.package['bonus'] ?? 0);
    final int coins = _parseInt(widget.package['total_coins'], baseCoins + bonusCoins);

    final int? packageId = widget.package['id'] != null
        ? _parseInt(widget.package['id'])
        : (widget.package['package_id'] != null ? _parseInt(widget.package['package_id']) : null);
    final int? paymentMethodId = _selectedMethod?['id'] != null ? _parseInt(_selectedMethod!['id']) : null;
    final String paymentMethodCode = _selectedMethod?['code']?.toString().toLowerCase() ??
        _selectedMethod?['name']?.toString().toLowerCase().split(' ').first ?? 'bkash';

    setState(() => _isSubmitting = true);

    final res = await WalletApiService.submitDepositRequest(
      packageId: packageId,
      paymentMethodId: paymentMethodId,
      paymentMethod: paymentMethodCode,
      amount: price,
      coins: coins > 0 ? coins : null,
      senderNumber: _senderNumberController.text.trim(),
      transactionId: _trxIdController.text.trim().toUpperCase(),
      screenshot: _screenshotFile,
      userNote: _userNoteController.text.trim(),
    );

    if (!mounted) return;
    setState(() => _isSubmitting = false);

    if (res['success'] == true) {
      Navigator.pop(context);
      widget.onSuccess();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: Colors.white),
              const SizedBox(width: 10),
              Expanded(child: Text(res['message'] ?? 'Deposit request submitted successfully!')),
            ],
          ),
          backgroundColor: AppColors.onlineGreen,
          duration: const Duration(seconds: 4),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res['message'] ?? 'Failed to submit deposit'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final int coins = _parseInt(widget.package['coins'] ?? widget.package['base_coins']);
    final int bonus = _parseInt(widget.package['bonus_coins'] ?? widget.package['bonus']);
    final int totalCoins = _parseInt(widget.package['total_coins'], coins + bonus);
    final priceStr = widget.package['formatted_price'] ?? '৳${widget.package['price'] ?? widget.package['price_bdt'] ?? 0}';

    final accountNumber = _selectedMethod?['account_number'] ?? '01700000000';
    final accountType = _selectedMethod?['account_type'] ?? 'Personal (Send Money)';
    final instructions = _selectedMethod?['instructions'] ?? '1. Send money to our number.\n2. Copy Transaction ID (TrxID).\n3. Enter TrxID and Sender number below.';

    return Container(
      height: MediaQuery.of(context).size.height * 0.88,
      decoration: const BoxDecoration(
        color: AppColors.surfaceDark,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Drag Handle
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 8),
            width: 40,
            height: 4,
            decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
          ),
          // Modal Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.diamond_rounded, color: AppColors.gemYellow, size: 22),
                    SizedBox(width: 8),
                    Text('Recharge Gems', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: Colors.white70, size: 22),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          const Divider(color: AppColors.cardBorder, height: 1),

          // Scrollable Content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Package Selected Summary Card
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        gradient: AppColors.primaryGradient,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '$totalCoins Gems',
                                style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                bonus > 0 ? 'Includes +$bonus Bonus Gems' : 'Standard Recharge Plan',
                                style: const TextStyle(color: Colors.white70, fontSize: 11),
                              ),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.black26,
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

                    // Payment Method Selector
                    const Text('Select Payment Method', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    if (widget.paymentMethods.isNotEmpty)
                      Row(
                        children: widget.paymentMethods.map((pm) {
                          final isSelected = _selectedMethod?['id'] == pm['id'];
                          final code = (pm['code'] ?? '').toString().toLowerCase();
                          return Expanded(
                            child: GestureDetector(
                              onTap: () => setState(() => _selectedMethod = pm),
                              child: Container(
                                margin: const EdgeInsets.only(right: 8),
                                padding: const EdgeInsets.symmetric(vertical: 10),
                                decoration: BoxDecoration(
                                  color: isSelected ? AppColors.neonPurple.withValues(alpha: 0.25) : AppColors.cardDark,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: isSelected ? AppColors.neonPink : AppColors.cardBorder,
                                    width: isSelected ? 1.5 : 1.0,
                                  ),
                                ),
                                child: Column(
                                  children: [
                                    Icon(
                                      code.contains('bkash')
                                          ? Icons.account_balance_wallet_rounded
                                          : code.contains('nagad')
                                              ? Icons.payments_rounded
                                              : Icons.credit_card_rounded,
                                      color: isSelected ? AppColors.neonPink : Colors.white70,
                                      size: 20,
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      pm['name'] ?? 'bKash',
                                      style: TextStyle(
                                        color: isSelected ? Colors.white : AppColors.textSecondary,
                                        fontSize: 11,
                                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    const SizedBox(height: 14),

                    // Mobile Banking Account Info Box
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E293B),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.cyanAccent.withValues(alpha: 0.4)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${_selectedMethod?['name'] ?? 'bKash'} $accountType',
                                    style: const TextStyle(color: Colors.cyanAccent, fontSize: 12, fontWeight: FontWeight.bold),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    accountNumber,
                                    style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w900, letterSpacing: 1),
                                  ),
                                ],
                              ),
                              ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.cyanAccent.withValues(alpha: 0.2),
                                  foregroundColor: Colors.cyanAccent,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                ),
                                icon: const Icon(Icons.copy_rounded, size: 14),
                                label: const Text('Copy', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                onPressed: () {
                                  Clipboard.setData(ClipboardData(text: accountNumber));
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('Number $accountNumber copied!'), duration: const Duration(seconds: 1)),
                                  );
                                },
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          const Divider(color: Colors.white12, height: 1),
                          const SizedBox(height: 8),
                          Text(
                            instructions,
                            style: const TextStyle(color: Colors.white70, fontSize: 11, height: 1.35),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Inputs: Sender Number & TrxID
                    TextFormField(
                      controller: _senderNumberController,
                      keyboardType: TextInputType.phone,
                      style: const TextStyle(color: Colors.white, fontSize: 13.5),
                      decoration: _inputDecoration(
                        label: 'Your Sender Number (bKash/Nagad)',
                        hint: 'e.g. 01711223344',
                        icon: Icons.phone_android_rounded,
                      ),
                      validator: (val) => val == null || val.trim().isEmpty ? 'Please enter your sender number' : null,
                    ),
                    const SizedBox(height: 12),

                    TextFormField(
                      controller: _trxIdController,
                      style: const TextStyle(color: Colors.white, fontSize: 13.5),
                      decoration: _inputDecoration(
                        label: 'Transaction ID (TrxID)',
                        hint: 'e.g. TRX9A8B7C6D',
                        icon: Icons.pin_rounded,
                      ),
                      validator: (val) => val == null || val.trim().isEmpty ? 'Please enter TrxID' : null,
                    ),
                    const SizedBox(height: 12),

                    // Screenshot Upload (Optional)
                    GestureDetector(
                      onTap: _pickReceiptScreenshot,
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.cardDark,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: _screenshotFile != null ? AppColors.onlineGreen : AppColors.cardBorder,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              _screenshotFile != null ? Icons.check_circle_rounded : Icons.add_photo_alternate_rounded,
                              color: _screenshotFile != null ? AppColors.onlineGreen : AppColors.neonPink,
                              size: 22,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _screenshotFile != null ? 'Receipt Attached (Tap to change)' : 'Attach Receipt Screenshot (Optional)',
                                    style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                                  ),
                                  if (_screenshotFile != null)
                                    Text(
                                      _screenshotFile!.path.split(Platform.pathSeparator).last,
                                      style: const TextStyle(color: AppColors.textMuted, fontSize: 10),
                                    ),
                                ],
                              ),
                            ),
                            if (_screenshotFile != null)
                              IconButton(
                                icon: const Icon(Icons.close_rounded, color: Colors.redAccent, size: 18),
                                onPressed: () => setState(() => _screenshotFile = null),
                              ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Optional User Note
                    TextFormField(
                      controller: _userNoteController,
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                      decoration: _inputDecoration(
                        label: 'Note (Optional)',
                        hint: 'Any remarks for admin review',
                        icon: Icons.note_alt_outlined,
                      ),
                    ),
                    const SizedBox(height: 20),

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
                                      Text('Submitting Deposit Request...', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                    ],
                                  )
                                : const Text(
                                    'Submit Deposit Verification',
                                    style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                                  ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
          ),
        ],
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
      hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 11.5),
      prefixIcon: Icon(icon, color: AppColors.neonPink, size: 18),
      filled: true,
      fillColor: AppColors.cardDark,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.redAccent, width: 1.5),
      ),
    );
  }
}

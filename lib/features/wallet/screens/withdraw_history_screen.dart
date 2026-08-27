import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../services/withdraw_api_service.dart';

class WithdrawHistoryScreen extends StatefulWidget {
  const WithdrawHistoryScreen({super.key});

  @override
  State<WithdrawHistoryScreen> createState() => _WithdrawHistoryScreenState();
}

class _WithdrawHistoryScreenState extends State<WithdrawHistoryScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _historyList = [];

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    setState(() => _isLoading = true);
    final list = await WithdrawApiService.getWithdrawHistory();
    if (mounted) {
      setState(() {
        _historyList = list;
        _isLoading = false;
      });
    }
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
          'Withdrawal History',
          style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: AppColors.neonPink),
            tooltip: 'Refresh',
            onPressed: _loadHistory,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.neonPink))
          : RefreshIndicator(
              color: AppColors.neonPink,
              backgroundColor: AppColors.surfaceDark,
              onRefresh: _loadHistory,
              child: _historyList.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(18),
                              decoration: BoxDecoration(
                                color: AppColors.surfaceDark,
                                shape: BoxShape.circle,
                                border: Border.all(color: AppColors.cardBorder),
                              ),
                              child: const Icon(Icons.receipt_long_rounded, color: AppColors.textMuted, size: 48),
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'No Cash Out History',
                              style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 6),
                            const Text(
                              'When you request coin withdrawals to bKash or Nagad, your records will show here with their live verification status.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: AppColors.textMuted, fontSize: 12.5),
                            ),
                          ],
                        ),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      physics: const BouncingScrollPhysics(),
                      itemCount: _historyList.length,
                      separatorBuilder: (context, index) => const SizedBox(height: 12),
                      itemBuilder: (ctx, idx) {
                        final item = _historyList[idx];
                        final status = (item['status'] ?? 'pending').toString().toLowerCase();
                        final coins = item['coins'] ?? 0;
                        final netBdt = item['net_payable_amount'] ?? item['gross_amount'] ?? '0';
                        final methodName = item['payment_method_name'] ?? item['payment_method'] ?? 'bKash';
                        final accountNumber = item['account_number'] ?? '';
                        final trxId = item['transaction_id'];
                        final adminNote = item['admin_note'];
                        final createdAt = item['created_at']?.toString() ?? '';

                        Color statusColor = Colors.amber;
                        String statusLabel = 'Pending Review';
                        IconData statusIcon = Icons.hourglass_bottom_rounded;

                        if (status == 'approved' || status == 'completed') {
                          statusColor = AppColors.onlineGreen;
                          statusLabel = 'Approved & Paid';
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
                            border: Border.all(color: statusColor.withValues(alpha: 0.35)),
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
                                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13.5),
                                      ),
                                    ],
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                                    decoration: BoxDecoration(
                                      color: statusColor.withValues(alpha: 0.18),
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
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text('Coins Withdrawn', style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
                                      const SizedBox(height: 2),
                                      Row(
                                        children: [
                                          const Icon(Icons.diamond_rounded, color: AppColors.gemYellow, size: 14),
                                          const SizedBox(width: 3),
                                          Text('$coins Gems', style: const TextStyle(color: AppColors.gemYellow, fontWeight: FontWeight.bold, fontSize: 13.5)),
                                        ],
                                      ),
                                    ],
                                  ),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      const Text('Net Payout (BDT)', style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
                                      const SizedBox(height: 2),
                                      Text('৳$netBdt', style: const TextStyle(color: AppColors.onlineGreen, fontWeight: FontWeight.w900, fontSize: 14)),
                                    ],
                                  ),
                                ],
                              ),
                              if (trxId != null && trxId.toString().isNotEmpty) ...[
                                const SizedBox(height: 6),
                                Text('TrxID: $trxId', style: const TextStyle(color: AppColors.textSecondary, fontSize: 11.5, fontFamily: 'monospace')),
                              ],
                              if (adminNote != null && adminNote.toString().isNotEmpty) ...[
                                const SizedBox(height: 6),
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(color: Colors.black45, borderRadius: BorderRadius.circular(8)),
                                  child: Text('Admin Note: $adminNote', style: const TextStyle(color: Colors.white70, fontSize: 11, fontStyle: FontStyle.italic)),
                                ),
                              ],
                              if (createdAt.isNotEmpty) ...[
                                const SizedBox(height: 6),
                                Text(
                                  createdAt.length > 19 ? createdAt.substring(0, 19).replaceAll('T', ' ') : createdAt,
                                  style: const TextStyle(color: Colors.white38, fontSize: 10.5),
                                ),
                              ],
                            ],
                          ),
                        );
                      },
                    ),
            ),
    );
  }
}

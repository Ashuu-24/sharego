import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';

import '../../core/app_theme.dart';
import '../../core/providers.dart';
import '../common/widgets.dart';

class WalletScreen extends ConsumerStatefulWidget {
  const WalletScreen({super.key});

  @override
  ConsumerState<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends ConsumerState<WalletScreen> {
  Map<String, dynamic>? _wallet;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadWallet();
  }

  Future<void> _loadWallet() async {
    setState(() { _loading = true; _error = null; });
    try {
      final result = await ref.read(walletServiceProvider).getWallet(limit: 50);
      if (mounted) setState(() { _wallet = result; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = formatErrorMessage(e); _loading = false; });
    }
  }

  bool _topUpLoading = false;

  void _showTopUpDialog() {
    final amountCtrl = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            return Padding(
              padding: EdgeInsets.fromLTRB(
                20, 20, 20, MediaQuery.of(ctx).viewInsets.bottom + 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Top Up Wallet',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: amountCtrl,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'Amount (PKR)',
                      prefixText: 'Rs. ',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    children: [1000, 5000, 10000, 50000].map((v) {
                      return ActionChip(
                        label: Text('Rs. ${NumberFormat('#,##0', 'en_US').format(v)}'),
                        onPressed: () => amountCtrl.text = v.toString(),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: _topUpLoading
                          ? null
                          : () async {
                              final amount = double.tryParse(amountCtrl.text.trim());
                              if (amount == null || amount <= 0) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Enter a valid amount')),
                                );
                                return;
                              }
                              setSheetState(() => _topUpLoading = true);
                              setState(() => _topUpLoading = true);
                              try {
                                await ref.read(walletServiceProvider).topUp(amount);
                                if (mounted) {
                                  Navigator.pop(ctx);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Rs. ${NumberFormat('#,##0', 'en_US').format(amount)} added to wallet'),
                                      backgroundColor: AppTheme.success,
                                    ),
                                  );
                                  _loadWallet();
                                }
                              } catch (e) {
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Top-up failed: ${formatErrorMessage(e)}'),
                                      backgroundColor: AppTheme.danger,
                                    ),
                                  );
                                }
                              } finally {
                                if (mounted) {
                                  setSheetState(() => _topUpLoading = false);
                                  setState(() => _topUpLoading = false);
                                }
                              }
                            },
                      style: ElevatedButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: _topUpLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Text('Top Up', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  String _reasonLabel(String reason) {
    switch (reason) {
      case 'demo_credit':
        return 'Welcome Bonus';
      case 'escrow_hold':
        return 'Payment Held';
      case 'escrow_release':
        return 'Earned from Delivery';
      case 'escrow_refund':
        return 'Refund';
      case 'admin_topup':
        return 'Admin Top-Up';
      case 'self_topup':
        return 'Wallet Top-Up';
      case 'bank_withdrawal':
        return 'Withdrawn to Bank';
      default:
        return reason;
    }
  }

  IconData _reasonIcon(String reason) {
    switch (reason) {
      case 'demo_credit':
        return Icons.card_giftcard;
      case 'escrow_hold':
        return Icons.lock;
      case 'escrow_release':
        return Icons.check_circle;
      case 'escrow_refund':
        return Icons.replay;
      case 'admin_topup':
        return Icons.admin_panel_settings;
      case 'self_topup':
        return Icons.add_circle;
      case 'bank_withdrawal':
        return Icons.account_balance;
      default:
        return Icons.swap_horiz;
    }
  }

  Color _deltaColor(double delta) {
    return delta >= 0 ? AppTheme.success : AppTheme.danger;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final balance = (_wallet?['balance'] as num?)?.toDouble() ?? 0;
    final currency = _wallet?['currency']?.toString() ?? 'PKR';
    final transactions = (_wallet?['transactions'] as List?) ?? [];
    final formatter = NumberFormat('#,##0', 'en_US');

    return Scaffold(
      appBar: AppBar(title: const Text('My Wallet')),
      body: _loading
          ? const Padding(
              padding: EdgeInsets.all(16),
              child: SkeletonList(items: 5, itemHeight: 60),
            )
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ErrorBanner(_error!),
                      const SizedBox(height: 12),
                      ElevatedButton(onPressed: _loadWallet, child: const Text('Retry')),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadWallet,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      // Balance card
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [AppTheme.primary, AppTheme.primaryDark],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.primary.withValues(alpha: 0.3),
                              blurRadius: 16,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Available Balance',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: Colors.white70,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '$currency ${formatter.format(balance)}',
                              style: theme.textTheme.headlineMedium?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.shield, color: Colors.white, size: 14),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Escrow Protected',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Top Up button
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: OutlinedButton.icon(
                          onPressed: _showTopUpDialog,
                          icon: const Icon(Icons.add_circle_outline),
                          label: const Text('Top Up Wallet', style: TextStyle(fontWeight: FontWeight.w600)),
                          style: OutlinedButton.styleFrom(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            side: BorderSide(color: AppTheme.primary),
                          ),
                        ),
                      ),

                      const SizedBox(height: 12),

                      // Withdraw to Bank button
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: OutlinedButton.icon(
                          onPressed: () => context.push('/wallet/bank-accounts'),
                          icon: const Icon(Icons.account_balance_outlined),
                          label: const Text('Withdraw to Bank', style: TextStyle(fontWeight: FontWeight.w600)),
                          style: OutlinedButton.styleFrom(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            side: BorderSide(color: AppTheme.primary),
                          ),
                        ),
                      ),

                      const SizedBox(height: 24),

                      // Transaction header
                      Text(
                        'Transactions',
                        style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 12),

                      // Transactions list
                      if (transactions.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 40),
                          child: Center(
                            child: Text('No transactions yet', style: TextStyle(color: Colors.black45)),
                          ),
                        )
                      else
                        ...transactions.map<Widget>((tx) {
                          final delta = (tx['delta'] as num?)?.toDouble() ?? 0;
                          final reason = tx['reason']?.toString() ?? '';
                          final refId = tx['ref_id']?.toString() ?? '';
                          final createdAt = tx['created_at']?.toString() ?? '';
                          String timeAgo = '';
                          try {
                            final dt = DateTime.parse(createdAt);
                            final diff = DateTime.now().difference(dt);
                            if (diff.inDays > 0) {
                              timeAgo = '${diff.inDays}d ago';
                            } else if (diff.inHours > 0) {
                              timeAgo = '${diff.inHours}h ago';
                            } else {
                              timeAgo = '${diff.inMinutes}m ago';
                            }
                          } catch (_) {}

                          return Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.grey.shade200),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: _deltaColor(delta).withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Icon(_reasonIcon(reason), color: _deltaColor(delta), size: 20),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        _reasonLabel(reason),
                                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        refId.isNotEmpty ? refId : timeAgo,
                                        style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                                      ),
                                    ],
                                  ),
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      '${delta >= 0 ? '+' : ''}$currency ${formatter.format(delta.abs())}',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 14,
                                        color: _deltaColor(delta),
                                      ),
                                    ),
                                    if (timeAgo.isNotEmpty && refId.isNotEmpty)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 2),
                                        child: Text(
                                          timeAgo,
                                          style: TextStyle(fontSize: 11, color: Colors.grey.shade400),
                                        ),
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        }),
                    ],
                  ),
                ),
    );
  }
}
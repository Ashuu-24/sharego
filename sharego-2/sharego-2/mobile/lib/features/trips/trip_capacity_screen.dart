import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/app_theme.dart';
import '../../core/providers.dart';
import 'trip_draft.dart';

class TripCapacityScreen extends ConsumerStatefulWidget {
  const TripCapacityScreen({super.key});

  @override
  ConsumerState<TripCapacityScreen> createState() => _TripCapacityScreenState();
}

class _TripCapacityScreenState extends ConsumerState<TripCapacityScreen> {
  late final TextEditingController _capacityCtrl;
  late final TextEditingController _feeCtrl;
  late final TextEditingController _budgetCtrl;
  late final TextEditingController _nameCtrl;
  late final TextEditingController _emailCtrl;
  late final TextEditingController _phoneCtrl;
  late final TextEditingController _cnicCtrl;
  late final TextEditingController _expMonthCtrl;
  late final TextEditingController _expYearCtrl;

  @override
  void initState() {
    super.initState();
    final draft = ref.read(tripDraftProvider);
    _capacityCtrl = TextEditingController(text: draft.capacityKg);
    _feeCtrl = TextEditingController(text: draft.feePerKg);
    _budgetCtrl = TextEditingController(text: draft.expectedEarning);
    _nameCtrl = TextEditingController(text: draft.travelerName);
    _emailCtrl = TextEditingController(text: draft.travelerEmail);
    _phoneCtrl = TextEditingController(text: draft.travelerPhone);
    _cnicCtrl = TextEditingController(text: draft.travelerCnic);
    _expMonthCtrl = TextEditingController(text: draft.expMonth);
    _expYearCtrl = TextEditingController(text: draft.expYear);

    // Auto-fill traveler info from profile if fields are empty
    if (draft.travelerName.isEmpty) {
      _autoFillFromProfile();
    }
  }

  Future<void> _autoFillFromProfile() async {
    try {
      final profile = await ref.read(profileServiceProvider).getMe();
      if (!mounted) return;
      final name = profile['name']?.toString() ?? '';
      final email = profile['email']?.toString() ?? '';
      final phone = profile['phone']?.toString() ?? '';
      setState(() {
        if (_nameCtrl.text.isEmpty && name.isNotEmpty) _nameCtrl.text = name;
        if (_emailCtrl.text.isEmpty && email.isNotEmpty) _emailCtrl.text = email;
        if (_phoneCtrl.text.isEmpty && phone.isNotEmpty) _phoneCtrl.text = phone;
      });
    } catch (_) {
      // Silently fail — user can fill manually
    }
  }

  @override
  void dispose() {
    _capacityCtrl.dispose();
    _feeCtrl.dispose();
    _budgetCtrl.dispose();
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _cnicCtrl.dispose();
    _expMonthCtrl.dispose();
    _expYearCtrl.dispose();
    super.dispose();
  }

  InputDecoration _input(String label, {String? hint}) => InputDecoration(
        labelText: label,
        hintText: hint,
        isDense: true,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Theme.of(context).dividerColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppTheme.primary, width: 1.4),
        ),
      );

  void _continue() {
    final capacity = double.tryParse(_capacityCtrl.text.trim());
    final fee = double.tryParse(_feeCtrl.text.trim());
    if (capacity == null || capacity <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter valid capacity in kg.')),
      );
      return;
    }
    if (fee == null || fee < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid fee per kg.')),
      );
      return;
    }
    ref.read(tripDraftProvider.notifier).updateCapacity(
          capacityKg: _capacityCtrl.text,
          feePerKg: _feeCtrl.text,
          expectedEarning: _budgetCtrl.text,
          travelerName: _nameCtrl.text,
          travelerEmail: _emailCtrl.text,
          travelerPhone: _phoneCtrl.text,
          travelerCnic: _cnicCtrl.text,
          expMonth: _expMonthCtrl.text,
          expYear: _expYearCtrl.text,
        );
    context.push('/trip/new/summary');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, color: theme.colorScheme.onSurface),
          onPressed: () => context.pop(),
        ),
        title: const Text('Trip details'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(0),
          child: Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text('Step 2 of 3', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 30),
        children: [
          _Card(
            title: 'Luggage / Capacity',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Available capacity (kg)',
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                TextField(
                  controller: _capacityCtrl,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: _input('Capacity', hint: '10'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _Card(
            title: 'Pricing',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Fees per kg (PKR)',
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                TextField(
                  controller: _feeCtrl,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: _input('Fees per kg', hint: '1500'),
                ),
                const SizedBox(height: 12),
                Text('Budget / expected earning (PKR)',
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                TextField(
                  controller: _budgetCtrl,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: _input('Budget', hint: '50000'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _Card(
            title: 'Traveler information',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(controller: _nameCtrl, decoration: _input('Name', hint: 'Ali Raza')),
                const SizedBox(height: 10),
                TextField(
                    controller: _emailCtrl,
                    decoration: _input('Email', hint: 'ali@example.com'),
                    keyboardType: TextInputType.emailAddress),
                const SizedBox(height: 10),
                TextField(
                    controller: _phoneCtrl,
                    decoration: _input('Phone', hint: '+92 300 1234567'),
                    keyboardType: TextInputType.phone),
                const SizedBox(height: 10),
                TextField(
                    controller: _cnicCtrl,
                    decoration: _input('CNIC', hint: '35202-xxxxxxx-x'),
                    keyboardType: TextInputType.number),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                          controller: _expMonthCtrl,
                          decoration: _input('Exp Month', hint: '07'),
                          keyboardType: TextInputType.number),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                          controller: _expYearCtrl,
                          decoration: _input('Exp Year', hint: '2028'),
                          keyboardType: TextInputType.number),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'If previously added, fields preload and stay editable.',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: _continue,
              child: const Text(
                'Continue',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.title, required this.child});
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Text(
              title,
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}


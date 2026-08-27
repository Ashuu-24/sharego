import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers.dart';
import '../common/widgets.dart';
import 'booking_draft.dart';

class BookingDetailsFormScreen extends ConsumerStatefulWidget {
  const BookingDetailsFormScreen({super.key});

  @override
  ConsumerState<BookingDetailsFormScreen> createState() =>
      _BookingDetailsFormScreenState();
}

class _BookingDetailsFormScreenState
    extends ConsumerState<BookingDetailsFormScreen> {
  late final TextEditingController senderNameCtrl;
  late final TextEditingController senderEmailCtrl;
  late final TextEditingController senderPhoneCtrl;
  late final TextEditingController itemNameCtrl;
  late final TextEditingController itemWeightCtrl;
  late final TextEditingController itemDescCtrl;
  late final TextEditingController itemPriceCtrl;
  String? _formError;

  @override
  void initState() {
    super.initState();
    final draft = ref.read(bookingDraftProvider);
    senderNameCtrl = TextEditingController(text: draft.senderName);
    senderEmailCtrl = TextEditingController(text: draft.senderEmail);
    senderPhoneCtrl = TextEditingController(text: draft.senderPhone);
    itemNameCtrl = TextEditingController(text: draft.itemName);
    itemWeightCtrl = TextEditingController(
      text: draft.itemWeight.isNotEmpty
          ? draft.itemWeight
          : draft.weightKg.toStringAsFixed(1),
    );
    itemDescCtrl = TextEditingController(text: draft.itemDescription);
    itemPriceCtrl = TextEditingController(text: draft.itemPrice);
    if (draft.senderName.isEmpty) _autoFillFromProfile();
  }

  Future<void> _autoFillFromProfile() async {
    try {
      final profile = await ref.read(profileServiceProvider).getMe();
      if (!mounted) return;
      final name = profile['name']?.toString() ?? '';
      final email = profile['email']?.toString() ?? '';
      final phone = profile['phone']?.toString() ?? '';
      setState(() {
        if (senderNameCtrl.text.isEmpty && name.isNotEmpty) senderNameCtrl.text = name;
        if (senderEmailCtrl.text.isEmpty && email.isNotEmpty) senderEmailCtrl.text = email;
        if (senderPhoneCtrl.text.isEmpty && phone.isNotEmpty) senderPhoneCtrl.text = phone;
      });
    } catch (_) {
      // Silently fail — user can fill manually
    }
  }

  @override
  void dispose() {
    senderNameCtrl.dispose();
    senderEmailCtrl.dispose();
    senderPhoneCtrl.dispose();
    itemNameCtrl.dispose();
    itemWeightCtrl.dispose();
    itemDescCtrl.dispose();
    itemPriceCtrl.dispose();
    super.dispose();
  }

  void _continue() {
    final weight = double.tryParse(itemWeightCtrl.text.trim());
    final price = double.tryParse(itemPriceCtrl.text.trim());
    if (senderEmailCtrl.text.trim().isEmpty ||
        !senderEmailCtrl.text.contains('@')) {
      setState(() => _formError = 'Enter a valid sender email.');
      return;
    }
    if (itemNameCtrl.text.trim().length < 3) {
      setState(() => _formError = 'Item name must be at least 3 characters.');
      return;
    }
    if (weight == null || weight <= 0) {
      setState(() => _formError = 'Enter valid item weight in kg.');
      return;
    }
    if (price == null || price < 0) {
      setState(() => _formError = 'Enter valid item price.');
      return;
    }
    setState(() => _formError = null);
    ref.read(bookingDraftProvider.notifier).updateDetails(
          senderName: senderNameCtrl.text,
          senderEmail: senderEmailCtrl.text,
          senderPhone: senderPhoneCtrl.text,
          itemName: itemNameCtrl.text,
          itemWeight: itemWeightCtrl.text,
          itemDescription: itemDescCtrl.text,
          itemPrice: itemPriceCtrl.text,
        );
    context.go('/book/review');
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
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Enter Full Details',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 18),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: theme.dividerColor),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Center(
                      child: Text(
                        'Sender Info / Buyer Contact',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    _LabelField(
                      label: 'Name:',
                      controller: senderNameCtrl,
                    ),
                    _LabelField(
                      label: 'Email:',
                      controller: senderEmailCtrl,
                      keyboardType: TextInputType.emailAddress,
                    ),
                    _LabelField(
                      label: 'Phone:',
                      controller: senderPhoneCtrl,
                      keyboardType: TextInputType.phone,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: theme.dividerColor),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Center(
                      child: Text(
                        'Item Info',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    _LabelField(
                      label: 'Name:',
                      controller: itemNameCtrl,
                    ),
                    _LabelField(
                      label: 'Weight:',
                      controller: itemWeightCtrl,
                      keyboardType: TextInputType.number,
                    ),
                    _LabelField(
                      label: 'Description:',
                      controller: itemDescCtrl,
                      maxLines: 3,
                    ),
                    _LabelField(
                      label: 'Item Price:',
                      controller: itemPriceCtrl,
                      keyboardType: TextInputType.number,
                    ),
                  ],
                ),
              ),
              if (_formError != null) ...[
                const SizedBox(height: 12),
                ErrorBanner(_formError!),
              ],
              const SizedBox(height: 28),
              LoadingButton(
                onPressed: _continue,
                label: 'Continue',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LabelField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final int maxLines;
  final TextInputType? keyboardType;

  const _LabelField({
    required this.label,
    required this.controller,
    this.maxLines = 1,
    this.keyboardType,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.onSurface),
          ),
          const SizedBox(height: 4),
          TextField(
            controller: controller,
            maxLines: maxLines,
            keyboardType: keyboardType,
            decoration: const InputDecoration(
              isDense: true,
              border: OutlineInputBorder(),
            ),
          ),
        ],
      ),
    );
  }
}


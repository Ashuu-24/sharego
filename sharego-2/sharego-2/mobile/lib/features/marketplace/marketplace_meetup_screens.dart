import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/app_theme.dart';
import '../../core/providers.dart';
import '../common/widgets.dart';

class MeetupCreateScreen extends ConsumerStatefulWidget {
  const MeetupCreateScreen({super.key, required this.id});
  final String id;

  @override
  ConsumerState<MeetupCreateScreen> createState() => _MeetupCreateScreenState();
}

class _MeetupCreateScreenState extends ConsumerState<MeetupCreateScreen> {
  final _placeCtrl = TextEditingController();
  DateTime? _scheduledDate;
  TimeOfDay? _scheduledTime;
  bool _submitting = false;
  String? _error;
  String? _otpDev;
  int? _meetupId;

  Future<void> _pickDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 90)),
    );
    if (date != null && mounted) setState(() => _scheduledDate = date);
  }

  Future<void> _pickTime() async {
    final time = await showTimePicker(context: context, initialTime: const TimeOfDay(hour: 14, minute: 0));
    if (time != null && mounted) setState(() => _scheduledTime = time);
  }

  Future<void> _submit() async {
    final place = _placeCtrl.text.trim();
    if (place.isEmpty) {
      setState(() => _error = 'Enter a meetup place.');
      return;
    }
    if (_scheduledDate == null || _scheduledTime == null) {
      setState(() => _error = 'Pick a date and time.');
      return;
    }

    final dt = DateTime(
      _scheduledDate!.year,
      _scheduledDate!.month,
      _scheduledDate!.day,
      _scheduledTime!.hour,
      _scheduledTime!.minute,
    );

    setState(() { _submitting = true; _error = null; });
    try {
      final service = ref.read(marketplaceServiceProvider);
      final result = await service.createMeetup(
        listingId: int.parse(widget.id),
        placeText: place,
        scheduledTs: dt,
      );
      if (mounted) {
        setState(() {
          _submitting = false;
          _meetupId = result['id'] as int?;
          _otpDev = result['otp_dev']?.toString();
        });
      }
    } catch (e) {
      if (mounted) {
        String errorMsg = e.toString().replaceFirst('Exception: ', '');
        if (e is DioException && e.response != null) {
          final data = e.response?.data;
          if (data is Map && data['detail'] is String) {
            errorMsg = data['detail'];
          } else if (data is Map && data['detail'] is Map) {
            errorMsg = data['detail']['message']?.toString() ?? errorMsg;
          } else {
            errorMsg = 'Error ${e.response?.statusCode}: ${e.response?.data}';
          }
        }
        setState(() { _error = errorMsg; _submitting = false; });
      }
    }
  }

  @override
  void dispose() {
    _placeCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(elevation: 0, title: const Text('Schedule Meetup')),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
        child: _meetupId != null ? _buildSuccess() : _buildForm(),
      ),
    );
  }

  Widget _buildSuccess() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.check_circle, color: AppTheme.success, size: 64),
        const SizedBox(height: 16),
        const Text('Meetup scheduled!', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
        if (_otpDev != null) ...[
          const SizedBox(height: 12),
          const Text('Meetup OTP (share with buyer):', style: TextStyle(fontSize: 13, color: Colors.black54)),
          const SizedBox(height: 6),
          Text(_otpDev!, style: const TextStyle(fontSize: 32, letterSpacing: 4, fontWeight: FontWeight.w800)),
        ],
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton(
            onPressed: () => context.push('/market/${widget.id}/meetup/otp', extra: _meetupId),
            child: const Text('Confirm meetup with OTP'),
          ),
        ),
        const SizedBox(height: 10),
        TextButton(
          onPressed: () => context.go('/market/${widget.id}'),
          child: const Text('Back to listing'),
        ),
      ],
    );
  }

  Widget _buildForm() {
    final dateText = _scheduledDate != null
        ? '${_scheduledDate!.day}/${_scheduledDate!.month}/${_scheduledDate!.year}'
        : 'Select date';
    final timeText = _scheduledTime != null ? _scheduledTime!.format(context) : 'Select time';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Where will you meet?', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
        const SizedBox(height: 12),
        TextField(
          controller: _placeCtrl,
          decoration: InputDecoration(
            labelText: 'Meetup location',
            hintText: 'e.g. McDonald\'s DHA Phase 5',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _pickDate,
                icon: const Icon(Icons.calendar_today, size: 18),
                label: Text(dateText),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _pickTime,
                icon: const Icon(Icons.access_time, size: 18),
                label: Text(timeText),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
          ],
        ),
        if (_error != null) ...[
          const SizedBox(height: 12),
          ErrorBanner(_error!),
        ],
        const Spacer(),
        LoadingButton(
          onPressed: _submit,
          label: 'Schedule meetup',
          isLoading: _submitting,
        ),
      ],
    );
  }
}

class MeetupOtpScreen extends ConsumerStatefulWidget {
  const MeetupOtpScreen({super.key, required this.id});
  final String id;

  @override
  ConsumerState<MeetupOtpScreen> createState() => _MeetupOtpScreenState();
}

class _MeetupOtpScreenState extends ConsumerState<MeetupOtpScreen> {
  final _otpCtrl = TextEditingController();
  bool _submitting = false;
  String? _error;
  bool _confirmed = false;

  Future<void> _confirm() async {
    final otp = _otpCtrl.text.trim();
    if (otp.length < 4) {
      setState(() => _error = 'Enter at least 4 digits.');
      return;
    }

    setState(() { _submitting = true; _error = null; });
    try {
      final service = ref.read(marketplaceServiceProvider);
      // The meetup ID is passed as extra from the previous screen.
      // If not available, use listing ID as a fallback for the demo.
      final meetupId = ModalRoute.of(context)?.settings.arguments as int? ?? int.tryParse(widget.id) ?? 0;
      await service.confirmMeetup(meetupId, otp);
      if (mounted) setState(() { _confirmed = true; _submitting = false; });
    } catch (e) {
      if (mounted) {
        String errorMsg = e.toString().replaceFirst('Exception: ', '');
        if (e is DioException && e.response != null) {
          final data = e.response?.data;
          if (data is Map && data['detail'] is String) {
            errorMsg = data['detail'];
          } else {
            errorMsg = 'Error ${e.response?.statusCode}: ${e.response?.data}';
          }
        }
        setState(() { _error = errorMsg; _submitting = false; });
      }
    }
  }

  @override
  void dispose() {
    _otpCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(elevation: 0, title: const Text('Confirm Meetup')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: _confirmed ? _buildSuccess() : _buildForm(),
      ),
    );
  }

  Widget _buildSuccess() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.handshake, color: AppTheme.success, size: 64),
          const SizedBox(height: 16),
          const Text('Meetup confirmed!', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
          const SizedBox(height: 8),
          const Text('You can now mark this listing as sold.', style: TextStyle(color: Colors.black54)),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: () => context.push('/market/${widget.id}/mark-sold'),
              child: const Text('Mark as sold'),
            ),
          ),
          const SizedBox(height: 10),
          TextButton(
            onPressed: () => context.go('/market/${widget.id}'),
            child: const Text('Back to listing'),
          ),
        ],
      ),
    );
  }

  Widget _buildForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Enter the meetup OTP', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
        const SizedBox(height: 6),
        const Text('The buyer shares this code at the meetup point.', style: TextStyle(color: Colors.black54)),
        const SizedBox(height: 20),
        TextField(
          controller: _otpCtrl,
          maxLength: 6,
          keyboardType: TextInputType.number,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 24, letterSpacing: 4, fontWeight: FontWeight.w800),
          decoration: InputDecoration(
            hintText: '123456',
            counterText: '',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
        if (_error != null) ...[
          const SizedBox(height: 8),
          ErrorBanner(_error!),
        ],
        const Spacer(),
        LoadingButton(
          onPressed: _confirm,
          label: 'Confirm meetup',
          isLoading: _submitting,
        ),
      ],
    );
  }
}

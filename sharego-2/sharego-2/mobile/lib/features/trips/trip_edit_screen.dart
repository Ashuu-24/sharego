import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers.dart';

class TripEditScreen extends ConsumerStatefulWidget {
  const TripEditScreen({super.key, required this.id, this.trip});
  final String id;
  final Map<String, dynamic>? trip;

  @override
  ConsumerState<TripEditScreen> createState() => _TripEditScreenState();
}

class _TripEditScreenState extends ConsumerState<TripEditScreen> {
  TextEditingController? routeCtrl;
  TextEditingController? timeCtrl;
  TextEditingController? fromCtrl;
  TextEditingController? toCtrl;
  TextEditingController? capacityCtrl;
  TextEditingController? rateCtrl;

  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Map<String, String> _normalizeTrip(Map<String, dynamic>? raw) {
    if (raw == null) {
      return {
        'route': '',
        'time': '',
        'fromAirport': '',
        'toAirport': '',
        'capacity': '',
        'rate': '',
      };
    }
    final from = raw['fromAirport']?.toString() ??
        raw['origin_airport']?.toString() ??
        '';
    final to = raw['toAirport']?.toString() ?? raw['dest_airport']?.toString() ?? '';
    final route = raw['route']?.toString() ??
        (from.isNotEmpty && to.isNotEmpty ? '$from → $to' : '');
    final dateRaw = raw['time'] ?? raw['date'];
    final time = dateRaw?.toString() ?? '';
    final cap = raw['capacity']?.toString() ??
        raw['capacity_kg']?.toString() ??
        '';
    final rate = raw['rate']?.toString() ?? raw['fee_pkr']?.toString() ?? '';
    return {
      'route': route,
      'time': time,
      'fromAirport': from,
      'toAirport': to,
      'capacity': cap,
      'rate': rate,
    };
  }

  Future<void> _load() async {
    Map<String, dynamic>? data = widget.trip;
    final tripId = int.tryParse(widget.id);
    if (data == null && tripId != null) {
      try {
        data = await ref.read(tripServiceProvider).getTrip(tripId);
      } catch (e) {
        if (mounted) {
          setState(() {
            _error = e.toString().replaceFirst('Exception: ', '');
            _loading = false;
          });
        }
        return;
      }
    }
    final n = _normalizeTrip(data);
    if (!mounted) return;
    setState(() {
      routeCtrl = TextEditingController(text: n['route']);
      timeCtrl = TextEditingController(text: n['time']);
      fromCtrl = TextEditingController(text: n['fromAirport']);
      toCtrl = TextEditingController(text: n['toAirport']);
      capacityCtrl = TextEditingController(text: n['capacity']);
      rateCtrl = TextEditingController(text: n['rate']);
      _loading = false;
    });
  }

  @override
  void dispose() {
    routeCtrl?.dispose();
    timeCtrl?.dispose();
    fromCtrl?.dispose();
    toCtrl?.dispose();
    capacityCtrl?.dispose();
    rateCtrl?.dispose();
    super.dispose();
  }

  void _save() {
    final r = routeCtrl;
    if (r == null) return;
    final updated = {
      'id': widget.id,
      'route': r.text,
      'time': timeCtrl!.text,
      'fromAirport': fromCtrl!.text,
      'toAirport': toCtrl!.text,
      'capacity': capacityCtrl!.text,
      'rate': rateCtrl!.text,
    };
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Trip details saved')),
    );
    context.pop(updated);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: Text('Edit ${widget.id}'), elevation: 0),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    if (_error != null) {
      return Scaffold(
        appBar: AppBar(title: Text('Edit ${widget.id}'), elevation: 0),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(_error!, textAlign: TextAlign.center),
                const SizedBox(height: 16),
                FilledButton(onPressed: _load, child: const Text('Retry')),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Edit ${widget.id}'),
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          _LabeledField(label: 'Route', controller: routeCtrl!),
          const SizedBox(height: 12),
          _LabeledField(label: 'Date & Time', controller: timeCtrl!),
          const SizedBox(height: 12),
          _LabeledField(
            label: 'From airport',
            controller: fromCtrl!,
            maxLines: 2,
          ),
          const SizedBox(height: 12),
          _LabeledField(
            label: 'To airport',
            controller: toCtrl!,
            maxLines: 2,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _LabeledField(label: 'Capacity', controller: capacityCtrl!),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _LabeledField(label: 'Rate', controller: rateCtrl!),
              ),
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: _save,
              style: ElevatedButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Save changes',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LabeledField extends StatelessWidget {
  const _LabeledField({
    required this.label,
    required this.controller,
    this.maxLines = 1,
  });
  final String label;
  final TextEditingController controller;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context)
              .textTheme
              .bodyMedium
              ?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          maxLines: maxLines,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            isDense: true,
          ),
        ),
      ],
    );
  }
}
